#!/usr/bin/env python3
"""Generate images via ComfyUI API on RTX 4060 (8GB VRAM).

Model stack: Anime Screenshot Merge NoobAI v4.0 + 90s Retro LoRA
Two-phase workflow: rapid iteration (8 steps) or final quality (25 steps)

Usage:
    python3 scripts/ml/generate-image.py "short spiky silver hair, red eye implant" --output agent_001.png
    python3 scripts/ml/generate-image.py "character block" --phase iterate --variations 4
    python3 scripts/ml/generate-image.py "character block" --phase final --seed 12345 --upscale

Requires: ComfyUI at /home/operator/comfyui with:
  - checkpoints/animeScreenshotMerge_v40.safetensors
  - loras/90retro-illustriousXL.safetensors
  - loras/SDXL-JojosoStyle-Lora-v2-r16.safetensors
  - loras/retro_scifi_90s_anime.safetensors (optional)
  - upscale_models/RealESRGAN_x4plus_anime_6B.pth (for --upscale)
"""

import argparse
import json
import os
import random
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

# Model stack
CHECKPOINT = "animeScreenshotMerge_v40.safetensors"
LORA_90S_RETRO = "90retro-illustriousXL.safetensors"
LORA_JOJO = "SDXL-JojosoStyle-Lora-v2-r16.safetensors"
LORA_SCIFI = "retro_scifi_90s_anime.safetensors"
LORA_LIGHTNING = "sdxl_lightning_4step_lora.safetensors"
UPSCALER = "RealESRGAN_x4plus_anime_6B.pth"

# Legacy support
LEGACY_CHECKPOINT = "sd_xl_turbo_1.0_fp16.safetensors"

SCRIPT_DIR = Path(__file__).parent
OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "images" / "generated"

# Master prompt template — character block gets inserted at {character_block}
MASTER_TEMPLATE = (
    "masterpiece, best quality, 1boy, {character_block}, "
    "90retrostyle, retro artstyle, anime screencap, "
    "anime coloring, cel shading, soft lighting, muted colors, "
    "dark background, portrait, upper body"
)

NEGATIVE_PROMPT = (
    "worst quality, low quality, blurry, watermark, text, signature, "
    "bad anatomy, extra fingers, mutated hands, deformed, "
    "3d, photorealistic, cgi, render, smooth shading, "
    "chibi, moe, cute, pastel colors, white background, "
    "extra limbs, missing fingers, cropped, out of frame"
)

# Legacy negative for non-portrait use
LEGACY_NEGATIVE = "text, watermark, human face, realistic photo, blurry, low quality, signature, words, letters"

# NixOS CUDA library paths
LD_LIBRARY_PATH = (
    "/run/opengl-driver/lib:"
    "/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:"
    "/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:"
    "/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:"
    "/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib"
)

# Comfyui launch flags for 8GB VRAM
COMFYUI_FLAGS = [
    "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch",
    "--force-fp16", "--fp16-vae", "--dont-upcast-attention", "--preview-method", "taesd",
]


def has_new_checkpoint():
    """Check if the new anime checkpoint exists."""
    return (COMFYUI_DIR / "models" / "checkpoints" / CHECKPOINT).exists()


def has_lora(name):
    """Check if a LoRA file exists."""
    return (COMFYUI_DIR / "models" / "loras" / name).exists()


def has_upscaler():
    """Check if the R-ESRGAN upscaler exists."""
    return (COMFYUI_DIR / "models" / "upscale_models" / UPSCALER).exists()


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
                return
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
    except Exception as e:
        print(f"ollama: could not reach ({e}), assuming VRAM is free")


def comfyui_is_running():
    """Check if ComfyUI server is responding."""
    try:
        req = urllib.request.Request(f"{COMFYUI_URL}/system_stats")
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status == 200
    except Exception:
        return False


def kill_existing_comfyui():
    """Kill any existing ComfyUI processes."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "comfyui/main.py"],
            capture_output=True, text=True,
        )
        pids = [p.strip() for p in result.stdout.strip().split("\n") if p.strip()]
        for pid in pids:
            try:
                os.kill(int(pid), signal.SIGTERM)
                print(f"comfyui: sent SIGTERM to pid {pid}")
            except (ProcessLookupError, PermissionError):
                pass
        if pids:
            time.sleep(3)
            for pid in pids:
                try:
                    os.kill(int(pid), signal.SIGKILL)
                except (ProcessLookupError, PermissionError):
                    pass
            time.sleep(1)
    except Exception as e:
        print(f"comfyui: could not kill existing processes: {e}")


def start_comfyui(force_restart=False):
    """Start ComfyUI server in the background."""
    if comfyui_is_running() and not force_restart:
        print("comfyui: already running")
        return None

    if comfyui_is_running() and force_restart:
        print("comfyui: killing existing instance for restart...")
        kill_existing_comfyui()
        for _ in range(10):
            if not comfyui_is_running():
                break
            time.sleep(1)

    print("comfyui: starting server...")
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = LD_LIBRARY_PATH + ":" + env.get("LD_LIBRARY_PATH", "")

    log_path = COMFYUI_DIR / "comfyui.log"
    log_file = open(log_path, "w")

    proc = subprocess.Popen(
        [str(COMFYUI_VENV), str(COMFYUI_MAIN)] + COMFYUI_FLAGS,
        cwd=str(COMFYUI_DIR),
        env=env,
        stdout=log_file,
        stderr=subprocess.STDOUT,
    )

    for i in range(90):  # 90s timeout for new larger models
        if proc.poll() is not None:
            log_file.close()
            out = log_path.read_text(errors="replace")
            print(f"comfyui: process died on startup:\n{out[-2000:]}", file=sys.stderr)
            sys.exit(1)
        if comfyui_is_running():
            print(f"comfyui: ready (took {i+1}s)")
            return proc
        time.sleep(1)

    log_file.close()
    out = log_path.read_text(errors="replace") if log_path.exists() else ""
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


def build_workflow(prompt, negative=NEGATIVE_PROMPT, width=832, height=1216,
                   steps=25, cfg=4.5, seed=None, phase="final",
                   use_scifi_lora=False, use_jojo_lora=False, upscale=False):
    """Build ComfyUI workflow for the new anime model stack.

    Phases:
        'iterate' — Lightning LoRA, 8 steps, DPM++ SDE Karras, CFG 1.5
        'final'   — No Lightning, 25 steps, Euler a, CFG 4.5
        'legacy'  — Old SDXL Turbo mode for backwards compatibility
    """
    if seed is None:
        seed = random.randint(0, 2**32 - 1)

    if phase == "legacy":
        return _build_legacy_workflow(prompt, negative, width, height, steps, cfg, seed)

    # Node IDs: 1=checkpoint, 2-4=loras, 5=positive clip, 6=negative clip,
    # 7=latent, 8=sampler, 9=vae decode, 10=save, 11=upscale, 12=scale down
    nodes = {}
    next_id = 1

    # 1: Load checkpoint
    ckpt_id = str(next_id); next_id += 1
    nodes[ckpt_id] = {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {"ckpt_name": CHECKPOINT},
    }

    # Chain LoRAs: each takes model+clip from the previous
    model_src = [ckpt_id, 0]
    clip_src = [ckpt_id, 1]

    # LoRA 1: 90s Retro Style (always)
    if has_lora(LORA_90S_RETRO):
        lora_id = str(next_id); next_id += 1
        nodes[lora_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA_90S_RETRO,
                "model": model_src, "clip": clip_src,
                "strength_model": 0.7, "strength_clip": 0.7,
            },
        }
        model_src = [lora_id, 0]
        clip_src = [lora_id, 1]

    # LoRA 2: JoJo Style (optional — off by default)
    if use_jojo_lora and has_lora(LORA_JOJO):
        lora_id = str(next_id); next_id += 1
        nodes[lora_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA_JOJO,
                "model": model_src, "clip": clip_src,
                "strength_model": 0.5, "strength_clip": 0.5,
            },
        }
        model_src = [lora_id, 0]
        clip_src = [lora_id, 1]

    # LoRA 3: Retro Sci-fi (optional, for cyberpunk-heavy characters)
    if use_scifi_lora and has_lora(LORA_SCIFI):
        lora_id = str(next_id); next_id += 1
        nodes[lora_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA_SCIFI,
                "model": model_src, "clip": clip_src,
                "strength_model": 0.4, "strength_clip": 0.4,
            },
        }
        model_src = [lora_id, 0]
        clip_src = [lora_id, 1]

    # LoRA 4: Lightning (Phase 1 iteration only)
    if phase == "iterate" and has_lora(LORA_LIGHTNING):
        lora_id = str(next_id); next_id += 1
        nodes[lora_id] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA_LIGHTNING,
                "model": model_src, "clip": clip_src,
                "strength_model": 1.0, "strength_clip": 1.0,
            },
        }
        model_src = [lora_id, 0]
        clip_src = [lora_id, 1]

    # Positive prompt
    pos_id = str(next_id); next_id += 1
    nodes[pos_id] = {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": clip_src, "text": prompt},
    }

    # Negative prompt
    neg_id = str(next_id); next_id += 1
    nodes[neg_id] = {
        "class_type": "CLIPTextEncode",
        "inputs": {"clip": clip_src, "text": negative},
    }

    # Empty latent
    latent_id = str(next_id); next_id += 1
    nodes[latent_id] = {
        "class_type": "EmptyLatentImage",
        "inputs": {"batch_size": 1, "height": height, "width": width},
    }

    # KSampler — settings differ by phase
    sampler_id = str(next_id); next_id += 1
    if phase == "iterate":
        sampler_cfg = {"sampler_name": "dpmpp_sde", "scheduler": "karras",
                       "steps": 8, "cfg": 1.5}
    else:  # final
        sampler_cfg = {"sampler_name": "euler_ancestral", "scheduler": "normal",
                       "steps": steps, "cfg": cfg}

    nodes[sampler_id] = {
        "class_type": "KSampler",
        "inputs": {
            "model": model_src,
            "positive": [pos_id, 0],
            "negative": [neg_id, 0],
            "latent_image": [latent_id, 0],
            "seed": seed,
            "denoise": 1.0,
            **sampler_cfg,
        },
    }

    # VAE Decode
    decode_id = str(next_id); next_id += 1
    nodes[decode_id] = {
        "class_type": "VAEDecode",
        "inputs": {
            "samples": [sampler_id, 0],
            "vae": [ckpt_id, 2],
        },
    }

    image_src = [decode_id, 0]

    # Upscale (optional, Phase 2 final only)
    if upscale and phase == "final" and has_upscaler():
        # Load upscale model
        up_load_id = str(next_id); next_id += 1
        nodes[up_load_id] = {
            "class_type": "UpscaleModelLoader",
            "inputs": {"model_name": UPSCALER},
        }
        # Upscale image
        up_id = str(next_id); next_id += 1
        nodes[up_id] = {
            "class_type": "ImageUpscaleWithModel",
            "inputs": {
                "upscale_model": [up_load_id, 0],
                "image": image_src,
            },
        }
        # Scale down to 2x (4x upscale is too large)
        scale_id = str(next_id); next_id += 1
        nodes[scale_id] = {
            "class_type": "ImageScale",
            "inputs": {
                "image": [up_id, 0],
                "upscale_method": "lanczos",
                "width": width * 2,
                "height": height * 2,
                "crop": "disabled",
            },
        }
        image_src = [scale_id, 0]

    # Save
    save_id = str(next_id); next_id += 1
    nodes[save_id] = {
        "class_type": "SaveImage",
        "inputs": {
            "filename_prefix": "generate",
            "images": image_src,
        },
    }

    return nodes, seed


def _build_legacy_workflow(prompt, negative, width, height, steps, cfg, seed):
    """Legacy SDXL Turbo workflow for backwards compatibility."""
    ckpt = CHECKPOINT if has_new_checkpoint() else LEGACY_CHECKPOINT
    use_lightning = has_lora(LORA_LIGHTNING) and ckpt == LEGACY_CHECKPOINT

    nodes = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"batch_size": 1, "height": height, "width": width}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": prompt}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": "" if cfg <= 1.0 else negative}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "generate", "images": ["8", 0]}},
    }

    model_src = ["4", 0]
    if use_lightning:
        nodes["10"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": LORA_LIGHTNING, "model": ["4", 0], "clip": ["4", 1],
                "strength_model": 1.0, "strength_clip": 1.0,
            },
        }
        model_src = ["10", 0]

    nodes["3"] = {
        "class_type": "KSampler",
        "inputs": {
            "cfg": cfg, "denoise": 1.0, "latent_image": ["5", 0],
            "model": model_src, "negative": ["7", 0], "positive": ["6", 0],
            "sampler_name": "euler_ancestral", "scheduler": "normal",
            "seed": seed, "steps": steps,
        },
    }
    return nodes, seed


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


def wait_for_completion(prompt_id, timeout=180):
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


def generate(prompt, width=832, height=1216, steps=25, cfg=4.5, seed=None,
             output=None, negative=NEGATIVE_PROMPT, phase="final",
             use_scifi_lora=False, use_jojo_lora=False, upscale=False,
             use_template=True):
    """Generate an image via ComfyUI API and save it."""
    # Apply master template if this is a character block
    if use_template and phase != "legacy":
        full_prompt = MASTER_TEMPLATE.format(character_block=prompt)
    else:
        full_prompt = prompt

    workflow, used_seed = build_workflow(
        full_prompt, negative=negative, width=width, height=height,
        steps=steps, cfg=cfg, seed=seed, phase=phase,
        use_scifi_lora=use_scifi_lora, use_jojo_lora=use_jojo_lora,
        upscale=upscale,
    )

    phase_label = {"iterate": "Rapid Iteration (8 steps)", "final": "Final Quality (25 steps)",
                   "legacy": "Legacy Turbo"}.get(phase, phase)

    print(f"  phase: {phase_label}")
    print(f"  prompt: {full_prompt[:100]}{'...' if len(full_prompt) > 100 else ''}")
    print(f"  size: {width}x{height}, seed: {used_seed}")

    prompt_id = submit_workflow(workflow)
    if not prompt_id:
        print("  error: failed to submit workflow", file=sys.stderr)
        return None
    print(f"  submitted: {prompt_id[:12]}...")

    timeout = 60 if phase == "iterate" else 180
    result = wait_for_completion(prompt_id, timeout=timeout)
    if result is None:
        print("  error: generation timed out", file=sys.stderr)
        return None

    status = result.get("status", {})
    if status.get("status_str") == "error":
        messages = status.get("messages", [])
        print(f"  error: generation failed: {messages}", file=sys.stderr)
        return None

    filename, subfolder = get_generated_image(result)
    if not filename:
        print("  error: no image in output", file=sys.stderr)
        return None

    image_data = download_image(filename, subfolder)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = Path(output) if os.path.isabs(output) else OUTPUT_DIR / output
    else:
        safe_name = prompt[:40].replace(" ", "-").replace("/", "_").replace("|", "_")
        out_path = OUTPUT_DIR / f"{safe_name}_{used_seed}_{phase}.png"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(image_data)
    print(f"  saved: {out_path}")
    print(f"  seed: {used_seed}")
    return str(out_path)


def main():
    parser = argparse.ArgumentParser(
        description="Generate images via ComfyUI — Anime Screenshot Merge NoobAI + 90s Retro LoRA")
    parser.add_argument("prompt", help="Character block (or full prompt with --no-template)")
    parser.add_argument("--phase", choices=["iterate", "final", "legacy"], default="final",
                        help="Generation phase: iterate (fast), final (quality), legacy (old SDXL Turbo)")
    parser.add_argument("--steps", type=int, default=25, help="Inference steps (default: 25 for final, 8 for iterate)")
    parser.add_argument("--cfg", type=float, default=4.5, help="CFG scale (default: 4.5)")
    parser.add_argument("--width", type=int, default=832, help="Width (default: 832)")
    parser.add_argument("--height", type=int, default=1216, help="Height (default: 1216)")
    parser.add_argument("--output", help="Output filename or path")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    parser.add_argument("--negative", default=NEGATIVE_PROMPT, help="Negative prompt")
    parser.add_argument("--scifi", action="store_true", help="Add Retro Sci-fi 90s LoRA (cyberpunk characters)")
    parser.add_argument("--jojo", action="store_true", help="Add JoJo Style v2 LoRA (off by default)")
    parser.add_argument("--upscale", action="store_true", help="Upscale with R-ESRGAN 4x+ Anime6B (final phase only)")
    parser.add_argument("--no-template", action="store_true", help="Use prompt as-is, don't apply master template")
    parser.add_argument("--variations", type=int, default=1, help="Number of variations to generate (random seeds)")
    parser.add_argument("--no-unload", action="store_true", help="Skip unloading Ollama models")
    parser.add_argument("--no-start", action="store_true", help="Don't auto-start ComfyUI")
    parser.add_argument("--no-stop", action="store_true", help="Don't stop ComfyUI after generation")
    parser.add_argument("--restart", action="store_true", help="Force restart ComfyUI")
    args = parser.parse_args()

    if not args.no_unload:
        unload_ollama_models()

    proc = None
    if args.restart:
        proc = start_comfyui(force_restart=True)
    elif not args.no_start:
        proc = start_comfyui()

    try:
        for i in range(args.variations):
            if args.variations > 1:
                print(f"\n--- Variation {i+1}/{args.variations} ---")
            seed = args.seed if args.variations == 1 else None
            result = generate(
                args.prompt, args.width, args.height, args.steps, args.cfg,
                seed, args.output if args.variations == 1 else None,
                args.negative, phase=args.phase,
                use_scifi_lora=args.scifi, use_jojo_lora=args.jojo,
                upscale=args.upscale, use_template=not args.no_template,
            )
            if result is None:
                print(f"  FAILED variation {i+1}", file=sys.stderr)
    finally:
        if not args.no_stop and proc is not None:
            stop_comfyui(proc)


if __name__ == "__main__":
    main()
