# Claude Code Remote Control on NixOS: Node 24 Bug
## Problem
`claude remote-control` fails with:
`nodejs-slim-24.13.0/bin/node: bad option; --sdk-url`
## Cause
Node 24 (slim) in nixpkgs unstable treats `--sdk-url` as a Node runtime flag.
## Fix
1. `nix profile remove claude-code`
2. `nix profile install nixpkgs#nodejs_22`
3. `nix-shell -p nodejs_22 --run "npm install -g @anthropic-ai/claude-code --prefix ~/.npm-global"`
4. `export PATH="$HOME/.npm-global/bin:$PATH"` (add to ~/.bashrc)
## Versions
Claude Code 2.1.71 / nodejs_22 (22.22.0) / broken: nodejs-slim-24.13.0 / NixOS unstable 26.05
