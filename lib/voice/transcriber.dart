import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'sherpa_engine.dart';
import 'speech_engine.dart';

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
  final StreamController<String> _utterances;

  Transcriber._(this._isolate, this._audio, this._incoming, this._utterances);

  /// Phrases heard, one per detected stretch of speech. Never empty strings.
  Stream<String> get utterances => _utterances.stream;

  static Future<Transcriber> start({
    required VoiceEngine engine,
    required String modelDirectory,
    required String vadModelPath,
  }) async {
    final incoming = ReceivePort();
    final isolate = await Isolate.spawn(
      _transcriberMain,
      _Setup(
        reply: incoming.sendPort,
        engine: engine,
        modelDirectory: modelDirectory,
        vadModelPath: vadModelPath,
      ),
      debugName: 'adwam-transcriber',
    );

    final utterances = StreamController<String>.broadcast();
    final ready = Completer<SendPort>();
    incoming.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message is String) {
        utterances.add(message);
      }
    });
    return Transcriber._(isolate, await ready.future, incoming, utterances);
  }

  /// Feeds one chunk of 16-bit mono PCM at [speechSampleRate], as it comes off
  /// the microphone.
  void addAudio(Uint8List pcm16) => _audio.send(pcm16);

  Future<void> stop() async {
    _audio.send(_stopSignal);
    await _utterances.close();
    _incoming.close();
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

Future<void> _transcriberMain(_Setup setup) async {
  sherpa.initBindings();

  final detector = sherpa.VoiceActivityDetector(
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

  final engine = SherpaSpeechEngine();
  await engine.load(setup.modelDirectory);

  final audio = ReceivePort();
  setup.reply.send(audio.sendPort);

  await for (final message in audio) {
    if (message == _stopSignal) break;
    if (message is! Uint8List) continue;
    detector.acceptWaveform(_toFloat32(message));
    while (!detector.isEmpty()) {
      final segment = detector.front();
      detector.pop();
      final text = await engine.transcribe(segment.samples);
      if (text.trim().isNotEmpty) setup.reply.send(text);
    }
  }

  detector.free();
  await engine.dispose();
  audio.close();
}

/// 16-bit little-endian PCM as the -1..1 floats the models expect.
Float32List _toFloat32(Uint8List pcm16) {
  final samples = pcm16.buffer.asInt16List(
    pcm16.offsetInBytes,
    pcm16.lengthInBytes ~/ 2,
  );
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] / 32768.0;
  }
  return out;
}
