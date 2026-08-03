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

  /// Vosk's `vosk-model-ar-mgb2-0.4`: broadcast Modern Standard Arabic.
  ///
  /// Not currently reachable. `vosk_flutter_service` 0.1.2 fails to build on
  /// Android under Flutter 3.44.6 — its Android module never produces the
  /// `org.vosk.vosk_flutter` package its own registration names, and the
  /// failure takes the sibling plugins' compilation down with it. Two other
  /// marks against it had already turned up: the Arabic model ships a
  /// precompiled static HCLG graph, so the grammar constraint that made Vosk
  /// attractive cannot bind to it, and the model unpacks to roughly 700 MB.
  /// The value stays here because the comparison is still worth making if a
  /// working binding appears.
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
