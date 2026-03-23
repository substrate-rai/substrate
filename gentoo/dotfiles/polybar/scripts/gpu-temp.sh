#!/bin/bash
# GPU temp for polybar
temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
if [ -n "$temp" ]; then
    echo "GPU ${temp}°C"
else
    echo "GPU --"
fi
