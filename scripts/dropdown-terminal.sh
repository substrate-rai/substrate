#!/bin/bash
# Toggle dropdown terminal via i3 scratchpad
# If it exists, toggle visibility. If not, spawn it.

if i3-msg '[instance="dropdown"] scratchpad show' 2>&1 | grep -q '"success":true'; then
    exit 0
fi

# Not found — spawn a new one, tmux will auto-attach via .bashrc
exec kitty --name dropdown --override background_opacity=0.9
