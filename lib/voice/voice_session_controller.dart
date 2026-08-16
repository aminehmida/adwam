import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../build_channel.dart';
import 'model_store.dart';
import 'phrase_matcher.dart';
import 'speech_engine.dart';
import 'transcriber.dart';

/// The voice detector ships in the app: it is under a megabyte, and without it
/// there is nothing to segment the microphone with.
const _vadAsset = 'assets/voice/silero_vad.onnx';

enum VoiceStatus {
  off,

  /// Loading the model and opening the microphone. Briefly visible; the model
  /// takes a moment to map in.
  starting,
  listening,

  /// The speech model has not been downloaded yet.
  needsModel,
  needsMicPermission,

  /// Something failed outright — recorded in [failure] for the dev harness.
  failed,
}

/// A running account of what voice mode is actually doing, for the dev-flavour
/// debug bar.
///
/// The pipeline has four places it can quietly stop — the microphone delivering
/// nothing, the detector finding no speech in it, the recogniser rendering no
/// words, the matcher rejecting the words it did get — and from the outside all
/// four look the same: a counter that will not move. These fields tell them
/// apart.
class VoiceDiagnostics {
  /// Bytes of audio off the microphone, and the loudest sample in the last
  /// chunk. A level pinned at zero means the microphone, not the recogniser.
  int bytes = 0;
  double level = 0;

  /// Chunks the detector has taken, and stretches of speech it cut from them.
  int chunks = 0;
  int segments = 0;

  /// Utterances the recogniser rendered into words.
  int utterances = 0;

  String? lastTranscript;

  /// The closest dhikr to the last utterance and how close it was, whether or
  /// not it cleared the bar.
  String? lastMatchId;
  double? lastScore;
  bool accepted = false;

  /// Whether the last acceptance came from hearing a dhikr's closing words
  /// rather than the whole of it — weaker evidence, worth seeing.
  bool byEnding = false;

  String? error;

  void reset() {
    bytes = 0;
    level = 0;
    chunks = 0;
    segments = 0;
    utterances = 0;
    lastTranscript = null;
    lastMatchId = null;
    lastScore = null;
    accepted = false;
    byEnding = false;
    error = null;
  }
}

/// Where the phrases still worth listening for come from. Read afresh for
/// every utterance, so finishing a dhikr takes it out of contention and the
/// identical one below it starts filling instead.
typedef MatcherSource = PhraseMatcher Function();

/// Runs voice mode for one open session: microphone in, recognised dhikrs out.
///
/// It deliberately knows nothing about progress or scrolling. It reports which
/// dhikr was heard and how many times; the session screen decides what that
/// means, through exactly the same path a tap takes.
class VoiceSessionController extends ChangeNotifier {
  final ModelStore modelStore;
  final ModelSpec spec;

  VoiceSessionController({required this.modelStore, required this.spec});

  final _recorder = AudioRecorder();
  final _matches = StreamController<PhraseMatch>.broadcast();
  Transcriber? _transcriber;
  StreamSubscription<Uint8List>? _microphone;
  StreamSubscription<TranscriberEvent>? _heard;

  VoiceStatus _status = VoiceStatus.off;
  VoiceStatus get status => _status;

  Object? failure;

  /// Everything the debug bar shows. Kept up to date whatever the channel —
  /// it costs a handful of fields — but only ever displayed on the dev build.
  final diagnostics = VoiceDiagnostics();

  /// Dhikrs recognised, in the order they were said.
  Stream<PhraseMatch> get matches => _matches.stream;

  /// Reports a match as though it had been heard. The recogniser lives on
  /// another isolate behind native code, so this is how a test drives the
  /// screen's voice path without a microphone.
  @visibleForTesting
  void emitMatch(PhraseMatch match) => _matches.add(match);

  bool get isOn => _status == VoiceStatus.listening ||
      _status == VoiceStatus.starting;

  Future<void> start(MatcherSource source) async {
    if (isOn) return;
    diagnostics.reset();
    _set(VoiceStatus.starting);

    if (!await modelStore.isInstalled(spec)) {
      return _set(VoiceStatus.needsModel);
    }
    if (!await _recorder.hasPermission()) {
      return _set(VoiceStatus.needsMicPermission);
    }

    try {
      final directory = await modelStore.directoryFor(spec);
      _transcriber = await Transcriber.start(
        engine: spec.engine,
        modelDirectory: directory.path,
        vadModelPath: await _extractVadModel(),
      );
      _heard = _transcriber!.events.listen(_onTranscriberEvent(source));

      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: speechSampleRate,
          numChannels: 1,
          device: await _preferredInput(),
          // Adhkar are often said under the breath, so lift the quiet end.
          autoGain: true,
          // Both of these are tuned for conversation and treat a whisper as
          // the noise they are meant to remove.
          noiseSuppress: false,
          echoCancel: false,
        ),
      );
      _microphone = stream.listen(
        (chunk) {
          // Measured here rather than in the isolate so the bar can tell a
          // silent microphone from a busy one that nothing matches.
          diagnostics.level = _loudnessOf(chunk);
          diagnostics.bytes += chunk.length;
          _transcriber?.addAudio(chunk);
          notifyListeners();
        },
        onError: (Object error) => _fail(error),
      );
      _set(VoiceStatus.listening);
    } catch (error) {
      await _teardown();
      _fail(error);
    }
  }

  Future<void> stop() async {
    if (_status == VoiceStatus.off) return;
    await _teardown();
    _set(VoiceStatus.off);
  }

  /// Records what the isolate reports and, for an utterance, decides whether
  /// it was a dhikr. The closest candidate is kept even when it is rejected:
  /// "heard you, scored 0.41" and "heard nothing" are different problems.
  void Function(TranscriberEvent) _onTranscriberEvent(MatcherSource source) {
    return (event) {
      if (event.chunks > 0) diagnostics.chunks = event.chunks;
      if (event.segments > 0) diagnostics.segments = event.segments;
      if (event.error != null) {
        _fail(event.error!);
        return;
      }
      final text = event.transcript;
      if (text != null) {
        diagnostics.utterances++;
        diagnostics.lastTranscript = text;
        final matcher = source();
        final counted = matcher.match(text);
        // What to show when nothing was counted: how close the nearest dhikr
        // came, rather than a bare "no".
        final closest = counted ?? matcher.best(text);
        diagnostics.lastMatchId = closest?.dhikrId;
        diagnostics.lastScore = closest?.score;
        diagnostics.accepted = counted != null;
        diagnostics.byEnding = counted?.byEnding ?? false;
        _log('heard "$text" -> ${closest?.dhikrId ?? "nothing"} '
            '${closest?.score.toStringAsFixed(2) ?? ""} '
            '${counted == null ? "rejected" : counted.byEnding ? "finished" : "counted"}');
        if (counted != null) _matches.add(counted);
      }
      notifyListeners();
    };
  }

  /// Peak sample of a 16-bit PCM chunk, 0..1.
  static double _loudnessOf(Uint8List pcm16) {
    var peak = 0;
    for (var i = 0; i + 1 < pcm16.length; i += 2) {
      var sample = pcm16[i] | (pcm16[i + 1] << 8);
      if (sample > 32767) sample -= 65536;
      final magnitude = sample.abs();
      if (magnitude > peak) peak = magnitude;
    }
    return peak / 32768.0;
  }

  /// An external microphone sits centimetres from the mouth, which is worth
  /// more for a whispered dhikr than any amount of tuning — so it is preferred
  /// whenever one is plugged in.
  Future<InputDevice?> _preferredInput() async {
    try {
      final devices = await _recorder.listInputDevices();
      for (final device in devices) {
        final label = device.label.toLowerCase();
        if (label.contains('headset') ||
            label.contains('headphone') ||
            label.contains('bluetooth') ||
            label.contains('earbud')) {
          return device;
        }
      }
    } catch (_) {
      // Device enumeration is best-effort; the default input still works.
    }
    return null;
  }

  /// The detector needs a real file, and an asset is not one.
  Future<String> _extractVadModel() async {
    final support = await getApplicationSupportDirectory();
    final file = File('${support.path}/voice-models/silero_vad.onnx');
    final data = await rootBundle.load(_vadAsset);
    if (!file.existsSync() ||
        await file.length() != data.lengthInBytes) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.path;
  }

  Future<void> _teardown() async {
    await _microphone?.cancel();
    _microphone = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    await _heard?.cancel();
    _heard = null;
    await _transcriber?.stop();
    _transcriber = null;
  }

  void _fail(Object error) {
    failure = error;
    diagnostics.error = error.toString();
    _set(VoiceStatus.failed);
    // A failure mid-listening leaves the microphone open; nothing downstream
    // will use what it hears.
    unawaited(_teardown());
  }

  void _set(VoiceStatus status) {
    if (_status == status) return;
    _status = status;
    _log('status: ${status.name}');
    notifyListeners();
  }

  /// Mirrors the debug bar into logcat, so a session can be diagnosed from
  /// `adb logcat` without watching the screen while reciting. Dev builds only;
  /// [isDevChannel] is a const, so prod drops these calls entirely.
  static void _log(String message) {
    if (isDevChannel) debugPrint('[voice] $message');
  }

  @override
  void dispose() {
    unawaited(_teardown().then((_) => _recorder.dispose()));
    unawaited(_matches.close());
    super.dispose();
  }
}
