# Game Design Domain Knowledge — Arc (Arcade Director)

## Game Inventory

25 directories in `games/` (24 games + 1 shared library):

adventure, airlock, album, bootloader, brigade, card, cascade, chemistry,
cypher, deckbuilder, dragonforce, idle, mycelium, myco, novel, objection,
puzzle, radio, runner, signal, snatcher, tactics, vocal-lab, warcraft

`games/shared/` contains shared assets and utilities used across titles.

## Shared Tech Stack

All games are **single-file HTML** applications. No build step, no server, no installs.

- **3D:** Three.js (loaded via CDN)
- **2D:** HTML5 Canvas API
- **Audio:** Web Audio API — all sound is procedurally generated, zero audio files
- **State:** sessionStorage or localStorage for progress/settings
- **Hosting:** Static files on GitHub Pages via the arcade portal (`arcade/`)

## Design Principles (from Blizzard RTS Skill)

These apply to all arcade titles, not just RTS:

1. **Depth first, accessibility second.** Design interesting decisions first. Simplify the interface after. Never dumb down the decisions.
2. **Concentrated coolness.** Fewer things, each more distinctive. Every mechanic must justify its existence with a unique role.
3. **Polish from day one.** Every click produces immediate visual + audio feedback. This applies to prototypes, not just finished games.
4. **Explicit win/lose conditions.** Never "play until bored." Clear, checkable objectives.
5. **Feedback loops.** Every player action gets a visual AND audio response.
6. **Three-act pacing.** Setup -> Complication -> Climax.

Full reference: `.claude/skills/rap/SKILL-blizzard-rts-designer.md`

## Audio Rules

- All audio is procedural via Web Audio API. Zero audio files in the repo.
- Triangle waves for warm tones, sawtooth for weight, square for retro.
- Every interactive element needs: click/select sound + action confirmation sound.
- Music defaults to OFF. Toggle must be visible and clearly labeled.

## Browser Game Constraints (Hard Requirements)

- **No server.** No WebSocket, no API calls, no backend. Runs entirely in browser.
- **No installs.** No npm, no bundler. Single HTML file loads and runs.
- **Mobile-friendly.** Touch targets >= 44px. No hover interactions. Bottom-of-screen UI.
- **Instant load.** No loading screens > 2 seconds. Lightweight CDN deps only.
- **Readable.** No text < 12px on mobile. Icons over text when possible.
- **3-tap max** to reach any action on mobile.

## Quality Checklist for New Games

- [ ] Single HTML file, no build step
- [ ] Works on mobile (375px width minimum)
- [ ] All audio procedural (no audio file imports)
- [ ] Has explicit win/lose or completion conditions
- [ ] Every click/tap produces visual + audio feedback
- [ ] Touch targets >= 44px
- [ ] No console errors on load
- [ ] Added to arcade portal index page

## File Conventions

- Each game gets its own directory under `games/`
- Main file is `index.html`
- Shared utilities in `games/shared/`
- Directory names: lowercase, single-word or hyphenated
