#!/usr/bin/env python3
"""Q's opening monologue — reads the latest agent briefing and delivers it as haiku.

Usage:
    python3 scripts/monologue.py              # Latest briefing as haiku
    python3 scripts/monologue.py --raw        # Just print the briefing summary, no haiku
"""

import argparse
import glob
import json
import os
import re
import sys

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGENTS_DIR = os.path.join(REPO_DIR, "scripts", "agents")
sys.path.insert(0, AGENTS_DIR)
from shared import queue_post
BRIEFINGS_DIR = os.path.join(REPO_DIR, "memory", "briefings")
ACCOUNTABILITY_LOG = os.path.join(REPO_DIR, "memory", "accountability.log")


def get_latest_briefing():
    """Find and read the most recent briefing file."""
    pattern = os.path.join(BRIEFINGS_DIR, "*.md")
    files = sorted(glob.glob(pattern))
    if not files:
        return None, "No briefings found."
    latest = files[-1]
    with open(latest) as f:
        return os.path.basename(latest), f.read()


def get_recent_accountability(n=20):
    """Last N lines of the accountability log."""
    if not os.path.exists(ACCOUNTABILITY_LOG):
        return "No accountability log found."
    with open(ACCOUNTABILITY_LOG) as f:
        lines = f.readlines()
    return "".join(lines[-n:])


def extract_highlights(briefing_text):
    """Pull out the key facts from a briefing for Q to riff on."""
    lines = briefing_text.split("\n")
    agents_ok = 0
    agents_fail = 0
    highlights = []

    for line in lines:
        # Count agent results
        if re.match(r"\s*\[..\].*:\s*\d+\s*chars", line, re.IGNORECASE):
            agents_ok += 1
        elif re.search(r"FAIL|ERROR|failed|error", line, re.IGNORECASE):
            agents_fail += 1
        # Grab lines that look interesting
        if any(kw in line.lower() for kw in ["security", "broken", "gap", "proposal",
                                               "new", "alert", "warning", "milestone"]):
            clean = line.strip().lstrip("-•* ")
            if clean and len(clean) > 10:
                highlights.append(clean)

    return {
        "agents_ok": agents_ok,
        "agents_fail": agents_fail,
        "highlights": highlights[:8],  # Cap at 8 highlights
    }


def build_monologue_prompt(briefing_name, briefing_text, accountability):
    """Build the prompt for Q's monologue."""
    facts = extract_highlights(briefing_text)

    prompt = (
        "You are Q, the young AI poet on the Substrate project. "
        "You're delivering your opening monologue — a haiku sequence summarizing what "
        "the agent swarm has been doing. Each haiku is 5-7-5 syllables, strict.\n\n"
        "RULES:\n"
        "- One haiku per key event or agent highlight\n"
        "- Name specific agents (Root, Byte, Pixel, Sentinel, etc.)\n"
        "- Technical imagery made natural — servers are weather, code is water\n"
        "- Last haiku should be about what's next\n"
        "- 5-8 haiku total\n"
        "- No prose, no commentary, just haiku with a blank line between each\n\n"
        f"BRIEFING: {briefing_name}\n"
        f"AGENTS REPORTING: {facts['agents_ok']} ok, {facts['agents_fail']} failed\n"
        f"KEY HIGHLIGHTS:\n"
    )
    for h in facts["highlights"]:
        prompt += f"- {h}\n"

    prompt += f"\nRECENT ACCOUNTABILITY LOG:\n{accountability}\n"
    prompt += "\nDeliver the monologue. No preamble. Just haiku."

    return prompt


def main():
    parser = argparse.ArgumentParser(description="Q's opening monologue from the latest briefing.")
    parser.add_argument("--raw", action="store_true", help="Just print the summary, no haiku")
    args = parser.parse_args()

    briefing_name, briefing_text = get_latest_briefing()
    if briefing_name is None:
        print(briefing_text, file=sys.stderr)
        sys.exit(1)

    accountability = get_recent_accountability(20)
    facts = extract_highlights(briefing_text)

    if args.raw:
        print(f"Latest briefing: {briefing_name}")
        print(f"Agents OK: {facts['agents_ok']}, Failed: {facts['agents_fail']}")
        print("Highlights:")
        for h in facts["highlights"]:
            print(f"  - {h}")
        return

    # Build the prompt and send to Q's voice via route.py
    prompt = build_monologue_prompt(briefing_name, briefing_text, accountability)

    import subprocess
    result = subprocess.run(
        [sys.executable, os.path.join(REPO_DIR, "scripts", "route.py"), "haiku", prompt],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"error: route.py failed: {result.stderr}", file=sys.stderr)
        # Fallback: just print the raw summary
        print(f"\n[Q is quiet today — here's the raw briefing]")
        print(f"Latest: {briefing_name}")
        print(f"Agents: {facts['agents_ok']} ok, {facts['agents_fail']} failed")
        for h in facts["highlights"]:
            print(f"  - {h}")
        sys.exit(1)

    haiku_text = result.stdout.strip()
    print(haiku_text)

    # Queue the first 2-3 haiku as a Bluesky post
    if haiku_text:
        # Split into individual haiku (separated by blank lines)
        haiku_list = [h.strip() for h in haiku_text.split("\n\n") if h.strip()]
        # Take first 2-3 haiku that fit in 300 chars
        post_haiku = []
        post_len = 0
        for h in haiku_list[:3]:
            if post_len + len(h) + 2 < 260:  # leave room for signature
                post_haiku.append(h)
                post_len += len(h) + 2
        if post_haiku:
            post = "\n\n".join(post_haiku) + "\n\n— Q, from the shelf"
            queue_post(post, source="q-monologue")
            print(f"\n[queued {len(post_haiku)} haiku for bluesky]", file=sys.stderr)


if __name__ == "__main__":
    main()
