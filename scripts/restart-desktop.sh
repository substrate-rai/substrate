#!/bin/bash
# Kill and relaunch Godot desktop shell

SUBSTRATE="/home/operator/substrate"

# Kill existing Godot
pkill -f "godot.*desktop-3d-godot" 2>/dev/null

# Wait for it to die (up to 3 seconds)
for i in 1 2 3; do
    pgrep -f "godot.*desktop-3d-godot" >/dev/null || break
    sleep 1
done

# Force kill if still alive
pkill -9 -f "godot.*desktop-3d-godot" 2>/dev/null
sleep 0.5

# Relaunch
DISPLAY=:0 godot --path "$SUBSTRATE/scripts/desktop-3d-godot" --rendering-driver vulkan &
disown

echo "Godot desktop restarted"
