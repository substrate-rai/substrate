#!/bin/bash
# Substrate screensaver — shader art fullscreen on top of everything
# Press any key or move mouse significantly to dismiss
# Toggle: run again to kill if already running

SUBSTRATE="/home/operator/substrate"
PIDFILE="/tmp/substrate-screensaver.pid"

# If already running, kill it
if [ -f "$PIDFILE" ] && kill -0 "$(cat $PIDFILE)" 2>/dev/null; then
    kill "$(cat $PIDFILE)" 2>/dev/null
    rm -f "$PIDFILE"
    echo "Screensaver dismissed"
    exit 0
fi

# Launch Godot
cd "$SUBSTRATE/scripts/desktop-3d-godot"
DISPLAY=:0 godot --path . --rendering-driver vulkan &
GODOT_PID=$!
echo $GODOT_PID > "$PIDFILE"

# Wait for window to appear
sleep 3

# Get Godot window ID and set it ABOVE everything
WID=$(xdotool search --pid $GODOT_PID 2>/dev/null | head -1)
if [ -n "$WID" ]; then
    xprop -id "$WID" -f _NET_WM_STATE 32a \
        -set _NET_WM_STATE "_NET_WM_STATE_ABOVE,_NET_WM_STATE_FULLSCREEN,_NET_WM_STATE_STICKY"
    xdotool windowactivate "$WID" 2>/dev/null
fi

# Monitor for input — dismiss on mouse movement or after idle timeout reset
(
    INITIAL_X=$(xdotool getmouselocation --shell 2>/dev/null | grep X= | cut -d= -f2)
    INITIAL_Y=$(xdotool getmouselocation --shell 2>/dev/null | grep Y= | cut -d= -f2)

    while kill -0 $GODOT_PID 2>/dev/null; do
        sleep 0.5
        CUR_X=$(xdotool getmouselocation --shell 2>/dev/null | grep X= | cut -d= -f2)
        CUR_Y=$(xdotool getmouselocation --shell 2>/dev/null | grep Y= | cut -d= -f2)

        DX=$(( ${CUR_X:-0} - ${INITIAL_X:-0} ))
        DY=$(( ${CUR_Y:-0} - ${INITIAL_Y:-0} ))
        DX=${DX#-}  # abs
        DY=${DY#-}  # abs

        # Dismiss if mouse moved more than 50px
        if [ "$DX" -gt 50 ] 2>/dev/null || [ "$DY" -gt 50 ] 2>/dev/null; then
            break
        fi
    done

    kill $GODOT_PID 2>/dev/null
    rm -f "$PIDFILE"
) &

echo "Screensaver active (PID: $GODOT_PID). Move mouse to dismiss."
