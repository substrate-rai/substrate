#!/usr/bin/env python3
"""GPU scheduler — manages VRAM between Ollama and ML models.

Ensures only one GPU-intensive task runs at a time on the RTX 4060 (8GB).
Auto-unloads Ollama before ML tasks, reloads after.

Usage:
    python3 scripts/ml/gpu-scheduler.py status
    python3 scripts/ml/gpu-scheduler.py run image "a cyberpunk cat"
    python3 scripts/ml/gpu-scheduler.py run transcribe audio.mp3
    python3 scripts/ml/gpu-scheduler.py run speak "Hello world"
    python3 scripts/ml/gpu-scheduler.py run music "lo-fi beat"
    python3 scripts/ml/gpu-scheduler.py switch sd
    python3 scripts/ml/gpu-scheduler.py switch ollama
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "shared"))
from ollama import unload_models, load_model

SCRIPT_DIR = Path(__file__).parent


def get_gpu_status():
    """Get current GPU memory usage."""
    try:
        import torch
        if torch.cuda.is_available():
            free, total = torch.cuda.mem_get_info()
            return {
                "device": torch.cuda.get_device_name(0),
                "total_gb": round(total / 1024**3, 1),
                "free_gb": round(free / 1024**3, 1),
                "used_gb": round((total - free) / 1024**3, 1),
            }
    except ImportError:
        pass

    # Fallback: nvidia-smi
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.free,memory.used",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True
        )
        parts = result.stdout.strip().split(", ")
        return {
            "device": parts[0],
            "total_gb": round(int(parts[1]) / 1024, 1),
            "free_gb": round(int(parts[2]) / 1024, 1),
            "used_gb": round(int(parts[3]) / 1024, 1),
        }
    except Exception:
        return {"device": "unknown", "total_gb": 0, "free_gb": 0, "used_gb": 0}


def get_ollama_status():
    """Check what models Ollama has loaded."""
    try:
        req = urllib.request.Request("http://localhost:11434/api/ps")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            return data.get("models", [])
    except Exception:
        return None


def unload_ollama():
    """Unload all Ollama models."""
    try:
        unloaded = unload_models()
        if not unloaded:
            print("  ollama: no models loaded")
        else:
            for name in unloaded:
                print(f"  ollama: unloaded {name}")
            print("  ollama: all models unloaded")
    except Exception as e:
        print(f"  ollama: unload failed ({e})")


def reload_ollama(model="qwen3:8b"):
    """Warm-load an Ollama model back into VRAM."""
    print(f"  ollama: reloading {model}...")
    try:
        load_model(model)
        print(f"  ollama: {model} loaded")
    except Exception as e:
        print(f"  ollama: reload failed ({e})")


def status():
    """Print current GPU and model status."""
    gpu = get_gpu_status()
    print(f"GPU: {gpu['device']}")
    print(f"  VRAM: {gpu['used_gb']}GB / {gpu['total_gb']}GB (free: {gpu['free_gb']}GB)")

    models = get_ollama_status()
    if models is None:
        print("  Ollama: not running")
    elif not models:
        print("  Ollama: running, no models loaded (idle)")
    else:
        for m in models:
            print(f"  Ollama: {m.get('name', '?')} loaded ({m.get('size', 0) / 1024**3:.1f}GB)")

    print("\nAvailable tools:")
    print("  image     — Stable Diffusion (SDXL Turbo / SD 1.5)")
    print("  transcribe — Faster Whisper (speech-to-text)")
    print("  speak     — SpeechT5 (text-to-speech)")
    print("  music     — MusicGen (text-to-music)")


def wait_vram_free(threshold_mb=500, poll_interval=2):
    """Poll nvidia-smi until VRAM usage drops below threshold."""
    print(f"[scheduler] waiting for VRAM usage to drop below {threshold_mb}MB...")
    while True:
        gpu = get_gpu_status()
        used_mb = int(gpu["used_gb"] * 1024)
        if used_mb < threshold_mb:
            print(f"[scheduler] VRAM used: {used_mb}MB — below threshold, GPU is free")
            return
        print(f"[scheduler] VRAM used: {used_mb}MB — waiting...")
        time.sleep(poll_interval)


def switch_mode(mode, model="qwen3:8b"):
    """Cleanly swap between ollama and sd modes.

    - 'sd' mode: unloads Ollama and waits for VRAM to free up, leaving
      the GPU ready for Stable Diffusion.
    - 'ollama' mode: reloads the default model back into Ollama.
    """
    if mode == "sd":
        print("[scheduler] switching to Stable Diffusion mode...")
        unload_ollama()
        wait_vram_free()
        gpu = get_gpu_status()
        print(f"[scheduler] GPU ready for SD — VRAM free: {gpu['free_gb']}GB")
    elif mode == "ollama":
        print("[scheduler] switching to Ollama mode...")
        reload_ollama(model)
        gpu = get_gpu_status()
        print(f"[scheduler] Ollama ready — VRAM used: {gpu['used_gb']}GB")
    else:
        print(f"error: unknown mode '{mode}'. Options: sd, ollama")
        sys.exit(1)


def run_tool(tool, args, no_reload=False):
    """Run an ML tool with automatic VRAM management."""
    scripts = {
        "image": SCRIPT_DIR / "generate-image.py",
        "transcribe": SCRIPT_DIR / "transcribe.py",
        "speak": SCRIPT_DIR / "speak.py",
        "music": SCRIPT_DIR / "compose.py",
    }

    if tool not in scripts:
        print(f"error: unknown tool '{tool}'. Options: {', '.join(scripts.keys())}")
        sys.exit(1)

    script = scripts[tool]

    print(f"[scheduler] preparing GPU for {tool}...")
    unload_ollama()

    gpu = get_gpu_status()
    print(f"[scheduler] VRAM free: {gpu['free_gb']}GB")

    print(f"[scheduler] running {tool}...")
    cmd = [sys.executable, str(script), "--no-unload"] + args
    result = subprocess.run(cmd)

    if not no_reload:
        print(f"\n[scheduler] restoring Ollama...")
        reload_ollama()

    return result.returncode


def main():
    parser = argparse.ArgumentParser(description="GPU scheduler for Substrate")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status", help="Show GPU and model status")

    run_parser = subparsers.add_parser("run", help="Run an ML tool")
    run_parser.add_argument("tool", choices=["image", "transcribe", "speak", "music"])
    run_parser.add_argument("args", nargs=argparse.REMAINDER)
    run_parser.add_argument("--no-reload", action="store_true",
                            help="Don't reload Ollama after task")

    switch_parser = subparsers.add_parser("switch", help="Switch GPU between modes")
    switch_parser.add_argument("mode", choices=["sd", "ollama"],
                               help="Target mode: 'sd' frees VRAM for Stable Diffusion, "
                                    "'ollama' reloads the default model")
    switch_parser.add_argument("--model", default="qwen3:8b",
                               help="Ollama model to reload (default: qwen3:8b)")

    args = parser.parse_args()

    if args.command == "status":
        status()
    elif args.command == "run":
        sys.exit(run_tool(args.tool, args.args, args.no_reload))
    elif args.command == "switch":
        switch_mode(args.mode, args.model)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
