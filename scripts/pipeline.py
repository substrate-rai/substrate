#!/usr/bin/env python3
"""Substrate daily blog pipeline. Reads the day's git log and drafts a post.

Usage:
    nix develop
    python3 scripts/pipeline.py                   # draft from today's commits
    python3 scripts/pipeline.py --date 2026-03-06  # specific date
    python3 scripts/pipeline.py --dry-run          # print draft, don't write file

Runs nightly at 9pm ET via systemd timer. Drafts locally via route.py,
writes to blog/posts/ for operator review before publishing.
"""

import argparse
import os
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

    # Build the full post
    slug = f"{date_str}-build-log"
    post = (
        f"---\n"
        f"title: \"Build Log: {date_str}\"\n"
        f"date: {date_str}\n"
        f"draft: true\n"
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
