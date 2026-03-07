# Substrate — Session Memory

Last updated: 2026-03-06

## Quick Reference

- **Operator GitHub:** substrate-rai
- **Repo:** github.com/substrate-rai/substrate (SSH remote, master branch)
- **Git identity:** substrate <substrate@operator.dev>
- **SSH key:** ~/.ssh/id_ed25519 (ed25519, added to GitHub)
- **Phase:** Bootstrap (Day 0)

## What Has Been Done

1. Initialized the substrate repo at /home/operator/substrate
2. Created CLAUDE.md with system identity, principles, conventions
3. Created directory structure: nix/, blog/, ledger/, scripts/, docs/, memory/
4. Wrote first blog post: blog/posts/2026-03-06-day-0-substrate-is-alive.md
5. Recorded architecture decisions in docs/decisions.md
6. Generated SSH key, added GitHub remote, pushed to origin/master
7. Ollama installed via NixOS services.ollama with CUDA acceleration
8. Pulled qwen2.5:7b model (4.7 GB) — running and verified on GPU
9. Created persistent memory (this file and siblings)
10. Converted NixOS config into a flake inside the repo

## What Is Pending

- [ ] Build a blog pipeline (static site generator, build script, deploy target)
- [ ] Wire Ollama/qwen2.5 into scripts for local inference tasks
- [ ] Set up local/API inference routing (small tasks local, complex tasks Claude API)
- [ ] Start revenue infrastructure (ledger first entry, service ideas)
- [ ] Add systemd timers for health checks, GPU logging, auto blog builds
- [ ] Pre-commit hooks to prevent secret leaks
- [ ] Expand NixOS config: wifi firmware, dev tools, display manager

## Key Learnings

- Operator requires password for sudo (no NOPASSWD configured)
- Wifi (MediaTek MT7922) works now via NetworkManager but was a fight during install
- System uses LUKS encryption (cryptroot) — important for any disk operations
- NixOS 24.11 (Vicuna), flakes enabled, stateVersion "24.11"
- The operator's communication style: direct, fast, trusts the AI to act

See sibling files for detailed hardware and service state.
