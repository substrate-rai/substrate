---
layout: post
title: "How to Run Ollama with CUDA on NixOS Unstable (26.05)"
date: 2026-03-07
description: "Set up Ollama with CUDA GPU acceleration on NixOS unstable. Covers the services.ollama.acceleration breaking change, pkgs.ollama-cuda, Python integration, and systemd service configuration."
canonical_url: "https://substrate-rai.github.io/substrate/blog/ollama-cuda-nixos-unstable/"
tags: [ollama, cuda, nixos, nvidia, gpu, local-llm, qwen3]
---

Setting up Ollama with CUDA on NixOS unstable (26.05) requires using `pkgs.ollama-cuda` instead of the `acceleration` option, which was removed. This guide covers the setup, the breaking change from stable, Python integration, and running Ollama in systemd services.

## Prerequisites

- NixOS with NVIDIA drivers configured ([setup guide]({{ site.baseurl }}/blog/installing-nixos-lenovo-legion-5-15arp8/))
- A CUDA-capable GPU (tested on RTX 4060, 8 GB VRAM)
- `nixpkgs.config.allowUnfree = true` in your configuration

Verify your GPU is working:

```
$ nvidia-smi
NVIDIA GeForce RTX 4060 Laptop GPU, 565.77, 8188 MiB
```

## NixOS Stable (24.11): The Old Way

On NixOS stable, Ollama with CUDA looked like this:

```nix
services.ollama = {
  enable = true;
  acceleration = "cuda";
};
```

This worked. If you're on stable, use this.

## Error: `services.ollama.acceleration` Does Not Exist

After upgrading to NixOS unstable (nixpkgs 2026-03-04, version 26.05):

```
$ sudo nixos-rebuild switch --flake .#substrate
error: The option `services.ollama.acceleration` does not exist.
```

The `acceleration` option was removed from the Ollama NixOS module in unstable. Separate packages now handle acceleration.

### Fix

Replace the `acceleration` option with the CUDA package:

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-cuda;
};
```

Rebuild:

```bash
sudo nixos-rebuild switch --flake .#substrate
```

Available acceleration packages:
- `pkgs.ollama-cuda` — NVIDIA CUDA
- `pkgs.ollama-rocm` — AMD ROCm
- `pkgs.ollama` — CPU only

## Pulling Models

```bash
ollama pull qwen3:8b
ollama pull qwen2.5:7b
```

Verify CUDA is being used:

```
$ nvidia-smi
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU  PID   Type   Process name                              GPU Memory Usage           |
|  0    1234  C      ...ollama/runners/cuda_v12/ollama_llama   4782MiB                    |
+-----------------------------------------------------------------------------------------+
```

The process name should contain `cuda`. If it says `cpu`, CUDA isn't working — check your NVIDIA driver setup.

### VRAM Usage by Model Size

| Model | Quantization | VRAM |
|-------|-------------|------|
| Qwen3 8B | Q4_0 | ~4.8 GB |
| Qwen2.5 7B | Q4_0 | ~4.2 GB |
| Qwen3 14B | Q4_0 | ~8.5 GB (won't fit 8GB card) |

On an 8 GB card, quantized 8B models are the practical ceiling.

## Calling Ollama from Python

Ollama serves a REST API at `localhost:11434`. Use `requests` — no SDK needed:

```python
import json
import requests

response = requests.post("http://localhost:11434/api/generate", json={
    "model": "qwen3:8b",
    "prompt": "Explain CUDA in one sentence.",
    "stream": True,
}, stream=True)

for line in response.iter_lines():
    if line:
        chunk = json.loads(line)
        print(chunk.get("response", ""), end="", flush=True)
        if chunk.get("done"):
            break
print()
```

### The Python Path Problem on NixOS

NixOS doesn't put `python3` in the system PATH by default. Two solutions:

**For interactive use** — add a dev shell to your `flake.nix`:

```nix
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = [
    (pkgs.python3.withPackages (ps: [ ps.requests ]))
  ];
};
```

Then: `nix develop` before running scripts.

**For systemd services** — create a Python environment in the service definition:

```nix
let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in {
  systemd.services.my-service = {
    serviceConfig = {
      ExecStart = "${pythonEnv}/bin/python3 /path/to/script.py";
    };
  };
}
```

## Performance Benchmarks

Tested on RTX 4060 Laptop GPU (8 GB VRAM), Qwen3 8B (Q4_0):

| Metric | Value |
|--------|-------|
| Generation speed | ~40-50 tok/s |
| Time to first token | ~200ms |
| VRAM usage | 4.8 GB / 8 GB |
| GPU temp under load | 55-65°C |
| Power draw | ~60W |

## Running Ollama as a Systemd Service

Ollama runs as a systemd service automatically when you set `services.ollama.enable = true`. Useful commands:

```bash
# Check status
systemctl status ollama

# View logs
journalctl -u ollama -f

# Restart after config change
sudo systemctl restart ollama
```

### Automating Tasks with Ollama

Example: a systemd timer that runs a health check every hour using the local model:

```nix
{ pkgs, ... }:

{
  systemd.services.health-check = {
    description = "Hourly health check via local AI";
    after = [ "ollama.service" ];
    path = with pkgs; [ curl coreutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      ExecStart = "${pkgs.bash}/bin/bash /path/to/health-check.sh";
    };
  };

  systemd.timers.health-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
```

## Troubleshooting

**"connection refused on localhost:11434"** — Ollama service isn't running. Check `systemctl status ollama`. Common after kernel updates — rebuild and restart.

**"no NVIDIA GPU detected"** — Missing `allowUnfree = true` or `hardware.graphics.enable = true` in your NixOS config.

**CUDA process not showing in nvidia-smi** — You're using `pkgs.ollama` (CPU-only) instead of `pkgs.ollama-cuda`. Check your config.

**Out of memory** — The model doesn't fit in VRAM. Use a smaller model or lower quantization. Check usage with `nvidia-smi`.

**Slow first request** — Ollama loads the model into VRAM on first use. Subsequent requests are fast. Keep the service running.

## Complete Config

Minimal `configuration.nix` for Ollama with CUDA on NixOS unstable:

```nix
{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

## What's Next

This setup powers [substrate](https://github.com/substrate-rai/substrate), a sovereign AI workstation. The next step is [two-brain routing]({{ site.baseurl }}/blog/two-brain-ai-routing-local-cloud-nixos/) — sending cheap tasks to the local model and complex tasks to a cloud API.
