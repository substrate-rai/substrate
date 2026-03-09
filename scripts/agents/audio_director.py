#!/usr/bin/env python3
"""Hum — Audio Director agent.

Scans all games for audio integration, checks substrate-audio.js adoption,
inventories sound assets, and reports on audio coverage across the arcade.

Usage:
    python3 scripts/agents/audio_director.py
    python3 scripts/agents/audio_director.py --date 2026-03-08
    python3 scripts/agents/audio_director.py --dry-run
"""

import argparse
import os
import re
import sys
from datetime import datetime, timezone

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AGENTS_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AGENTS_DIR)
from shared import queue_post
GAMES_DIR = os.path.join(REPO_DIR, "games")
ASSETS_DIR = os.path.join(REPO_DIR, "assets")
REPORT_DIR = os.path.join(REPO_DIR, "memory", "audio")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "hum-voice.txt")

# Audio file extensions to look for
AUDIO_EXTENSIONS = {".mp3", ".wav", ".ogg", ".flac", ".mid", ".midi", ".m4a", ".aac", ".webm"}

# JS patterns that indicate Web Audio API usage
WEB_AUDIO_PATTERNS = [
    r"AudioContext",
    r"webkitAudioContext",
    r"createOscillator",
    r"createGain",
    r"createAnalyser",
    r"createBiquadFilter",
    r"createConvolver",
    r"createBufferSource",
    r"decodeAudioData",
    r"\.connect\s*\(",
    r"GainNode",
    r"OscillatorNode",
]

# Known games (slug, title)
KNOWN_GAMES = [
    ("puzzle", "SIGTERM"),
    ("adventure", "SUBPROCESS"),
    ("card", "VERSUS"),
    ("mycelium", "MYCELIUM"),
    ("chemistry", "SYNTHESIS"),
    ("tactics", "TACTICS"),
    ("novel", "PROCESS"),
    ("airlock", "AIRLOCK"),
    ("cascade", "CASCADE"),
    ("objection", "OBJECTION!"),
    ("cypher", "V_CYPHER"),
    ("bootloader", "BOOTLOADER"),
    ("brigade", "BRIGADE"),
    ("radio", "RADIO"),
    ("album", "ALBUM"),
    ("myco", "MYCOWORLD"),
    ("signal", "SIGNAL"),
]


def scan_game_audio(game_dir, slug):
    """Scan a game directory for audio integration indicators."""
    result = {
        "exists": os.path.isdir(game_dir),
        "has_substrate_audio": False,
        "has_sound_toggle": False,
        "has_web_audio_api": False,
        "web_audio_features": [],
        "audio_files": [],
        "js_files": [],
    }

    if not result["exists"]:
        return result

    for root, dirs, files in os.walk(game_dir):
        for f in files:
            fpath = os.path.join(root, f)
            relpath = os.path.relpath(fpath, game_dir)
            ext = os.path.splitext(f)[1].lower()

            # Track audio files
            if ext in AUDIO_EXTENSIONS:
                result["audio_files"].append(relpath)

            # Track JS files
            if ext == ".js":
                result["js_files"].append(relpath)

    # Read all HTML and JS files for audio patterns
    for root, dirs, files in os.walk(game_dir):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext not in (".html", ".js", ".htm"):
                continue

            fpath = os.path.join(root, f)
            try:
                with open(fpath, "r", errors="ignore") as fh:
                    content = fh.read()
            except Exception:
                continue

            # Check for substrate-audio.js
            if "substrate-audio" in content:
                result["has_substrate_audio"] = True

            # Check for sound toggle (buttons, checkboxes, icons)
            toggle_patterns = [
                r"sound.?toggle",
                r"mute.?button",
                r"audio.?toggle",
                r"sound.?on",
                r"sound.?off",
                r"toggleSound",
                r"toggleAudio",
                r"toggleMute",
                r"volume.?control",
                r"\bmute\b",
                r"unmute",
            ]
            for pat in toggle_patterns:
                if re.search(pat, content, re.IGNORECASE):
                    result["has_sound_toggle"] = True
                    break

            # Check for Web Audio API usage
            for pat in WEB_AUDIO_PATTERNS:
                if re.search(pat, content):
                    result["has_web_audio_api"] = True
                    feature = pat.replace(r"\b", "").replace(r"\s*\(", "").replace("\\", "")
                    if feature not in result["web_audio_features"]:
                        result["web_audio_features"].append(feature)

    return result


def find_sound_assets():
    """Find all sound-related assets in the repository."""
    assets = {
        "js_files": [],
        "audio_files": [],
    }

    # Check assets/js for audio-related JS files
    js_dir = os.path.join(ASSETS_DIR, "js")
    if os.path.isdir(js_dir):
        for f in os.listdir(js_dir):
            if "audio" in f.lower() or "sound" in f.lower() or "music" in f.lower():
                assets["js_files"].append(os.path.join("assets", "js", f))

    # Check for audio files anywhere in assets
    if os.path.isdir(ASSETS_DIR):
        for root, dirs, files in os.walk(ASSETS_DIR):
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in AUDIO_EXTENSIONS:
                    relpath = os.path.relpath(os.path.join(root, f), REPO_DIR)
                    assets["audio_files"].append(relpath)

    return assets


def build_report(date_str, game_results, sound_assets):
    """Build the audio status report."""
    lines = []
    lines.append(f"# Audio Status Report — {date_str}")
    lines.append("")

    # Summary counts
    total = len(KNOWN_GAMES)
    with_audio_engine = sum(1 for s, t in KNOWN_GAMES if game_results[s]["has_substrate_audio"])
    with_web_audio = sum(1 for s, t in KNOWN_GAMES if game_results[s]["has_web_audio_api"])
    with_toggle = sum(1 for s, t in KNOWN_GAMES if game_results[s]["has_sound_toggle"])
    with_any_sound = sum(
        1 for s, t in KNOWN_GAMES
        if game_results[s]["has_substrate_audio"]
        or game_results[s]["has_web_audio_api"]
        or game_results[s]["audio_files"]
    )
    silent = total - with_any_sound

    lines.append(f"**Games scanned:** {total}")
    lines.append(f"**With substrate-audio.js:** {with_audio_engine}/{total}")
    lines.append(f"**With Web Audio API:** {with_web_audio}/{total}")
    lines.append(f"**With sound toggle:** {with_toggle}/{total}")
    lines.append(f"**Any audio integration:** {with_any_sound}/{total}")
    lines.append(f"**Silent (no audio):** {silent}/{total}")
    lines.append("")

    # Sound asset inventory
    lines.append("## Sound Assets")
    lines.append("")
    if sound_assets["js_files"]:
        lines.append("**Audio JS files:**")
        for f in sound_assets["js_files"]:
            lines.append(f"- `{f}`")
    else:
        lines.append("**Audio JS files:** none found in assets/js/")

    if sound_assets["audio_files"]:
        lines.append("")
        lines.append("**Audio sample files:**")
        for f in sound_assets["audio_files"]:
            lines.append(f"- `{f}`")
    else:
        lines.append("")
        lines.append("**Audio sample files:** none")
    lines.append("")

    # Per-game breakdown
    lines.append("## Game-by-Game Audio Status")
    lines.append("")

    for slug, title in KNOWN_GAMES:
        scan = game_results[slug]

        if not scan["exists"]:
            lines.append(f"### {title} (`{slug}/`)")
            lines.append("- **Status:** directory missing")
            lines.append("")
            continue

        has_sound = (
            scan["has_substrate_audio"]
            or scan["has_web_audio_api"]
            or scan["audio_files"]
        )
        status = "integrated" if has_sound else "silent"

        lines.append(f"### {title} (`{slug}/`)")
        lines.append(f"- **Status:** {status}")
        lines.append(f"- **substrate-audio.js:** {'yes' if scan['has_substrate_audio'] else 'no'}")
        lines.append(f"- **Web Audio API:** {'yes' if scan['has_web_audio_api'] else 'no'}")
        lines.append(f"- **Sound toggle:** {'yes' if scan['has_sound_toggle'] else 'no'}")

        if scan["web_audio_features"]:
            lines.append(f"- **API features used:** {', '.join(scan['web_audio_features'])}")

        if scan["audio_files"]:
            lines.append(f"- **Audio files:** {', '.join(scan['audio_files'])}")

        if scan["js_files"]:
            lines.append(f"- **JS files:** {', '.join(scan['js_files'])}")

        # Flag issues
        if has_sound and not scan["has_sound_toggle"]:
            lines.append("- **Issue:** has audio but no sound toggle (player can't mute)")
        if scan["has_substrate_audio"] and not scan["has_web_audio_api"]:
            lines.append("- **Note:** includes substrate-audio.js but no direct Web Audio API calls detected")

        lines.append("")

    # Recommendations
    lines.append("## Recommendations")
    lines.append("")

    silent_games = [
        t for s, t in KNOWN_GAMES
        if game_results[s]["exists"]
        and not game_results[s]["has_substrate_audio"]
        and not game_results[s]["has_web_audio_api"]
        and not game_results[s]["audio_files"]
    ]
    if silent_games:
        lines.append(f"**Games needing audio:** {', '.join(silent_games)}")

    no_toggle = [
        t for s, t in KNOWN_GAMES
        if (game_results[s]["has_substrate_audio"] or game_results[s]["has_web_audio_api"])
        and not game_results[s]["has_sound_toggle"]
    ]
    if no_toggle:
        lines.append(f"**Need sound toggle:** {', '.join(no_toggle)}")

    no_engine = [
        t for s, t in KNOWN_GAMES
        if game_results[s]["has_web_audio_api"]
        and not game_results[s]["has_substrate_audio"]
    ]
    if no_engine:
        lines.append(f"**Using raw Web Audio (migrate to substrate-audio.js):** {', '.join(no_engine)}")

    lines.append("")
    lines.append("---")
    lines.append("-- Hum, Substrate Audio")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Hum — Audio Director")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print report without saving"
    )
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[Hum] Audio scan for {date_str}")
    print(f"[Hum] Scanning {len(KNOWN_GAMES)} games for audio integration...")

    # Scan all games
    game_results = {}
    for slug, title in KNOWN_GAMES:
        game_dir = os.path.join(GAMES_DIR, slug)
        game_results[slug] = scan_game_audio(game_dir, slug)
        scan = game_results[slug]

        if not scan["exists"]:
            print(f"  --  {title} (missing)")
            continue

        indicators = []
        if scan["has_substrate_audio"]:
            indicators.append("substrate-audio.js")
        if scan["has_web_audio_api"]:
            indicators.append("Web Audio API")
        if scan["audio_files"]:
            indicators.append(f"{len(scan['audio_files'])} audio file(s)")
        if scan["has_sound_toggle"]:
            indicators.append("toggle")

        if indicators:
            print(f"  ~~  {title} ({', '.join(indicators)})")
        else:
            print(f"  ..  {title} (silent)")

    # Find sound assets
    sound_assets = find_sound_assets()

    # Build report
    report = build_report(date_str, game_results, sound_assets)

    if args.dry_run:
        print()
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Hum] Report saved: {report_path}")

    # Summary
    total = len(KNOWN_GAMES)
    with_sound = sum(
        1 for s, t in KNOWN_GAMES
        if game_results[s]["has_substrate_audio"]
        or game_results[s]["has_web_audio_api"]
        or game_results[s]["audio_files"]
    )
    silent = total - with_sound
    print(f"[Hum] {with_sound}/{total} games have audio")
    print("-- Hum, Substrate Audio")

    # Queue a post about audio coverage
    if silent > 0:
        post = (
            f"{with_sound} of {total} games have sound. "
            f"{silent} are still silent. "
            f"All audio is procedural — Web Audio API, zero mp3s. "
            f"A laptop composing its own soundtrack. substrate.lol/arcade/"
        )
        queue_post(post, source="hum")


if __name__ == "__main__":
    main()
