import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_engine.dart';
import 'speech_engine.dart';

/// Something the recogniser isolate noticed, reported back so the dev-flavour
/// debug bar can show where a recitation got to — or where it stopped.
class TranscriberEvent {
  /// Text heard, when this event is an utterance.
  final String? transcript;

  /// A failure the isolate could not continue past. Recognition has stopped.
  final String? error;

  /// Audio chunks handed to the detector since the microphone opened.
  final int chunks;

  /// Stretches of speech the detector has cut out of them.
  final int segments;

  const TranscriberEvent({
    this.transcript,
    this.error,
    this.chunks = 0,
    this.segments = 0,
  });
}

/// Turns a stream of microphone audio into the phrases that were said.
///
/// All of it — voice detection and recognition — happens on its own isolate.
/// Recognition is blocking FFI, and native pointers cannot be passed between
/// isolates, so the engine has to live entirely where it is used. The UI
/// isolate only ever posts raw audio in and receives text back, which keeps a
/// slow utterance from stuttering the scroll of the session list.
class Transcriber {
  final Isolate _isolate;
  final SendPort _audio;
  final ReceivePort _incoming;
  final ReceivePort _errors;
  final StreamController<TranscriberEvent> _events;

  Transcriber._(
    this._isolate,
    this._audio,
    this._incoming,
    this._errors,
    this._events,
  );

  /// Utterances, running counts and failures, in the order they happen.
  Stream<TranscriberEvent> get events => _events.stream;

  /// Loading the model can fail for reasons only visible inside the isolate —
  /// a missing file, an unreadable model, a native abort. Every one of those
  /// used to leave this future hanging and voice mode stuck on "starting", so
  /// startup failures are now surfaced as an error rather than a silence.
  static Future<Transcriber> start({
    required VoiceEngine engine,
    required String modelDirectory,
    required String vadModelPath,
  }) async {
    final incoming = ReceivePort();
    final errors = ReceivePort();
    final events = StreamController<TranscriberEvent>.broadcast();
    final ready = Completer<SendPort>();

    void fail(Object error) {
      if (!ready.isCompleted) ready.completeError(error);
      if (!events.isClosed) {
        events.add(TranscriberEvent(error: error.toString()));
      }
    }

    // An uncaught error in the isolate arrives here as [error, stackTrace];
    // the isolate ending before it was ready arrives as null.
    errors.listen((message) {
      if (message is List && message.isNotEmpty) {
        fail(message.first ?? 'recogniser isolate failed');
      } else {
        fail('recogniser isolate stopped');
      }
    });

    incoming.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is TranscriberEvent) {
        if (!events.isClosed) events.add(message);
        if (message.error != null) fail(message.error!);
      }
    });

    final isolate = await Isolate.spawn(
      _transcriberMain,
      _Setup(
        reply: incoming.sendPort,
        engine: engine,
        modelDirectory: modelDirectory,
        vadModelPath: vadModelPath,
      ),
      onError: errors.sendPort,
      onExit: errors.sendPort,
      errorsAreFatal: true,
      debugName: 'adwam-transcriber',
    );

    try {
      final audio = await ready.future;
      return Transcriber._(isolate, audio, incoming, errors, events);
    } catch (_) {
      incoming.close();
      errors.close();
      isolate.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  /// Feeds one chunk of 16-bit mono PCM at [speechSampleRate], as it comes off
  /// the microphone.
  void addAudio(Uint8List pcm16) => _audio.send(pcm16);

  Future<void> stop() async {
    _audio.send(_stopSignal);
    await _events.close();
    _incoming.close();
    _errors.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

const _stopSignal = 'stop';

class _Setup {
  final SendPort reply;
  final VoiceEngine engine;
  final String modelDirectory;
  final String vadModelPath;

  const _Setup({
    required this.reply,
    required this.engine,
    required this.modelDirectory,
    required this.vadModelPath,
  });
}

/// How many chunks pass between progress reports. The microphone delivers many
/// small buffers a second and the bar only has to look alive.
const _reportEvery = 15;

Future<void> _transcriberMain(_Setup setup) async {
  late final sherpa.VoiceActivityDetector detector;
  late final SpeechEngine engine;
  try {
    sherpa.initBindings();
    detector = sherpa.VoiceActivityDetector(
      config: sherpa.VadModelConfig(
        sileroVad: sherpa.SileroVadModelConfig(
          model: setup.vadModelPath,
          // Adhkar are often said quietly, so the bar for "this is speech" sits
          // below the default. The cost is more segments offered to the
          // recogniser, which simply fail to match and cost nothing else.
          threshold: 0.35,
          // Short enough to cut between repetitions of a quick tasbih, but long
          // enough not to split a phrase at its internal pauses. Runs that do
          // get glued together are counted by the matcher instead.
          minSilenceDuration: 0.35,
          minSpeechDuration: 0.2,
          // A long dua runs far past the 5s default, and being cut mid-phrase
          // would leave nothing matchable.
          maxSpeechDuration: 30,
        ),
        sampleRate: speechSampleRate,
        debug: false,
      ),
      bufferSizeInSeconds: 60,
    );
    engine = SherpaSpeechEngine();
    await engine.load(setup.modelDirectory);
  } catch (error) {
    setup.reply.send(TranscriberEvent(error: 'load failed: $error'));
    return;
  }

  final audio = ReceivePort();
  setup.reply.send(audio.sendPort);

  var chunks = 0;
  var segments = 0;
  try {
    await for (final message in audio) {
      if (message == _stopSignal) break;
      if (message is! Uint8List) continue;
      chunks++;
      detector.acceptWaveform(_toFloat32(message));
      while (!detector.isEmpty()) {
        final segment = detector.front();
        detector.pop();
        segments++;
        final text = await engine.transcribe(segment.samples);
        setup.reply.send(TranscriberEvent(
          transcript: text.trim().isEmpty ? null : text,
          chunks: chunks,
          segments: segments,
        ));
      }
      if (chunks % _reportEvery == 0) {
        setup.reply.send(
          TranscriberEvent(chunks: chunks, segments: segments),
        );
      }
    }
  } catch (error) {
    setup.reply.send(TranscriberEvent(error: 'while listening: $error'));
  }

  detector.free();
  await engine.dispose();
  audio.close();
}

/// 16-bit little-endian PCM as the -1..1 floats the models expect.
Float32List _toFloat32(Uint8List pcm16) {
  // A chunk can arrive on an odd byte offset, which asInt16List refuses to
  // view; copying is cheap next to recognition and always aligned.
  final aligned = pcm16.offsetInBytes.isEven && pcm16.lengthInBytes.isEven
      ? pcm16
      : Uint8List.fromList(pcm16);
  final samples = aligned.buffer.asInt16List(
    aligned.offsetInBytes,
    aligned.lengthInBytes ~/ 2,
  );
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] / 32768.0;
  }
  return out;
}
