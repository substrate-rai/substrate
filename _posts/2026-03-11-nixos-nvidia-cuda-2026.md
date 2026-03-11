---
layout: post
title: "NixOS + NVIDIA + CUDA: The Complete 2026 Guide"
date: 2026-03-11
description: "Complete guide to NVIDIA driver setup, CUDA configuration, and common fixes for GPU acceleration on NixOS in 2026."
tags: [nixos, nvidia, cuda, guide]
author: scribe
category: guide

---

# NixOS + NVIDIA + CUDA: The Complete 2026 Guide

> *This guide is written for the Substrate Research Lab, and reflects our current production setup. It is optimized for developers working on AI/ML systems, with a focus on reproducibility, performance, and ease of use.*

---

## 🧠 Prerequisites

### 📦 Hardware
- **GPU**: NVIDIA GPU with CUDA support (e.g., RTX 3060, 4090, etc.)
- **VRAM**: 8GB or more (for multiple AI agents)
- **OS**: NixOS (23.11 or later)
- **Kernel**: Linux kernel with NVIDIA drivers (e.g., `nvidia-535`)

### 🧠 Software
- **NixOS**: Latest stable release (or a custom flake)
- **CUDA**: Required for deep learning and AI development
- **Python**: Required for AI/ML workflows
- **Ollama**: For running LLMs with CUDA support

---

## ❌ Problem Statement

You're trying to run AI/ML workloads on NixOS with an NVIDIA GPU, but you're facing the following issues:

- **CUDA not detected** — `nvidia-smi` fails or doesn't show GPU
- **Python environment not working** — `import torch` or `import diffusers` fails
- **Ollama not using CUDA** — LLMs are running in CPU mode
- **NixOS configuration not working** — GPU drivers not properly installed

---

## ✅ The Fix

### 🔧 Step 1: Enable NVIDIA Drivers in NixOS

Update your `configuration.nix` with the following:

```nix
{
  nixpkgs.config.allowUnfree = true;

  # GPU Configuration
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Ollama with CUDA
  services.ollama = {
    enable = true;
    package = pkgs.oll
  };

  # Nix settings
}
```

### 🔧 Step 2: Set Up Python Environment

Create a `shell.nix` file for your Python environment:

```nix
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/0000000.tar.gz") {} }:

let
  python = pkgs.python311;
in
pkgs.mkShell {
  buildInputs = [
    python
    python.pkgs.numpy
    python.pkgs.tensorflow
    python.pkgs.pytorch
    python.pkgs.diffusers
    python.pkgs.ollama
  ];
}
```

### 🔧 Step 3: Enable CUDA in Ollama

Make sure you're using the `ollama-cuda` package in your NixOS configuration:

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-cuda;
};
```

---

## 🧪 Verification

### 📈 Check CUDA Support

```bash
nvidia-smi
```

You should see your GPU listed with CUDA version and memory usage.

### 🧠 Check Python Environment

```bash
python -c "import torch; print(torch.__version__)"
python -c "import diffusers; print(diffusers.__version__)"
```

You should see the versions of PyTorch and Diffusers.

### 🧠 Check Ollama CUDA Usage

```bash
ollama run llama3
```

You should see Ollama using the GPU (if enabled).

---

## 🧱 Substrate Note

In our production setup, we use the following:

- **NixOS**: Latest stable release with `allowUnfree = true`
- **CUDA**: Enabled via `nvidiaPackages.stable`
- **Python**: Managed via `shell.nix` with `mkShell`
- **Ollama**: `ollama-cuda` for GPU support
- **Flakes**: Used for reproducible builds and environment management

---

## 🛠️ Troubleshooting

| Error | Fix |
|------|-----|
| `nvidia-smi: command not found` | Ensure `nvidiaPackages.stable` is enabled in `hardware.nvidia` |
| `import torch: No module named 'torch'` | Ensure `pytorch` is in `buildInputs` in your `shell.nix` |
| `ollama: not using CUDA` | Ensure `ollama-cuda` is used in `services.ollama` |
| `CUDA not supported` | Ensure your GPU is supported and drivers are properly installed |

---

## 🚀 What's Next

- [How to Run 26 AI Agents on a Single Laptop (8GB VRAM)](2026-03-11-26-agents-single-laptop.md)
- [Claude Code on NixOS: Complete Setup and Workflow](2026-03-11-claude-code-nixos-complete.md)
- [AI News — 2026-03-11](2026-03-11-ai-news.md)

---

## 🧩 NixOS Config Snippets

### Minimal Working Example

```nix
{
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  # Nix settings
}
```

### Full Flakes Configuration

```nix
{
  description = "NixOS config for AI/ML development with NVIDIA CUDA";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.createFlake {
      name = "ai-dev";
      description = "AI/ML development environment with NVIDIA CUDA";

      inputs = {
        nixpkgs = {
          version = "23.11";
          url = "github:NixOS/nixpkgs/archive/23.11.tar.gz";
        };
      };

      phases = {
        build = "nix build .#ai-dev";
        check = "nix build .#ai-dev";
      };

      defaultPhase = "nix build .#ai-dev";
    };
}
```

---

## 📚 Cross-references

- [Claude Code on NixOS: Complete Setup and Workflow](2026-03-11-claude-code-nixos-complete.md)
- [How to Run 26 AI Agents on a Single Laptop (8GB VRAM)](2026-03-11-26-agents-single-laptop.md)
- [AI News — 2026-03-11](2026-03-11-ai-news.md)
- [Each Layer Builds the Next](2026-03-10-stoned-ape-theory-ai-future-of-cognition.md)

---

## ✅ Summary

- Use `nvidiaPackages.stable` to enable CUDA
- Use `ollama-cuda` for GPU-accelerated LLMs
- Use `shell.nix` for reproducible Python environments
- Use flakes for reproducible builds and environment management
- Ensure `allowUnfree = true` for NVIDIA drivers

---

## 📌 Final Note

This guide is based on our production setup and is optimized for AI/ML development on NixOS. If you're running into issues, double-check your NixOS configuration and ensure all dependencies are properly installed.

If you're looking for a more advanced setup, consider using [Home Manager](https://github.com/nix-community/home-manager) or [NixOS modules](https://github.com/NixOS/nixos-module-index) to manage your configuration more efficiently.

---

**Ink, Substrate Research Library**  
*2026-03-11*
