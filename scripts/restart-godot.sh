#!/usr/bin/env bash
# restart-godot.sh — Nightly memory leak mitigation
# Kills and relaunches the Godot Desktop 3D process (~20MB/hr leak)
# Run by fcron at 4am daily

set -euo pipefail

GODOT_PROJECT="/home/operator/substrate/scripts/desktop-3d-godot"

# Kill existing Godot process
if pgrep -f "godot4.*desktop-3d-godot" >/dev/null 2>&1; then
    pkill -f "godot4.*desktop-3d-godot" || true
    sleep 2
fi

# Relaunch (only if X11 is running — skip if headless/SSH-only)
if [ -n "${DISPLAY:-}" ] || pgrep -x Xorg >/dev/null 2>&1; then
    export DISPLAY="${DISPLAY:-:0}"
    export XAUTHORITY="${XAUTHORITY:-$(ls /run/user/$(id -u)/xauth_* 2>/dev/null | head -1)}"
    nohup godot4 --path "$GODOT_PROJECT" --rendering-driver vulkan >/dev/null 2>&1 &
    echo "$(date '+%Y-%m-%d %H:%M:%S') restart-godot: restarted successfully"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') restart-godot: no display, skipping relaunch"
fi
