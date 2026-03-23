#!/bin/bash
# Screenshot menu — saves to file AND copies to clipboard for instant paste

DIR="$HOME/Pictures"
mkdir -p "$DIR"
STAMP=$(date +%Y-%m-%d_%H%M%S)
FILE="$DIR/screenshot_${STAMP}.png"

choice=$(echo -e "Selection (copy + save)\nFull Screen (copy + save)\nCurrent Window (copy + save)\nFull Screen (3s delay)" | \
    DISPLAY=:0 rofi -dmenu -p "SCREENSHOT" -theme death-stranding -no-custom 2>/dev/null)

case "$choice" in
    "Selection (copy + save)")
        scrot -s -f "$FILE"
        ;;
    "Full Screen (copy + save)")
        scrot "$FILE"
        ;;
    "Current Window (copy + save)")
        scrot -u "$FILE"
        ;;
    "Full Screen (3s delay)")
        sleep 3
        scrot "$FILE"
        ;;
    *)
        exit 0
        ;;
esac

# Copy to clipboard — ready to Ctrl+V into claude.ai or any browser
xclip -selection clipboard -t image/png -i "$FILE" 2>/dev/null

# Sound + notification
paplay ~/substrate/assets/sounds/notify.wav 2>/dev/null &
python3 ~/substrate/scripts/notify.py "Screenshot" "Copied to clipboard + saved" system 3 2>/dev/null &
