#!/bin/bash
# Substrate Post-Installation Verification
# Run after completing the Gentoo migration to verify everything works
#
# Usage: bash gentoo/verify.sh

set -uo pipefail

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  \033[0;32m✓\033[0m $1"; ((PASS++)); }
fail() { echo -e "  \033[0;31m✗\033[0m $1"; ((FAIL++)); }
warn() { echo -e "  \033[1;33m⚠\033[0m $1"; ((WARN++)); }

echo "====================================="
echo "  Substrate Verification Checklist"
echo "====================================="
echo ""

# --- GPU ---
echo "GPU:"
if nvidia-smi &>/dev/null; then
    gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
    pass "nvidia-smi works (${gpu})"
else
    fail "nvidia-smi not working"
fi

if nvidia-smi --query-gpu=driver_version --format=csv,noheader &>/dev/null; then
    ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)
    pass "NVIDIA driver loaded (v${ver})"
else
    fail "NVIDIA driver not loaded"
fi

if command -v nvcc &>/dev/null; then
    pass "CUDA toolkit installed ($(nvcc --version | grep release | awk '{print $6}'))"
else
    warn "CUDA toolkit not found (nvcc)"
fi

echo ""

# --- Ollama ---
echo "Ollama:"
if command -v ollama &>/dev/null; then
    pass "ollama binary found"
else
    fail "ollama not installed"
fi

if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    pass "ollama API responding"
else
    fail "ollama API not responding"
fi

if ollama list 2>/dev/null | grep -q "qwen3:8b"; then
    pass "qwen3:8b model loaded"
else
    warn "qwen3:8b not found (run: ollama pull qwen3:8b)"
fi

echo ""

# --- OpenRC Services ---
echo "Services:"
for svc in ollama substrate-battery-guard nvidia-persistenced dbus elogind NetworkManager sshd syslog-ng fcron fail2ban; do
    if rc-service "$svc" status &>/dev/null; then
        pass "${svc} running"
    elif rc-update show | grep -q "$svc"; then
        warn "${svc} enabled but not running"
    else
        fail "${svc} not found/enabled"
    fi
done

echo ""

# --- fcron ---
echo "Scheduled tasks:"
if command -v fcrontab &>/dev/null; then
    count=$(fcrontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | grep -cv '^[A-Z]' || echo 0)
    if [ "$count" -gt 15 ]; then
        pass "fcrontab has ${count} jobs"
    else
        warn "fcrontab only has ${count} jobs (expected ~22)"
    fi
else
    fail "fcrontab not found"
fi

echo ""

# --- Blog ---
echo "Blog build:"
if command -v jekyll &>/dev/null; then
    pass "jekyll installed"
else
    fail "jekyll not found"
fi

if [ -d "/home/operator/substrate/_posts" ]; then
    count=$(ls /home/operator/substrate/_posts/*.md 2>/dev/null | wc -l)
    pass "blog posts present (${count} posts)"
else
    fail "blog posts directory missing"
fi

echo ""

# --- Git ---
echo "Git:"
if git -C /home/operator/substrate remote -v 2>/dev/null | grep -q "github.com"; then
    pass "git remote configured"
else
    fail "git remote not pointing to GitHub"
fi

if git -C /home/operator/substrate push --dry-run origin master &>/dev/null; then
    pass "git push works (dry-run)"
else
    warn "git push failed — check SSH keys"
fi

echo ""

# --- Desktop ---
echo "Desktop:"
if command -v godot4 &>/dev/null; then
    pass "godot4 installed"
else
    warn "godot4 not found"
fi

if command -v lightdm &>/dev/null; then
    pass "lightdm installed"
else
    warn "lightdm not found"
fi

if pgrep -x Xorg &>/dev/null || pgrep -x X &>/dev/null; then
    pass "X11 running"
else
    warn "X11 not running (may be normal if checking via SSH)"
fi

echo ""

# --- Audio ---
echo "Audio:"
if command -v pw-cli &>/dev/null; then
    pass "pipewire installed"
else
    warn "pipewire not found"
fi

if command -v mpd &>/dev/null; then
    pass "mpd installed"
else
    warn "mpd not found"
fi

echo ""

# --- Network ---
echo "Network:"
if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q "wifi:connected"; then
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
    pass "WiFi connected (${ssid})"
else
    warn "WiFi not connected"
fi

if ping -c1 -W3 github.com &>/dev/null; then
    pass "Internet reachable"
else
    fail "No internet connectivity"
fi

echo ""

# --- BTRFS ---
echo "Filesystem:"
if btrfs subvolume list / &>/dev/null; then
    subs=$(btrfs subvolume list / 2>/dev/null | wc -l)
    pass "BTRFS subvolumes present (${subs})"

    for sub in @ @home @snapshots @var_log; do
        if btrfs subvolume list / 2>/dev/null | grep -q "$sub"; then
            pass "  subvolume ${sub} exists"
        else
            fail "  subvolume ${sub} missing"
        fi
    done
else
    fail "BTRFS not detected on /"
fi

if command -v snapper &>/dev/null; then
    snap_count=$(snapper list 2>/dev/null | wc -l || echo 0)
    pass "snapper installed (${snap_count} snapshots)"
else
    warn "snapper not installed"
fi

echo ""

# --- Summary ---
echo "====================================="
echo "  Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
echo "====================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Fix failures before considering migration complete."
    exit 1
fi

if [ "$WARN" -gt 0 ]; then
    echo ""
    echo "Warnings are non-critical but should be addressed."
fi

exit 0
