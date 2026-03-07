# Stable Diffusion on NixOS (RTX 4060, 8GB VRAM)

Practical guide for running local image generation on the Substrate workstation.

## 1. Model Selection for 8GB VRAM

### Recommended: SD 1.5 and SDXL (with optimizations)

| Model | Base VRAM | With --medvram | Quality | Speed (4060) |
|-------|-----------|----------------|---------|---------------|
| SD 1.5 | ~4 GB | ~3 GB | Good | ~3-5s/image (512x512) |
| SDXL 1.0 | ~7 GB | ~5 GB | Excellent | ~10-20s/image (1024x1024) |
| SDXL Turbo | ~7 GB | ~5 GB | Good | ~2-4s/image (512x512) |
| Flux.1 Dev | ~12 GB | ~8-10 GB | Best | Too slow / OOM risk |
| Flux.1 Schnell | ~10 GB | ~7-8 GB | Very Good | Marginal, risky |

**Best choices for 8GB:**

- **SD 1.5** -- Runs comfortably with plenty of VRAM headroom. Huge ecosystem of fine-tuned models (Realistic Vision, DreamShaper, etc.) and LoRAs. Best if you want to run alongside Ollama.
- **SDXL 1.0** -- Runs on 8GB with `--medvram` or fp16. Noticeably better quality than SD 1.5. Will consume most/all VRAM, so Ollama must be idle.
- **SDXL Turbo / Lightning** -- Fast SDXL variants, fewer steps needed (1-4 vs 20-30). Same VRAM as SDXL but much faster.

**Avoid on 8GB:**
- **Flux** -- The smallest variant (Schnell) needs ~10GB minimum. Even with quantization, it is marginal on 8GB and will be very slow with offloading.
- **SD 3.x** -- Similar VRAM demands to Flux, poor community support.

### Practical recommendation

Start with **SD 1.5** (e.g., Realistic Vision v5.1 or DreamShaper v8) for reliability and Ollama coexistence. Upgrade to **SDXL** when you need higher quality and can afford to stop Ollama temporarily.

## 2. Interface Selection

### Recommended: ComfyUI

| Interface | Pros | Cons |
|-----------|------|------|
| **ComfyUI** | Node-based, memory efficient, modern, active development, good SDXL support | Learning curve for node graphs |
| AUTOMATIC1111 | Most popular, huge extension ecosystem | Heavy, slower development, higher VRAM overhead |
| SD.Next / Forge | Fork of A1111, better VRAM management | Still heavier than ComfyUI |
| Python diffusers | Maximum control, scriptable | No UI, more manual work |

**ComfyUI is the best choice** because:
1. Most memory-efficient of the GUI options (critical for 8GB)
2. Actively maintained with fast support for new models
3. Node-based workflow is powerful once learned
4. Has a NixOS packaging path (see below)
5. Can be scripted via its API for automation (useful for Substrate's pipeline)

## 3. NixOS Installation Approaches

### Option A: nixpkgs package (if available)

As of early 2026, ComfyUI and AUTOMATIC1111 have been packaged in nixpkgs, though packaging status changes frequently. Check availability:

```bash
nix search nixpkgs comfyui
nix search nixpkgs stable-diffusion
nix search nixpkgs invokeai
```

Known packages that have existed in nixpkgs:
- `comfyui` -- ComfyUI with CUDA support
- `stable-diffusion-cpp` -- C++ inference engine (llama.cpp-style, very efficient)
- `invokeai` -- InvokeAI (another SD frontend)

### Option B: Flake-based ComfyUI (recommended approach)

The most reliable NixOS approach is a flake that wraps ComfyUI with its Python dependencies and CUDA:

```nix
# flake.nix addition or separate flake
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
      };
    };
  in {
    # Dev shell for running ComfyUI
    devShells.${system}.comfyui = pkgs.mkShell {
      buildInputs = with pkgs; [
        (python3.withPackages (ps: with ps; [
          torch
          torchvision
          torchaudio
          torchsde
          einops
          transformers
          safetensors
          accelerate
          aiohttp
          yarl
          requests
          pyyaml
          pillow
          scipy
          tqdm
          psutil
          kornia
        ]))
        git
      ];

      shellHook = ''
        export CUDA_PATH=${pkgs.cudatoolkit}
        export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
          pkgs.cudatoolkit
          pkgs.cudnn
          pkgs.stdenv.cc.cc.lib
        ]}:$LD_LIBRARY_PATH

        if [ ! -d "$HOME/ComfyUI" ]; then
          echo "Clone ComfyUI first: git clone https://github.com/comfyanonymous/ComfyUI ~/ComfyUI"
        fi
        echo "Run with: cd ~/ComfyUI && python main.py --lowvram"
      '';
    };
  };
}
```

### Option C: OCI container (Docker/Podman)

NixOS can run containers. This avoids all packaging headaches:

```nix
# In nix/configuration.nix
virtualisation.podman.enable = true;
virtualisation.podman.dockerCompat = true;

# Enable NVIDIA container runtime
hardware.nvidia-container-toolkit.enable = true;
```

Then run a pre-built ComfyUI container:

```bash
podman run --rm -it \
  --gpus all \
  -p 8188:8188 \
  -v ~/comfyui-data/models:/app/models \
  -v ~/comfyui-data/output:/app/output \
  ghcr.io/ai-dock/comfyui:latest
```

**This is the path of least resistance on NixOS.** The Python dependency hell is pre-solved in the container.

### Option D: stable-diffusion.cpp

If you want minimal overhead and just need image generation (no complex UI):

```bash
nix search nixpkgs stable-diffusion-cpp
```

`stable-diffusion.cpp` is a C++ implementation (like llama.cpp for LLMs) that:
- Has minimal dependencies (easy to package for Nix)
- Supports SD 1.5, SDXL, and SD3 with CUDA
- Uses ~2-4GB VRAM for SD 1.5
- Can coexist with Ollama easily
- Has a simple CLI interface

```bash
# If packaged:
nix run nixpkgs#stable-diffusion-cpp -- \
  -m ~/models/dreamshaper-v8.safetensors \
  -p "a mountain landscape at sunset" \
  -o output.png \
  --steps 20
```

## 4. VRAM Management and Ollama Coexistence

### The core problem

The RTX 4060 has 8GB VRAM. Ollama with Qwen3 8B uses ~5-6GB when loaded. SD 1.5 uses ~4GB. They cannot run simultaneously at full capacity.

### Solutions

**Option 1: Time-sharing (recommended)**

Stop Ollama before generating images, restart after:

```bash
# Before image generation
sudo systemctl stop ollama

# Generate images...

# After done
sudo systemctl start ollama
```

Or create a script:

```bash
#!/usr/bin/env bash
# scripts/generate-image.sh
set -euo pipefail

echo "Stopping Ollama to free VRAM..."
sudo systemctl stop ollama
sleep 2

# Run SD generation
cd ~/ComfyUI && python main.py --lowvram "$@"

echo "Restarting Ollama..."
sudo systemctl start ollama
```

**Option 2: Ollama model unloading**

Ollama unloads models after a timeout (default 5 minutes). If you wait for the model to unload, both can coexist:

```bash
# Force Ollama to unload its model
curl -X DELETE http://localhost:11434/api/generate -d '{"model": "qwen3:8b", "keep_alive": 0}'
# Now VRAM is free for SD
```

**Option 3: CPU offloading for SD**

Run SD with aggressive CPU offloading (`--lowvram` or `--cpu` flags in ComfyUI). This is slower but allows coexistence:

```bash
# ComfyUI with CPU offloading
python main.py --lowvram  # Moves model parts to CPU as needed
```

With `--lowvram`, SD 1.5 uses ~1-2GB VRAM, leaving room for a loaded Ollama model.

**Option 4: Use stable-diffusion.cpp**

The C++ implementation is more memory-efficient and loads/unloads quickly, making time-sharing nearly instant.

### VRAM budget table

| Configuration | Ollama (Qwen3 8B) | SD | Total | Feasible? |
|--------------|-------------------|-----|-------|-----------|
| SD 1.5 only | - | 4 GB | 4 GB | Yes, comfortable |
| SDXL only | - | 7 GB | 7 GB | Yes, tight |
| SD 1.5 + Ollama idle | 0 GB (unloaded) | 4 GB | 4 GB | Yes |
| SD 1.5 --lowvram + Ollama loaded | 5.5 GB | 1.5 GB | 7 GB | Yes, slow SD |
| SDXL + Ollama loaded | 5.5 GB | 7 GB | 12.5 GB | No, OOM |

## 5. NixOS-Specific Gotchas

### CUDA and Python torch

The biggest pain point on NixOS. PyTorch with CUDA must be built with `cudaSupport = true` in the nixpkgs config. If using a flake:

```nix
nixpkgs.config = {
  allowUnfree = true;
  cudaSupport = true;
};
```

Without this, torch will be CPU-only and SD will be unusably slow.

### LD_LIBRARY_PATH issues

NixOS does not use `/usr/lib`. Python packages that dynamically link to CUDA libraries will fail unless `LD_LIBRARY_PATH` includes the Nix store paths for `cudatoolkit` and `cudnn`. The flake example above handles this.

### FHS environment

Some tools expect a standard Linux filesystem. If ComfyUI or extensions break due to hardcoded paths, wrap in an FHS-compatible environment:

```nix
let
  fhs = pkgs.buildFHSEnv {
    name = "comfyui-fhs";
    targetPkgs = pkgs: with pkgs; [
      python3
      python3Packages.pip
      python3Packages.virtualenv
      cudatoolkit
      cudnn
      stdenv.cc.cc.lib
      zlib
      libGL
      libGLU
      xorg.libX11
      xorg.libXext
      xorg.libXrender
    ];
    runScript = "bash";
  };
in
# Then: nix run .#comfyui-fhs
# Inside the FHS env: pip install comfyui in a venv
```

This gives you a `/usr/lib`-style environment inside Nix. **This is the most battle-tested approach** for running complex Python ML stacks on NixOS when pure Nix packaging is too fragile.

### libGL / OpenGL

Some SD dependencies need `libGL`. On NixOS, ensure:

```nix
hardware.graphics.enable = true;  # was hardware.opengl.enable before 24.11
```

This should already be set since Ollama/CUDA is working.

### Model storage

Models are large (2-7 GB each). Store them outside the Nix store:

```
~/models/
  stable-diffusion/
    sd-v1-5.safetensors          # ~4 GB
    dreamshaper-v8.safetensors   # ~2 GB
    sdxl-base-1.0.safetensors    # ~6.5 GB
  loras/
    # LoRA files, ~50-200 MB each
  vae/
    # VAE files if needed
```

Download from https://huggingface.co or https://civitai.com.

### Nix garbage collection

If you build torch with CUDA from source via Nix, the build artifacts are huge (10+ GB in the Nix store). Be mindful of disk space:

```bash
nix-collect-garbage -d  # Clean old generations
```

## 6. Recommended Setup for Substrate

Given the constraints (8GB VRAM, NixOS, coexistence with Ollama, automation potential):

### Phase 1: Quick start with containers

1. Enable Podman + NVIDIA container toolkit in `nix/configuration.nix`
2. Pull a ComfyUI container
3. Create `scripts/generate-image.sh` that stops Ollama, runs SD, restarts Ollama
4. Use SD 1.5 models initially

### Phase 2: Native Nix (if containers are too heavy)

1. Use `buildFHSEnv` to create a ComfyUI-compatible environment
2. Install ComfyUI + deps in a virtualenv inside the FHS env
3. Add a systemd service for on-demand image generation

### Phase 3: Integration with Substrate pipeline

1. ComfyUI has an HTTP API (port 8188) -- queue prompts programmatically
2. Extend `scripts/pipeline.py` to generate blog post hero images
3. Add image generation as a step in the daily blog timer

### Minimal NixOS config additions

```nix
# nix/configuration.nix additions

# For container approach
virtualisation.podman = {
  enable = true;
  dockerCompat = true;
};
hardware.nvidia-container-toolkit.enable = true;

# Alternatively, for native approach, add to the existing flake devShell
# or create a dedicated shell (see Option B above)
```

## 7. Quick Reference Commands

```bash
# Check VRAM usage
nvidia-smi

# Unload Ollama model to free VRAM
curl http://localhost:11434/api/generate -d '{"model": "qwen3:8b", "keep_alive": 0}'

# Search nixpkgs for SD-related packages
nix search nixpkgs comfyui
nix search nixpkgs stable-diffusion
nix search nixpkgs invokeai

# Run ComfyUI (after setup)
cd ~/ComfyUI && python main.py --lowvram --listen 0.0.0.0 --port 8188

# ComfyUI API: queue a prompt
curl -X POST http://localhost:8188/prompt -H 'Content-Type: application/json' -d @workflow.json
```
