#!/bin/bash
# Substrate power profile switcher
# Usage: power-profile.sh [road|server|performance|status]
#
# road:        Max battery life — powersave CPU, GPU off, WiFi powersave, dim screen
# server:      Headless — no display, no compositor, services only, lid close = nothing
# performance: Full power — performance CPU, GPU persist, WiFi full, max brightness
# status:      Show current profile

PROFILE_FILE="$HOME/.cache/substrate-power-profile"

current_profile() {
    cat "$PROFILE_FILE" 2>/dev/null || echo "unknown"
}

set_road() {
    echo "road" > "$PROFILE_FILE"
    # CPU powersave
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo powersave > "$cpu" 2>/dev/null
    done
    # GPU minimal
    nvidia-smi -pm 0 2>/dev/null
    # WiFi power save
    iw dev wlo1 set power_save on 2>/dev/null
    # Kill GPU-heavy stuff only
    pkill -f "godot" 2>/dev/null
    notify-send -t 3000 "ROAD MODE" "Max battery — GPU off, powersave" 2>/dev/null
    echo "ROAD MODE — max battery, minimal services"
}

set_server() {
    echo "server" > "$PROFILE_FILE"
    # CPU performance (need it for serving)
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null
    done
    # GPU persist for CUDA
    nvidia-smi -pm 1 2>/dev/null
    # WiFi full power
    iw dev wlo1 set power_save off 2>/dev/null
    # Screen off
    DISPLAY=:0 xset dpms force off 2>/dev/null
    # Kill desktop stuff
    pkill -f "godot" 2>/dev/null
    killall -q picom polybar 2>/dev/null
    echo "SERVER MODE — headless, full compute, screen off"
}

set_performance() {
    echo "performance" > "$PROFILE_FILE"
    # CPU performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance > "$cpu" 2>/dev/null
    done
    # GPU persist
    nvidia-smi -pm 1 2>/dev/null
    # WiFi full power
    iw dev wlo1 set power_save off 2>/dev/null
    # Screen bright
    brightnessctl set 80% 2>/dev/null
    # Screen on
    DISPLAY=:0 xset dpms force on 2>/dev/null
    # Restart desktop
    DISPLAY=:0 picom --config ~/.config/picom/picom-substrate.conf -b 2>/dev/null
    ~/.config/polybar/launch.sh 2>/dev/null &
    echo "PERFORMANCE MODE — full power, full desktop"
}

case "${1:-status}" in
    road)       set_road ;;
    server)     set_server ;;
    performance|perf) set_performance ;;
    status)
        echo "Profile: $(current_profile)"
        echo "CPU: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
        echo "GPU: $(nvidia-smi --query-gpu=persistence-mode --format=csv,noheader 2>/dev/null)"
        echo "Battery: $(cat /sys/class/power_supply/BAT0/capacity)% ($(cat /sys/class/power_supply/BAT0/status))"
        watts=$(awk '{printf "%.1f", $1/1000000}' /sys/class/power_supply/BAT0/power_now 2>/dev/null)
        echo "Power draw: ${watts}W"
        ;;
    *)
        echo "Usage: power-profile.sh [road|server|performance|status]"
        echo ""
        echo "  road         — max battery: powersave, GPU off, dim screen"
        echo "  server       — headless: no display, full compute, lid = nothing"
        echo "  performance  — full power: max CPU/GPU, bright screen, full desktop"
        echo "  status       — show current state"
        ;;
esac
