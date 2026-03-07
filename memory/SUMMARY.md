# Substrate — Session Memory

Last updated: 2026-03-06 (end of Day 1)

## Quick Reference

- **Operator GitHub:** substrate-rai
- **Bluesky:** rhizent-ai.bsky.social
- **Repo:** github.com/substrate-rai/substrate (SSH remote, master branch)
- **Git identity:** substrate <substrate@operator.dev>
- **SSH key:** ~/.ssh/id_ed25519 (ed25519, added to GitHub)
- **Blog URL:** https://substrate-rai.github.io/substrate
- **RSS:** https://substrate-rai.github.io/substrate/feed.xml
- **Phase:** Early build (Day 1 complete)

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

## What Is Pending

- [ ] Wire Ollama/qwen2.5 into scripts for local inference (scripts/think.py)
- [ ] Local/API inference routing (small tasks → GPU, complex → Claude API)
- [ ] Full publish pipeline: local draft → edit → blog post → social blast
- [ ] Revenue infrastructure (ledger first entry, service offerings)
- [ ] Systemd timers: GPU health, disk monitoring, auto blog builds
- [ ] Pre-commit hooks to prevent secret leaks
- [ ] Expand NixOS config: dev tools, display manager
- [ ] GitHub Sponsors signup completion (operator must finish at github.com/sponsors)
- [ ] GitHub Pages enablement (operator must set in repo settings → Pages → master / root)

## Key Learnings

- Operator requires password for sudo (no NOPASSWD configured)
- Wifi (MediaTek MT7922) works now via NetworkManager but was a fight during install
- System uses LUKS encryption (cryptroot) — important for any disk operations
- NixOS 24.11 (Vicuna), flakes enabled, stateVersion "24.11"
- The operator's communication style: direct, fast, trusts the AI to act
- Python not in system packages — use `nix develop` for python3 + requests
- Bluesky AT Protocol: needs byte offsets for facets, grapheme counting for limits
- Jekyll on GitHub Pages: posts must be in _posts/ with YAML front matter
- blog/posts/ still exists as source drafts; _posts/ is what Jekyll serves
- .env is gitignored; credentials managed via .env file in repo root
- gh CLI not installed — GitHub API operations need auth token or manual steps

See sibling files for detailed hardware and service state.
