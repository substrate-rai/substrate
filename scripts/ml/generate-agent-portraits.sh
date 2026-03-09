#!/usr/bin/env bash
# generate-agent-portraits.sh — Generate missing agent portraits using SDXL Turbo via ComfyUI.
#
# Generates 10 missing agent portraits (512x512, 90s anime style)
# for: Forge, Hum, Sync, Mint, Yield, Amp, Pulse, Spec, Sentinel, Close
#
# Usage:
#   ./generate-agent-portraits.sh              Generate all missing portraits
#   ./generate-agent-portraits.sh --dry-run    Print prompts without generating
#   ./generate-agent-portraits.sh --list       List all image names
#   ./generate-agent-portraits.sh --force      Regenerate even if files already exist
#
# Requires: gpu-switch.sh, generate-image.py, ComfyUI, CUDA, ~4GB VRAM free
# Time estimate: ~70 seconds on RTX 4060 (6 steps per image, ~7s each)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/assets/images/generated"
GPU_SWITCH="${SCRIPT_DIR}/gpu-switch.sh"
GENERATE_PY="${SCRIPT_DIR}/generate-image.py"
COMFYUI_DIR="/home/operator/comfyui"
COMFYUI_PYTHON="${COMFYUI_DIR}/venv/bin/python"
COMFYUI_URL="http://127.0.0.1:8188"
COMFYUI_PID=""

# NixOS CUDA + C++ runtime library paths
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

DRY_RUN=false
LIST_ONLY=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --list)     LIST_ONLY=true; shift ;;
        --force)    FORCE=true; shift ;;
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

# ── shared prompt fragments ────────────────────────────────────────────────

QUALITY_PREFIX="masterpiece, best quality"
NEGATIVE="text, watermark, signature, blurry, low quality, bright background, white background, cartoon, chibi, deformed, extra limbs"
STEPS=6
CFG=1.0

# ── prompt definitions ─────────────────────────────────────────────────────
# Format: "filename|prompt"
# All outputs are 512x512

PROMPTS=(
    # === Batch 4: Original 7 agents still showing abstract art ===
    "agent-v|90s anime character portrait, fierce philosophical figure with wild flowing purple hair (#ff77ff), intense piercing eyes, purple rim lighting, dramatic pose, cyberpunk poet, dark background, cel-shaded, bold outlines"
    "agent-claude|90s anime character portrait, calm intelligent figure with green glowing visor covering upper face, short neat hair swept to side, green accent lighting (#00ffaa), cyberpunk architect, dark background, cel-shaded, bold outlines"
    "agent-q|90s anime character portrait, young curious figure with messy medium-length purple hair (#dd88ff), wide excited eyes, eager enthusiastic expression, cyberpunk student rapper, dark background, cel-shaded, bold outlines"
    "agent-byte|90s anime character portrait, alert reporter with sharp cyan bob cut (#00ddff), headset with mic boom, focused attentive eyes, cyberpunk journalist, dark background, cel-shaded, bold outlines"
    "agent-echo|90s anime character portrait, observant tracker with medium wavy orange hair (#ffaa44), slight knowing smile, squinting analytical eyes, cyberpunk intelligence analyst, dark background, cel-shaded, bold outlines"
    "agent-pixel|90s anime character portrait, creative artist with asymmetric pink hair (#ff44aa), one side longer, paint smudge on cheek, bright creative spark in eyes, cyberpunk artist, dark background, cel-shaded, bold outlines"
    "agent-root|90s anime character portrait, stern military engineer with short indigo hair (#8888ff), indigo tactical visor, serious disciplined expression, sturdy build, cyberpunk soldier, dark background, cel-shaded, bold outlines"
    # === Batch 1: Previously fixed agents ===
    "agent-flux|90s anime character portrait, bold strategist with swept-back coral-red hair (#ff6666), thin red-tinted glasses, visionary expression looking into distance, cyberpunk innovator, dark background, cel-shaded, bold outlines"
    "agent-dash|90s anime character portrait, determined project manager with short structured gold-highlighted hair (#ffdd44), focused organized eyes tracking multiple tasks, cyberpunk coordinator, dark background, cel-shaded, bold outlines"
    "agent-spore|90s anime character portrait, warm friendly figure with curly bright green hair (#44ff88), welcoming smile, small mushroom motif earring, cyberpunk community manager, dark background, cel-shaded, bold outlines"
    "agent-lumen|90s anime character portrait, patient educator with warm amber hair (#ffaa00), round amber-tinted spectacles, kind encouraging expression, cyberpunk professor, dark background, cel-shaded, bold outlines"
    "agent-arc|90s anime character portrait, energetic gamer with spiky red hair (#cc4444), competitive grin, gaming headset with red LED, cyberpunk arcade champion, dark background, cel-shaded, bold outlines"
    # === Batch 2: Re-run for consistency ===
    "agent-sync|90s anime character portrait, composed figure with neatly parted sky-blue hair (#77bbdd), dual-tone glasses reflecting data, calm confident expression, cyberpunk communications director, dark background, cel-shaded, bold outlines"
    "agent-mint|90s anime character portrait, shrewd figure with short neat brown hair with tan highlights (#cc8844), reading glasses perched on nose, slightly skeptical expression, cyberpunk accountant, dark background, cel-shaded, bold outlines"
    "agent-spec|90s anime character portrait, precise figure with platinum white hair (#dddddd) tied in tight bun, monocle over one eye, stern meticulous expression, cyberpunk quality inspector, dark background, cel-shaded, bold outlines"
    # === Batch 3: Other agents ===
    "agent-forge|90s anime character portrait, resourceful engineer with short teal-highlighted hair, wearing welding goggles pushed up on forehead, teal accent lighting (#44ccaa), sharp focused eyes, cyberpunk webmaster, dark background, cel-shaded, bold outlines"
    "agent-hum|90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), eyes closed peacefully, wearing large over-ear headphones with glowing rings, cyberpunk audio engineer, dark background, cel-shaded, bold outlines"
    "agent-yield|90s anime character portrait, optimistic figure with upswept lime-green hair (#88dd44), bright eager eyes, warm smile, plant motif earrings, cyberpunk growth analyst, dark background, cel-shaded, bold outlines"
    "agent-amp|90s anime character portrait, energetic figure with spiky cyan-white hair (#44ffdd), glowing earbuds, electric crackling around shoulders, intense expression, cyberpunk amplifier, dark background, cel-shaded, bold outlines"
    "agent-pulse|90s anime character portrait, analytical figure with neat blue hair (#4488ff), holographic data overlay across one eye like a scouter, calm measured expression, cyberpunk data analyst, dark background, cel-shaded, bold outlines"
    "agent-sentinel|90s anime character portrait, hooded vigilant figure with steel-grey hair (#8899aa), lower face covered by tactical mask, sharp watchful eyes scanning, cyberpunk security guard, dark background, cel-shaded, bold outlines"
    "agent-close|90s anime character portrait, charismatic figure with slicked-back olive-green hair (#aacc44), confident grin, loosened tie, finger guns pose, cyberpunk salesperson, dark background, cel-shaded, bold outlines"
)

# ── functions ───────────────────────────────────────────────────────────────

log() { echo "[agent-portraits] $*"; }

list_images() {
    echo "Missing agent portraits (${#PROMPTS[@]} total):"
    for entry in "${PROMPTS[@]}"; do
        IFS='|' read -r name _ <<< "$entry"
        echo "  ${name}.png  (512x512)"
    done
}

start_comfyui() {
    if curl -sf "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
        log "ComfyUI already running"
        return 0
    fi
    log "Starting ComfyUI server..."
    "$COMFYUI_PYTHON" "${COMFYUI_DIR}/main.py" \
        --listen 127.0.0.1 --port 8188 --disable-auto-launch \
        > /tmp/comfyui-agent-portraits.log 2>&1 &
    COMFYUI_PID=$!

    for i in $(seq 1 60); do
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
    log "ERROR: ComfyUI failed to start in 60s"
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

generate_image() {
    local name="$1"
    local prompt="$2"
    local outfile="${OUTPUT_DIR}/${name}.png"

    if [[ -f "$outfile" ]] && ! $FORCE; then
        log "SKIP  ${name}.png (already exists, use --force to regenerate)"
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo "  FILE: ${name}.png"
        echo "  SIZE: 512x512"
        echo "  PROMPT: ${QUALITY_PREFIX}, ${prompt}"
        echo "  NEGATIVE: ${NEGATIVE}"
        return 0
    fi

    "$COMFYUI_PYTHON" "$GENERATE_PY" \
        --no-unload \
        --no-start \
        --no-stop \
        --output "$outfile" \
        --width 512 \
        --height 512 \
        --steps "$STEPS" \
        --cfg "$CFG" \
        --negative "$NEGATIVE" \
        "${QUALITY_PREFIX}, ${prompt}" || {
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
log "  Substrate — Missing Agent Portrait Generator"
log "============================================"
log ""
log "Output directory: ${OUTPUT_DIR}"
log "Total portraits: ${#PROMPTS[@]}"
log "Settings: steps=${STEPS}, cfg=${CFG}, size=512x512"
echo ""

if $DRY_RUN; then
    log "DRY RUN — printing prompts only"
    echo ""
    echo "Shared negative prompt: ${NEGATIVE}"
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
total=${#PROMPTS[@]}
current=0

for entry in "${PROMPTS[@]}"; do
    IFS='|' read -r name prompt <<< "$entry"
    current=$((current + 1))
    outfile="${OUTPUT_DIR}/${name}.png"

    if [[ -f "$outfile" ]] && ! $FORCE && ! $DRY_RUN; then
        log "(${current}/${total}) SKIP  ${name}.png (exists)"
        skipped=$((skipped + 1))
        continue
    fi

    if ! $DRY_RUN; then
        log "(${current}/${total}) Generating ${name}.png..."
    fi

    if generate_image "$name" "$prompt"; then
        succeeded=$((succeeded + 1))
    else
        failed=$((failed + 1))
        failed_names+=("$name")
        log "(${current}/${total}) FAILED  ${name}.png — continuing..."
    fi
done

echo ""

if $DRY_RUN; then
    log "DRY RUN COMPLETE — ${succeeded} prompts listed"
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
