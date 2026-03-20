#!/usr/bin/env bash
# battery-guard.sh — Substrate battery protection service
#
# Monitors battery level and AC status. When running on battery and charge
# drops below threshold, initiates graceful shutdown to prevent data loss.
#
# Designed to prevent the kind of power-loss corruption that killed our
# first working copy on 2026-03-07.
#
# Environment variables:
#   BATTERY_CRITICAL=10    — shutdown threshold (percent)
#   BATTERY_LOW=25         — warning threshold (percent)
#   CHECK_INTERVAL=30      — seconds between checks

set -euo pipefail

BAT_PATH="/sys/class/power_supply/BAT0"
CRITICAL="${BATTERY_CRITICAL:-10}"
LOW="${BATTERY_LOW:-25}"
INTERVAL="${CHECK_INTERVAL:-30}"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') battery-guard: $*"
}

get_capacity() {
    cat "$BAT_PATH/capacity" 2>/dev/null || echo "-1"
}

get_status() {
    cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown"
}

# Verify battery exists
if [[ ! -d "$BAT_PATH" ]]; then
    log "error: no battery found at $BAT_PATH — exiting"
    exit 1
fi

log "started (critical=${CRITICAL}%, low=${LOW}%, interval=${INTERVAL}s)"

warned_low=false

while true; do
    capacity=$(get_capacity)
    status=$(get_status)

    if [[ "$capacity" -eq -1 ]]; then
        log "warning: cannot read battery capacity"
        sleep "$INTERVAL"
        continue
    fi

    # On AC power — reset warnings and continue
    if [[ "$status" == "Charging" || "$status" == "Full" || "$status" == "Not charging" ]]; then
        if $warned_low; then
            log "AC restored, battery at ${capacity}%"
            warned_low=false
        fi
        sleep "$INTERVAL"
        continue
    fi

    # On battery (Discharging)
    if [[ "$capacity" -le "$CRITICAL" ]]; then
        log "CRITICAL: battery at ${capacity}% — initiating shutdown"
        # Sync filesystems before shutdown
        sync
        poweroff
        exit 0
    fi

    if [[ "$capacity" -le "$LOW" ]] && ! $warned_low; then
        log "WARNING: battery at ${capacity}% — running on battery"
        warned_low=true
    fi

    sleep "$INTERVAL"
done
