#!/usr/bin/env bash
# Downloads CC0 asset packs for Desktop 3D
# Run from scripts/desktop-3d-godot/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="${SCRIPT_DIR}/assets/models"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

echo "=== Downloading CC0 3D assets ==="

# Kenney Nature Kit — trees, rocks, mushrooms, ground tiles (~15MB)
if [ ! -d "kenney-nature" ]; then
    echo "Downloading Kenney Nature Kit..."
    curl -L "https://kenney.nl/media/pages/assets/nature-kit/3876445481-1677495930/kenney_nature-kit.zip" -o nature-kit.zip
    unzip -q nature-kit.zip -d kenney-nature/
    rm nature-kit.zip
    echo "Kenney Nature Kit installed."
else
    echo "Kenney Nature Kit already present, skipping."
fi

echo "=== Done. Assets in: $MODELS_DIR ==="
echo "Load models via: scripts/desktop-3d.sh load_model --path $MODELS_DIR/kenney-nature/Models/GLTF/tree.glb"
