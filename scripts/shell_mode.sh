#!/bin/bash
# Toggle between Substrate mode (Godot HUD, animated picom)
# and i3 classic mode (polybar, basic picom)

MODE_FILE="$HOME/.cache/substrate-shell-mode"
SUBSTRATE="/home/operator/substrate"

current_mode() {
    cat "$MODE_FILE" 2>/dev/null || echo "i3"
}

switch_to_substrate() {
    echo "substrate" > "$MODE_FILE"

    # Kill polybar
    killall -q polybar

    # Restart picom with animations
    killall -q picom
    sleep 0.3
    picom --config ~/.config/picom/picom-substrate.conf -b

    # Tell Godot to show HUD
    echo '{"type":"shell_mode","params":{"mode":"substrate"}}' | nc -w1 127.0.0.1 9877 2>/dev/null

    # Make all windows float
    i3-msg 'for_window [class=".*"] floating enable' >/dev/null 2>&1

    echo "Switched to SUBSTRATE mode"
}

switch_to_i3() {
    echo "i3" > "$MODE_FILE"

    # Restart polybar
    ~/.config/polybar/launch.sh &

    # Restart picom without animations
    killall -q picom
    sleep 0.3
    picom --config ~/.config/picom/picom.conf -b

    # Tell Godot to hide HUD (just wallpaper)
    echo '{"type":"shell_mode","params":{"mode":"i3"}}' | nc -w1 127.0.0.1 9877 2>/dev/null

    echo "Switched to i3 CLASSIC mode"
}

case "${1:-toggle}" in
    substrate)
        switch_to_substrate
        ;;
    i3)
        switch_to_i3
        ;;
    toggle)
        if [ "$(current_mode)" = "substrate" ]; then
            switch_to_i3
        else
            switch_to_substrate
        fi
        ;;
    status)
        echo "Current mode: $(current_mode)"
        ;;
    *)
        echo "Usage: shell_mode.sh [substrate|i3|toggle|status]"
        ;;
esac
