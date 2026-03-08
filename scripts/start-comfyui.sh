#!/run/current-system/sw/bin/bash
# Start ComfyUI with CUDA support on NixOS.
#
# Uses a standalone venv at /home/operator/comfyui/venv with pip-installed
# PyTorch CUDA 12.4, bypassing the slow nix develop shell.
#
# Usage:
#   ./scripts/start-comfyui.sh                    # normal start on port 8188
#   ./scripts/start-comfyui.sh --port 8190        # custom port
#   ./scripts/start-comfyui.sh --listen 0.0.0.0   # listen on all interfaces
#
# The SDXL Turbo model (fp16) is at:
#   /home/operator/comfyui/models/checkpoints/sd_xl_turbo_1.0_fp16.safetensors
#
# VRAM note: RTX 4060 has 8GB shared with Ollama. This script unloads
# Ollama models before starting to maximize available VRAM.

set -euo pipefail

COMFYUI_DIR="/home/operator/comfyui"
VENV_DIR="$COMFYUI_DIR/venv"
PYTHON="$VENV_DIR/bin/python3"

# NixOS library paths — required for CUDA and C++ runtime
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/nix/store/ihpdbhy4rfxaixiamyb588zfc3vj19al-gcc-15.2.0-lib/lib:/nix/store/m028f6iw72di3mqah6zmfpjx91973bk0-cuda-merged-12.4/lib:/nix/store/drxbq03f66krz302bp077bqf0damsayv-zlib-1.3.1/lib:/nix/store/rla54w2i158xf5i5fla3mwh5760x3pgn-libglvnd-1.7.0/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ ! -d "$COMFYUI_DIR" ]; then
    echo "error: ComfyUI not found at $COMFYUI_DIR"
    echo "Clone it: git clone https://github.com/comfyanonymous/ComfyUI.git $COMFYUI_DIR"
    exit 1
fi

if [ ! -f "$PYTHON" ]; then
    echo "error: venv not found at $VENV_DIR"
    echo "The ComfyUI venv needs to be set up first."
    exit 1
fi

echo "[comfyui] python: $PYTHON"
$PYTHON -c "import torch; print(f'[comfyui] torch {torch.__version__}, CUDA: {torch.cuda.is_available()}')"

# Unload Ollama models to free VRAM
echo "[comfyui] freeing GPU VRAM (unloading Ollama models)..."
$PYTHON -c "
import json, urllib.request
try:
    req = urllib.request.Request('http://localhost:11434/api/ps')
    with urllib.request.urlopen(req, timeout=5) as resp:
        models = json.loads(resp.read()).get('models', [])
        for m in models:
            name = m.get('name', 'unknown')
            body = json.dumps({'model': name, 'keep_alive': 0}).encode()
            req2 = urllib.request.Request('http://localhost:11434/api/generate', data=body,
                headers={'Content-Type': 'application/json'}, method='POST')
            urllib.request.urlopen(req2, timeout=30)
            print(f'  unloaded {name}')
        if not models:
            print('  no models loaded')
except Exception as e:
    print(f'  ollama not reachable ({e}), continuing')
" 2>/dev/null || true

echo "[comfyui] starting ComfyUI..."
echo "[comfyui] web UI: http://127.0.0.1:8188"
echo "[comfyui] model dir: $COMFYUI_DIR/models/"
echo ""

cd "$COMFYUI_DIR"
exec "$PYTHON" main.py --listen 127.0.0.1 --port 8188 "$@"
