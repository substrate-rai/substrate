---
globs: ["assets/**", "scripts/ml/**"]
---

# Art Direction

- Full reference: `memory/art-direction.md` — colors, type, SD prompts, UI patterns, audio, checklists
- **Style:** 90s anime, cel-shaded, bold outlines, dark backgrounds, mycopunk (bioluminescent, forest floor)
- **Model stack:** NoobAI v4.0 + 90s Retro LoRA (0.7), JoJo optional
- **Resolution:** 832x1216 portraits, two-phase workflow (iterate 8 steps / final 25 steps)
- **Character manifest:** `scripts/ml/characters.json` — all agents with prompt blocks, colors, seeds
- All agents have SD-generated portraits in `assets/images/generated/`
- **Typography:** Inter + IBM Plex Mono
- **Color palette:** CSS vars + agent colors defined in art-direction.md
