#!/bin/bash
# Substrate Migration Backup Script
# Copies secrets, config, and recovery files to USB for Gentoo migration
#
# Usage: bash scripts/migrate/backup.sh /mnt/usb
#   where /mnt/usb is the mounted USB 2 drive

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[*]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[!]${NC} $1"; exit 1; }

USB="${1:-}"
[ -n "$USB" ] || error "Usage: $0 /mnt/usb"
[ -d "$USB" ] || error "USB mount point not found: $USB"

DEST="${USB}/substrate-migration"
SUBSTRATE="/home/operator/substrate"
HOME_DIR="/home/operator"

info "Substrate Migration Backup"
echo "  Source: ${HOME_DIR}"
echo "  Dest:   ${DEST}"
echo ""

# Create directory structure
mkdir -p "${DEST}"/{secrets/ssh,secrets/ledger,config,gentoo}

# === Secrets ===
info "Backing up secrets..."

# .env (API keys)
if [ -f "${SUBSTRATE}/.env" ]; then
    cp "${SUBSTRATE}/.env" "${DEST}/secrets/.env"
    info "  .env copied"
else
    warn "  .env not found — check manually"
fi

# SSH keys
if [ -d "${HOME_DIR}/.ssh" ]; then
    [ -f "${HOME_DIR}/.ssh/id_ed25519" ] && cp "${HOME_DIR}/.ssh/id_ed25519" "${DEST}/secrets/ssh/"
    [ -f "${HOME_DIR}/.ssh/id_ed25519.pub" ] && cp "${HOME_DIR}/.ssh/id_ed25519.pub" "${DEST}/secrets/ssh/"
    [ -f "${HOME_DIR}/.ssh/authorized_keys" ] && cp "${HOME_DIR}/.ssh/authorized_keys" "${DEST}/secrets/ssh/"
    [ -f "${HOME_DIR}/.ssh/known_hosts" ] && cp "${HOME_DIR}/.ssh/known_hosts" "${DEST}/secrets/ssh/"
    info "  SSH keys copied"
else
    warn "  ~/.ssh not found"
fi

# Ledger private files (gitignored)
if [ -d "${SUBSTRATE}/ledger" ]; then
    for f in expenses.private.txt revenue.private.txt; do
        [ -f "${SUBSTRATE}/ledger/${f}" ] && cp "${SUBSTRATE}/ledger/${f}" "${DEST}/secrets/ledger/"
    done
    info "  Ledger privates copied"
fi

# === Config ===
info "Backing up config..."

# Claude Code config
if [ -f "${HOME_DIR}/.claude.json" ]; then
    cp "${HOME_DIR}/.claude.json" "${DEST}/config/"
    info "  .claude.json copied"
fi

# Claude Code projects dir (OAuth, project settings)
if [ -d "${HOME_DIR}/.claude" ]; then
    # Copy selectively — skip large cache files
    mkdir -p "${DEST}/config/.claude"
    [ -f "${HOME_DIR}/.claude/settings.json" ] && cp "${HOME_DIR}/.claude/settings.json" "${DEST}/config/.claude/"
    [ -f "${HOME_DIR}/.claude/settings.local.json" ] && cp "${HOME_DIR}/.claude/settings.local.json" "${DEST}/config/.claude/"
    [ -d "${HOME_DIR}/.claude/todos" ] && cp -r "${HOME_DIR}/.claude/todos" "${DEST}/config/.claude/"
    info "  .claude/ config copied"
fi

# Git config
[ -f "${HOME_DIR}/.gitconfig" ] && cp "${HOME_DIR}/.gitconfig" "${DEST}/config/"

# NPM config
[ -f "${HOME_DIR}/.npmrc" ] && cp "${HOME_DIR}/.npmrc" "${DEST}/config/"

# tmux launcher scripts
for f in claude-tmux-start.sh claude-session-cleanup.sh; do
    [ -f "${HOME_DIR}/${f}" ] && cp "${HOME_DIR}/${f}" "${DEST}/config/"
done

info "  Config files copied"

# === 3D Assets (gitignored — 71MB, Kenney CC0 packs) ===
info "Backing up 3D model assets..."
ASSETS_DIR="${SUBSTRATE}/scripts/desktop-3d-godot/assets"
if [ -d "${ASSETS_DIR}" ]; then
    mkdir -p "${DEST}/assets/desktop-3d"
    cp -r "${ASSETS_DIR}" "${DEST}/assets/desktop-3d/"
    asset_size=$(du -sh "${ASSETS_DIR}" | cut -f1)
    info "  3D assets copied (${asset_size})"
else
    warn "  3D assets not found at ${ASSETS_DIR}"
fi

# === ComfyUI Models (gitignored — ~14GB, SD checkpoints + LoRAs) ===
info "Backing up ComfyUI models..."
COMFYUI_MODELS="${HOME_DIR}/comfyui/models"
if [ -d "${COMFYUI_MODELS}" ]; then
    mkdir -p "${DEST}/assets/comfyui-models"
    # Checkpoints
    if [ -d "${COMFYUI_MODELS}/checkpoints" ]; then
        mkdir -p "${DEST}/assets/comfyui-models/checkpoints"
        for f in "${COMFYUI_MODELS}/checkpoints/"*.safetensors; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            size=$(du -sh "$f" | cut -f1)
            info "  checkpoint: ${name} (${size})"
            cp "$f" "${DEST}/assets/comfyui-models/checkpoints/"
        done
    fi
    # LoRAs
    if [ -d "${COMFYUI_MODELS}/loras" ]; then
        mkdir -p "${DEST}/assets/comfyui-models/loras"
        for f in "${COMFYUI_MODELS}/loras/"*.safetensors; do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            size=$(du -sh "$f" | cut -f1)
            info "  lora: ${name} (${size})"
            cp "$f" "${DEST}/assets/comfyui-models/loras/"
        done
    fi
    total_size=$(du -sh "${DEST}/assets/comfyui-models" | cut -f1)
    info "  ComfyUI models copied (${total_size} total)"
else
    warn "  ComfyUI models not found at ${COMFYUI_MODELS}"
fi

# === Gentoo configs ===
info "Copying Gentoo configs from repo..."
if [ -d "${SUBSTRATE}/gentoo" ]; then
    cp -r "${SUBSTRATE}/gentoo/"* "${DEST}/gentoo/"
    info "  gentoo/ directory copied"
fi

# === Notes ===
info "Generating hardware notes..."
cat > "${DEST}/notes.txt" << EOF
# Substrate Migration Notes — $(date -I)
# Generated by scripts/migrate/backup.sh

## Disk Layout (current NixOS)
$(lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null || echo "lsblk unavailable")

## UUIDs
$(blkid 2>/dev/null || echo "blkid unavailable")

## Network
Hostname: $(hostname)
# WiFi SSID: [connect manually after install — never save credentials to disk]

## GPU
$(nvidia-smi -L 2>/dev/null || echo "nvidia-smi unavailable")

## CPU
$(grep "model name" /proc/cpuinfo | head -1 || echo "unknown")
Cores: $(nproc)

## Memory
$(free -h | head -2)

## Kernel
$(uname -r)
EOF
info "  notes.txt generated"

# === Summary ===
echo ""
info "Backup complete!"
echo ""

# Show directory sizes instead of listing every file (too many with 3D assets)
info "Directory sizes:"
du -sh "${DEST}"/secrets/ 2>/dev/null | awk '{print "  secrets:         " $1}'
du -sh "${DEST}"/config/  2>/dev/null | awk '{print "  config:          " $1}'
du -sh "${DEST}"/gentoo/  2>/dev/null | awk '{print "  gentoo:          " $1}'
du -sh "${DEST}"/assets/desktop-3d/ 2>/dev/null | awk '{print "  3d-assets:       " $1}'
du -sh "${DEST}"/assets/comfyui-models/ 2>/dev/null | awk '{print "  comfyui-models:  " $1}'
echo ""
info "Total size: $(du -sh "${DEST}" | cut -f1)"

# Verify critical files
echo ""
info "Critical file check:"
for f in secrets/.env secrets/ssh/id_ed25519 secrets/ledger/expenses.private.txt; do
    if [ -f "${DEST}/${f}" ]; then
        echo -e "  \033[0;32m✓\033[0m ${f}"
    else
        echo -e "  \033[0;31m✗\033[0m ${f} — MISSING"
    fi
done

echo ""
warn "VERIFY: Check that .env and SSH keys are present before wiping!"
warn "DO NOT commit this USB's contents to git (contains secrets)"
warn "USB will need ~15GB free (mostly ComfyUI models)"
