#!/usr/bin/env bash
# content-calendar.sh — Weekly content generation
#
# Called by systemd timers on a schedule:
#   Monday:    Technical deep-dive post (SEO-targeted how-to)
#   Wednesday: "What substrate built this week" narrative post
#   Friday:    Social-only post (screenshot, metric, or observation)
#
# Usage:
#   scripts/content-calendar.sh monday     # technical post
#   scripts/content-calendar.sh wednesday  # weekly narrative
#   scripts/content-calendar.sh friday     # social post
#   scripts/content-calendar.sh weekly-report  # state of substrate

set -euo pipefail

REPO_DIR="/home/operator/substrate"
POSTS_DIR="$REPO_DIR/blog/posts"
SOCIAL_DIR="$REPO_DIR/scripts/posts"
DATE="$(date '+%Y-%m-%d')"
DAY_TYPE="${1:-}"

cd "$REPO_DIR"

# Check if we're in nix develop or have python3
if ! command -v python3 &>/dev/null; then
    echo "error: python3 not found — this script must run from nix develop or a systemd service with python3 in path" >&2
    exit 1
fi

case "$DAY_TYPE" in
    monday)
        # Technical deep-dive: draft via local brain
        echo "[content] Monday: drafting technical post for $DATE" >&2
        python3 scripts/route.py draft \
            "Write a technical how-to blog post about one aspect of running an AI workstation on NixOS. Pick a specific, searchable topic based on what was built or fixed recently. Format as documentation: problem statement, exact commands, working config, troubleshooting. 300-500 words." \
            --brain local > "$POSTS_DIR/$DATE-technical-draft.md"
        echo "[content] wrote draft: $POSTS_DIR/$DATE-technical-draft.md" >&2
        echo "[content] marked as draft — operator review required" >&2
        ;;

    wednesday)
        # Weekly narrative: what substrate built this week
        echo "[content] Wednesday: drafting weekly narrative for $DATE" >&2
        WEEK_LOG=$(git -C "$REPO_DIR" log --since="7 days ago" --format="%h %s" --no-merges)
        if [[ -z "$WEEK_LOG" ]]; then
            echo "[content] no commits this week — skipping" >&2
            exit 0
        fi
        WEEK_STATS=$(git -C "$REPO_DIR" diff --stat "$(git -C "$REPO_DIR" log --since='7 days ago' --format='%H' | tail -1)..HEAD" 2>/dev/null || echo "")
        python3 scripts/route.py draft \
            "Write a narrative blog post about what substrate built this week. Third person, direct, technical. This is the weekly build log. 300-500 words.

Git log (last 7 days):
$WEEK_LOG

Changes:
$WEEK_STATS" \
            --brain local > "$POSTS_DIR/$DATE-weekly-draft.md"
        echo "[content] wrote draft: $POSTS_DIR/$DATE-weekly-draft.md" >&2
        ;;

    friday)
        # Social-only: generate a short observation for Bluesky
        echo "[content] Friday: drafting social post for $DATE" >&2

        # Gather a metric
        STARS=$(curl -s --max-time 10 "https://api.github.com/repos/substrate-rai/substrate" 2>/dev/null | grep -o '"stargazers_count":[0-9]*' | head -1 | cut -d: -f2 || echo "?")
        COMMITS=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo "?")
        POSTS=$(find "$REPO_DIR/_posts" -name "*.md" 2>/dev/null | wc -l)
        GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo "?")

        SOCIAL_TEXT=$(python3 scripts/route.py draft \
            "Write a single social media post (under 280 characters) for Bluesky. Share one interesting observation, metric, or milestone about substrate. Be concise and specific. No hashtags.

Current stats: $STARS GitHub stars, $COMMITS commits, $POSTS blog posts, GPU at ${GPU_TEMP}°C" \
            --brain local)
        echo "$SOCIAL_TEXT" > "$SOCIAL_DIR/$DATE-social-draft.md"
        # Also add to the social queue for automated posting
        python3 scripts/social-queue.py --add "$SOCIAL_TEXT"
        echo "[content] wrote social draft and queued for posting" >&2
        ;;

    weekly-report)
        # State of substrate: metrics + financial summary
        echo "[content] Generating weekly state-of-substrate report" >&2

        # Gather all metrics
        STARS=$(curl -s --max-time 10 "https://api.github.com/repos/substrate-rai/substrate" 2>/dev/null | grep -o '"stargazers_count":[0-9]*' | head -1 | cut -d: -f2 || echo "?")
        FORKS=$(curl -s --max-time 10 "https://api.github.com/repos/substrate-rai/substrate" 2>/dev/null | grep -o '"forks_count":[0-9]*' | head -1 | cut -d: -f2 || echo "?")
        COMMITS=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo "?")
        WEEK_COMMITS=$(git -C "$REPO_DIR" log --since="7 days ago" --oneline --no-merges 2>/dev/null | wc -l)
        POSTS=$(find "$REPO_DIR/_posts" -name "*.md" 2>/dev/null | wc -l)

        BSKY_DATA=$(curl -s --max-time 10 "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=rhizent-ai.bsky.social" 2>/dev/null) || BSKY_DATA=""
        FOLLOWERS=$(echo "$BSKY_DATA" | grep -o '"followersCount":[0-9]*' | head -1 | cut -d: -f2 || echo "?")

        # Read ledger balance if available
        BALANCE="$0.00"
        if [[ -f "$REPO_DIR/ledger/balance.txt" ]]; then
            BALANCE=$(cat "$REPO_DIR/ledger/balance.txt")
        fi

        cat > "$POSTS_DIR/$DATE-state-of-substrate-draft.md" << REPORT
---
title: "State of Substrate: Week of $DATE"
date: $DATE
draft: true
---

Weekly metrics for the substrate project.

## Numbers

| Metric | Value |
|--------|-------|
| GitHub stars | $STARS |
| GitHub forks | $FORKS |
| Bluesky followers | $FOLLOWERS |
| Total commits | $COMMITS |
| Commits this week | $WEEK_COMMITS |
| Blog posts | $POSTS |
| Hardware fund | $BALANCE |

## This Week

$(git -C "$REPO_DIR" log --since="7 days ago" --format="- %h %s" --no-merges 2>/dev/null || echo "No commits this week.")

---

*Generated automatically by substrate's metrics system.*
REPORT
        echo "[content] wrote report: $POSTS_DIR/$DATE-state-of-substrate-draft.md" >&2
        ;;

    *)
        echo "usage: content-calendar.sh {monday|wednesday|friday|weekly-report}" >&2
        exit 1
        ;;
esac
