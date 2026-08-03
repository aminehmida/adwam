import 'dart:typed_data';

/// Sample rate every engine here expects. The mic is opened at this rate so
/// nothing has to resample on the way in.
const speechSampleRate = 16000;

/// Which recogniser turns an utterance into text.
///
/// Two are carried at once so they can be compared on real recitation rather
/// than argued about: one trained on diacritised Arabic, one on broadcast MSA.
/// The comparison runs on the dev channel; the release build ships the winner
/// and the loser's dependency is deleted outright — a plugin's native library
/// is linked into every flavour and does not tree-shake the way Dart does.
enum VoiceEngine {
  /// NVIDIA FastConformer CTC, exported from
  /// `nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0` (CC-BY-4.0) and
  /// quantised to int8. Trained on Arabic *with* diacritics, which is the
  /// register the adhkar are written and recited in.
  fastConformer,

  /// Vosk's `vosk-model-ar-mgb2-0.4`: broadcast Modern Standard Arabic. Its
  /// grammar-constraint feature is unavailable here — the model ships a
  /// precompiled static HCLG graph — so it decodes freely and the closed set
  /// is applied afterwards, exactly as for the other engine.
  vosk,
}

/// One way of turning a recorded utterance into text.
///
/// The audio pipeline and the UI only ever see this interface, so swapping
/// recognisers is a constructor change and tests can drive a whole session
/// from a scripted fake without a microphone.
abstract class SpeechEngine {
  /// Prepares the engine from an unpacked model directory. Called once, off
  /// the UI path — loading is slow and allocates a lot.
  Future<void> load(String modelDirectory);

  /// What was heard in [samples]: mono PCM at [speechSampleRate], normalised
  /// to -1..1.
  ///
  /// An empty result means the engine could render nothing, which the caller
  /// treats exactly like unrecognised speech: silence, and keep listening.
  Future<String> transcribe(Float32List samples);

  Future<void> dispose();
}
