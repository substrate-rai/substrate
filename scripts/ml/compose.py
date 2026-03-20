#!/usr/bin/env python3
"""Generate music with MusicGen on GPU.

Uses Facebook's MusicGen-small (~2GB VRAM) to generate music from text prompts.
Q can finally produce beats.

Usage:
    python3 scripts/ml/compose.py "lo-fi hip hop beat with vinyl crackle"
    python3 scripts/ml/compose.py "dark ambient synth" --duration 10
    python3 scripts/ml/compose.py "chiptune boss battle" --output boss.wav
"""

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "shared"))
from ollama import unload_models

OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "audio"


def unload_ollama():
    """Unload Ollama models to free VRAM."""
    try:
        for name in unload_models():
            print(f"ollama: unloaded {name}")
    except Exception:
        pass


def compose(prompt, duration=5, output=None):
    """Generate music from text prompt."""
    import torch
    import soundfile as sf
    from transformers import AutoProcessor, MusicgenForConditionalGeneration

    if not torch.cuda.is_available():
        print("error: CUDA required for MusicGen", file=sys.stderr)
        sys.exit(1)

    print(f"gpu: {torch.cuda.get_device_name(0)}")
    print(f"vram free: {torch.cuda.mem_get_info()[0] / 1024**3:.1f} GB")
    print(f"prompt: {prompt}")
    print(f"duration: {duration}s")

    processor = AutoProcessor.from_pretrained("facebook/musicgen-small")
    model = MusicgenForConditionalGeneration.from_pretrained(
        "facebook/musicgen-small"
    ).to("cuda")

    inputs = processor(text=[prompt], padding=True, return_tensors="pt").to("cuda")

    # MusicGen generates at 32kHz, ~1500 tokens per second
    max_tokens = int(duration * 1500 / 20)  # approximate
    audio = model.generate(**inputs, max_new_tokens=max_tokens)

    # Output is (batch, channels, samples)
    audio_data = audio[0, 0].cpu().numpy()
    sample_rate = model.config.audio_encoder.sampling_rate

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = Path(output) if "/" in output else OUTPUT_DIR / output
    else:
        safe_name = prompt[:30].replace(" ", "-").replace("/", "_")
        out_path = OUTPUT_DIR / f"music-{safe_name}.wav"

    sf.write(str(out_path), audio_data, samplerate=sample_rate)
    print(f"saved: {out_path} ({len(audio_data) / sample_rate:.1f}s)")

    del model
    torch.cuda.empty_cache()

    return str(out_path)


def main():
    parser = argparse.ArgumentParser(description="Generate music with MusicGen")
    parser.add_argument("prompt", help="Text description of desired music")
    parser.add_argument("--duration", type=int, default=5,
                        help="Duration in seconds (default: 5)")
    parser.add_argument("--output", help="Output filename (.wav)")
    parser.add_argument("--no-unload", action="store_true")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama()

    compose(args.prompt, args.duration, args.output)


if __name__ == "__main__":
    main()
