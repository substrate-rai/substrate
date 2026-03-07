#!/usr/bin/env python3
"""Transcribe audio to text using Faster Whisper on GPU.

Uses faster-whisper (CTranslate2) for efficient CUDA inference.
Auto-unloads Ollama models to free VRAM if needed.

Usage:
    nix develop .#ml --command python3 scripts/ml/transcribe.py audio.mp3
    nix develop .#ml --command python3 scripts/ml/transcribe.py recording.wav --model large-v3
    nix develop .#ml --command python3 scripts/ml/transcribe.py meeting.m4a --output transcript.txt
"""

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path


def unload_ollama():
    """Unload Ollama models to free VRAM."""
    try:
        req = urllib.request.Request("http://localhost:11434/api/ps")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            for m in data.get("models", []):
                name = m.get("name", "unknown")
                print(f"ollama: unloading {name}...")
                body = json.dumps({"model": name, "keep_alive": 0}).encode()
                req2 = urllib.request.Request(
                    "http://localhost:11434/api/generate",
                    data=body,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                urllib.request.urlopen(req2, timeout=30)
    except Exception:
        pass


def transcribe(audio_path, model_size="base", language=None, output=None):
    """Transcribe audio file."""
    from faster_whisper import WhisperModel

    if not Path(audio_path).exists():
        print(f"error: {audio_path} not found", file=sys.stderr)
        sys.exit(1)

    print(f"model: faster-whisper {model_size}")
    print(f"input: {audio_path}")

    model = WhisperModel(model_size, device="cuda", compute_type="float16")

    segments, info = model.transcribe(
        audio_path,
        language=language,
        beam_size=5,
        vad_filter=True,
    )

    print(f"detected language: {info.language} (prob: {info.language_probability:.2f})")
    print(f"duration: {info.duration:.1f}s")
    print("---")

    lines = []
    for segment in segments:
        timestamp = f"[{segment.start:.1f}s -> {segment.end:.1f}s]"
        line = f"{timestamp} {segment.text.strip()}"
        print(line)
        lines.append(line)

    if output:
        with open(output, "w") as f:
            f.write("\n".join(lines))
        print(f"\nsaved: {output}")

    # Clean up
    del model
    try:
        import torch
        torch.cuda.empty_cache()
    except ImportError:
        pass

    return lines


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio with Faster Whisper")
    parser.add_argument("audio", help="Path to audio file")
    parser.add_argument("--model", default="base",
                        choices=["tiny", "base", "small", "medium", "large-v3"],
                        help="Whisper model size (default: base, ~1GB VRAM)")
    parser.add_argument("--language", help="Language code (auto-detected if omitted)")
    parser.add_argument("--output", help="Save transcript to file")
    parser.add_argument("--no-unload", action="store_true")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama()

    transcribe(args.audio, args.model, args.language, args.output)


if __name__ == "__main__":
    main()
