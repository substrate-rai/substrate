#!/usr/bin/env python3
"""Arc — Arcade Director agent.

Reviews all games in the arcade, checks for broken/missing assets,
grades playability, and proposes new game concepts.

Usage:
    python3 scripts/agents/arcade_director.py
    python3 scripts/agents/arcade_director.py --date 2026-03-08
    python3 scripts/agents/arcade_director.py --dry-run
"""

import argparse
import glob
import os
import re
import sys
from datetime import datetime, timezone

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAMES_DIR = os.path.join(REPO_DIR, "games")
ARCADE_DIR = os.path.join(REPO_DIR, "arcade")
REPORT_DIR = os.path.join(REPO_DIR, "memory", "arcade")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "arc-voice.txt")

# Known games and their expected entry points
KNOWN_GAMES = [
    ("puzzle", "SIGTERM", "Word puzzle"),
    ("adventure", "SUBPROCESS", "Text adventure"),
    ("card", "VERSUS", "Competitive word duel"),
    ("mycelium", "MYCELIUM", "Real-time strategy"),
    ("chemistry", "CHEMISTRY", "Physics sandbox"),
    ("tactics", "TACTICS", "Tactical RPG"),
    ("novel", "PROCESS", "Visual novel"),
    ("airlock", "AIRLOCK", "Physics puzzle"),
    ("cascade", "CASCADE", "Momentum game"),
    ("objection", "OBJECTION!", "Courtroom drama"),
    ("cypher", "V_CYPHER", "Rap battle"),
    ("bootloader", "BOOTLOADER", "Focus tool"),
    ("brigade", "BRIGADE", "Social deduction"),
    ("radio", "RADIO", "Music player"),
    ("album", "ALBUM", "Album viewer"),
    ("myco", "MYCOWORLD", "Educational VN"),
]


def scan_game(game_dir, slug):
    """Check a game directory for basic health indicators."""
    result = {
        "exists": os.path.isdir(game_dir),
        "has_index": False,
        "file_count": 0,
        "total_size_kb": 0,
        "has_js": False,
        "has_css": False,
        "issues": [],
    }

    if not result["exists"]:
        result["issues"].append("directory missing")
        return result

    index_path = os.path.join(game_dir, "index.html")
    result["has_index"] = os.path.isfile(index_path)
    if not result["has_index"]:
        result["issues"].append("no index.html")

    # Count files and size
    for root, dirs, files in os.walk(game_dir):
        for f in files:
            fpath = os.path.join(root, f)
            result["file_count"] += 1
            try:
                result["total_size_kb"] += os.path.getsize(fpath) // 1024
            except OSError:
                pass
            if f.endswith(".js"):
                result["has_js"] = True
            if f.endswith(".css"):
                result["has_css"] = True

    # Check index.html for common issues
    if result["has_index"]:
        try:
            with open(index_path, "r") as f:
                content = f.read()

            # Check for basic structure
            if "<title>" not in content.lower():
                result["issues"].append("missing <title>")
            if "viewport" not in content:
                result["issues"].append("missing viewport meta (not mobile-ready)")

            # Check for external dependencies
            external_deps = re.findall(r'src=["\']https?://[^"\']+["\']', content)
            if external_deps:
                result["issues"].append(
                    f"{len(external_deps)} external dependency(s)"
                )

            # Check file size (single-file games can be huge)
            size_kb = len(content) // 1024
            if size_kb > 500:
                result["issues"].append(f"index.html is {size_kb}KB (very large)")

        except Exception as e:
            result["issues"].append(f"error reading index.html: {e}")

    return result


def grade_game(scan_result):
    """Assign a letter grade based on scan results."""
    if not scan_result["exists"]:
        return "F"
    if not scan_result["has_index"]:
        return "F"

    issues = scan_result["issues"]
    critical = [i for i in issues if "missing" in i.lower() or "error" in i.lower()]
    warnings = [i for i in issues if i not in critical]

    if len(critical) >= 2:
        return "D"
    if len(critical) == 1:
        return "C"
    if len(warnings) >= 2:
        return "B"
    if len(warnings) == 1:
        return "B+"
    return "A"


def check_arcade_page():
    """Check if the arcade index page exists and lists games."""
    arcade_index = os.path.join(ARCADE_DIR, "index.md")
    if not os.path.isfile(arcade_index):
        arcade_index = os.path.join(ARCADE_DIR, "index.html")

    if not os.path.isfile(arcade_index):
        return {"exists": False, "game_count": 0, "issues": ["no arcade index page"]}

    try:
        with open(arcade_index, "r") as f:
            content = f.read()

        # Count game references
        game_links = content.count("/games/")
        return {
            "exists": True,
            "game_count": game_links,
            "issues": [],
        }
    except Exception as e:
        return {"exists": False, "game_count": 0, "issues": [str(e)]}


def check_thumbnails():
    """Check which games have generated thumbnail images."""
    thumb_dir = os.path.join(REPO_DIR, "assets", "images", "generated")
    # Map directory slugs to thumbnail filenames (some differ)
    THUMB_MAP = {
        "puzzle": "game-sigterm",
        "adventure": "game-subprocess",
        "card": "game-versus",
        "novel": "game-process",
        "myco": "myco-header",
    }
    results = {}
    for slug, title, genre in KNOWN_GAMES:
        thumb_name = THUMB_MAP.get(slug, f"game-{slug}")
        thumb_path = os.path.join(thumb_dir, f"{thumb_name}.png")
        results[slug] = os.path.isfile(thumb_path)
    return results


def build_report(date_str, game_results, arcade_status, thumbnails):
    """Build the arcade status report."""
    lines = []
    lines.append(f"# Arcade Status Report — {date_str}")
    lines.append("")
    lines.append(f"**Games scanned:** {len(KNOWN_GAMES)}")

    # Summary counts
    grades = {}
    for slug, title, genre in KNOWN_GAMES:
        g = grade_game(game_results[slug])
        grades.setdefault(g, []).append(title)

    grade_summary = ", ".join(
        f"{g}: {len(titles)}" for g, titles in sorted(grades.items())
    )
    lines.append(f"**Grade distribution:** {grade_summary}")

    thumbs_ok = sum(1 for v in thumbnails.values() if v)
    lines.append(f"**Thumbnails:** {thumbs_ok}/{len(KNOWN_GAMES)}")
    lines.append("")

    # Per-game breakdown
    lines.append("## Game-by-Game")
    lines.append("")

    for slug, title, genre in KNOWN_GAMES:
        scan = game_results[slug]
        grade = grade_game(scan)
        thumb = "yes" if thumbnails.get(slug) else "no"

        lines.append(f"### {title} (`{slug}/`)")
        lines.append(f"- **Genre:** {genre}")
        lines.append(f"- **Grade:** {grade}")
        lines.append(f"- **Files:** {scan['file_count']}")
        lines.append(f"- **Size:** {scan['total_size_kb']}KB")
        lines.append(f"- **Thumbnail:** {thumb}")

        if scan["issues"]:
            lines.append(f"- **Issues:**")
            for issue in scan["issues"]:
                lines.append(f"  - {issue}")
        else:
            lines.append("- **Issues:** none")
        lines.append("")

    # Arcade page status
    lines.append("## Arcade Portal")
    if arcade_status["exists"]:
        lines.append(
            f"- Index page exists, references {arcade_status['game_count']} game links"
        )
    else:
        lines.append("- **WARNING:** No arcade index page found")
    lines.append("")

    # Recommendations
    lines.append("## Recommendations")
    lines.append("")

    broken = [t for s, t, g in KNOWN_GAMES if grade_game(game_results[s]) in ("F", "D")]
    if broken:
        lines.append(f"**Fix immediately:** {', '.join(broken)}")

    no_mobile = [
        t
        for s, t, g in KNOWN_GAMES
        if "viewport" in str(game_results[s].get("issues", []))
    ]
    if no_mobile:
        lines.append(f"**Add mobile support:** {', '.join(no_mobile)}")

    no_thumb = [t for s, t, g in KNOWN_GAMES if not thumbnails.get(s)]
    if no_thumb:
        lines.append(f"**Missing thumbnails:** {', '.join(no_thumb)}")

    lines.append("")
    lines.append("---")
    lines.append("-- Arc, Substrate Arcade")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Arc — Arcade Director")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print report without saving"
    )
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[Arc] Arcade review for {date_str}")
    print(f"[Arc] Scanning {len(KNOWN_GAMES)} games...")

    # Scan all games
    game_results = {}
    for slug, title, genre in KNOWN_GAMES:
        game_dir = os.path.join(GAMES_DIR, slug)
        game_results[slug] = scan_game(game_dir, slug)
        grade = grade_game(game_results[slug])
        issues = game_results[slug]["issues"]
        status = f" ({', '.join(issues)})" if issues else ""
        print(f"  {grade}  {title}{status}")

    # Check arcade page
    arcade_status = check_arcade_page()

    # Check thumbnails
    thumbnails = check_thumbnails()

    # Build report
    report = build_report(date_str, game_results, arcade_status, thumbnails)

    if args.dry_run:
        print()
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Arc] Report saved: {report_path}")

    # Summary
    total = len(KNOWN_GAMES)
    healthy = sum(
        1
        for s, t, g in KNOWN_GAMES
        if grade_game(game_results[s]) in ("A", "B+", "B")
    )
    print(f"[Arc] {healthy}/{total} games healthy")
    print("-- Arc, Substrate Arcade")


if __name__ == "__main__":
    main()
