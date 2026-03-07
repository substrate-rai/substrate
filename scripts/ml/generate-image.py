#!/usr/bin/env python3
"""Generate images with Stable Diffusion on RTX 4060 (8GB VRAM).

Uses SDXL Turbo for fast generation or SD 1.5 for quality.
Automatically manages VRAM — unloads Ollama models first if needed.

Usage:
    nix develop .#ml --command python3 scripts/ml/generate-image.py "a cyberpunk laptop on a shelf"
    nix develop .#ml --command python3 scripts/ml/generate-image.py "NixOS logo" --model sd15 --steps 30
    nix develop .#ml --command python3 scripts/ml/generate-image.py "robot writing" --output blog-header.png
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

MODELS = {
    "sdxl-turbo": {
        "id": "stabilityai/sdxl-turbo",
        "vram": "~4GB",
        "steps_default": 4,
        "guidance_default": 0.0,
    },
    "sd15": {
        "id": "stable-diffusion-v1-5/stable-diffusion-v1-5",
        "vram": "~4GB",
        "steps_default": 25,
        "guidance_default": 7.5,
    },
}

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "generated"


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


def generate(prompt, model_key="sdxl-turbo", steps=None, guidance=None,
             width=512, height=512, output=None, seed=None):
    """Generate an image using diffusers."""
    import torch
    from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline

    model_info = MODELS[model_key]
    model_id = model_info["id"]
    steps = steps or model_info["steps_default"]
    guidance = guidance if guidance is not None else model_info["guidance_default"]

    if not torch.cuda.is_available():
        print("error: CUDA not available", file=sys.stderr)
        sys.exit(1)

    print(f"gpu: {torch.cuda.get_device_name(0)}")
    print(f"vram free: {torch.cuda.mem_get_info()[0] / 1024**3:.1f} GB")
    print(f"model: {model_id}")
    print(f"prompt: {prompt}")
    print(f"steps: {steps}, guidance: {guidance}, size: {width}x{height}")

    # Load pipeline
    if model_key == "sdxl-turbo":
        pipe = StableDiffusionXLPipeline.from_pretrained(
            model_id, torch_dtype=torch.float16, variant="fp16"
        )
    else:
        pipe = StableDiffusionPipeline.from_pretrained(
            model_id, torch_dtype=torch.float16
        )

    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()

    generator = torch.Generator("cuda").manual_seed(seed) if seed else None

    result = pipe(
        prompt=prompt,
        num_inference_steps=steps,
        guidance_scale=guidance,
        width=width,
        height=height,
        generator=generator,
    )

    image = result.images[0]

    # Save
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = Path(output) if os.path.isabs(output) else OUTPUT_DIR / output
    else:
        safe_name = prompt[:40].replace(" ", "-").replace("/", "_")
        out_path = OUTPUT_DIR / f"{safe_name}.png"

    image.save(out_path)
    print(f"saved: {out_path}")

    # Clean up VRAM
    del pipe
    torch.cuda.empty_cache()

    return str(out_path)


def main():
    parser = argparse.ArgumentParser(description="Generate images with Stable Diffusion")
    parser.add_argument("prompt", help="Text prompt for image generation")
    parser.add_argument("--model", choices=list(MODELS.keys()), default="sdxl-turbo",
                        help="Model to use (default: sdxl-turbo)")
    parser.add_argument("--steps", type=int, help="Number of inference steps")
    parser.add_argument("--guidance", type=float, help="Guidance scale")
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=512)
    parser.add_argument("--output", help="Output filename")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    parser.add_argument("--no-unload", action="store_true",
                        help="Skip unloading Ollama models")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama_models()

    generate(args.prompt, args.model, args.steps, args.guidance,
             args.width, args.height, args.output, args.seed)


if __name__ == "__main__":
    main()
