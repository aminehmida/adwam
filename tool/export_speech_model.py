#!/usr/bin/env python3
"""Export the Arabic speech model the app matches recitation with, to ONNX.

Adapted from sherpa-onnx's export-onnx-ctc-non-streaming.py (Xiaomi Corp.,
Fangjun Kuang, Apache-2.0) to work from a checkpoint already on disk instead
of downloading one.

Source model: nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0 (CC-BY-4.0) —
a FastConformer hybrid RNNT/CTC, 1024-token Arabic BPE, trained on Arabic
*with* diacritics, which is the register the adhkar are written in. Only the
CTC branch is exported: it is the smaller and faster of the two heads, and
closed-set matching does not need a transducer's language modelling.

The toolchain is heavy (NeMo + PyTorch, several GB) and deliberately kept out
of the app's build. To recreate it:

    mise x python@3.11 -- python -m venv tool/.venv-nemo
    tool/.venv-nemo/bin/pip install "nemo_toolkit[asr]" onnx onnxruntime
    curl -L --http1.1 -o tool/model-export/<name>.nemo \\
        https://huggingface.co/nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0/resolve/main/<name>.nemo
    tool/.venv-nemo/bin/python tool/export_speech_model.py

Outputs tool/model-export/out/{model.onnx, model.int8.onnx, tokens.txt}. Only
the int8 model and tokens.txt are shipped.
"""
import argparse
from pathlib import Path
from typing import Dict

import nemo.collections.asr as nemo_asr
import onnx
import torch
from onnxruntime.quantization import QuantType, quantize_dynamic

HERE = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = (
    HERE / "model-export" / "stt_ar_fastconformer_hybrid_large_pcd_v1.0.nemo"
)
SOURCE_URL = (
    "https://huggingface.co/nvidia/stt_ar_fastconformer_hybrid_large_pcd_v1.0"
)


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--out", type=Path, default=HERE / "model-export" / "out")
    return parser.parse_args()


def add_meta_data(filename: Path, meta_data: Dict[str, str]):
    """Stamp key-value metadata onto an ONNX model in place. sherpa-onnx reads
    these at load time to configure the feature front-end, so an export without
    them loads but transcribes nonsense."""
    model = onnx.load(str(filename))
    while len(model.metadata_props):
        model.metadata_props.pop()
    for key, value in meta_data.items():
        meta = model.metadata_props.add()
        meta.key = key
        meta.value = str(value)
    onnx.save(model, str(filename))


@torch.no_grad()
def main():
    args = get_args()
    if not args.checkpoint.is_file():
        raise SystemExit(f"checkpoint not found: {args.checkpoint}")
    args.out.mkdir(parents=True, exist_ok=True)

    asr_model = nemo_asr.models.ASRModel.restore_from(
        restore_path=str(args.checkpoint), map_location="cpu"
    )

    tokens = args.out / "tokens.txt"
    with open(tokens, "w", encoding="utf-8") as f:
        for i, s in enumerate(asr_model.joint.vocabulary):
            f.write(f"{s} {i}\n")
        f.write(f"<blk> {i + 1}\n")

    asr_model.change_decoding_strategy(decoder_type="ctc")
    asr_model.eval()
    asr_model.set_export_config({"decoder_type": "ctc"})

    model = args.out / "model.onnx"
    asr_model.export(str(model))

    normalize_type = asr_model.cfg.preprocessor.normalize
    if normalize_type == "NA":
        normalize_type = ""

    add_meta_data(
        model,
        {
            "vocab_size": asr_model.decoder.vocab_size,
            "normalize_type": normalize_type,
            "subsampling_factor": 8,
            "model_type": "EncDecHybridRNNTCTCBPEModel",
            "version": "1",
            "model_author": "NeMo",
            "url": SOURCE_URL,
            "comment": "Only the CTC branch is exported",
            "doc": "Arabic with diacritics; CC-BY-4.0",
        },
    )

    quantized = args.out / "model.int8.onnx"
    quantize_dynamic(
        model_input=str(model),
        model_output=str(quantized),
        weight_type=QuantType.QUInt8,
    )

    for path in (model, quantized, tokens):
        print(f"{path.stat().st_size / 1e6:8.1f} MB  {path}")


if __name__ == "__main__":
    main()
