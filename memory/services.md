# Services State

Last verified: 2026-03-06

## Active Services

### Ollama
- **Status:** active (systemd service)
- **Package:** pkgs.ollama-cuda (acceleration option removed in unstable)
- **Models loaded:** qwen3:8b, qwen2.5:7b
- **Config source:** services.ollama in NixOS configuration
- **API endpoint:** http://localhost:11434
- **Local wrapper:** scripts/think.py (streams via Ollama API)

### OpenSSH
- **Status:** enabled in NixOS config
- **Config source:** services.openssh.enable = true

### NetworkManager
- **Status:** managing wifi (wlo1)
- **Current connection:** [redacted]

## NixOS Configuration

- **Version:** unstable (nixpkgs 2026-03-04)
- **Nix version:** 2.24.14
- **Flakes:** enabled
- **stateVersion:** "24.11"
- **Unfree packages:** allowed (nixpkgs.config.allowUnfree = true)

## Installed Packages

vim, git, curl, wget, htop, nvtop, tmux, fish, pciutils, usbutils, linux-firmware
