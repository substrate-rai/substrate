#!/usr/bin/env python3
"""Batch portrait generator — reads characters.json and generates all agent portraits.

Usage: python3 scripts/ml/batch-portraits.py [--start-from AGENT_ID] [--only AGENT_ID]
"""

import json
import os
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
CHARACTERS_JSON = os.path.join(SCRIPT_DIR, "characters.json")
GENERATE_SCRIPT = os.path.join(SCRIPT_DIR, "generate-image.py")
OUTPUT_DIR = os.path.join(REPO_ROOT, "assets", "images", "generated")

# VRAM management — import from shared ollama client
sys.path.insert(0, os.path.join(os.path.dirname(SCRIPT_DIR), "shared"))
from ollama import unload_models, load_model, is_available

NEGATIVE_DARK = "pale skin, white skin"


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Batch generate agent portraits")
    parser.add_argument("--start-from", help="Start from this agent ID (skip earlier ones)")
    parser.add_argument("--only", help="Generate only this agent ID")
    parser.add_argument("--phase", default="final", choices=["iterate", "final"],
                        help="Generation phase (default: final)")
    parser.add_argument("--dry-run", action="store_true", help="Print commands without running")
    args = parser.parse_args()

    with open(CHARACTERS_JSON) as f:
        data = json.load(f)

    characters = data["characters"]
    total = len(characters)
    started = args.start_from is None

    print(f"Batch portrait generation: {total} agents")
    print(f"Phase: {args.phase}")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # --- VRAM bookend: unload Ollama before batch ---
    if not args.dry_run:
        try:
            unloaded = unload_models()
            for name in unloaded:
                print(f"ollama: unloaded {name}")
            if not unloaded:
                print("ollama: no models loaded, VRAM is free")
        except Exception as e:
            print(f"ollama: could not reach ({e}), assuming VRAM is free")
        print()

    success = 0
    failed = 0
    skipped = 0

    for i, char in enumerate(characters):
        agent_id = char["id"]
        name = char["name"]

        if args.only and agent_id != f"agent-{args.only}":
            continue

        if not started:
            if agent_id == f"agent-{args.start_from}":
                started = True
            else:
                skipped += 1
                continue

        prompt = char["prompt_block"]
        output = os.path.join(OUTPUT_DIR, f"{agent_id}.webp")
        skin_tone = char.get("skin_tone", "default")
        use_scifi = "scifi" in char.get("extra_loras", [])

        # Build negative prompt with skin correction for dark characters
        negative_extra = ""
        if skin_tone in ("dark", "very_dark"):
            negative_extra = f", {NEGATIVE_DARK}"

        print(f"[{i+1}/{total}] {name} ({agent_id})")
        print(f"  skin: {skin_tone}, gender: {char.get('gender_tag', '?')}")
        print(f"  prompt: {prompt[:80]}...")

        cmd = [
            sys.executable, GENERATE_SCRIPT,
            "--phase", args.phase,
            "--output", output,
            "--no-unload",  # already unloaded
            "--no-stop",    # keep ComfyUI running between generations
        ]

        if use_scifi:
            cmd.append("--scifi")

        if negative_extra:
            # Read the default negative from generate-image.py and append
            cmd.extend(["--negative",
                "worst quality, low quality, blurry, watermark, text, signature, "
                "bad anatomy, extra fingers, mutated hands, deformed, "
                "3d, photorealistic, cgi, render, smooth shading, "
                "chibi, moe, cute, pastel colors, white background, "
                "extra limbs, missing fingers, cropped, out of frame"
                + negative_extra
            ])

        cmd.append(prompt)

        if args.dry_run:
            print(f"  [dry-run] would run: python3 generate-image.py --output {output} ...")
            print()
            continue

        t0 = time.time()
        try:
            result = subprocess.run(cmd, timeout=300, capture_output=False)
            elapsed = time.time() - t0

            if result.returncode == 0:
                success += 1
                print(f"  OK ({elapsed:.1f}s)")
            else:
                failed += 1
                print(f"  FAILED (exit {result.returncode}, {elapsed:.1f}s)")
        except subprocess.TimeoutExpired:
            failed += 1
            print(f"  TIMEOUT (>300s)")
        except Exception as e:
            failed += 1
            print(f"  ERROR: {e}")

        print()

    print("=" * 50)
    print(f"Done. {success} ok, {failed} failed, {skipped} skipped")

    # --- VRAM bookend: reload Ollama after batch ---
    if not args.dry_run:
        try:
            if is_available(timeout=3):
                print("\nollama: reloading model into VRAM...")
                load_model()
                print("ollama: model loaded")
            else:
                print("\nollama: service not running, skipping reload")
        except Exception as e:
            print(f"\nollama: reload failed ({e}), run manually if needed")


if __name__ == "__main__":
    main()
