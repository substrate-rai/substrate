#!/bin/bash
# Kill existing polybar instances
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
# Launch both bars
polybar main 2>&1 | tee -a /tmp/polybar.log & disown
polybar hud 2>&1 | tee -a /tmp/polybar-hud.log & disown
