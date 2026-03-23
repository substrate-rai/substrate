#!/bin/bash
# Kill existing polybar instances
killall -q polybar
# Wait for them to die
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
# Launch
polybar main 2>&1 | tee -a /tmp/polybar.log & disown
