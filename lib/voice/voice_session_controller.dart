import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  StreamSubscription<String>? _heard;

  VoiceStatus _status = VoiceStatus.off;
  VoiceStatus get status => _status;

  Object? failure;

  /// The last thing the recogniser rendered, matched or not. Only used by the
  /// dev-flavour harness; the app itself never shows a transcript.
  String? lastTranscript;

  /// Dhikrs recognised, in the order they were said.
  Stream<PhraseMatch> get matches => _matches.stream;

  bool get isOn => _status == VoiceStatus.listening ||
      _status == VoiceStatus.starting;

  Future<void> start(MatcherSource source) async {
    if (isOn) return;
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
      _heard = _transcriber!.utterances.listen((text) {
        lastTranscript = text;
        final match = source().match(text);
        if (match != null) _matches.add(match);
      });

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
        (chunk) => _transcriber?.addAudio(chunk),
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
    _set(VoiceStatus.failed);
  }

  void _set(VoiceStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_teardown().then((_) => _recorder.dispose()));
    unawaited(_matches.close());
    super.dispose();
  }
}
