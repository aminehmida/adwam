import 'model_store.dart';
import 'speech_engine.dart';

/// Release tag holding the speech models. Kept apart from the app's own `v*`
/// tags so it neither triggers the release workflow nor gets swept up by the
/// dev-build pruning, and so a model can be replaced without cutting an app
/// release.
const _modelsTag = 'models-v1';

Uri _release(String file) => Uri.parse(
      'https://github.com/aminehmida/adwam/releases/download/$_modelsTag/$file',
    );

/// The Arabic FastConformer CTC branch, quantised to int8.
///
/// Produced by tool/export_speech_model.py from NVIDIA's
/// `stt_ar_fastconformer_hybrid_large_pcd_v1.0` (CC-BY-4.0), which is trained
/// on Arabic *with* diacritics — the register the adhkar are written in. The
/// attribution is shown in the app's licences screen.
final fastConformerArabic = ModelSpec(
  engine: VoiceEngine.fastConformer,
  version: '1',
  files: [
    ModelFile(
      name: 'model.int8.onnx',
      source: _release('model.int8.onnx'),
      bytes: 131652659,
      sha256:
          'e51c9724336dc90e17763b73225920670c9a66e556c2f4293bfe7575808fe3d6',
    ),
    ModelFile(
      name: 'tokens.txt',
      source: _release('tokens.txt'),
      bytes: 12858,
      sha256:
          '9b938381a19a69bb279cdcfc299419f25a049ea1de192e0d10317274a0f20074',
    ),
  ],
);
