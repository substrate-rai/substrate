#!/bin/bash
# Game-style resource bars — HP(bat) MP(ram) SP(cpu) SH(gpu)

BAT=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
RAM=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
GPU=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' || echo 0)
CPU=$(top -bn1 | awk '/Cpu\(s\)/ {printf "%.0f", 100-$8}' 2>/dev/null || echo 0)

bar() {
    local pct=${1:-0} max=8
    local filled=$((pct * max / 100))
    [ "$filled" -gt "$max" ] && filled=$max
    [ "$filled" -lt 0 ] && filled=0
    local empty=$((max - filled))
    local b=""
    for ((i=0; i<filled; i++)); do b+="|"; done
    for ((i=0; i<empty; i++)); do b+="-"; done
    echo "[$b]"
}

bc="#30c470"
[ "$BAT" -lt 30 ] && bc="#FBC02D"
[ "$BAT" -lt 15 ] && bc="#c43030"

echo "%{F$bc}HP$(bar $BAT)${BAT}%%%{F-}  %{F#1EA5C7}MP$(bar $RAM)${RAM}%%%{F-}  %{F#FBC02D}SP$(bar $CPU)${CPU}%%%{F-}  %{F#3dd8f0}SH$(bar $GPU)${GPU}%%%{F-}"
