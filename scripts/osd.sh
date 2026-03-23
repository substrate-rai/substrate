#!/bin/bash
# On-screen display — brief popup for volume/brightness feedback
# Usage: osd.sh "Volume: 80%"

MSG="${1:-}"
[ -z "$MSG" ] && exit 0

# Kill any existing OSD
pkill -f "rofi.*OSD" 2>/dev/null

# Show for 1 second then auto-close
(echo "$MSG" | DISPLAY=:0 rofi -dmenu -p "OSD" -theme death-stranding -no-custom -auto-select 2>/dev/null) &
OSD_PID=$!

(sleep 1.5 && kill $OSD_PID 2>/dev/null) &
