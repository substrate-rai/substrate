#!/usr/bin/env bash
# desktop-3d.sh — CLI client for Substrate Desktop 3D overlay
# Sends JSON commands to the overlay server on TCP localhost:9877
#
# Usage:
#   desktop-3d.sh status
#   desktop-3d.sh mushroom --color "#00ffaa" --x 0 --y 0
#   desktop-3d.sh spore_cluster --color "#ff77ff" --x 2
#   desktop-3d.sh tree --color "#77aaff" --x -2
#   desktop-3d.sh forest_floor
#   desktop-3d.sh clear
#   desktop-3d.sh bloom --strength 2.0
#   desktop-3d.sh raw '{"type":"status","params":{}}'
set -euo pipefail

HOST="${SUBSTRATE_3D_HOST:-127.0.0.1}"
PORT="${SUBSTRATE_3D_PORT:-9877}"
TIMEOUT=5
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 1; }

# Find python3
find_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    else
        die "python3 not found in PATH"
    fi
}

PYTHON_CMD="$(find_python)"

send_json() {
    local json="$1"
    $PYTHON_CMD -c "
import socket, sys, json
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout($TIMEOUT)
try:
    s.connect(('$HOST', $PORT))
    s.sendall(json.dumps(json.loads(sys.argv[1])).encode() + b'\n')
    data = b''
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        data += chunk
        try:
            json.loads(data.decode())
            break
        except json.JSONDecodeError:
            continue
    print(data.decode().strip())
except ConnectionRefusedError:
    print(json.dumps({'status': 'error', 'message': 'Cannot connect to Desktop 3D on $HOST:$PORT — is the service running?'}))
    sys.exit(1)
except socket.timeout:
    print(json.dumps({'status': 'error', 'message': 'Connection timed out'}))
    sys.exit(1)
finally:
    s.close()
" "$json"
}

# ── build JSON from CLI args ─────────────────────────────────────────────────

build_params_json() {
    # Parse --key value pairs into JSON object
    local params="{"
    local first=true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*)
                local key="${1#--}"
                local val="${2:-}"
                [[ -z "$val" ]] && die "Missing value for $1"

                $first || params+=","
                first=false

                # Detect numbers vs strings
                if [[ "$val" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
                    params+="\"$key\":$val"
                else
                    # Escape quotes in value
                    val="${val//\\/\\\\}"
                    val="${val//\"/\\\"}"
                    params+="\"$key\":\"$val\""
                fi
                shift 2
                ;;
            *)
                die "Unknown argument: $1 (expected --key value)"
                ;;
        esac
    done
    params+="}"
    echo "$params"
}

# ── main ─────────────────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && die "Usage: desktop-3d.sh <command> [args...]
Commands: status, clear, bloom, raw
Scenes:     desktop-3d.sh full_scene         (mycopunk forest)
            desktop-3d.sh abyss_scene        (underwater abyss)
            desktop-3d.sh crystal_cave       (crystalline cavern)
            desktop-3d.sh neon_city          (neon cityscape)
            desktop-3d.sh volcanic           (lava hellscape)
            desktop-3d.sh zen_garden         (japanese garden)
            desktop-3d.sh fairy_garden       (growing fairy garden)
            desktop-3d.sh haunted_graveyard  (gothic graveyard — reactive)
            desktop-3d.sh space_outpost      (sci-fi frontier — reactive)
            desktop-3d.sh autumn_campsite    (warm autumn — reactive, day/night)
            desktop-3d.sh abandoned_station  (liminal overgrowth — reactive)
Art:        desktop-3d.sh fractal           (raymarched mandelbulb)
            desktop-3d.sh aurora            (northern lights)
            desktop-3d.sh matrix_rain       (digital rain)
            desktop-3d.sh mycelium          (reaction-diffusion network)
            desktop-3d.sh attractor         (lorenz strange attractor)
            desktop-3d.sh galaxy            (spiral galaxy)
            desktop-3d.sh visualizer        (audio spectrum ring)
            desktop-3d.sh lsystem           (procedural L-system trees)
            desktop-3d.sh vine_garden       (climbing vines + flowers)
            desktop-3d.sh fluid             (cursor-interactive particles)
            desktop-3d.sh fire              (procedural fire)
            desktop-3d.sh vaporwave         (retro grid + sunset)
            desktop-3d.sh domain_warp       (nested fBM warp art)
            desktop-3d.sh ocean             (gerstner wave ocean)
            desktop-3d.sh cloudscape        (volumetric clouds)
            desktop-3d.sh physarum          (slime mold simulation)
            desktop-3d.sh plasma            (demoscene sine waves)
            desktop-3d.sh kaleidoscope      (polar coordinate reflections)
            desktop-3d.sh tunnel            (infinite corridor)
            desktop-3d.sh starfield         (parallax warp stars)
            desktop-3d.sh julia             (julia set fractal)
            desktop-3d.sh lava              (voronoi flowing magma)
            desktop-3d.sh nebula            (layered space nebula)
            desktop-3d.sh lightning         (electrical arcs)
            desktop-3d.sh blackhole         (gravitational lensing)
            desktop-3d.sh metaballs         (organic blob SDF)
            desktop-3d.sh menger            (menger sponge fractal)
            desktop-3d.sh supernova        (expanding shockwave rings)
            desktop-3d.sh synthgrid        (retro grid + audio pillars)
            desktop-3d.sh waveform         (7-band audio mountain range)
PostFX:     desktop-3d.sh postfx --effect crt|tiltshift|ink|vhs|chroma|anime|nightvision|pixelate|glitch|thermal|ascii|none
Objects:    desktop-3d.sh mushroom --color '#00ffaa' --x 0 --y 0
            desktop-3d.sh mecha --color '#00ffaa' --x 0 --y 0 --animation idle|walk|patrol
            desktop-3d.sh jellyfish|coral|vent|anglerfish|ruin [--x N --y N]
Camera:     desktop-3d.sh camera --mode orbit|follow_cursor|cinematic|cycle
Cursor:     desktop-3d.sh cursor --enabled true|false
Auto:       desktop-3d.sh auto_rotate --enabled true|false
            desktop-3d.sh idle --threshold 300
Transition: desktop-3d.sh transition --scene haunted_graveyard   (fade to black)
Spawn:      desktop-3d.sh spawn --model character-ghost.glb --kit graveyard --x 0 --y 0
Hologram:   desktop-3d.sh hologram_display --x 0 --y 1.2 --z -2
Events:     desktop-3d.sh event --event commit|ollama_start|ollama_stop
Screenshot: desktop-3d.sh screenshot --path /tmp/screenshot.png
Pomodoro:   desktop-3d.sh pomodoro --action start|stop|status --duration 1500
Music:      desktop-3d.sh music play|pause|toggle|next|prev|stop|status
            desktop-3d.sh music volume <0-100>
Utility:    desktop-3d.sh sky '#ff0066' '#0033aa' 2.0   (top, horizon, energy)
            desktop-3d.sh particles fireflies|rain|embers|snow
Load model: desktop-3d.sh load_model --path /path/to/model.glb --x 0 --y 0 --scale 1.0"

CMD="$1"
shift

case "$CMD" in
    raw)
        [[ $# -lt 1 ]] && die "Usage: desktop-3d.sh raw '{\"type\":\"...\"}'"
        send_json "$1"
        ;;
    status|clear)
        send_json "{\"type\":\"$CMD\",\"params\":{}}"
        ;;
    full_scene|abyss_scene|crystal_cave|neon_city|volcanic|zen_garden|fairy_garden|haunted_graveyard|space_outpost|autumn_campsite|abandoned_station|fractal|aurora|matrix_rain|mycelium|attractor|galaxy|visualizer|lsystem|vine_garden|fluid|fire|vaporwave|domain_warp|ocean|cloudscape|physarum|plasma|kaleidoscope|tunnel|starfield|julia|lava|nebula|lightning|blackhole|metaballs|menger|supernova|synthgrid|waveform|castlevania|mgs|aquarium)
        send_json "{\"type\":\"$CMD\",\"params\":{}}"
        ;;
    postfx)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"postfx\",\"params\":$PARAMS}"
        ;;
    sky)
        send_json "{\"type\":\"sky\",\"params\":{\"top\":\"${1:-#0d0328}\",\"horizon\":\"${2:-#0a1e0f}\",\"energy\":${3:-1.0}}}"
        ;;
    particles)
        send_json "{\"type\":\"particles\",\"params\":{\"preset\":\"${1:-fireflies}\"}}"
        ;;
    camera|cursor|auto_rotate|idle|transition|spawn|hologram_display)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"$CMD\",\"params\":$PARAMS}"
        ;;
    event)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"event\",\"params\":$PARAMS}"
        ;;
    screenshot)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"screenshot\",\"params\":$PARAMS}"
        ;;
    pomodoro)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"pomodoro\",\"params\":$PARAMS}"
        ;;
    mushroom|spore_cluster|tree|forest_floor|mecha|load_model|bloom|jellyfish|coral|vent|anglerfish|ruin)
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"$CMD\",\"params\":$PARAMS}"
        ;;
    music)
        subcmd="${1:-status}"; shift || true
        case "$subcmd" in
            play|pause|toggle|next|prev|stop) mpc "$subcmd" 2>/dev/null | head -3 ;;
            status) mpc status 2>/dev/null || echo "MPD not running" ;;
            volume) mpc volume "${1:-}" 2>/dev/null ;;
            *) die "Unknown music command: $subcmd" ;;
        esac
        ;;
    *)
        die "Unknown command: $CMD"
        ;;
esac
