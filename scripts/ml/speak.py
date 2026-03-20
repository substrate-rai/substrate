#!/usr/bin/env python3
"""Text-to-speech using transformers on GPU.

Uses Microsoft SpeechT5 for lightweight TTS (~1GB VRAM).
Can give Q a voice.

Usage:
    python3 scripts/ml/speak.py "Hello, I am Q."
    python3 scripts/ml/speak.py "Substrate is online." --output greeting.wav
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


def speak(text, output=None):
    """Generate speech from text."""
    import torch
    import soundfile as sf
    from transformers import SpeechT5Processor, SpeechT5ForTextToSpeech, SpeechT5HifiGan
    from datasets import load_dataset

    if not torch.cuda.is_available():
        print("warning: CUDA not available, using CPU (slower)", file=sys.stderr)
        device = "cpu"
    else:
        device = "cuda"
        print(f"gpu: {torch.cuda.get_device_name(0)}")

    print(f"text: {text[:80]}{'...' if len(text) > 80 else ''}")

    processor = SpeechT5Processor.from_pretrained("microsoft/speecht5_tts")
    model = SpeechT5ForTextToSpeech.from_pretrained("microsoft/speecht5_tts").to(device)
    vocoder = SpeechT5HifiGan.from_pretrained("microsoft/speecht5_hifigan").to(device)

    # Speaker embedding
    embeddings = load_dataset("Matthijs/cmu-arctic-xvectors", split="validation")
    speaker_embedding = torch.tensor(embeddings[7306]["xvector"]).unsqueeze(0).to(device)

    inputs = processor(text=text, return_tensors="pt").to(device)
    speech = model.generate_speech(inputs["input_ids"], speaker_embedding, vocoder=vocoder)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = Path(output) if "/" in output else OUTPUT_DIR / output
    else:
        safe_name = text[:30].replace(" ", "-").replace("/", "_")
        out_path = OUTPUT_DIR / f"{safe_name}.wav"

    sf.write(str(out_path), speech.cpu().numpy(), samplerate=16000)
    print(f"saved: {out_path}")

    del model, vocoder
    if device == "cuda":
        torch.cuda.empty_cache()

    return str(out_path)


def main():
    parser = argparse.ArgumentParser(description="Text-to-speech with SpeechT5")
    parser.add_argument("text", help="Text to speak")
    parser.add_argument("--output", help="Output filename (.wav)")
    parser.add_argument("--no-unload", action="store_true")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama()

    speak(args.text, args.output)


if __name__ == "__main__":
    main()
