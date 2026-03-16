#!/usr/bin/env bash
# autopush.sh — commit and push data changes hourly
# Runs via systemd timer. Idempotent: exits cleanly if nothing changed.
set -euo pipefail

REPO="/home/operator/substrate"
LOCKFILE="/tmp/substrate-autopush.lock"
LOG="$REPO/memory/health.log"

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') [autopush] $*" | tee -a "$LOG"; }

# Prevent concurrent runs
exec 200>"$LOCKFILE"
flock -n 200 || { log "SKIP: another autopush is running"; exit 0; }

cd "$REPO"

# Bail early if nothing changed
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard -- _data/ memory/ news/ scripts/posts/)" ]; then
    log "OK: nothing to push"
    exit 0
fi

# Stage only data files — never secrets, never unrelated work
git add _data/news.json \
        memory/news/ \
        memory/releases/ \
        memory/brainstorms/ \
        memory/curriculum/ \
        memory/diplomat/ \
        memory/engagement/ \
        memory/executive/ \
        memory/infra/ \
        memory/lore/ \
        memory/patron/ \
        memory/scout/ \
        memory/site/ \
        memory/vision/ \
        memory/visuals/ \
        news/ \
        scripts/posts/queue.jsonl \
        2>/dev/null || true

# Check if anything was actually staged
if git diff --cached --quiet; then
    log "OK: nothing staged after add"
    exit 0
fi

# Count what we're committing
NEWS_COUNT=$(python3 -c "import json; d=json.load(open('_data/news.json')); print(d.get('total',0))" 2>/dev/null || echo "?")
SIGNAL_COUNT=$(python3 -c "import json; d=json.load(open('_data/news.json')); print(d.get('signal_count',0))" 2>/dev/null || echo "?")
DATE=$(date -u +%Y-%m-%d)

git commit -m "data: hourly update ${DATE} — ${NEWS_COUNT} stories, ${SIGNAL_COUNT} signal"

# Push with one retry on failure
if ! git push origin master 2>&1; then
    log "WARN: push failed, attempting fetch+rebase"
    git fetch origin master
    if git rebase origin/master; then
        git push origin master 2>&1 || {
            log "ERROR: push failed after rebase"
            exit 1
        }
    else
        git rebase --abort
        log "ERROR: rebase conflict, skipping this cycle"
        exit 1
    fi
fi

log "OK: pushed ${NEWS_COUNT} stories"
