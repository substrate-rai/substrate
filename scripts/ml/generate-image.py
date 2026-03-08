#!/usr/bin/env python3
"""Generate images with Stable Diffusion via ComfyUI API on RTX 4060 (8GB VRAM).

Uses SDXL Turbo (local checkpoint) through ComfyUI's REST API.
Automatically starts ComfyUI if not running.

Usage:
    python3 scripts/ml/generate-image.py "a cyberpunk laptop on a shelf"
    python3 scripts/ml/generate-image.py "robot writing" --output hero.png
    python3 scripts/ml/generate-image.py "NixOS logo" --steps 6 --seed 42

Requires: ComfyUI at /home/operator/comfyui with sd_xl_turbo_1.0_fp16.safetensors
"""

import argparse
import io
import json
import os
import random
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

COMFYUI_DIR = Path("/home/operator/comfyui")
COMFYUI_VENV = COMFYUI_DIR / "venv" / "bin" / "python"
COMFYUI_MAIN = COMFYUI_DIR / "main.py"
COMFYUI_URL = "http://127.0.0.1:8188"
COMFYUI_OUTPUT = COMFYUI_DIR / "output"
CHECKPOINT = "sd_xl_turbo_1.0_fp16.safetensors"

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "images" / "generated"

NEGATIVE_PROMPT = "text, watermark, human face, realistic photo, blurry, low quality, signature, words, letters"


def unload_ollama_models():
    """Ask Ollama to unload all models to free VRAM."""
    try:
        req = urllib.request.Request(
            "http://localhost:11434/api/ps",
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            models = data.get("models", [])
            if not models:
                print("ollama: no models loaded, VRAM is free")
                return True
            for m in models:
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
                print(f"ollama: {name} unloaded")
            return True
    except Exception as e:
        print(f"ollama: could not reach ({e}), assuming VRAM is free")
        return True


def comfyui_is_running():
    """Check if ComfyUI server is responding."""
    try:
        req = urllib.request.Request(f"{COMFYUI_URL}/system_stats")
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status == 200
    except Exception:
        return False


def start_comfyui():
    """Start ComfyUI server in the background."""
    if comfyui_is_running():
        print("comfyui: already running")
        return None

    print("comfyui: starting server...")
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = "/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib:" + env.get("LD_LIBRARY_PATH", "")

    proc = subprocess.Popen(
        [str(COMFYUI_VENV), str(COMFYUI_MAIN), "--listen", "127.0.0.1", "--port", "8188",
         "--disable-auto-launch"],
        cwd=str(COMFYUI_DIR),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    # Wait for server to be ready (up to 60s)
    for i in range(60):
        if proc.poll() is not None:
            out = proc.stdout.read().decode(errors="replace")
            print(f"comfyui: process died on startup:\n{out[-2000:]}", file=sys.stderr)
            sys.exit(1)
        if comfyui_is_running():
            print(f"comfyui: ready (took {i+1}s)")
            return proc
        time.sleep(1)

    # Timed out
    out = proc.stdout.read(4096).decode(errors="replace") if proc.stdout else ""
    print(f"comfyui: timed out waiting for startup\n{out[-2000:]}", file=sys.stderr)
    proc.terminate()
    sys.exit(1)


def stop_comfyui(proc):
    """Stop a ComfyUI process we started."""
    if proc is None:
        return
    print("comfyui: shutting down...")
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
    print("comfyui: stopped")


def build_workflow(prompt, negative=NEGATIVE_PROMPT, width=512, height=512,
                   steps=4, cfg=1.0, seed=None):
    """Build a ComfyUI workflow dict for SDXL Turbo generation."""
    if seed is None:
        seed = random.randint(0, 2**32 - 1)

    return {
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "cfg": cfg,
                "denoise": 1.0,
                "latent_image": ["5", 0],
                "model": ["4", 0],
                "negative": ["7", 0],
                "positive": ["6", 0],
                "sampler_name": "euler_ancestral",
                "scheduler": "normal",
                "seed": seed,
                "steps": steps,
            },
        },
        "4": {
            "class_type": "CheckpointLoaderSimple",
            "inputs": {
                "ckpt_name": CHECKPOINT,
            },
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {
                "batch_size": 1,
                "height": height,
                "width": width,
            },
        },
        "6": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["4", 1],
                "text": prompt,
            },
        },
        "7": {
            "class_type": "CLIPTextEncode",
            "inputs": {
                "clip": ["4", 1],
                "text": negative,
            },
        },
        "8": {
            "class_type": "VAEDecode",
            "inputs": {
                "samples": ["3", 0],
                "vae": ["4", 2],
            },
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": "generate",
                "images": ["8", 0],
            },
        },
    }


def submit_workflow(workflow):
    """Submit a workflow to ComfyUI and return the prompt_id."""
    payload = json.dumps({"prompt": workflow}).encode()
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read())
        return data.get("prompt_id")


def wait_for_completion(prompt_id, timeout=120):
    """Poll ComfyUI history until the prompt is complete."""
    start = time.time()
    while time.time() - start < timeout:
        try:
            req = urllib.request.Request(f"{COMFYUI_URL}/history/{prompt_id}")
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read())
                if prompt_id in data:
                    return data[prompt_id]
        except Exception:
            pass
        time.sleep(1)
    return None


def get_generated_image(history_entry):
    """Extract the generated image filename from a completed workflow history."""
    outputs = history_entry.get("outputs", {})
    for node_id, node_output in outputs.items():
        images = node_output.get("images", [])
        for img in images:
            return img.get("filename"), img.get("subfolder", "")
    return None, None


def download_image(filename, subfolder=""):
    """Download a generated image from ComfyUI."""
    params = f"filename={filename}"
    if subfolder:
        params += f"&subfolder={subfolder}"
    req = urllib.request.Request(f"{COMFYUI_URL}/view?{params}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


def generate(prompt, width=512, height=512, steps=4, cfg=1.0, seed=None,
             output=None, negative=NEGATIVE_PROMPT):
    """Generate an image via ComfyUI API and save it."""
    workflow = build_workflow(prompt, negative=negative, width=width, height=height,
                              steps=steps, cfg=cfg, seed=seed)

    print(f"  prompt: {prompt[:80]}{'...' if len(prompt) > 80 else ''}")
    print(f"  size: {width}x{height}, steps: {steps}, cfg: {cfg}")

    # Submit
    prompt_id = submit_workflow(workflow)
    if not prompt_id:
        print("  error: failed to submit workflow", file=sys.stderr)
        return None
    print(f"  submitted: {prompt_id[:12]}...")

    # Wait
    result = wait_for_completion(prompt_id)
    if result is None:
        print("  error: generation timed out", file=sys.stderr)
        return None

    # Check for errors
    status = result.get("status", {})
    if status.get("status_str") == "error":
        messages = status.get("messages", [])
        print(f"  error: generation failed: {messages}", file=sys.stderr)
        return None

    # Get the image
    filename, subfolder = get_generated_image(result)
    if not filename:
        print("  error: no image in output", file=sys.stderr)
        return None

    image_data = download_image(filename, subfolder)

    # Save
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = Path(output) if os.path.isabs(output) else OUTPUT_DIR / output
    else:
        safe_name = prompt[:40].replace(" ", "-").replace("/", "_").replace("|", "_")
        out_path = OUTPUT_DIR / f"{safe_name}.png"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(image_data)
    print(f"  saved: {out_path}")
    return str(out_path)


def main():
    parser = argparse.ArgumentParser(description="Generate images with Stable Diffusion via ComfyUI")
    parser.add_argument("prompt", help="Text prompt for image generation")
    parser.add_argument("--steps", type=int, default=4, help="Number of inference steps (default: 4)")
    parser.add_argument("--cfg", type=float, default=1.0, help="CFG scale (default: 1.0 for SDXL Turbo)")
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    parser.add_argument("--output", help="Output filename or path")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    parser.add_argument("--negative", default=NEGATIVE_PROMPT, help="Negative prompt")
    parser.add_argument("--no-unload", action="store_true",
                        help="Skip unloading Ollama models")
    parser.add_argument("--no-start", action="store_true",
                        help="Don't auto-start ComfyUI (assume it's running)")
    parser.add_argument("--no-stop", action="store_true",
                        help="Don't stop ComfyUI after generation")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama_models()

    proc = None
    if not args.no_start:
        proc = start_comfyui()

    try:
        result = generate(args.prompt, args.width, args.height, args.steps,
                          args.cfg, args.seed, args.output, args.negative)
        if result is None:
            sys.exit(1)
    finally:
        if not args.no_stop and proc is not None:
            stop_comfyui(proc)


if __name__ == "__main__":
    main()
