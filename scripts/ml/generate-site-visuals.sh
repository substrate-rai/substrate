#!/usr/bin/env bash
# generate-site-visuals.sh — Batch generate all site images using SDXL Turbo.
#
# Generates ~30 images for the Substrate site:
#   - 1 homepage hero background
#   - 11 agent portraits (Claude, Q, V, Byte, Echo, Flux, Dash, Pixel, Spore, Root, Lumen)
#   - 5 tier illustrations (roots, mycelium, fruiting body, network, organism)
#   - 1 MycoWorld header
#   - 13 game thumbnails (one per arcade game)
#
# Usage:
#   ./generate-site-visuals.sh              Generate all images (requires GPU)
#   ./generate-site-visuals.sh --dry-run    Print prompts without generating
#   ./generate-site-visuals.sh --only hero  Generate only one category
#   ./generate-site-visuals.sh --list       List all image names
#
# Requires: gpu-switch.sh, generate-image.py, CUDA, ~4GB VRAM free
# Time estimate: ~3 minutes on RTX 4060 (4 steps per image, ~5s each)

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

# NixOS CUDA + C++ runtime library paths (must match start-comfyui.sh)
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

DRY_RUN=false
ONLY=""
LIST_ONLY=false

# ── parse args ──────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --only)     ONLY="$2"; shift 2 ;;
        --list)     LIST_ONLY=true; shift ;;
        -h|--help)
            head -20 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "error: unknown argument '$1'" >&2
            exit 1
            ;;
    esac
done

# ── negative prompt (shared across all generations) ─────────────────────────

NEGATIVE="text, watermark, human face, realistic photo, blurry, low quality, signature, words, letters"

# ── prompt definitions ──────────────────────────────────────────────────────
# Format: "category|filename|prompt"
# SDXL Turbo works best with concise, keyword-rich prompts.

PROMPTS=(
    # ── Homepage hero ───────────────────────────────────────────────────────
    "hero|hero-bg|dark bioluminescent mycelium network spreading across black void, glowing green tendrils, cyberpunk organic, terminal phosphor green light, macro photography style, deep shadows"

    # ── Agent portraits ─────────────────────────────────────────────────────
    # Each: abstract digital entity, no human features, symbolic representation
    "agents|agent-claude|abstract digital architect entity, geometric green terminal glow, command prompt cursor shape, dark background, neon green wireframe structures, cyberpunk organic, commanding presence"
    "agents|agent-q|abstract creative entity, flowing magenta and pink energy streams, audio waveform patterns, dark background, musical notation dissolving into particles, hip-hop aesthetic digital art"
    "agents|agent-v|abstract spiral energy entity, fierce magenta vortex, logarithmic spiral radiating power, dark background, momentum lines, glitch art aesthetic, kinetic digital painting"
    "agents|agent-byte|abstract data reporter entity, cyan data streams flowing at high speed, news ticker ribbons of light, dark background, information particles, fast-moving digital currents"
    "agents|agent-echo|abstract watchdog entity, concentric orange radar sweep rings, patient sonar pulse expanding outward, dark background, amber monitoring waves, surveillance aesthetic"
    "agents|agent-flux|abstract dreamer entity, explosive red idea sparks and branching thought trees, dark background, mind map of light connections, creative chaos, firework burst patterns"
    "agents|agent-dash|abstract project manager entity, sharp yellow geometric dashboard elements, progress bars and checklist grids of light, dark background, relentless precision, golden task matrix"
    "agents|agent-pixel|abstract artist entity, hot pink paint splatter dissolving into pixels, color palette fragments floating in void, dark background, digital canvas aesthetic, creative composition"
    "agents|agent-spore|abstract community entity, green bioluminescent spore cloud forming network connections, mycelium branching pattern, dark background, growing organic links, collective intelligence"
    "agents|agent-root|abstract engineer entity, deep periwinkle and blue infrastructure layers, circuit board tree roots, dark background, foundational architecture lines, deep system topology"
    "agents|agent-lumen|abstract educator entity, warm amber lantern glow illuminating pathways, guiding light trails through dark space, dark background, knowledge constellation, gentle radiance"

    # ── Tier illustrations ──────────────────────────────────────────────────
    # Progression from underground to full organism
    "tiers|tier-roots|deep underground root system, bioluminescent green tips in dark soil, minimal glow, just beginning to spread, macro cross-section view, dark earthy background"
    "tiers|tier-mycelium|sprawling white mycelium threads branching through dark substrate, hyphal network detail, underground web of connections, cyan bioluminescent nodes, microscope aesthetic"
    "tiers|tier-fruiting|single glowing mushroom fruiting body emerging from dark ground, bioluminescent cap with green-cyan glow, spore release particles, emergence moment, dramatic lighting"
    "tiers|tier-network|vast interconnected fungal network seen from above, hundreds of glowing nodes connected by light threads, neural network pattern, green and cyan bioluminescence, aerial view"
    "tiers|tier-organism|complete living organism, massive bioluminescent mycelium superorganism, roots and fruiting bodies and network unified, cosmic scale, galaxy of green connections, transcendent"

    # ── MycoWorld header ────────────────────────────────────────────────────
    "myco|myco-header|mushroom cap cross-section merged with circuit board traces, organic meets digital, mycelium threads becoming wire pathways, green bioluminescent, dark background, hybrid biotech aesthetic"

    # ── Game thumbnails ─────────────────────────────────────────────────────
    "games|game-sigterm|dark terminal screen with five glowing green letter slots, word puzzle grid, phosphor CRT aesthetic, scanlines, retro computer game, minimal"
    "games|game-subprocess|dark cyberpunk corridor, process spawning in digital space, glowing PID number, neon red emergency lights, NixOS-inspired architecture, text adventure aesthetic"
    "games|game-versus|two opposing terminal screens facing each other, competitive word duel, split screen green vs blue glow, versus battle aesthetic, dark background"
    "games|game-mycelium|top-down view of glowing fungal network spreading across dark terrain, real-time strategy minimap aesthetic, green colony vs purple colony, resource nodes"
    "games|game-chemistry|physics sandbox with elemental objects, fire meeting wood meeting water, chain reaction particles, laboratory experiment aesthetic, warm orange and cool blue, dark background"
    "games|game-tactics|isometric tactical grid battlefield, chess-like units on elevated terrain, purple and gold, strategy RPG aesthetic, dark background, dramatic height differences"
    "games|game-process|visual novel dialogue box with silhouette portraits, six AI characters in a row, muted colors, conversation aesthetic, laptop interior setting, dark moody"
    "games|game-airlock|top-down spaceship room, locked door puzzle, scattered physics objects, emergency lighting, among-us-inspired aesthetic, claustrophobic space, cyan and red"
    "games|game-cascade|momentum meter maxed out, spiral energy explosion, surge wave effects, abstract speedometer at 90 percent, golden energy cascade, dark background, kinetic"
    "games|game-objection|courtroom scene silhouette, dramatic desk slam, evidence presentation hologram, red objection flash, ace-attorney aesthetic, dramatic lighting, dark background"
    "games|game-cypher|rap battle stage with two microphones, spiral energy background, magenta vs cyan spotlights, hip-hop arena aesthetic, crowd silhouettes, dark dramatic"
    "games|game-bootloader|minimal boot screen with single task focus, progress spinner, clean terminal interface, green on black, productivity tool aesthetic, zen minimal"
    "games|game-brigade|military recruitment desk with holographic agent dossiers, interrogation room lighting, social deduction aesthetic, red warning indicators, dark tactical"
)

# ── functions ───────────────────────────────────────────────────────────────

log() { echo "[visuals] $*"; }

count_category() {
    local cat="$1"
    local n=0
    for entry in "${PROMPTS[@]}"; do
        IFS='|' read -r c _ _ <<< "$entry"
        [[ "$c" == "$cat" ]] && ((n++))
    done
    echo "$n"
}

list_images() {
    echo "All site visuals (${#PROMPTS[@]} total):"
    echo ""
    local current_cat=""
    for entry in "${PROMPTS[@]}"; do
        IFS='|' read -r cat name prompt <<< "$entry"
        if [[ "$cat" != "$current_cat" ]]; then
            current_cat="$cat"
            echo "  [$cat]"
        fi
        echo "    ${name}.png"
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
        > /tmp/comfyui-visuals.log 2>&1 &
    COMFYUI_PID=$!

    for i in $(seq 1 60); do
        if curl -sf "${COMFYUI_URL}/system_stats" -o /dev/null 2>/dev/null; then
            log "ComfyUI ready (took ${i}s)"
            return 0
        fi
        if ! kill -0 "$COMFYUI_PID" 2>/dev/null; then
            log "ERROR: ComfyUI died on startup. Log:"
            tail -30 /tmp/comfyui-visuals.log
            return 1
        fi
        sleep 1
    done
    log "ERROR: ComfyUI failed to start in 60s"
    tail -20 /tmp/comfyui-visuals.log
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

    if [[ -f "$outfile" ]]; then
        log "SKIP  ${name}.png (already exists)"
        return 0
    fi

    if $DRY_RUN; then
        echo ""
        echo "  FILE: ${name}.png"
        echo "  PROMPT: ${prompt}"
        echo "  NEGATIVE: ${NEGATIVE}"
        echo "  SIZE: 512x512"
        return 0
    fi

    log "GENERATE  ${name}.png"
    "$COMFYUI_PYTHON" "$GENERATE_PY" \
        --no-unload \
        --no-start \
        --no-stop \
        --output "$outfile" \
        --width 512 \
        --height 512 \
        "$prompt" || {
        log "FAILED  ${name}.png"
        return 1
    }
    log "OK  ${name}.png"
}

# ── main ────────────────────────────────────────────────────────────────────

if $LIST_ONLY; then
    list_images
    exit 0
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

log "Output directory: ${OUTPUT_DIR}"
log "Total images to generate: ${#PROMPTS[@]}"
log "  hero:   $(count_category hero)"
log "  agents: $(count_category agents)"
log "  tiers:  $(count_category tiers)"
log "  myco:   $(count_category myco)"
log "  games:  $(count_category games)"
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
    log "Freeing VRAM for Stable Diffusion..."
    source "$GPU_SWITCH"
    cmd_unload
    cmd_wait_free
    log "VRAM free"

    # Step 2: Start ComfyUI
    if ! start_comfyui; then
        log "FATAL: Could not start ComfyUI"
        exit 1
    fi
fi

# Step 3: Generate each image
failed=0
generated=0
skipped=0

for entry in "${PROMPTS[@]}"; do
    IFS='|' read -r cat name prompt <<< "$entry"

    # Filter by category if --only is set
    if [[ -n "$ONLY" && "$cat" != "$ONLY" ]]; then
        continue
    fi

    if generate_image "$name" "$prompt"; then
        if ! $DRY_RUN && [[ ! -f "${OUTPUT_DIR}/${name}.png" ]]; then
            skipped=$((skipped + 1))
        else
            generated=$((generated + 1))
        fi
    else
        failed=$((failed + 1))
    fi
done

echo ""
if $DRY_RUN; then
    log "DRY RUN COMPLETE — ${generated} prompts listed"
else
    # Step 4: Stop ComfyUI (handled by trap, but explicit is nice)
    stop_comfyui

    log "DONE — generated: ${generated}, skipped: ${skipped}, failed: ${failed}"

    # Step 5: Reload Ollama
    log "Restoring Ollama..."
    source "$GPU_SWITCH"
    cmd_reload
    log "Ollama restored. All done."
fi
