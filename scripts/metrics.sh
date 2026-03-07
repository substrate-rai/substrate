#!/usr/bin/env bash
# metrics.sh — Track GitHub and social metrics
#
# Logs GitHub stars/forks and Bluesky follower count to memory/metrics.log.
# Run by systemd timer (weekly) or manually.
#
# Requires: curl (system), no auth needed for public GitHub API.

set -euo pipefail

REPO_DIR="/home/operator/substrate"
LOG_FILE="$REPO_DIR/memory/metrics.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

GITHUB_REPO="substrate-rai/substrate"
BLUESKY_HANDLE="rhizent-ai.bsky.social"

mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "--- $TIMESTAMP ---"

    # GitHub stars and forks (public API, no auth needed)
    gh_data=$(curl -s --max-time 10 "https://api.github.com/repos/$GITHUB_REPO" 2>/dev/null) || gh_data=""
    if [[ -n "$gh_data" ]]; then
        stars=$(echo "$gh_data" | grep -o '"stargazers_count":[0-9]*' | head -1 | cut -d: -f2)
        forks=$(echo "$gh_data" | grep -o '"forks_count":[0-9]*' | head -1 | cut -d: -f2)
        watchers=$(echo "$gh_data" | grep -o '"subscribers_count":[0-9]*' | head -1 | cut -d: -f2)
        echo "github: ${stars:-0} stars, ${forks:-0} forks, ${watchers:-0} watchers"
    else
        echo "github: api unreachable"
    fi

    # Bluesky followers (public API)
    bsky_data=$(curl -s --max-time 10 "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=$BLUESKY_HANDLE" 2>/dev/null) || bsky_data=""
    if [[ -n "$bsky_data" ]]; then
        followers=$(echo "$bsky_data" | grep -o '"followersCount":[0-9]*' | head -1 | cut -d: -f2)
        following=$(echo "$bsky_data" | grep -o '"followsCount":[0-9]*' | head -1 | cut -d: -f2)
        posts=$(echo "$bsky_data" | grep -o '"postsCount":[0-9]*' | head -1 | cut -d: -f2)
        echo "bluesky: ${followers:-0} followers, ${following:-0} following, ${posts:-0} posts"
    else
        echo "bluesky: api unreachable"
    fi

    # Blog (check if site is up, get rough page count)
    blog_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://substrate-rai.github.io/substrate/" 2>/dev/null) || blog_status="error"
    echo "blog: status $blog_status"

    # Local stats
    post_count=$(find "$REPO_DIR/_posts" -name "*.md" 2>/dev/null | wc -l)
    commit_count=$(git -C "$REPO_DIR" rev-list --count HEAD 2>/dev/null || echo "0")
    echo "repo: $commit_count commits, $post_count posts"

    echo ""
} >> "$LOG_FILE"

echo "[metrics] logged to $LOG_FILE" >&2
