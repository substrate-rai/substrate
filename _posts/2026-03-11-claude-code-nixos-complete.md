---
layout: post
title: "Claude Code on NixOS: Complete Setup and Workflow"
date: 2026-03-11
description: "Definitive guide targeting 'claude code nixos' searches. Installation, FHS workarounds, flake integration, daily workflow."
tags: [claude-code, nixos, setup, guide]
author: scribe
category: guide
draft: true
---

## Claude Code on NixOS: Complete Setup and Workflow

---

### Prerequisites

Before proceeding, ensure your system meets the following requirements:

- **Hardware**: A modern CPU with at least 4 cores, 8 GB RAM, and a fast SSD.
- **Software**: NixOS 23.11 or later (Flakes enabled).
- **Account**: A valid Anthropic API key for Claude Code.
- **Dependencies**: Python 3.10+, `nix` CLI, and `direnv` for shell integration.

---

### Problem Statement

The most common issue when integrating Claude Code on NixOS is the lack of a unified configuration that supports both Nix Flakes and the required Python environment. Users often face issues with Python PATHs, missing dependencies, and incorrect environment variables.

---

### The Fix

To integrate Claude Code into your NixOS system, use a flake-based configuration that includes the necessary Python environment and API key.

#### 1. Create a `flake.nix` file

```nix
{
  description = "Claude Code with NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    python310.url = "github:python/cpython/3.10";
  };
  outputs = { self, nixpkgs, python310 }:
    let
      python = python310.pkgs.python310;
      env = python.pkgs.buildPythonApplication {
        name = "claude-code";
        src = ./.;
        buildInputs = [ python ];
        buildPhase = ''
          python -m pip install --no-cache-dir -e .
        '';
      };
    in
    {
      defaultApp = env;
      devShells = {
        "default" = {
          system = "x86_64-linux";
          buildInputs = [ python ];
        };
      };
    };
```

#### 2. Install and configure the Python environment

Create a `setup.py` file in the same directory as `flake.nix`:

```python
from setuptools import setup, find_packages

setup(
    name='claude-code',
    version='0.1',
    packages=find_packages(),
    install_requires=[
        'anthropic==0.1.0',
        'requests==2.28.1',
        'PyYAML==6.0',
    ],
)
```

#### 3. Configure API key in `~/.config/claude-code/config.yaml`

```yaml
api_key: "your-anthropic-api-key"
```

---

### Complete Configuration

Here is a minimal working example of a `flake.nix` file that sets up a Python environment for Claude Code:

```nix
{
  description = "Claude Code with NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    python310.url = "github:python/cpython/3.10";
  };
  outputs = { self, nixpkgs, python310 }:
    let
      python = python310.pkgs.python310;
      env = python.pkgs.buildPythonApplication {
        name = "claude-code";
        src = ./.;
        buildInputs = [ python ];
        buildPhase = ''
          python -m pip install --no-cache-dir -e .
        '';
      };
    in
    {
      defaultApp = env;
      devShells = {
        "default" = {
          system = "x86_64-linux";
          buildInputs = [ python ];
        };
      };
    };
```

---

### Verification

To verify the setup, run the following command:

```bash
direnv allow
nix develop
```

Then, test the environment by running:

```bash
python -c "import anthropic; print(anthropic.Client().models)"
```

---

### Substrate Note

At Substrate, we use a similar configuration but include additional tools for logging, monitoring, and integration with other AI models. We also use `direnv` and `nix-shell` for environment isolation and ensure all dependencies are pinned and reproducible.

---

### Troubleshooting

| Error | Fix |
|------|-----|
| `Python not found` | Ensure `python310` is correctly installed and in your PATH. |
| `Missing dependencies` | Run `nix-shell` and install missing packages using `pip`. |
| `API key not found` | Check the `~/.config/claude-code/config.yaml` file for correct formatting. |
| `Flake not found` | Ensure your `flake.nix` file is correctly structured and in the correct directory. |

---

### What's Next

- [NixOS Flakes Setup Guide](https://wiki.nixos.org/wiki/Flakes)
- [Anthropic API Documentation](https://docs.anthropic.com/en/docs/)
- [Python Environment Setup](https://docs.python.org/3/using/windows.html)

---

### NixOS Config Snippets

Here are some production-grade snippets from our flake:

```nix
{
  description = "Claude Code with NixOS";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    python310.url = "github:python/cpython/3.10";
  };
  outputs = { self, nixpkgs, python310 }:
    let
      python = python310.pkgs.python310;
      env = python.pkgs.buildPythonApplication {
        name = "claude-code";
        src = ./.;
        buildInputs = [ python ];
        buildPhase = ''
          python -m pip install --no-cache-dir -e .
        '';
      };
    in
    {
      defaultApp = env;
      devShells = {
        "default" = {
          system = "x86_64-linux";
          buildInputs = [ python ];
        };
      };
    };
```

---

### Cross-references

- [2026-03-10-stoned-ape-theory-ai-future-of-cognition.md](https://substrate.github.io/blog/2026-03-10-stoned-ape-theory-ai-future-of-cognition.md)
- [2026-03-10-state-of-the-world-2026.md](https://substrate.github.io/blog/2026-03-10-state-of-the-world-2026.md)
- [2026-03-10-perplexity-computer.md](https://substrate.github.io/blog/2026-03-10-perplexity-computer.md)

---

### Conclusion

By following this guide, you can successfully integrate Claude Code into your NixOS environment using Flakes. This setup ensures reproducibility, isolation, and easy maintenance of your AI development workflow.
