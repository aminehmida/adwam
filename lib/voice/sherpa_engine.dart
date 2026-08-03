import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'speech_engine.dart';

/// [SpeechEngine] backed by sherpa-onnx running the Arabic FastConformer CTC
/// branch exported by tool/export_speech_model.py.
///
/// Every call here is blocking FFI, so the engine must be created and used on
/// the same isolate — and not the UI one. A native pointer cannot be handed
/// across isolates, which is why the whole engine, rather than a single
/// transcribe call, lives wherever the audio pipeline puts it.
class SherpaSpeechEngine implements SpeechEngine {
  sherpa.OfflineRecognizer? _recognizer;

  /// Two threads: enough to keep a short utterance ahead of real time on a
  /// phone without competing with the audio callback for cores.
  static const _threads = 2;

  @override
  Future<void> load(String modelDirectory) async {
    sherpa.initBindings();
    _recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          nemoCtc: sherpa.OfflineNemoEncDecCtcModelConfig(
            model: '$modelDirectory/model.int8.onnx',
          ),
          tokens: '$modelDirectory/tokens.txt',
          numThreads: _threads,
          debug: false,
        ),
      ),
    );
  }

  @override
  Future<String> transcribe(Float32List samples) async {
    final recognizer = _recognizer;
    if (recognizer == null || samples.isEmpty) return '';
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: speechSampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text;
    } finally {
      stream.free();
    }
  }

  @override
  Future<void> dispose() async {
    _recognizer?.free();
    _recognizer = null;
  }
}
