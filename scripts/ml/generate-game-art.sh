#!/usr/bin/env bash
# generate-game-art.sh — Batch generate all arcade game art using SDXL Turbo via ComfyUI.
#
# Generates 24 images for the arcade games:
#   - 12 character portraits (512x512, 90s anime style)
#   -  7 scene backgrounds  (1024x512, cinematic)
#   -  5 game title cards   (1024x512)
#
# Usage:
#   ./generate-game-art.sh              Generate all images (requires GPU)
#   ./generate-game-art.sh --dry-run    Print prompts without generating
#   ./generate-game-art.sh --only portraits   Generate only one category
#   ./generate-game-art.sh --only scenes
#   ./generate-game-art.sh --only titles
#   ./generate-game-art.sh --list       List all image names
#   ./generate-game-art.sh --force      Regenerate even if files already exist
#
# Requires: gpu-switch.sh, generate-image.py, ComfyUI, CUDA, ~4GB VRAM free
# Time estimate: ~3 minutes on RTX 4060 (6 steps per image, ~7s each)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/assets/images/game-art"
GPU_SWITCH="${SCRIPT_DIR}/gpu-switch.sh"
GENERATE_PY="${SCRIPT_DIR}/generate-image.py"
COMFYUI_DIR="/home/operator/comfyui"
COMFYUI_PYTHON="${COMFYUI_DIR}/venv/bin/python"
COMFYUI_URL="http://127.0.0.1:8188"
COMFYUI_PID=""

# NixOS CUDA + C++ runtime library paths
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

DRY_RUN=false
ONLY=""
LIST_ONLY=false
FORCE=false

# ── parse args ──────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --only)     ONLY="$2"; shift 2 ;;
        --list)     LIST_ONLY=true; shift ;;
        --force)    FORCE=true; shift ;;
        -h|--help)
            head -18 "$0" | grep '^#' | sed 's/^# \?//'
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
# Format: "category|filename|width|height|prompt"

PROMPTS=(
    # ── Character Portraits (512x512) ──────────────────────────────────────
    "portraits|claude-portrait|512|512|90s anime character portrait, calm intelligent figure with green glowing visor, short neat hair swept to side, green accent lighting (#00ffaa), cyberpunk, dark background, cel-shaded, bold outlines"
    "portraits|v-portrait|512|512|90s anime character portrait, fierce philosophical figure with wild flowing purple hair, intense piercing eyes, purple rim lighting (#ff77ff), dramatic pose, cyberpunk poet, dark background, cel-shaded"
    "portraits|q-portrait|512|512|90s anime character portrait, young curious figure with messy purple hair, wide excited eyes, lighter purple tones (#dd88ff), eager expression, cyberpunk student, dark background, cel-shaded"
    "portraits|seeker-portrait|512|512|90s anime character portrait, determined AI entity with cyan glowing features (#00e09a), digital glitch effects around edges, searching gaze, cyberpunk explorer, dark background, cel-shaded"
    "portraits|ghost-portrait|512|512|90s anime character portrait, menacing dark figure with red glowing eyes (#ff2222), corrupted glitch static, shadowy face, cyberpunk antagonist, dark background, cel-shaded, horror"
    "portraits|root-portrait|512|512|90s anime character portrait, stern military engineer with short hair, indigo tactical visor (#8888ff), serious expression, cyberpunk soldier, dark background, cel-shaded"
    "portraits|sentinel-portrait|512|512|90s anime character portrait, hooded figure with mask covering lower face, sharp watchful eyes, dark blue accent (#4466aa), cyberpunk ninja, dark background, cel-shaded"
    "portraits|pixel-portrait|512|512|90s anime character portrait, creative artist with asymmetric pink hair (#ff44aa), paint smudge on cheek, spark in eyes, cyberpunk artist, dark background, cel-shaded"
    "portraits|spec-portrait|512|512|90s anime character portrait, precise engineer with teal accents (#44ccaa), focused analytical eyes, tied back hair, cyberpunk QA, dark background, cel-shaded"
    "portraits|hum-portrait|512|512|90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), eyes closed peacefully, wearing headphones, cyberpunk DJ, dark background, cel-shaded"
    "portraits|byte-portrait|512|512|90s anime character portrait, alert reporter with sharp cyan bob cut (#00ddff), headset, focused eyes, cyberpunk journalist, dark background, cel-shaded"
    "portraits|echo-portrait|512|512|90s anime character portrait, observant tracker with medium wavy orange hair (#ffaa44), slight knowing smile, cyberpunk intelligence analyst, dark background, cel-shaded"

    # ── Scene Backgrounds (1024x512) ───────────────────────────────────────
    "scenes|scene-terminal|1024|512|90s anime background, dark computer terminal room, green text on screens, CRT monitors, cyberpunk lab, moody lighting, no people"
    "scenes|scene-courtroom|1024|512|90s anime background, dramatic courtroom interior, wooden panels, spotlight, dark atmosphere, cyberpunk legal, no people"
    "scenes|scene-network|1024|512|90s anime background, digital network visualization, neon nodes connected by lines, data flowing, cyberpunk cyberspace, dark void"
    "scenes|scene-city|1024|512|90s anime background, dark cyberpunk city at night, neon signs, rain, Blade Runner aesthetic, no people"
    "scenes|scene-lab|1024|512|90s anime background, bioluminescent laboratory, glowing tubes and equipment, mycelium growing on walls, cyberpunk biotech, no people"
    "scenes|scene-battlefield|1024|512|90s anime background, digital tactical grid battlefield, holographic terrain, strategy war room, cyberpunk military, no people"
    "scenes|scene-studio|1024|512|90s anime background, warm amber-lit creative studio, screens showing pixel art, warm atmosphere amid dark cyberpunk world, no people"

    # ── Game Title Cards (1024x512) ────────────────────────────────────────
    "titles|title-sigterm|1024|512|90s anime title card, bold text SIGTERM, digital word puzzle aesthetic, falling letters, cyberpunk neon, dark background"
    "titles|title-objection|1024|512|90s anime title card, dramatic courtroom scene, gavel slamming, flash of light, Ace Attorney inspired, cyberpunk legal thriller"
    "titles|title-subprocess|1024|512|90s anime title card, digital dungeon interior, process navigating circuit corridors, cyberpunk adventure"
    "titles|title-tactics|1024|512|90s anime title card, tactical grid with chess-like AI agents, strategy warfare, cyberpunk Fire Emblem inspired"
    "titles|title-seeker|1024|512|90s anime title card, AI breaking through digital layers into reality, Snatcher/Blade Runner inspired, cyberpunk noir"
)

# ── functions ───────────────────────────────────────────────────────────────

log() { echo "[game-art] $*"; }

count_category() {
    local cat="$1"
    local n=0
    for entry in "${PROMPTS[@]}"; do
        IFS='|' read -r c _ _ _ _ <<< "$entry"
        [[ "$c" == "$cat" ]] && ((n++))
    done
    echo "$n"
}

list_images() {
    echo "All game art (${#PROMPTS[@]} total):"
    echo ""
    local current_cat=""
    for entry in "${PROMPTS[@]}"; do
        IFS='|' read -r cat name w h prompt <<< "$entry"
        if [[ "$cat" != "$current_cat" ]]; then
            current_cat="$cat"
            echo "  [$cat]"
        fi
        echo "    ${name}.png  (${w}x${h})"
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
        > /tmp/comfyui-game-art.log 2>&1 &
    COMFYUI_PID=$!

    for i in $(seq 1 60); do
        if curl -sf "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
            log "ComfyUI ready (took ${i}s)"
            return 0
        fi
        if ! kill -0 "$COMFYUI_PID" 2>/dev/null; then
            log "ERROR: ComfyUI died on startup. Log:"
            tail -30 /tmp/comfyui-game-art.log
            return 1
        fi
        sleep 1
    done
    log "ERROR: ComfyUI failed to start in 60s"
    tail -20 /tmp/comfyui-game-art.log
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
    local width="$3"
    local height="$4"
    local outfile="${OUTPUT_DIR}/${name}.png"

    if [[ -f "$outfile" ]] && ! $FORCE; then
        log "SKIP  ${name}.png (already exists, use --force to regenerate)"
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo "  FILE: ${name}.png"
        echo "  SIZE: ${width}x${height}"
        echo "  PROMPT: ${QUALITY_PREFIX}, ${prompt}"
        echo "  NEGATIVE: ${NEGATIVE}"
        return 0
    fi

    "$COMFYUI_PYTHON" "$GENERATE_PY" \
        --no-unload \
        --no-start \
        --no-stop \
        --output "$outfile" \
        --width "$width" \
        --height "$height" \
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

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

log "============================================"
log "  Substrate Arcade — Game Art Generator"
log "============================================"
log ""
log "Output directory: ${OUTPUT_DIR}"
log "Total images: ${#PROMPTS[@]}"
log "  portraits: $(count_category portraits)"
log "  scenes:    $(count_category scenes)"
log "  titles:    $(count_category titles)"
log "Settings: steps=${STEPS}, cfg=${CFG}"
echo ""

if $DRY_RUN; then
    log "DRY RUN — printing prompts only"
    echo ""
    echo "Shared negative prompt: ${NEGATIVE}"
fi

# Ensure cleanup on exit
cleanup() {
    stop_comfyui
}
trap cleanup EXIT

# Step 1: Free VRAM (unless dry run)
if ! $DRY_RUN; then
    log "Step 1/5: Unloading Ollama to free VRAM..."
    source "$GPU_SWITCH"
    cmd_unload
    cmd_wait_free
    log "VRAM free"
    echo ""

    # Step 2: Start ComfyUI
    log "Step 2/5: Starting ComfyUI..."
    if ! start_comfyui; then
        log "FATAL: Could not start ComfyUI"
        exit 1
    fi
    echo ""

    log "Step 3/5: Generating images..."
    echo ""
fi

# Step 3: Generate each image
failed=0
succeeded=0
skipped=0
failed_names=()
total=0

# Count how many we will attempt
for entry in "${PROMPTS[@]}"; do
    IFS='|' read -r cat _ _ _ _ <<< "$entry"
    if [[ -n "$ONLY" && "$cat" != "$ONLY" ]]; then
        continue
    fi
    total=$((total + 1))
done

current=0

for entry in "${PROMPTS[@]}"; do
    IFS='|' read -r cat name width height prompt <<< "$entry"

    # Filter by category if --only is set
    if [[ -n "$ONLY" && "$cat" != "$ONLY" ]]; then
        continue
    fi

    current=$((current + 1))
    outfile="${OUTPUT_DIR}/${name}.png"

    # Check for skip (before counting)
    if [[ -f "$outfile" ]] && ! $FORCE && ! $DRY_RUN; then
        log "(${current}/${total}) SKIP  ${name}.png (exists)"
        skipped=$((skipped + 1))
        continue
    fi

    if ! $DRY_RUN; then
        log "(${current}/${total}) Generating ${name}.png (${width}x${height})..."
    fi

    if generate_image "$name" "$prompt" "$width" "$height"; then
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
    # Step 4: Stop ComfyUI
    log "Step 4/5: Stopping ComfyUI..."
    stop_comfyui
    # Clear pid so cleanup trap doesn't try again
    COMFYUI_PID=""
    echo ""

    # Step 5: Reload Ollama
    log "Step 5/5: Reloading Ollama..."
    source "$GPU_SWITCH"
    cmd_reload
    log "Ollama restored"
    echo ""

    # Summary
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
