#!/bin/bash
# Kill and relaunch Godot desktop shell (wallpaper mode — BELOW windows)
# Super+Shift+G toggles: if running, kill it. If not, start it.

SUBSTRATE="/home/operator/substrate"

# If running, kill it
if pgrep -f "godot.*desktop-3d-godot" >/dev/null 2>&1; then
    pkill -f "godot.*desktop-3d-godot" 2>/dev/null
    for i in 1 2 3; do
        pgrep -f "godot.*desktop-3d-godot" >/dev/null || break
        sleep 1
    done
    pkill -9 -f "godot.*desktop-3d-godot" 2>/dev/null
    notify-send -t 2000 "GODOT" "Wallpaper stopped" 2>/dev/null
    exit 0
fi

# Not running — start it
cd "$SUBSTRATE/scripts/desktop-3d-godot"
DISPLAY=:0 godot --path . --rendering-driver vulkan &
disown
notify-send -t 2000 "GODOT" "Wallpaper starting..." 2>/dev/null
