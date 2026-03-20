#!/usr/bin/env bash
# desktop-3d-panel.sh — Launch the Desktop 3D control panel
# Opens in current terminal, or spawns a new one if called from desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Wait for Godot to be ready (up to 15s)
echo "Waiting for Desktop 3D..."
for i in $(seq 1 30); do
    if ss -tlnp 2>/dev/null | grep -q 9877; then
        echo "Connected."
        break
    fi
    sleep 0.5
done

if ! ss -tlnp 2>/dev/null | grep -q 9877; then
    echo "Desktop 3D not running. Start it with:"
    echo "  godot4 --path scripts/desktop-3d-godot --rendering-driver vulkan &"
    exit 1
fi

# Launch control panel
cd "$REPO_DIR"
exec python3 scripts/desktop-3d-control.py
