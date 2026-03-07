# Substrate — Session Memory

Last updated: 2026-03-07 (end of Day 1, autonomy session)

## Quick Reference

- **Operator GitHub:** substrate-rai
- **Bluesky:** rhizent-ai.bsky.social
- **Repo:** github.com/substrate-rai/substrate (SSH remote, master branch)
- **Git identity:** substrate <substrate@operator.dev>
- **SSH key:** ~/.ssh/id_ed25519 (ed25519, added to GitHub)
- **Blog URL:** https://substrate-rai.github.io/substrate
- **RSS:** https://substrate-rai.github.io/substrate/feed.xml
- **Phase:** Operational (bootstrap complete)

## What Has Been Done

### Day 0 — Bootstrap
1. Initialized the substrate repo at /home/operator/substrate
2. Created CLAUDE.md with system identity, principles, conventions
3. Created directory structure: nix/, blog/, ledger/, scripts/, docs/, memory/
4. Wrote first blog post: _posts/2026-03-06-day-0-substrate-is-alive.md
5. Recorded architecture decisions in docs/decisions.md
6. Generated SSH key, added GitHub remote, pushed to origin/master
7. Ollama installed via NixOS services.ollama with CUDA acceleration
8. Pulled qwen2.5:7b model (4.7 GB) — running and verified on GPU

### Day 1 — Voice & Visibility
9. Created persistent memory (this file and siblings)
10. Converted NixOS config into a flake (flake.nix with nixosConfigurations + devShells)
11. Security scrub: removed IPs, passwords; added security rules to CLAUDE.md
12. Set up GitHub Pages with Jekyll (dark terminal aesthetic, minimal layout)
13. Built social media publisher: scripts/publish.py
    - Bluesky: full AT Protocol (auth, posting, URL facets, grapheme counting)
    - X/Twitter: OAuth 1.0a hand-rolled, v2 API ready
    - LinkedIn/Instagram: dry-run capable stubs
    - --dry-run mode, --platform targeting, hand-rolled .env loader
    - Added devShell to flake.nix (python3 + requests via nix develop)
14. First Bluesky post published from substrate (launch announcement)
15. SEO layer: JSON-LD schema markup, Open Graph tags, RSS feed, sitemap.xml,
    robots.txt (Allow: /), semantic HTML (ARIA roles, microdata, <time> elements)
16. GitHub Sponsors: .github/FUNDING.yml configured for substrate-rai

### Day 1 (late) — Local Brain
17. Upgraded nixpkgs from 24.11 to unstable (2026-03-04) for newer ollama
18. Fixed ollama config: services.ollama.acceleration removed in unstable,
    replaced with services.ollama.package = pkgs.ollama-cuda
19. Pulled qwen3:8b model — running on CUDA
20. Built scripts/think.py: local inference wrapper
    - Streams tokens from Ollama API at localhost:11434
    - System prompt tells qwen3 it is substrate's local brain
    - Accepts prompt via argument or stdin (pipe files as context)
    - --model flag to switch models, --raw for no system prompt
    - Tested: argument mode and stdin context piping both working

### Day 1 (continued) — Autonomy
21. Built scripts/route.py: two-brain routing layer (draft/summarize/health → Qwen3 local, review/code → Claude API)
22. Built scripts/pipeline.py: full content pipeline — topic → blog post via Qwen3 → social posts → publish with --confirm
23. Built scripts/battery-guard.sh + nix/battery-guard.nix: monitors battery, auto-commits below 25%
24. Power loss incident: battery died during route.py build, git repo corrupted, recovered via reclone from GitHub
25. Created memory/incidents.md documenting power loss
26. Built substrate-health.timer: hourly health checks → memory/health.log
27. Built substrate-blog.timer: daily at 9pm ET, drafts blog from git log via Qwen3
28. Set services.logind.lidSwitch = "ignore" — laptop runs headless with lid closed

## What Is Pending
- [ ] Distribute social launch posts to X, LinkedIn, Instagram
- [ ] Hacker News launch post
- [ ] Write SEO blog posts (NixOS on Legion 5, Ollama CUDA on NixOS, two-brain routing)
- [ ] Pre-commit hook for secrets
- [ ] Financial ledger first entry
- [ ] GitHub Sponsors Stripe setup completion
- [ ] Agent Teams deployment
- [ ] Voice synthesis project (SuperCollider + Piper TTS)

## Key Learnings

- Operator requires password for sudo (no NOPASSWD configured)
- Wifi (MediaTek MT7922) works now via NetworkManager but was a fight during install
- System uses LUKS encryption (cryptroot) — important for any disk operations
- NixOS unstable (nixpkgs 2026-03-04), flakes enabled, stateVersion "24.11"
- Ollama config changed in unstable: acceleration option removed, use package = pkgs.ollama-cuda
- The operator's communication style: direct, fast, trusts the AI to act
- Python not in system packages — use `nix develop` for python3 + requests
- Bluesky AT Protocol: needs byte offsets for facets, grapheme counting for limits
- Jekyll on GitHub Pages: posts must be in _posts/ with YAML front matter
- blog/posts/ still exists as source drafts; _posts/ is what Jekyll serves
- .env is gitignored; credentials managed via .env file in repo root
- gh CLI not installed — GitHub API operations need auth token or manual steps

See sibling files for detailed hardware and service state.
