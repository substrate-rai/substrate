#!/bin/bash
# Substrate screensaver — shader art fullscreen
# Super+Shift+S toggles on/off
# Also auto-dismisses on mouse movement

SUBSTRATE="/home/operator/substrate"
PIDFILE="/tmp/substrate-screensaver.pid"
I3_SOCK=$(ls /run/user/*/i3/ipc-socket.* 2>/dev/null | head -1)

# If already running, kill it
if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    kill "$(cat $PIDFILE)" 2>/dev/null
    sleep 0.5
    kill -9 "$(cat $PIDFILE)" 2>/dev/null
    rm -f "$PIDFILE"
    # Refocus previous window
    i3-msg -s "$I3_SOCK" '[class="kitty"] focus' 2>/dev/null
    exit 0
fi

# Launch Godot
cd "$SUBSTRATE/scripts/desktop-3d-godot"
DISPLAY=:0 godot --path . --rendering-driver vulkan &
GODOT_PID=$!
echo $GODOT_PID > "$PIDFILE"
sleep 3

# Use i3 to fullscreen Godot (keeps i3 keybinds working!)
i3-msg -s "$I3_SOCK" '[class="Godot"] fullscreen enable' 2>/dev/null

# Mouse movement dismiss (background watcher)
(
    sleep 2
    IX=$(xdotool getmouselocation --shell 2>/dev/null | grep X= | cut -d= -f2)
    IY=$(xdotool getmouselocation --shell 2>/dev/null | grep Y= | cut -d= -f2)
    while kill -0 $GODOT_PID 2>/dev/null; do
        sleep 0.5
        CX=$(xdotool getmouselocation --shell 2>/dev/null | grep X= | cut -d= -f2)
        CY=$(xdotool getmouselocation --shell 2>/dev/null | grep Y= | cut -d= -f2)
        DX=$(( ${CX:-0} - ${IX:-0} )); DX=${DX#-}
        DY=$(( ${CY:-0} - ${IY:-0} )); DY=${DY#-}
        if [ "${DX:-0}" -gt 80 ] 2>/dev/null || [ "${DY:-0}" -gt 80 ] 2>/dev/null; then
            kill $GODOT_PID 2>/dev/null
            rm -f "$PIDFILE"
            i3-msg -s "$I3_SOCK" '[class="kitty"] focus' 2>/dev/null
            exit 0
        fi
    done
) &
