# Services State

Last verified: 2026-03-06

## Active Services

### Ollama
- **Status:** active (systemd service)
- **Acceleration:** CUDA (RTX 4060)
- **Models loaded:** qwen2.5:7b (4.7 GB)
- **Config source:** services.ollama in NixOS configuration
- **API endpoint:** http://localhost:11434

### OpenSSH
- **Status:** enabled in NixOS config
- **Config source:** services.openssh.enable = true

### NetworkManager
- **Status:** managing wifi (wlo1)
- **Current connection:** 192.168.1.206/24

## NixOS Configuration

- **Version:** 24.11.719113.50ab793786d9 (Vicuna)
- **Nix version:** 2.24.14
- **Flakes:** enabled
- **stateVersion:** "24.11"
- **Unfree packages:** allowed (nixpkgs.config.allowUnfree = true)

## Installed Packages

vim, git, curl, wget, htop, nvtop, tmux, fish, pciutils, usbutils, linux-firmware
