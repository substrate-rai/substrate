#!/bin/bash
BL=$(ls /sys/class/backlight/ | head -1)
[ -z "$BL" ] && exit 0
MAX=$(cat /sys/class/backlight/$BL/max_brightness)
CUR=$(cat /sys/class/backlight/$BL/brightness)
STEP=$((MAX / 10))

case "$1" in
    up)   NEW=$((CUR + STEP)); [ "$NEW" -gt "$MAX" ] && NEW=$MAX ;;
    down) NEW=$((CUR - STEP)); [ "$NEW" -lt 0 ] && NEW=0 ;;
    *)    exit 0 ;;
esac

echo "$NEW" > /sys/class/backlight/$BL/brightness 2>/dev/null
PCT=$((NEW * 100 / MAX))
notify-send -t 2000 \
    -h string:x-dunst-stack-tag:brightness \
    -h int:value:"$PCT" \
    "BRIGHTNESS" "${PCT}%"
