#!/usr/bin/env python3
"""Batch mycopunk 'in action' portrait generator.

Reads action-portraits.json and generates all agent action portraits.
Each portrait shows the agent performing their role in a bioluminescent
fungal environment (mycopunk aesthetic).

Usage: python3 scripts/ml/batch-action-portraits.py [--only AGENT] [--dry-run]
"""

import json
import os
import subprocess
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
MANIFEST = os.path.join(SCRIPT_DIR, "action-portraits.json")
GENERATE_SCRIPT = os.path.join(SCRIPT_DIR, "generate-image.py")
OUTPUT_DIR = os.path.join(REPO_ROOT, "assets", "images", "generated")

NEGATIVE_DARK = "pale skin, white skin, light skin"


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Batch generate mycopunk action portraits")
    parser.add_argument("--only", help="Generate only this agent name (e.g. 'flux')")
    parser.add_argument("--start-from", help="Start from this agent name (skip earlier ones)")
    parser.add_argument("--phase", default="final", choices=["iterate", "final"],
                        help="Generation phase (default: final)")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts without running")
    args = parser.parse_args()

    with open(MANIFEST) as f:
        data = json.load(f)

    master_template = data["_master_template"]
    scene_suffix = data["_scene_suffix"]
    portraits = data["portraits"]
    total = len(portraits)
    started = args.start_from is None

    print(f"Mycopunk action portrait generation: {total} agents")
    print(f"Phase: {args.phase}")
    print(f"Output: {OUTPUT_DIR}")
    print()

    success = 0
    failed = 0
    skipped = 0

    for i, portrait in enumerate(portraits):
        name = portrait["name"]
        agent_key = name.lower()

        if args.only and agent_key != args.only.lower():
            continue

        if not started:
            if agent_key == args.start_from.lower():
                started = True
            else:
                skipped += 1
                continue

        # Build the full prompt using the master template
        prompt_block = portrait["prompt_block"]
        action_scene = portrait["action_scene"]
        full_character = f"{prompt_block}, {action_scene}, {scene_suffix}"

        full_prompt = master_template.replace("{prompt_block}", prompt_block)
        full_prompt = full_prompt.replace("{action_scene}", f"{action_scene}, {scene_suffix}")

        output_path = os.path.join(OUTPUT_DIR, portrait["output"])

        # Check if dark skin needs negative correction
        needs_dark_neg = "(dark skin" in prompt_block.lower() or "dark-skinned" in prompt_block.lower()

        print(f"[{i+1}/{total}] {name}")
        print(f"  action: {action_scene[:80]}...")

        cmd = [
            sys.executable, GENERATE_SCRIPT,
            "--phase", args.phase,
            "--output", output_path,
            "--no-unload",
            "--no-stop",
        ]

        if needs_dark_neg:
            cmd.extend(["--negative",
                "worst quality, low quality, blurry, watermark, text, signature, "
                "bad anatomy, extra fingers, mutated hands, deformed, "
                "3d, photorealistic, cgi, render, smooth shading, "
                "chibi, moe, cute, pastel colors, white background, "
                "extra limbs, missing fingers, cropped, out of frame, "
                + NEGATIVE_DARK
            ])

        cmd.append(full_prompt)

        if args.dry_run:
            print(f"  [dry-run] prompt: {full_prompt[:120]}...")
            print(f"  [dry-run] output: {output_path}")
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


if __name__ == "__main__":
    main()
