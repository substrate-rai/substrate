#!/usr/bin/env bash
# health-check.sh — Hourly system health logger with self-repair
#
# Logs GPU temp, VRAM usage, Ollama status to memory/health.log.
# Auto-repairs: restarts Ollama if down, alerts on high disk/temp.
# Run by systemd timer every hour.

set -euo pipefail

REPO_DIR="/home/operator/substrate"
LOG_FILE="$REPO_DIR/memory/health.log"
ALERT_FILE="$REPO_DIR/memory/alerts.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
ACTIONS=""

mkdir -p "$(dirname "$LOG_FILE")"

alert() {
    echo "[ALERT $TIMESTAMP] $1" >> "$ALERT_FILE"
    echo "ALERT: $1"
}

{
    echo "--- $TIMESTAMP ---"

    # GPU
    if command -v nvidia-smi &>/dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null) || gpu_info="error"
        if [[ "$gpu_info" != "error" ]]; then
            IFS=', ' read -r temp mem_used mem_total util <<< "$gpu_info"
            echo "gpu: ${temp}°C, ${mem_used}/${mem_total} MiB VRAM, ${util}% util"
            # Alert on high GPU temp
            if [[ "$temp" -gt 85 ]]; then
                alert "GPU temperature critical: ${temp}°C"
            fi
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
        if [[ "$bat_cap" -lt 20 && "$bat_status" == "Discharging" ]]; then
            alert "Battery low: ${bat_cap}% and discharging"
        fi
    fi

    # Ollama — check and auto-restart
    if curl -s --max-time 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
        models=$(curl -s --max-time 5 http://localhost:11434/api/tags | \
            grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"//' | paste -sd', ' 2>/dev/null || echo "parse error")
        echo "ollama: online, models: ${models:-none}"
    else
        echo "ollama: offline — attempting restart"
        if systemctl restart ollama 2>/dev/null; then
            sleep 3
            if curl -s --max-time 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo "ollama: restarted successfully"
                ACTIONS="restarted ollama"
            else
                echo "ollama: restart failed"
                alert "Ollama restart failed — service is down"
            fi
        else
            echo "ollama: cannot restart (no systemctl access)"
            alert "Ollama is down and cannot be restarted"
        fi
    fi

    # Disk
    disk_usage=$(df -h / --output=used,size,pcent | tail -1 | xargs)
    disk_pct=$(df / --output=pcent | tail -1 | tr -d '% ')
    echo "disk: $disk_usage"
    if [[ "$disk_pct" -gt 90 ]]; then
        alert "Disk usage critical: ${disk_pct}%"
    elif [[ "$disk_pct" -gt 80 ]]; then
        alert "Disk usage high: ${disk_pct}%"
    fi

    # Actions taken
    if [[ -n "$ACTIONS" ]]; then
        echo "actions: $ACTIONS"
    fi

    echo ""
} >> "$LOG_FILE"
