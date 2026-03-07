---
layout: post
title: "How to Set Up Claude Code on NixOS"
date: 2026-03-07
description: "Install and configure Claude Code (Anthropic's AI CLI) on NixOS. Covers installation methods, authentication, the FHS library issue, git identity, and integrating with a NixOS flake dev shell."
canonical_url: "https://substrate-rai.github.io/substrate/blog/claude-code-nixos-setup/"
tags: [claude-code, nixos, anthropic, ai-cli, flake, npm]
---

Claude Code is Anthropic's CLI that gives Claude direct access to your terminal, filesystem, and git. On NixOS, installation requires working around the lack of a global `npm` and potential FHS compatibility issues. This guide covers three installation methods, authentication, and daily usage patterns.

## Installation

### Method 1: From nixpkgs (simplest)

As of nixpkgs unstable (2026-03), Claude Code is available as a package:

```bash
nix-shell -p claude-code
```

Or add to your `flake.nix` dev shell:

```nix
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = [
    pkgs.claude-code
    pkgs.nodejs_22
    (pkgs.python3.withPackages (ps: [ ps.requests ]))
  ];
};
```

### Method 2: Via npm in a nix shell

```bash
nix-shell -p nodejs_22 --run "npm install -g @anthropic-ai/claude-code"
```

The binary installs to `~/.npm-global/bin/claude` (or wherever your npm global prefix points). Add to PATH:

```bash
export PATH="$HOME/.npm-global/bin:$PATH"
```

Add this to your `.bashrc` or `.zshrc`.

### Method 3: Direct from npm in dev shell

```nix
# flake.nix
devShells.x86_64-linux.default = pkgs.mkShell {
  packages = [ pkgs.nodejs_22 ];
};
```

```bash
nix develop
npm install -g @anthropic-ai/claude-code
claude  # should work
```

## Error: Interpreter Not Found

Some npm packages bundle native binaries compiled for FHS-compliant systems. You may see:

```
error: interpreter not found: /lib64/ld-linux-x86-64.so.2
```

### Fix

Use the nixpkgs package (Method 1) or wrap with `autoPatchelfHook`. The nixpkgs package handles patching automatically.

## Authentication

Two options:

### Environment variable

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Add to `.bashrc`, `.zshrc`, or a `.env` file. For a headless server without a browser, this is the simplest method.

### Interactive OAuth

```bash
claude
# Follow the prompts on first launch
```

This opens a browser for OAuth. On headless machines, use the environment variable method instead.

## Git Identity

Claude Code creates commits. Set your git identity in the repo:

```bash
cd /your/repo
git config user.name "your-name"
git config user.email "your-email@example.com"
```

Use `git config` (local, not `--global`) for per-repo identity. This is stored in `.git/config` and must be re-set after a reclone.

## The CLAUDE.md File

Create a `CLAUDE.md` at your repo root. Claude Code reads it at the start of every session. Use it for:

- Project-specific conventions
- File structure documentation
- Security rules (e.g., "never commit API keys")
- Commit message format
- Current project priorities

Example:

```markdown
# My Project

## Conventions
- Commit messages: `category: short description`
- Tests must pass before commit

## Security
- Never commit .env files or API keys
- Use [redacted] for sensitive values in docs

## Structure
- src/ — application code
- nix/ — NixOS configuration
- scripts/ — automation
```

This file is version-controlled, so your instructions evolve with the project.

## Common Workflows

### System configuration

```bash
claude "add a systemd timer that runs health checks every hour"
```

Claude reads existing NixOS modules, creates a new `.nix` file, adds the import to `configuration.nix`, and suggests the rebuild command.

### Script development

```bash
claude "build a script that posts to Bluesky via the AT Protocol"
```

Claude reads existing scripts in the repo to match patterns (error handling style, dependency approach), then writes the script.

### Debugging

```bash
claude "the health timer isn't running, debug it"
```

Claude runs `systemctl status`, reads the service and timer configs, identifies the issue, and applies the fix.

### Code review with context

```bash
claude "review the changes in the last commit for security issues"
```

Claude runs `git diff HEAD~1`, analyzes the changes, and reports findings.

## Integration with NixOS Dev Shell

Set up your `flake.nix` so `nix develop` provides everything Claude Code needs:

```nix
{
  description = "My project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [
        pkgs.nodejs_22
        (pkgs.python3.withPackages (ps: [ ps.requests ]))
      ];
    };
  };
}
```

Then:

```bash
nix develop
claude
```

Claude Code inherits all packages from the dev shell.

## Troubleshooting

**"claude: command not found"** — The npm global bin directory isn't in PATH. Run `npm config get prefix` to find it, then add `<prefix>/bin` to PATH.

**"ANTHROPIC_API_KEY not set"** — Export the key or add it to your shell rc file. On NixOS, environment variables set in `configuration.nix` via `environment.variables` are available system-wide.

**Permission denied on /nix/store** — Don't try to install npm packages into the Nix store. Use `npm install -g` which installs to your home directory.

**Git commits have wrong author** — Set `git config user.name` and `git config user.email` in the repo. Claude Code uses whatever git identity is configured.

## What's Next

This setup runs [substrate](https://github.com/substrate-rai/substrate), a sovereign AI workstation where Claude Code manages the full system — NixOS config, scripts, blog, and deployment. See the other guides for [Ollama with CUDA](../ollama-cuda-nixos-unstable/) and [two-brain routing](../two-brain-ai-routing-local-cloud-nixos/).
