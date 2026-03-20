#!/usr/bin/env bash
# Start the ML Toolkit Web UI on port 8190.
#
# Uses the ComfyUI venv (PyTorch CUDA 12.4, diffusers, transformers, etc.)
# for GPU acceleration.
#
# Usage:
#   ./scripts/start-ml-ui.sh                # default: 127.0.0.1:8190
#   ./scripts/start-ml-ui.sh --port 9000    # custom port
#
# Web UI: http://127.0.0.1:8190
#
# Features:
#   - Image generation (SDXL Turbo / SD 1.5)
#   - Speech-to-text (Faster Whisper)
#   - Text-to-speech (SpeechT5)
#   - Music generation (MusicGen)
#   - GPU status monitoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_UI="$SCRIPT_DIR/ml/web-ui.py"

VENV_DIR="/home/operator/comfyui/venv"
PYTHON="$VENV_DIR/bin/python3"

# CUDA library paths (Gentoo standard locations)
export LD_LIBRARY_PATH="/usr/lib64:/opt/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ ! -f "$PYTHON" ]; then
    echo "error: venv not found at $VENV_DIR"
    echo "The ComfyUI venv is required (it has PyTorch + CUDA + ML deps)."
    exit 1
fi

if [ ! -f "$WEB_UI" ]; then
    echo "error: web-ui.py not found at $WEB_UI"
    exit 1
fi

echo "[ml-ui] python: $PYTHON"
$PYTHON -c "import torch; print(f'[ml-ui] torch {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
echo "[ml-ui] starting ML Toolkit Web UI..."
echo "[ml-ui] web UI: http://127.0.0.1:8190"
echo ""

cd "$SUBSTRATE_DIR"
exec "$PYTHON" "$WEB_UI" "$@"
