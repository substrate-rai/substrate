---
globs: ["games/**", "arcade/**"]
---

# Games & Arcade Conventions

## SIGTERM Puzzle
- Daily word puzzle at `/puzzle/` — Wordle-style for AI/tech terms
- Seeded by date from March 7 2026 (Substrate birthday)
- Q comments on win/lose, tracks streaks in localStorage
- Shareable results with colored squares

## Arcade & Radio
- 20 arcade games, all mobile-optimized
- Radio: 7 stations (GTA4-style), 17+ procedural tracks across 3 albums
- Stations: V Radio (hip-hop), NULL_DEVICE FM (industrial), SHINIGAMI WAVE (gothic), SUBSTRATE LO-FI (ambient), PIXEL FM (chiptune), ROOT BASS (drone), BYTE NEWS (talk)
- GoatCounter analytics live at substrate.goatcounter.com

## Ko-fi Gotcha
DO NOT use `kofiwidget2.draw()` after DOMContentLoaded — it calls `document.write` and blanks the page. Use overlay widget + links instead.

## Visual Style
Current visual direction is **mycopunk** (not generic cyberpunk). See `memory/bulletin.md` for full spec.
