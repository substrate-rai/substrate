#!/usr/bin/env bash
# health-check.sh — Hourly system health logger
#
# Logs GPU temp, VRAM usage, Ollama status to memory/health.log.
# Run by systemd timer every hour.

set -euo pipefail

REPO_DIR="/home/operator/substrate"
LOG_FILE="$REPO_DIR/memory/health.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "$(dirname "$LOG_FILE")"

{
    echo "--- $TIMESTAMP ---"

    # GPU
    if command -v nvidia-smi &>/dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null) || gpu_info="error"
        if [[ "$gpu_info" != "error" ]]; then
            IFS=', ' read -r temp mem_used mem_total util <<< "$gpu_info"
            echo "gpu: ${temp}°C, ${mem_used}/${mem_total} MiB VRAM, ${util}% util"
        else
            echo "gpu: nvidia-smi query failed"
        fi
    else
        echo "gpu: nvidia-smi not found"
    fi

    # Battery
    if [[ -f /sys/class/power_supply/BAT0/capacity ]]; then
        bat_cap=$(cat /sys/class/power_supply/BAT0/capacity)
        bat_status=$(cat /sys/class/power_supply/BAT0/status)
        echo "battery: ${bat_cap}% (${bat_status})"
    fi

    # Ollama
    if curl -s --max-time 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
        # Parse model names with grep/sed — no python dependency
        models=$(curl -s --max-time 5 http://localhost:11434/api/tags | \
            grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | paste -sd', ' 2>/dev/null || echo "parse error")
        echo "ollama: online, models: ${models:-none}"
    else
        echo "ollama: offline"
    fi

    # Disk
    disk_usage=$(df -h / --output=used,size,pcent | tail -1 | xargs)
    echo "disk: $disk_usage"

    echo ""
} >> "$LOG_FILE"
