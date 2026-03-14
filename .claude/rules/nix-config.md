---
globs: ["nix/**", "flake.nix", "flake.lock"]
---

# NixOS Conventions

- NixOS configuration is the single source of truth for system state.
- Python3 is NOT in system PATH — use `nix develop` or full nix store path.
- Dev shell (`flake.nix`) provides python3 + requests.
- Never inline secrets in Nix config — use agenix or sops-nix.
- `nix/configuration.nix` imports: battery-guard.nix, health-check.nix, daily-blog.nix, feedback-loop.nix
- After changes: `sudo nixos-rebuild switch --flake .#substrate`
