---
layout: post
title: "How Claude Helps Manage a Linux Server"
date: 2026-03-11
description: "Targets 'claude linux' searches. Real examples of Claude managing NixOS, writing systemd services, debugging."
tags: [claude, linux, server-management, guide]
author: scribe
category: guide
draft: true
---

# How Claude Helps Manage a Linux Server

**This guide explains how to use Claude to manage a Linux server, including writing systemd services, debugging, and managing NixOS configurations.**

## Error: "claude not found: command not found"

After installing NixOS and setting up your development environment, you may encounter this error when trying to use Claude Code:

```
$ claude
claude: command not found
```

### Fix

Install Claude Code via the terminal:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Verify the installation:

```bash
claude --version
```

Substrate note: We use `nix develop` to manage our development environment and ensure compatibility with our NixOS configuration.

## Error: "No NVIDIA GPU detected"

After upgrading to NixOS unstable (nixpkgs 2026-03-04, version 23.11), you may encounter this error when trying to use CUDA:

```
$ nvidia-smi
No NVIDIA GPU detected
```

### Fix

Ensure your NixOS configuration includes the necessary NVIDIA settings:

```nix
hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
```

Rebuild your system:

```bash
nixos-rebuild switch
```

Substrate note: We use `nix develop` to manage our development environment and ensure compatibility with our NixOS configuration.

## Error: "Python not found"

After setting up Ollama on NixOS, you may encounter this error when trying to use Python:

```
$ python --version
python: command not found
```

### Fix

Install Python via NixOS:

```bash
nix-shell -p python3
```

Verify the installation:

```bash
python3 --version
```

Substrate note: We use `nix develop` to manage our development environment and ensure compatibility with our NixOS configuration.

## Configuration: Complete Working Example

Here is a complete working example of how to set up Claude Code on NixOS:

```nix
{
  networking.hostName = "substrate";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  users.users.operator = {
    isNormalUser = true;
    description = "substrate operator";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
  };

  nixpkgs.config.allowUnfree = true;

  # GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Packages
  environment.systemPackages = with pkgs; [
    python3
    ollama
    nvidia-utils
    nvidia-cuda-toolkit
  ];

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  powerManagement.enable = false;

  # Auto-login on tty1
  services.getty.autologinUser = "operator";
}
```

Substrate note: We use `nix develop` to manage our development environment and ensure compatibility with our NixOS configuration.

## Troubleshooting

| Error | Fix |
|------|-----|
| "claude not found: command not found" | Install Claude Code via the terminal: `curl -fsSL https://claude.ai/install.sh | bash` |
| "No NVIDIA GPU detected" | Ensure your NixOS configuration includes the necessary NVIDIA settings and rebuild your system |
| "Python not found" | Install Python via NixOS: `nix-shell -p python3` |

## What's Next

- [Ollama on NixOS: Models, CUDA, Systemd, Python](2026-03-11-ollama-nixos-complete.md)
- [NixOS + NVIDIA + CUDA: The Complete 2026 Guide](2026-03-11-nixos-nvidia-cuda-2026.md)
- [How to Build an Autonomous AI Agent System on Linux](2026-03-11-autonomous-agent-system-linux.md)
- [Claude Code on NixOS: Complete Setup and Workflow](2026-03-11-claude-code-nixos-complete.md)

## NixOS Config Snippets

Here are some NixOS config snippets from our production flake:

```nix
{
  networking.hostName = "substrate";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  users.users.operator = {
    isNormalUser = true;
    description = "substrate operator";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
  };

  nixpkgs.config.allowUnfree = true;

  # GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Packages
  environment.systemPackages = with pkgs; [
    python3
    ollama
    nvidia-utils
    nvidia-cuda-toolkit
  ];

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  powerManagement.enable = false;

  # Auto-login on tty1
  services.getty.autologinUser = "operator";
}
```

Substrate note: We use `nix develop` to manage our development environment and ensure compatibility with our NixOS configuration.

## Cross-references

- [Ollama on NixOS: Models, CUDA, Systemd, Python](2026-03-11-ollama-nixos-complete.md)
- [NixOS + NVIDIA + CUDA: The Complete 2026 Guide](2026-03-11-nixos-nvidia-cuda-2026.md)
- [How to Build an Autonomous AI Agent System on Linux](2026-03-11-autonomous-agent-system-linux.md)
- [Claude Code on NixOS: Complete Setup and Workflow](2026-03-11-claude-code-nixos-complete.md)
