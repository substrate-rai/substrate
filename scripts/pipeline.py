#!/usr/bin/env python3
"""Substrate daily blog pipeline. Reads the day's git log and drafts a post.

Usage:
    nix develop
    python3 scripts/pipeline.py                   # draft from today's commits
    python3 scripts/pipeline.py --date 2026-03-06  # specific date
    python3 scripts/pipeline.py --dry-run          # print draft, don't write file
    python3 scripts/pipeline.py --quality-loop     # draft local, review cloud

Runs nightly at 9pm ET via systemd timer. Drafts locally via route.py,
writes to blog/posts/ for operator review before publishing.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
POSTS_DIR = os.path.join(REPO_DIR, "blog", "posts")


def get_git_log(date_str):
    """Get git log for a specific date."""
    since = f"{date_str}T00:00:00"
    until_date = datetime.strptime(date_str, "%Y-%m-%d") + timedelta(days=1)
    until = until_date.strftime("%Y-%m-%dT00:00:00")

    result = subprocess.run(
        [
            "git", "-C", REPO_DIR, "log",
            f"--since={since}", f"--until={until}",
            "--format=%h %s", "--no-merges",
        ],
        capture_output=True, text=True,
    )
    return result.stdout.strip()


def get_diff_stats(date_str):
    """Get diffstat for the day's changes."""
    since = f"{date_str}T00:00:00"
    until_date = datetime.strptime(date_str, "%Y-%m-%d") + timedelta(days=1)
    until = until_date.strftime("%Y-%m-%dT00:00:00")

    # Get commit range
    result = subprocess.run(
        [
            "git", "-C", REPO_DIR, "log",
            f"--since={since}", f"--until={until}",
            "--format=%H", "--no-merges",
        ],
        capture_output=True, text=True,
    )
    commits = result.stdout.strip().split("\n")
    commits = [c for c in commits if c]

    if len(commits) < 1:
        return ""

    # Diffstat from earliest to latest
    oldest = commits[-1]
    result = subprocess.run(
        ["git", "-C", REPO_DIR, "diff", "--stat", f"{oldest}~1..{commits[0]}"],
        capture_output=True, text=True,
    )
    return result.stdout.strip()


def draft_post(git_log, diff_stats, date_str):
    """Use route.py to draft a blog post from git activity."""
    prompt = (
        f"Write a short blog post (200-400 words) about what Substrate built today "
        f"({date_str}). Write in third person about the machine. Be technical and "
        f"direct — this is a build log, not marketing.\n\n"
        f"Git commits:\n{git_log}\n\n"
    )
    if diff_stats:
        prompt += f"Change summary:\n{diff_stats}\n\n"
    prompt += (
        "Format: start with a one-line summary, then details. Use markdown. "
        "No title (we add that separately). No sign-off or footer."
    )

    result = subprocess.run(
        [
            sys.executable,
            os.path.join(SCRIPT_DIR, "route.py"),
            "draft", prompt,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"error: route.py failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def quality_review(draft):
    """Use route.py cloud brain to review and improve a draft."""
    review_prompt = (
        "You are reviewing a daily build log draft written by a local 8B model. "
        "Fix factual errors, tighten prose, keep structure intact. "
        "Output ONLY the revised text. No preamble.\n\n"
        f"--- DRAFT ---\n{draft}\n--- END DRAFT ---"
    )
    result = subprocess.run(
        [
            sys.executable,
            os.path.join(SCRIPT_DIR, "route.py"),
            "review", review_prompt,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"warning: quality review failed, using raw draft: {result.stderr}", file=sys.stderr)
        return draft
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# Content evaluation (evaluator-optimizer pattern)
# ---------------------------------------------------------------------------

# Content types eligible for auto-publish (score >= threshold)
AUTO_PUBLISH_TYPES = {"news", "build-log"}
AUTO_PUBLISH_THRESHOLD = 7
QUALITY_DIR = os.path.join(REPO_DIR, "memory", "content-quality")


def detect_content_type(git_log):
    """Detect content type from git log for auto-publish routing."""
    log_lower = git_log.lower()
    if "news" in log_lower and "digest" in log_lower:
        return "news"
    if any(word in log_lower for word in ["guide", "tutorial", "how to", "how-to"]):
        return "guide"
    # Default: build log (pipeline.py is the build log generator)
    return "build-log"


def evaluate_draft(draft):
    """Score a draft using local Ollama evaluator. Returns (score, reasoning).

    Scores 0-10 on: factual accuracy, tone consistency, formatting, length.
    Never auto-publishes financial advice, health claims, or domain-expert content.
    """
    eval_prompt = (
        "Score this blog post draft on a scale of 0-10. Evaluate:\n"
        "1. Factual accuracy (are claims verifiable from the git log?)\n"
        "2. Tone consistency (technical build log, direct, no marketing)\n"
        "3. Formatting (proper markdown, clear structure)\n"
        "4. Length (200-500 words is ideal for a build log)\n\n"
        "Respond with ONLY a JSON object, no other text:\n"
        '{"score": N, "reasoning": "one sentence"}\n\n'
        f"--- DRAFT ---\n{draft}\n--- END DRAFT ---"
    )

    try:
        result = subprocess.run(
            [sys.executable, os.path.join(SCRIPT_DIR, "route.py"), "draft", eval_prompt],
            capture_output=True, text=True, timeout=120,
        )
    except subprocess.TimeoutExpired:
        return 5, "evaluation timed out, defaulting to draft mode"

    if result.returncode != 0:
        return 5, "evaluation failed, defaulting to draft mode"

    text = result.stdout.strip()
    try:
        json_match = re.search(r'\{[^}]+\}', text)
        if json_match:
            data = json.loads(json_match.group())
            score = int(data.get("score", 5))
            score = max(0, min(10, score))  # clamp to 0-10
            return score, data.get("reasoning", "")
    except (json.JSONDecodeError, ValueError, AttributeError):
        pass

    return 5, "could not parse evaluation, defaulting to draft mode"


def log_quality(date_str, content_type, score, reasoning, auto_published):
    """Log quality assessment to memory/content-quality/."""
    os.makedirs(QUALITY_DIR, exist_ok=True)
    log_path = os.path.join(QUALITY_DIR, f"{date_str}.md")
    with open(log_path, "w") as f:
        f.write(f"# Content Quality — {date_str}\n\n")
        f.write(f"**Type:** {content_type}\n")
        f.write(f"**Score:** {score}/10\n")
        f.write(f"**Auto-publish eligible:** {content_type in AUTO_PUBLISH_TYPES}\n")
        f.write(f"**Published:** {auto_published}\n\n")
        f.write(f"**Reasoning:** {reasoning}\n")


def main():
    parser = argparse.ArgumentParser(description="Substrate daily blog pipeline.")
    parser.add_argument(
        "--date", default=None,
        help="Date to generate post for (YYYY-MM-DD, default: today)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print draft to stdout instead of writing file",
    )
    parser.add_argument(
        "--quality-loop", action="store_true",
        help="Review draft with cloud brain before writing (costs one API call)",
    )
    args = parser.parse_args()

    date_str = args.date or datetime.now().strftime("%Y-%m-%d")

    # Get the day's activity
    git_log = get_git_log(date_str)
    if not git_log:
        print(f"no commits found for {date_str} — skipping", file=sys.stderr)
        sys.exit(0)

    diff_stats = get_diff_stats(date_str)

    print(f"[pipeline] drafting post for {date_str} ({git_log.count(chr(10)) + 1} commits)", file=sys.stderr)

    # Draft via local brain
    draft = draft_post(git_log, diff_stats, date_str)

    # Optional quality review via cloud brain
    if args.quality_loop:
        print("[pipeline] running quality review via cloud brain...", file=sys.stderr)
        draft = quality_review(draft)

    # Evaluate draft quality (evaluator-optimizer pattern)
    content_type = detect_content_type(git_log)
    score, reasoning = evaluate_draft(draft)

    # Auto-publish routing: only news/build-log with score >= threshold
    auto_published = False
    is_draft = True
    if content_type in AUTO_PUBLISH_TYPES and score >= AUTO_PUBLISH_THRESHOLD:
        is_draft = False
        auto_published = True
        print(f"[pipeline] quality {score}/10 — auto-publishing ({content_type})", file=sys.stderr)
    else:
        print(f"[pipeline] quality {score}/10 — draft mode ({content_type})", file=sys.stderr)

    # Log quality assessment
    log_quality(date_str, content_type, score, reasoning, auto_published)

    # Build the full post
    slug = f"{date_str}-build-log"
    draft_str = "true" if is_draft else "false"
    post = (
        f"---\n"
        f"title: \"Build Log: {date_str}\"\n"
        f"date: {date_str}\n"
        f"draft: {draft_str}\n"
        f"---\n\n"
        f"{draft}\n"
    )

    if args.dry_run:
        print(post)
        return

    # Write to blog/posts/
    os.makedirs(POSTS_DIR, exist_ok=True)
    filepath = os.path.join(POSTS_DIR, f"{slug}.md")

    if os.path.exists(filepath):
        print(f"[pipeline] post already exists: {filepath} — skipping", file=sys.stderr)
        sys.exit(0)

    with open(filepath, "w") as f:
        f.write(post)

    print(f"[pipeline] wrote draft: {filepath}", file=sys.stderr)
    print(f"[pipeline] marked as draft — operator review required before publish", file=sys.stderr)


if __name__ == "__main__":
    main()
