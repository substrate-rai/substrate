#!/usr/bin/env bash
# blender-live.sh — CLI client for Substrate Live Server in Blender
# Sends JSON commands to Blender over TCP (localhost:9876)
#
# Usage:
#   blender-live.sh status
#   blender-live.sh mushroom --color "#00ffaa" --x 0 --y 0
#   blender-live.sh spore_cluster --color "#ff77ff" --x 1 --y 1
#   blender-live.sh tree --color "#77aaff" --x -1 --y 0
#   blender-live.sh forest_floor
#   blender-live.sh clear
#   blender-live.sh camera --x 3 --y -3 --z 2.5
#   blender-live.sh animate --target Cap --property rotation_euler --axis 2 --start 0 --end 6.28 --frames 120
#   blender-live.sh scene_setup --engine eevee
#   blender-live.sh exec "bpy.ops.mesh.primitive_monkey_add(location=(2,0,0))"
#   blender-live.sh raw '{"type":"status","params":{}}'
set -euo pipefail

HOST="${SUBSTRATE_BLENDER_HOST:-127.0.0.1}"
PORT="${SUBSTRATE_BLENDER_PORT:-9876}"
TIMEOUT=5
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "error: $*" >&2; exit 1; }

# Find python3 — try PATH first, then nix develop
find_python() {
    if command -v python3 &>/dev/null; then
        echo "python3"
    else
        # Use nix develop to get python3 from the flake
        echo "nix develop ${REPO_DIR} --command python3"
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
    print(json.dumps({'status': 'error', 'message': 'Cannot connect to Blender on $HOST:$PORT — is the server running?'}))
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

[[ $# -lt 1 ]] && die "Usage: blender-live.sh <command> [args...]
Commands: status, mushroom, spore_cluster, tree, forest_floor, clear,
          camera, animate, scene_setup, exec, raw"

CMD="$1"
shift

case "$CMD" in
    raw)
        # Send raw JSON
        [[ $# -lt 1 ]] && die "Usage: blender-live.sh raw '{\"type\":\"...\"}'"
        send_json "$1"
        ;;
    exec)
        # Execute arbitrary bpy code
        [[ $# -lt 1 ]] && die "Usage: blender-live.sh exec 'bpy.ops...'"
        CODE="$1"
        # Escape for JSON
        CODE="${CODE//\\/\\\\}"
        CODE="${CODE//\"/\\\"}"
        send_json "{\"type\":\"exec\",\"code\":\"$CODE\"}"
        ;;
    status|clear)
        # No-param commands
        send_json "{\"type\":\"$CMD\",\"params\":{}}"
        ;;
    mushroom|spore_cluster|tree|forest_floor|camera|animate|scene_setup)
        # Commands with --key value params
        PARAMS=$(build_params_json "$@")
        send_json "{\"type\":\"$CMD\",\"params\":$PARAMS}"
        ;;
    *)
        die "Unknown command: $CMD"
        ;;
esac
