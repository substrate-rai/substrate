#!/usr/bin/env python3
"""
Mobile QA Screenshot Agent
Takes mobile-viewport screenshots of all arcade games and saves them for review.
Usage: nix-shell -p python3 python3Packages.playwright chromium --run "python3 scripts/mobile-qa.py"
"""

import os
import sys
import json
import time
import shutil
from pathlib import Path
from playwright.sync_api import sync_playwright

# Base URL for the live site
BASE_URL = "https://substrate-rai.github.io/substrate"

# All arcade games to test
GAMES = [
    {"name": "bootloader", "path": "/games/bootloader/", "wait": 2},
    {"name": "cypher", "path": "/games/cypher/", "wait": 2},
    {"name": "objection", "path": "/games/objection/", "wait": 2},
    {"name": "cascade", "path": "/games/cascade/", "wait": 2},
    {"name": "tactics", "path": "/games/tactics/", "wait": 3},
    {"name": "mycelium", "path": "/games/mycelium/", "wait": 3},
    {"name": "chemistry", "path": "/games/chemistry/", "wait": 3},
    {"name": "airlock", "path": "/games/airlock/", "wait": 3},
    {"name": "brigade", "path": "/games/brigade/", "wait": 2},
    {"name": "adventure", "path": "/games/adventure/", "wait": 2},
    {"name": "novel", "path": "/games/novel/", "wait": 2},
    {"name": "radio", "path": "/games/radio/", "wait": 2},
    {"name": "album", "path": "/games/album/", "wait": 2},
    {"name": "puzzle", "path": "/games/puzzle/", "wait": 2},
    {"name": "chat", "path": "/site/chat/", "wait": 2},
]

# Mobile device profiles
DEVICES = [
    {
        "name": "iphone-14",
        "viewport": {"width": 390, "height": 844},
        "device_scale_factor": 3,
        "user_agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "is_mobile": True,
        "has_touch": True,
    },
    {
        "name": "pixel-7",
        "viewport": {"width": 412, "height": 915},
        "device_scale_factor": 2.625,
        "user_agent": "Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        "is_mobile": True,
        "has_touch": True,
    },
]


def take_screenshots(output_dir="screenshots/mobile-qa"):
    """Take mobile screenshots of all games."""
    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    results = []

    with sync_playwright() as p:
        # Use system chromium on NixOS (dynamically-linked playwright browsers won't work)
        chromium_path = shutil.which("chromium") or shutil.which("google-chrome-stable")
        if not chromium_path:
            print("ERROR: No chromium/chrome found in PATH. Run inside nix-shell -p chromium")
            sys.exit(1)
        browser = p.chromium.launch(headless=True, executable_path=chromium_path)

        for device in DEVICES:
            print(f"\n{'='*50}")
            print(f"Device: {device['name']} ({device['viewport']['width']}x{device['viewport']['height']})")
            print(f"{'='*50}")

            context = browser.new_context(
                viewport=device["viewport"],
                device_scale_factor=device["device_scale_factor"],
                user_agent=device["user_agent"],
                is_mobile=device["is_mobile"],
                has_touch=device["has_touch"],
            )

            for game in GAMES:
                url = BASE_URL + game["path"]
                filename = f"{device['name']}_{game['name']}.png"
                filepath = out / filename

                print(f"  {game['name']}...", end=" ", flush=True)

                try:
                    page = context.new_page()

                    # Capture console errors
                    errors = []
                    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)
                    page.on("pageerror", lambda err: errors.append(str(err)))

                    page.goto(url, wait_until="networkidle", timeout=30000)
                    time.sleep(game["wait"])

                    page.screenshot(path=str(filepath), full_page=False)

                    result = {
                        "game": game["name"],
                        "device": device["name"],
                        "screenshot": str(filepath),
                        "url": url,
                        "errors": errors[:5],  # cap at 5
                        "status": "ok",
                    }
                    results.append(result)
                    print(f"OK{' (' + str(len(errors)) + ' errors)' if errors else ''}")

                except Exception as e:
                    result = {
                        "game": game["name"],
                        "device": device["name"],
                        "screenshot": None,
                        "url": url,
                        "errors": [str(e)],
                        "status": "failed",
                    }
                    results.append(result)
                    print(f"FAILED: {e}")

                finally:
                    page.close()

            context.close()

        browser.close()

    # Write results manifest
    manifest_path = out / "manifest.json"
    with open(manifest_path, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\n{'='*50}")
    print(f"Screenshots saved to: {output_dir}/")
    print(f"Manifest: {manifest_path}")
    print(f"Total: {len(results)} screenshots ({sum(1 for r in results if r['status'] == 'ok')} ok, {sum(1 for r in results if r['status'] == 'failed')} failed)")

    return results


if __name__ == "__main__":
    take_screenshots()
