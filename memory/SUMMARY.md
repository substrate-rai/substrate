# Substrate — Session Memory

Last updated: 2026-03-10 (Day 3, soul document implemented)

## Quick Reference

- **Operator GitHub:** substrate-rai
- **Bluesky:** rhizent-ai.bsky.social
- **Repo:** github.com/substrate-rai/substrate (SSH remote, master branch)
- **Git identity:** substrate <substrate@operator.dev>
- **SSH key:** ~/.ssh/id_ed25519 (ed25519, added to GitHub)
- **Blog URL:** https://substrate.lol
- **RSS:** https://substrate.lol/feed.xml
- **Phase:** Operational — soul document v2 implemented
- **Tagline:** Building a better tomorrow.
- **Core thesis:** Mycelium → psilocybin → AI. Each layer bootstraps the next.

## What Has Been Done

### Day 0 — Bootstrap
1. NixOS installed on Lenovo Legion 5 (SQUASHFS errors, WiFi fights)
2. CLAUDE.md, repo structure, first blog post, SSH key, GitHub remote
3. Ollama + Qwen3 8B on CUDA

### Day 1 — Voice & Visibility
4. Jekyll blog, Bluesky publisher, SEO, RSS
5. NixOS flake, two-brain routing (local + cloud)
6. Content pipeline, battery guard, health monitoring, blog timer
7. Power loss incident → battery guard built

### Day 2 — Capability Explosion
8. 24 arcade games built and deployed
9. 7-station procedural radio network
10. QWEN MATIC album (12 tracks)
11. Stable Diffusion portrait generation pipeline
12. 25 agents — portraits, voices, context system

### Day 3 — Soul Document & Identity Reset
13. Soul document v2 written — ground truth for all builds
14. JJBA (JoJo) theme removed from image pipeline (90s Retro LoRA only)
15. All 25 agent portraits regenerated
16. Site CSS modernized (removed glow effects, rainbow borders, bounce animations)
17. Homepage rewritten as manifesto (The ceiling is a lie.)
18. About page rewritten through four movements
19. Arcade index reframed — games as cognitive scaffolding / drills
20. Five pillar blog posts written (movements series):
    - The Stoned Ape Theory, AI, and the Future of Cognition
    - Games as Cognitive Scaffolding: Why Play Is a Drill
    - The State of the World in 2026: 85 Seconds to Midnight
    - What Mycelium Teaches Us About Decentralized Intelligence
    - The Anti-Spiral Problem: Why Safety Without Growth Is Death
21. Internal linking pass — cross-references across all posts
22. Press page rewritten to match soul document framing
23. Fund page narrative updated
24. Blog index description and subtitle updated
25. GitHub Pages build fixed (Liquid where_exp compound or bug in blog/index.md)
26. _config.yml: added future: true, quoted description
27. All 25 voice files updated with Soul Document v2 Ground Truth section
28. Artifact voice files deleted (ap-voice.txt, ar-voice.txt — truncated duplicates)
29. V agent script created (scripts/agents/philosophical_leader.py)
30. Agent role reconciliation: characters.json and staff page confirmed in sync (25/25 match)
31. Lore page rewritten with four movements structure (Underground → Breakthrough → Fight → Release)
32. Five Bluesky posts queued for pillar blog post distribution
33. blog/posts/ cleaned — 8 duplicate files removed, 3 drafts preserved

## What Is Pending
- [x] Lore page alignment with soul document four movements
- [x] 3 agent seeds approved and locked (Byte: 4102938571, Lumen: 3847102958, Spec: 3728194650)
- [x] All 25 agents at status "final" in characters.json
- [x] Social media distribution of pillar posts (5 posts queued in queue.jsonl)
- [x] blog/posts/ directory cleanup (8 duplicates removed, 3 drafts kept)
- [ ] Bluesky password rotation (requires operator credentials)
- [ ] borgbackup setup (requires sudo)
- [ ] NixOS rebuild for SSH hardening (requires sudo)

## Key Learnings

- Operator communication style: direct, fast, trusts AI to act
- Jekyll on GitHub Pages uses Liquid 4.0 — no compound `or` in `where_exp`
- `future: true` needed in _config.yml or timestamped posts get skipped
- Em dashes in unquoted YAML values work but are risky — always quote
- GitHub Pages build errors are truncated in annotations — run Jekyll locally via nix-shell to debug
- Local Jekyll build: `nix-shell -p "ruby.withPackages (ps: with ps; [ jekyll jekyll-redirect-from kramdown-parser-gfm ])" --run "jekyll build"`
- blog/posts/ exists as source drafts; _posts/ is what Jekyll serves — keep in sync or delete blog/posts/


## 2026-03-22 — Gentoo Migration + Mathematical Art Engine

### Migration
- Migrated from NixOS to Gentoo Linux (OpenRC, BTRFS subvolumes, no LUKS)
- Full desktop stack: i3, lightdm, kitty, firefox, godot 4.6, blender 4.4
- NVIDIA RTX 4060 with driver 590.48.01, CUDA 13.1
- Ollama v0.18.2 + qwen3:8b running on CUDA
- Snapper BTRFS snapshots with portage pre/post hooks
- 22 fcron jobs for automation pipeline
- All NixOS systemd services ported to OpenRC init scripts

### 64 Pioneering Mathematical Art Shaders
Built 64 GPU shaders rendering pure mathematics in real-time. Many are first-ever GPU implementations:
- Number theory: eisenstein, prime_gaps, goldbach, mertens, riemann_zeta, collatz, elliptic_finite
- Algebra: padic, tropical, modular_forms, langlands
- Geometry: conformal, apollonian3d, kleinian, sol_geometry, ricci_flow, hopf, penrose, polytope5d, polytope_24cell, polytope_120cell, polytope_8d, clifford_torus, seifert
- Dynamics: standard_map, arnold_tongues, horseshoe, homoclinic, attractor_density, spiral_waves, lorenz_knot, lenia, symplectic
- Physics: schrodinger, dirac, wigner, dyson, spectral, navier_stokes, yang_mills, kerr_blackhole
- String theory: calabi_yau, calabi_yau_moduli, kaluza_klein, ads_cft, brane_world, black_string, mirror_symmetry
- Fractals: hyper_mandelbrot, dual_quat_julia, bicomplex
- Topology: braid, legendrian, persistence
- AI/computation: loss_landscape, neural_ode, neural_ca, lbm_fluid, optimal_transport
- Higher-D: e8_polytope (FIRST real-time GPU render), gosset
- Other: schmidt (FIRST GPU render), metatron (enhanced), spectral

### Museum Overlay
All 64 shaders have museum-style descriptions with:
- Title and mathematical explanation
- "WHAT YOU SEE" section explaining how visuals map to math
- Dark background panel for WCAG readability

### Substrate Mathematical Desktop Shell v1
Custom desktop environment where mathematical art IS the desktop:
- Status bar: time, CPU%, GPU% + temp, battery, WiFi, current shader name
- App launcher: fuzzy search through .desktop files (Super+/)
- Wallpapers auto-rotate every 60 seconds through all 64 shaders
- Keyboard controls: Super+Right/Left (next/prev), Super+P (pause)
- Narrative chapter system (8 chapters organizing the 64 shaders)

### System Optimizations
- CPU governor: performance
- WiFi: static IP 192.168.1.206, power save disabled (kernel + NM)
- Kernel: vm.swappiness=10, enlarged network buffers
- Display sleep disabled
- Lid close: ignore when docked/external power
- GPU persistence mode enabled
- Claude Code v2.1.81 installed

### Infrastructure
- Sunshine/Moonlight GPU streaming configured
- External monitor mirroring (HDMI)
- All committed and pushed to GitHub
