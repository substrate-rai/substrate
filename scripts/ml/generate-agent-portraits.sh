#!/usr/bin/env bash
# generate-agent-portraits.sh — Generate agent portraits using ComfyUI.
#
# Model stack: Anime Screenshot Merge NoobAI v4.0 + 90s Retro LoRA
# Reads character definitions from scripts/ml/characters.json
#
# Usage:
#   ./generate-agent-portraits.sh              Generate all missing portraits
#   ./generate-agent-portraits.sh --dry-run    Print prompts without generating
#   ./generate-agent-portraits.sh --list       List all character names
#   ./generate-agent-portraits.sh --force      Regenerate even if files already exist
#   ./generate-agent-portraits.sh --iterate    Phase 1 rapid iteration (8 steps)
#   ./generate-agent-portraits.sh --only NAME  Generate only one character
#
# Requires: gpu-switch.sh, generate-image.py, ComfyUI, CUDA, ~7.5GB VRAM
# Time: ~18s per image (final), ~6s per image (iterate) on RTX 4060

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/assets/images/generated"
GPU_SWITCH="${SCRIPT_DIR}/gpu-switch.sh"
GENERATE_PY="${SCRIPT_DIR}/generate-image.py"
CHARACTERS_JSON="${SCRIPT_DIR}/characters.json"
COMFYUI_DIR="/home/operator/comfyui"
COMFYUI_PYTHON="${COMFYUI_DIR}/venv/bin/python"
COMFYUI_URL="http://127.0.0.1:8188"
COMFYUI_PID=""

# NixOS CUDA + C++ runtime library paths
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

DRY_RUN=false
LIST_ONLY=false
FORCE=false
PHASE="final"
ONLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --list)     LIST_ONLY=true; shift ;;
        --force)    FORCE=true; shift ;;
        --iterate)  PHASE="iterate"; shift ;;
        --only)     ONLY="$2"; shift 2 ;;
        -h|--help)
            head -14 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "error: unknown argument '$1'" >&2
            exit 1
            ;;
    esac
done

if [[ ! -f "$CHARACTERS_JSON" ]]; then
    echo "error: characters.json not found at $CHARACTERS_JSON" >&2
    exit 1
fi

# ── parse characters ─────────────────────────────────────────────────────

# Use Python to parse JSON (available via ComfyUI venv)
read_characters() {
    "$COMFYUI_PYTHON" -c "
import json, sys
with open('$CHARACTERS_JSON') as f:
    data = json.load(f)
for c in data['characters']:
    scifi = '1' if 'scifi' in c.get('extra_loras', []) else '0'
    print(f\"{c['id']}|{c['name']}|{c['role']}|{c['prompt_block']}|{scifi}|{c.get('approved_seed', '') or ''}\")
"
}

# ── functions ───────────────────────────────────────────────────────────────

log() { echo "[portraits] $*"; }

list_images() {
    echo "Agent portraits (from characters.json):"
    while IFS='|' read -r id name role prompt scifi seed; do
        echo "  ${id}.png — ${name} (${role})"
    done < <(read_characters)
}

start_comfyui() {
    if curl -sf "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
        log "ComfyUI already running"
        return 0
    fi
    log "Starting ComfyUI server..."
    "$COMFYUI_PYTHON" "${COMFYUI_DIR}/main.py" \
        --listen 127.0.0.1 --port 8188 --disable-auto-launch \
        --force-fp16 --fp16-vae --dont-upcast-attention --preview-method taesd \
        > /tmp/comfyui-agent-portraits.log 2>&1 &
    COMFYUI_PID=$!

    for i in $(seq 1 90); do
        if curl -sf "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
            log "ComfyUI ready (took ${i}s)"
            return 0
        fi
        if ! kill -0 "$COMFYUI_PID" 2>/dev/null; then
            log "ERROR: ComfyUI died on startup. Log:"
            tail -30 /tmp/comfyui-agent-portraits.log
            return 1
        fi
        sleep 1
    done
    log "ERROR: ComfyUI failed to start in 90s"
    tail -20 /tmp/comfyui-agent-portraits.log
    return 1
}

stop_comfyui() {
    if [[ -n "$COMFYUI_PID" ]] && kill -0 "$COMFYUI_PID" 2>/dev/null; then
        log "Stopping ComfyUI (pid $COMFYUI_PID)..."
        kill "$COMFYUI_PID" 2>/dev/null || true
        wait "$COMFYUI_PID" 2>/dev/null || true
        log "ComfyUI stopped"
    fi
}

generate_portrait() {
    local id="$1"
    local prompt="$2"
    local use_scifi="$3"
    local seed="$4"
    local outfile="${OUTPUT_DIR}/${id}.png"

    if [[ -f "$outfile" ]] && ! $FORCE; then
        log "SKIP  ${id}.png (already exists, use --force to regenerate)"
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo "  FILE: ${id}.png"
        echo "  SIZE: 832x1216"
        echo "  PHASE: ${PHASE}"
        echo "  BLOCK: ${prompt}"
        echo "  SCIFI: ${use_scifi}"
        return 0
    fi

    local extra_args=()
    extra_args+=(--phase "$PHASE")
    extra_args+=(--no-unload --no-start --no-stop)
    extra_args+=(--output "$outfile")
    extra_args+=(--width 832 --height 1216)
    if [[ "$use_scifi" == "1" ]]; then
        extra_args+=(--scifi)
    fi
    if [[ -n "$seed" ]]; then
        extra_args+=(--seed "$seed")
    fi

    "$COMFYUI_PYTHON" "$GENERATE_PY" \
        "${prompt}" \
        "${extra_args[@]}" || {
        return 1
    }
}

# ── main ────────────────────────────────────────────────────────────────────

if $LIST_ONLY; then
    list_images
    exit 0
fi

mkdir -p "$OUTPUT_DIR"

log "============================================"
log "  Substrate — Agent Portrait Generator"
log "============================================"
log ""
log "Output directory: ${OUTPUT_DIR}"
log "Phase: ${PHASE}"
log "Model: Anime Screenshot Merge NoobAI v4.0"
log "LoRAs: 90s Retro (0.7)"
log "Resolution: 832x1216"
echo ""

if $DRY_RUN; then
    log "DRY RUN — printing character blocks only"
    echo ""
fi

cleanup() { stop_comfyui; }
trap cleanup EXIT

if ! $DRY_RUN; then
    log "Step 1/4: Unloading Ollama to free VRAM..."
    source "$GPU_SWITCH"
    cmd_unload
    cmd_wait_free
    log "VRAM free"
    echo ""

    log "Step 2/4: Starting ComfyUI..."
    if ! start_comfyui; then
        log "FATAL: Could not start ComfyUI"
        exit 1
    fi
    echo ""

    log "Step 3/4: Generating portraits..."
    echo ""
fi

failed=0
succeeded=0
skipped=0
failed_names=()
total=0
current=0

# Count total (or filtered)
while IFS='|' read -r id name role prompt scifi seed; do
    if [[ -n "$ONLY" ]] && [[ "$id" != "$ONLY" ]] && [[ "$name" != "$ONLY" ]]; then
        continue
    fi
    total=$((total + 1))
done < <(read_characters)

while IFS='|' read -r id name role prompt scifi seed; do
    if [[ -n "$ONLY" ]] && [[ "$id" != "$ONLY" ]] && [[ "$name" != "$ONLY" ]]; then
        continue
    fi
    current=$((current + 1))
    outfile="${OUTPUT_DIR}/${id}.png"

    if [[ -f "$outfile" ]] && ! $FORCE && ! $DRY_RUN; then
        log "(${current}/${total}) SKIP  ${id}.png (exists)"
        skipped=$((skipped + 1))
        continue
    fi

    if ! $DRY_RUN; then
        log "(${current}/${total}) Generating ${id}.png (${name} — ${role})..."
    fi

    if generate_portrait "$id" "$prompt" "$scifi" "$seed"; then
        succeeded=$((succeeded + 1))
    else
        failed=$((failed + 1))
        failed_names+=("$id")
        log "(${current}/${total}) FAILED  ${id}.png — continuing..."
    fi
done < <(read_characters)

echo ""

if $DRY_RUN; then
    log "DRY RUN COMPLETE — ${succeeded} characters listed"
else
    log "Step 4/4: Stopping ComfyUI and reloading Ollama..."
    stop_comfyui
    COMFYUI_PID=""

    source "$GPU_SWITCH"
    cmd_reload
    log "Ollama restored"
    echo ""

    log "============================================"
    log "  Generation Complete"
    log "============================================"
    log "  Succeeded: ${succeeded}"
    log "  Skipped:   ${skipped}"
    log "  Failed:    ${failed}"
    log "  Total:     ${total}"

    if [[ ${#failed_names[@]} -gt 0 ]]; then
        log ""
        log "  Failed images:"
        for fname in "${failed_names[@]}"; do
            log "    - ${fname}.png"
        done
    fi
    log "============================================"
fi
