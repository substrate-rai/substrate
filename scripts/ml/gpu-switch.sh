#!/usr/bin/env bash
# gpu-switch.sh — Manage VRAM between Ollama and Stable Diffusion on RTX 4060 (8GB).
#
# Usage:
#   gpu-switch.sh unload          Unload all Ollama models to free VRAM
#   gpu-switch.sh reload          Reload the default model (qwen3:8b) into Ollama
#   gpu-switch.sh status          Show current VRAM usage via nvidia-smi
#   gpu-switch.sh run-sd <prompt> Unload Ollama, generate image, reload Ollama
#   gpu-switch.sh wait-free       Poll nvidia-smi until VRAM usage drops below 500MB

set -euo pipefail

OLLAMA_API="http://localhost:11434"
DEFAULT_MODEL="qwen3:8b"
VRAM_FREE_THRESHOLD_MB=500
POLL_INTERVAL=2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ─────────────────────────────────────────────────────────────────

log() { echo "[gpu-switch] $*"; }

get_vram_used_mb() {
    nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

get_vram_total_mb() {
    nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

get_vram_free_mb() {
    nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | tr -d ' '
}

ollama_running() {
    curl -sf "${OLLAMA_API}/api/ps" -o /dev/null 2>/dev/null
}

get_loaded_models() {
    curl -sf "${OLLAMA_API}/api/ps" 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(m.get('name', 'unknown'))
" 2>/dev/null
}

# ── commands ────────────────────────────────────────────────────────────────

cmd_unload() {
    log "unloading all Ollama models..."
    if ! ollama_running; then
        log "ollama is not running, nothing to unload"
        return 0
    fi

    local models
    models="$(get_loaded_models)"
    if [[ -z "$models" ]]; then
        log "no models currently loaded"
        return 0
    fi

    while IFS= read -r model; do
        log "unloading ${model}..."
        curl -sf "${OLLAMA_API}/api/generate" \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"${model}\", \"keep_alive\": 0}" \
            -o /dev/null
        log "unloaded ${model}"
    done <<< "$models"

    log "all models unloaded"
}

cmd_reload() {
    local model="${1:-$DEFAULT_MODEL}"
    log "reloading ${model} into Ollama..."
    if ! ollama_running; then
        log "error: ollama is not running"
        return 1
    fi

    curl -sf "${OLLAMA_API}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model}\"}" \
        -o /dev/null

    log "${model} loaded"
}

cmd_status() {
    local used total free
    used="$(get_vram_used_mb)"
    total="$(get_vram_total_mb)"
    free="$(get_vram_free_mb)"

    echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'unknown')"
    echo "  VRAM: ${used}MB / ${total}MB (free: ${free}MB)"

    if ollama_running; then
        local models
        models="$(get_loaded_models)"
        if [[ -z "$models" ]]; then
            echo "  Ollama: running, no models loaded (idle)"
        else
            echo "  Ollama: loaded models:"
            while IFS= read -r m; do
                echo "    - ${m}"
            done <<< "$models"
        fi
    else
        echo "  Ollama: not running"
    fi
}

cmd_run_sd() {
    if [[ $# -eq 0 ]]; then
        echo "error: run-sd requires a prompt argument" >&2
        echo "usage: gpu-switch.sh run-sd <prompt>" >&2
        return 1
    fi

    local prompt="$*"
    log "preparing GPU for Stable Diffusion..."

    # Step 1: free VRAM
    cmd_unload

    # Step 2: wait for VRAM to actually free up
    cmd_wait_free

    local free_mb
    free_mb="$(get_vram_free_mb)"
    log "VRAM free: ${free_mb}MB — launching image generation"

    # Step 3: run the generate-image script
    local sd_script="${SCRIPT_DIR}/generate-image.py"
    if [[ ! -f "$sd_script" ]]; then
        log "error: ${sd_script} not found"
        return 1
    fi

    local rc=0
    python3 "$sd_script" --no-unload "$prompt" || rc=$?

    # Step 4: reload Ollama regardless of SD outcome
    log "restoring Ollama..."
    cmd_reload

    return $rc
}

cmd_wait_free() {
    log "waiting for VRAM usage to drop below ${VRAM_FREE_THRESHOLD_MB}MB..."
    local used
    while true; do
        used="$(get_vram_used_mb)"
        if [[ -z "$used" ]]; then
            log "error: could not read VRAM usage from nvidia-smi"
            return 1
        fi
        if [[ "$used" -lt "$VRAM_FREE_THRESHOLD_MB" ]]; then
            log "VRAM used: ${used}MB — below threshold, GPU is free"
            return 0
        fi
        log "VRAM used: ${used}MB — waiting..."
        sleep "$POLL_INTERVAL"
    done
}

# ── main ────────────────────────────────────────────────────────────────────

usage() {
    cat <<'USAGE'
gpu-switch.sh — manage VRAM between Ollama and Stable Diffusion (RTX 4060 8GB)

Commands:
  unload          Unload all Ollama models to free VRAM
  reload [model]  Reload a model into Ollama (default: qwen3:8b)
  status          Show current VRAM usage and loaded models
  run-sd <prompt> Unload Ollama → generate image → reload Ollama
  wait-free       Poll until VRAM usage drops below 500MB
USAGE
}

case "${1:-}" in
    unload)    cmd_unload ;;
    reload)    shift; cmd_reload "$@" ;;
    status)    cmd_status ;;
    run-sd)    shift; cmd_run_sd "$@" ;;
    wait-free) cmd_wait_free ;;
    -h|--help) usage ;;
    *)
        usage >&2
        exit 1
        ;;
esac
