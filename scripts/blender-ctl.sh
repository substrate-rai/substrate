#!/usr/bin/env bash
# blender-ctl — Claude-native 3D modeling control via Blender headless
# Lets the managing intelligence create, render, export, and convert 3D assets
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/blender"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source VRAM management from gpu-switch.sh
source "${SCRIPT_DIR}/ml/gpu-switch.sh"

# ── helpers ──────────────────────────────────────────────────────────────────

log() { echo "[blender-ctl] $*"; }

needs_gpu() {
    # Returns 0 if the operation needs GPU (should manage VRAM)
    return 0
}

with_gpu() {
    # Wraps a command with VRAM management: unload Ollama → run → reload
    log "acquiring GPU (unloading Ollama)..."
    cmd_unload
    cmd_wait_free
    local rc=0
    "$@" || rc=$?
    log "releasing GPU (reloading Ollama)..."
    cmd_reload || true
    return $rc
}

run_blender() {
    # Run blender headless with a template script
    # Usage: run_blender [file.blend] template.py [-- args...]
    local blend_file=""
    local template="$1"
    shift

    if [[ "$template" == *.blend ]]; then
        blend_file="$template"
        template="$1"
        shift
    fi

    if [[ -n "$blend_file" ]]; then
        blender --background "$blend_file" --python "${TEMPLATE_DIR}/${template}" -- "$@"
    else
        blender --background --python "${TEMPLATE_DIR}/${template}" -- "$@"
    fi
}

# ── subcommands ──────────────────────────────────────────────────────────────

cmd="${1:-help}"
shift || true

case "$cmd" in
    status)
        echo "=== Blender ==="
        blender --version 2>/dev/null | head -1 || echo "blender not found"
        echo ""
        echo "=== GPU ==="
        nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "nvidia-smi unavailable"
        echo ""
        echo "=== Templates ==="
        for f in "${TEMPLATE_DIR}"/*.py; do
            echo "  $(basename "$f")"
        done
        ;;

    create)
        # create <type> [--color <hex>] [--emission <N>] [--output <path>]
        prim_type="${1:-cube}"
        shift || true
        color="#00ffaa"
        emission="2.0"
        output="${REPO_DIR}/assets/3d/primitive.blend"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --color)   color="$2"; shift 2 ;;
                --emission) emission="$2"; shift 2 ;;
                --output)  output="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        mkdir -p "$(dirname "$output")"
        run_blender create_primitive.py --type "$prim_type" --color "$color" --emission "$emission" --output "$output"
        ;;

    render)
        # render <file.blend> [--engine cycles|eevee] [--gpu] [--samples N] [--resolution WxH] [--output <path>]
        blend_file="$1"; shift
        [[ -f "$blend_file" ]] || { log "Error: file not found: $blend_file" >&2; exit 1; }

        engine="eevee"
        use_gpu=false
        samples="128"
        resolution="1920x1080"
        output="/tmp/render-$(date +%s).png"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --engine)     engine="$2"; shift 2 ;;
                --gpu)        use_gpu=true; shift ;;
                --samples)    samples="$2"; shift 2 ;;
                --resolution) resolution="$2"; shift 2 ;;
                --output)     output="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        mkdir -p "$(dirname "$output")"
        render_args=(--engine "$engine" --samples "$samples" --resolution "$resolution" --output "$output")
        if $use_gpu; then
            render_args+=(--gpu)
        fi

        # GPU operations need VRAM management
        if $use_gpu || [[ "$engine" == "eevee" ]]; then
            with_gpu run_blender "$blend_file" render.py "${render_args[@]}"
        else
            run_blender "$blend_file" render.py "${render_args[@]}"
        fi
        ;;

    export)
        # export <file.blend> [--format gltf|glb|obj|stl|fbx] [--output <path>]
        blend_file="$1"; shift
        [[ -f "$blend_file" ]] || { log "Error: file not found: $blend_file" >&2; exit 1; }

        format="glb"
        output=""

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --format) format="$2"; shift 2 ;;
                --output) output="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        if [[ -z "$output" ]]; then
            base="$(basename "$blend_file" .blend)"
            output="${REPO_DIR}/assets/3d/${base}.${format}"
        fi

        mkdir -p "$(dirname "$output")"
        run_blender "$blend_file" export_scene.py --format "$format" --output "$output"
        ;;

    convert)
        # convert <input> <output>
        input_file="$1"
        output_file="$2"
        [[ -f "$input_file" ]] || { log "Error: file not found: $input_file" >&2; exit 1; }

        mkdir -p "$(dirname "$output_file")"
        run_blender convert.py --input "$input_file" --output "$output_file"
        ;;

    info)
        # info <file.blend>
        blend_file="$1"
        [[ -f "$blend_file" ]] || { log "Error: file not found: $blend_file" >&2; exit 1; }
        run_blender "$blend_file" info.py
        ;;

    run)
        # run <script.py> [-- args...]
        script="$1"; shift
        [[ -f "$script" ]] || { log "Error: script not found: $script" >&2; exit 1; }
        blender --background --python "$script" "$@"
        ;;

    mycopunk)
        # mycopunk <type> [--color <hex>] [--emission <N>] [--output <path>] [--render <path>]
        #          [--engine cycles|eevee] [--samples N] [--resolution WxH]
        myco_type="${1:-mushroom}"
        shift || true
        color="#00ffaa"
        emission="3.0"
        output="${REPO_DIR}/assets/3d/mycopunk-${myco_type}.blend"
        render_path=""
        engine="eevee"
        samples="64"
        resolution="1920x1080"

        while [[ $# -gt 0 ]]; do
            case "$1" in
                --color)      color="$2"; shift 2 ;;
                --emission)   emission="$2"; shift 2 ;;
                --output)     output="$2"; shift 2 ;;
                --render)     render_path="$2"; shift 2 ;;
                --engine)     engine="$2"; shift 2 ;;
                --samples)    samples="$2"; shift 2 ;;
                --resolution) resolution="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        mkdir -p "$(dirname "$output")"

        myco_args=(--type "$myco_type" --color "$color" --emission "$emission" --output "$output")
        myco_args+=(--engine "$engine" --samples "$samples" --resolution "$resolution")

        if [[ -n "$render_path" ]]; then
            mkdir -p "$(dirname "$render_path")"
            myco_args+=(--render "$render_path")
            # Rendering needs GPU
            with_gpu run_blender mycopunk.py "${myco_args[@]}"
        else
            # Just creating .blend, no GPU needed
            run_blender mycopunk.py "${myco_args[@]}"
        fi
        ;;

    help|*)
        cat <<'HELP'
blender-ctl — Claude-native 3D modeling control via Blender headless

CREATION:
  create <type> [--color <hex>] [--emission N] [--output <path>]
      Create primitive with emission material
      Types: cube, sphere, cylinder, torus, monkey
      Default color: #00ffaa (substrate green)

  mycopunk <type> [--color <hex>] [--emission N] [--output <path>]
           [--render <path>] [--engine cycles|eevee] [--samples N] [--resolution WxH]
      Generate procedural mycopunk objects
      Types: mushroom, spore-cluster, bioluminescent-tree, forest-floor
      Default color: #00ffaa | Add --render to also render to PNG

RENDERING:
  render <file.blend> [--engine cycles|eevee] [--gpu] [--samples N]
         [--resolution WxH] [--output <path>]
      Render .blend file to PNG
      GPU operations automatically manage VRAM (unload/reload Ollama)

EXPORT/CONVERT:
  export <file.blend> [--format gltf|glb|obj|stl|fbx] [--output <path>]
      Export scene to interchange format (default: glb)

  convert <input> <output>
      Convert between 3D formats (infers from file extensions)
      Supported: .blend, .obj, .stl, .fbx, .gltf, .glb, .ply

INSPECTION:
  info <file.blend>
      Print scene info (objects, vertices, materials, render settings)

SCRIPTING:
  run <script.py> [-- args...]
      Execute arbitrary Blender Python script in headless mode

SYSTEM:
  status     Show Blender version, GPU info, available templates
  help       Show this help

VRAM MANAGEMENT:
  Operations that use the GPU (render, mycopunk --render) automatically
  unload Ollama models before running and reload them after.
  CPU-only operations (create, export, convert, info) skip VRAM management.

OUTPUT DIRECTORIES:
  .blend files → assets/3d/
  Rendered PNGs → assets/images/generated/
HELP
        ;;
esac
