# Substrate Art Direction

Practical reference for reproducing Substrate's visual style consistently. Covers color, type, image generation, UI, audio, and step-by-step checklists.

---

## 1. Color Palette

### Core Colors (CSS Variables from `_layouts/default.html`)

| Token | Hex | Usage |
|---|---|---|
| `--bg` | `#0a0a0f` | Page background — near-black with slight blue |
| `--surface` | `#12121a` | Card/panel backgrounds |
| `--surface-hover` | `#1a1a24` | Hovered cards, interactive surfaces |
| `--surface-alt` | `#161620` | Secondary surface (terminal bar, alternating rows) |
| `--border` | `#1e1e2a` | Default borders — subtle, low contrast |
| `--border-hover` | `#2a2a3a` | Hover/active borders |
| `--text` | `#c8c8d0` | Body text |
| `--text-muted` | `#6a6a78` | Secondary text, labels |
| `--text-dim` | `#44444f` | Tertiary text, timestamps, metadata |
| `--heading` | `#e8e8ef` | Headings, strong emphasis |
| `--accent` | `#00e09a` | Primary accent — green (Claude's color, CTAs, links) |
| `--accent-dim` | `rgba(0, 224, 154, 0.1)` | Accent background tint |
| `--accent-border` | `rgba(0, 224, 154, 0.2)` | Accent-tinted borders |
| `--link` | `#6ea8fe` | Inline link color |
| `--link-hover` | `#93bfff` | Link hover state |

### Agent Colors (all 22)

| Agent | Hex | CSS Var | Role |
|---|---|---|---|
| V | `#ff77ff` | `--q` | Philosophical Leader |
| Claude | `#00ffaa` | `--claude` | Executor / Architect |
| Q | `#ff77ff` | `--q` | Staff Writer |
| Byte | `#00ddff` | `--byte` | News Reporter |
| Echo | `#ffaa44` | `--echo` | Release Tracker |
| Flux | `#ff6666` | `--flux` | Innovation Strategist |
| Dash | `#ffdd44` | `--dash` | Project Manager |
| Pixel | `#ff44aa` | — | Visual Artist |
| Spore | `#44ff88` | — | Community Manager |
| Root | `#8888ff` | — | Infrastructure Engineer |
| Lumen | `#ffaa00` | — | Educator |
| Arc | `#cc4444` | — | Arcade Director |
| Forge | `#44ccaa` | — | Site Engineer |
| Hum | `#aa77cc` | — | Audio Director |
| Sync | `#77bbdd` | — | Communications Director |
| Mint | `#cc8844` | — | Accounts Payable |
| Yield | `#88dd44` | — | Accounts Receivable |
| Amp | `#44ffdd` | — | Distribution |
| Pulse | `#4488ff` | — | Analytics |
| Spec | `#dddddd` | — | QA Engineer |
| Sentinel | `#8899aa` | — | Security |
| Close | `#aacc44` | — | Sales |

### Surface Hierarchy

```
Layer 0:  #0a0a0f  (page background)
Layer 1:  #12121a  (cards, panels)
Layer 2:  #161620  (nested surfaces, terminal bars)
Layer 3:  #1a1a24  (hover states)
Borders:  #1e1e2a → #2a2a3a on hover
```

### Accent Usage Rules

- Green (`#00e09a`) is the primary accent. Use for: logo, CTAs, blinking cursor, status indicators, blockquote borders, code text, progress bars.
- Agent colors are used only in their context: author tags, staff bio left-borders, portrait accents. Never use an agent color as a general UI accent.
- Author tags use the agent color at 10% opacity as background, the agent color as text, and the agent color at 20% opacity as border.
- Selection highlight: `background: var(--accent-dim); color: var(--accent);`

---

## 2. Typography

### Font Families

```css
--font: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
--mono: 'IBM Plex Mono', 'JetBrains Mono', 'Fira Code', monospace;
```

Both loaded from Google Fonts: `IBM+Plex+Mono:wght@400;500;600;700` and `Inter:wght@400;500;600;700`.

### Size Scale

| Element | Font | Size | Weight | Notes |
|---|---|---|---|---|
| Body text | Inter | 15px | 400 | line-height: 1.6 |
| Paragraph | Inter | 15px | 400 | line-height: 1.75, margin-bottom: 1.25rem |
| h1 | Inter | 1.75rem | 700 | color: --heading, letter-spacing: -0.5px |
| h2 | Inter | 1.2rem | 600 | color: --heading, letter-spacing: -0.3px |
| h3 | Inter | 1rem | 600 | color: --text |
| Hero tagline | IBM Plex Mono | 1.6rem | 700 | letter-spacing: -0.5px |
| Site logo | IBM Plex Mono | 1.1rem | 600 | color: --accent |
| Nav links | Inter | 0.8rem | 400 | color: --text-muted |
| Author tag | IBM Plex Mono | 0.65rem | 600 | uppercase vibe, letter-spacing: 0.3px |
| Post date | IBM Plex Mono | 0.75rem | 400 | color: --text-dim |
| Section heading | IBM Plex Mono | 0.85rem | 600 | uppercase, letter-spacing: 1px |
| Footer heading | IBM Plex Mono | 0.65rem | 600 | uppercase, letter-spacing: 1px |
| Stat value | IBM Plex Mono | 1.5rem | 700 | color: --accent |
| Stat label | IBM Plex Mono | 0.7rem | 400 | uppercase, color: --text-dim |
| Inline code | IBM Plex Mono | 0.85em | 400 | color: --accent, bg: --surface |
| Code block | IBM Plex Mono | 0.85rem | 400 | line-height: 1.6 |

### When to Use Mono vs Sans

- **Mono (IBM Plex Mono):** Logo, terminal prompts, code, metadata (dates, stats, labels), tags, section headings, nav labels, status indicators, CTA buttons. Anything that should feel "system" or "machine-generated."
- **Sans (Inter):** Body prose, headings (h1-h3), descriptions, card text, long-form reading. Anything that should feel "human-readable."
- **Never use:** serif fonts, handwriting fonts, decorative type.

---

## 3. Portrait Style (Stable Diffusion)

### Model and Settings

- **Model:** SDXL Turbo (via ComfyUI)
- **Resolution:** 512x512
- **Steps:** 6
- **CFG:** 1.0
- **Pipeline:** generate-image.py sends to ComfyUI's API

### Quality Prefix

```
masterpiece, best quality
```

Prepended to every prompt. For the `generate-site-visuals.sh` (abstract portraits), it is omitted — those prompts stand alone.

### Negative Prompt

Two variants are in use:

**For character portraits (anime):**
```
text, watermark, signature, blurry, low quality, bright background, white background, cartoon, chibi, deformed, extra limbs
```

**For abstract/site visuals:**
```
text, watermark, human face, realistic photo, blurry, low quality, signature, words, letters
```

### Prompt Structure (Character Portraits)

Template:
```
90s anime character portrait, [personality description] with [hair description using agent color], [eye/expression details], [agent color] accent lighting (#hex), [role description], dark background, cel-shaded, bold outlines
```

Real examples from `generate-game-art.sh` and `generate-agent-portraits.sh`:

```
90s anime character portrait, calm intelligent figure with green glowing visor, short neat hair swept to side, green accent lighting (#00ffaa), cyberpunk, dark background, cel-shaded, bold outlines

90s anime character portrait, fierce philosophical figure with wild flowing purple hair, intense piercing eyes, purple rim lighting (#ff77ff), dramatic pose, cyberpunk poet, dark background, cel-shaded

90s anime character portrait, resourceful engineer with short teal-highlighted hair, wearing welding goggles pushed up on forehead, teal accent lighting (#44ccaa), sharp focused eyes, cyberpunk webmaster, dark background, cel-shaded, bold outlines

90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), eyes closed peacefully, wearing large over-ear headphones with glowing rings, cyberpunk audio engineer, dark background, cel-shaded, bold outlines
```

### Character Design Rules

1. **Hair color matches agent color.** Claude = green visor/green tones. V = purple hair. Hum = lavender hair. Forge = teal highlights. This is the single most important visual identity rule.
2. **Personality visible in expression/accessories.** Byte has a headset (reporter). Hum has headphones (audio). Forge has welding goggles (engineer). Spec has a monocle (inspector). Close has finger guns (salesperson).
3. **Dark background, always.** Never bright or white backgrounds. The character should emerge from darkness.
4. **Cel-shaded with bold outlines.** This is the non-negotiable style marker. Flat color areas, hard shadow edges, thick outlines.
5. **Cyberpunk role descriptor.** End with "cyberpunk [role], dark background, cel-shaded, bold outlines."
6. **Include hex color in prompt.** Put the agent's hex color in parentheses after the color name: `teal accent lighting (#44ccaa)`.

### What to Avoid (Negative Prompt Breakdown)

- `text, watermark, signature` — SDXL loves to hallucinate text
- `blurry, low quality` — quality floor
- `bright background, white background` — breaks the dark aesthetic
- `cartoon, chibi` — wrong anime style; we want 90s serious anime, not cute
- `deformed, extra limbs` — anatomical safety net

### Abstract Portrait Style (Site Visuals)

For the original abstract agent portraits (`generate-site-visuals.sh`), the style is different — no human features, purely symbolic:

```
abstract digital architect entity, geometric green terminal glow, command prompt cursor shape, dark background, neon green wireframe structures, cyberpunk organic, commanding presence
```

Keywords: abstract, entity, dark background, cyberpunk organic, energy streams, data visualization.

---

## 4. Scene Art Style

### Settings

- **Resolution:** 1024x512 (widescreen, cinematic)
- **Steps:** 6
- **CFG:** 1.0
- **Quality prefix:** `masterpiece, best quality`
- **Same negative prompt as portraits**

### Prompt Structure

Template:
```
90s anime background, [environment description], [lighting details], [specific aesthetic reference], no people
```

Real examples:
```
90s anime background, dark computer terminal room, green text on screens, CRT monitors, cyberpunk lab, moody lighting, no people

90s anime background, dark cyberpunk city at night, neon signs, rain, Blade Runner aesthetic, no people

90s anime background, bioluminescent laboratory, glowing tubes and equipment, mycelium growing on walls, cyberpunk biotech, no people

90s anime background, digital tactical grid battlefield, holographic terrain, strategy war room, cyberpunk military, no people
```

### Aesthetic References

Primary references (named in prompts and anime-effects.js):
- **Cowboy Bebop** — warm color palette, jazz noir mood
- **Ghost in the Shell** — cyberpunk, terminal interfaces, philosophical
- **Evangelion** — dramatic lighting, apocalyptic scale
- **Akira** — kinetic energy, neon city, speed lines
- **Blade Runner** — rain, neon signs, dark city, noir

### Lighting Rules

- **Base is always dark.** Scenes emerge from shadow.
- **Neon accents provide color.** Green terminal glow, blue screen light, orange warning indicators.
- **Moody, not flat.** Strong directional light from screens/neon, deep shadows everywhere else.
- **Bioluminescence for organic scenes.** Mycelium glows green/cyan. Spore clouds have soft radiance.

### Game Thumbnails

512x512. Standalone atmospheric images — no text, no characters. Each should capture the game's core mechanic as a visual metaphor:

```
dark terminal screen with five glowing green letter slots, word puzzle grid, phosphor CRT aesthetic, scanlines, retro computer game, minimal

isometric tactical grid battlefield, chess-like units on elevated terrain, purple and gold, strategy RPG aesthetic, dark background
```

---

## 5. UI/Visual Design Principles

### Dark-First Design

- Background is always `#0a0a0f` or darker. Never white. Never light gray.
- Cards and panels use `#12121a` — one step above void.
- Text is light-on-dark. Primary text `#c8c8d0`, muted `#6a6a78`, dim `#44444f`.

### Surface and Border Treatment

- Borders are 1px solid `#1e1e2a` — barely visible, structural.
- Border-radius: 8-10px for cards/panels, 4-6px for tags/buttons.
- No box shadows. Light comes from color, not elevation.
- Hover borders shift to `#2a2a3a` — subtle acknowledgment.

### Accent as Highlight, Not Fill

- Accent green (`#00e09a`) used for: text, borders, small indicators, progress bars.
- Primary CTA buttons are the exception — they use accent as fill with dark text.
- Background tints use accent at 10% opacity: `rgba(0, 224, 154, 0.1)`.
- Never fill large areas with accent color.

### Animation

Three named animations in the site CSS:

```css
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
/* Used on body load — 0.4s ease-out */

@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
/* Used on cursor, continue indicators — 1-1.5s step-end infinite */

@keyframes eq { 0% { transform: scaleY(0.3); } 100% { transform: scaleY(1); } }
/* Used on equalizer bars — 0.8s ease-in-out infinite alternate */
```

Principles:
- **Subtle.** Animations should feel like breathing, not bouncing.
- **Purposeful.** Only animate to communicate state: loading, attention, aliveness.
- **transition: 0.2-0.3s** for hover states and interactive feedback.
- **transform: translateY(-1px)** for card hover lifts — one pixel, no more.
- Respect `prefers-reduced-motion: reduce`.

### Anime Effects (anime-effects.js)

The `anime-effects.js` library provides game-specific visual effects drawn from 90s anime:

- **CRT scanlines:** Repeating horizontal lines at low opacity (0.05)
- **Speed lines burst:** Radiating lines from a point — for impacts, attacks
- **Screen flash:** Full-screen white/color flash, 150-300ms
- **Text slam:** Large text appears at scale(3), slams to scale(1) — for "OBJECTION!", phase names
- **Title card:** Full-screen with speed lines background, large monospace text
- **CRT frame:** Inset box-shadow simulating monitor curvature
- **Impact frame:** White flash + radial lines — 150ms
- **Encounter splash:** Diagonal slash background with sliding text

### Undertale/Deltarune Inspiration

Game UIs (especially visual novels and text-heavy games) use:
- Black background with white text
- Simple bordered text boxes at screen bottom
- Character portraits in conversation (80x80px, border-radius: 8px)
- Monospace font for system/UI text
- Action buttons with colored borders on dark backgrounds
- Minimal chrome — let the text carry the experience

---

## 6. Web Aesthetic

### Terminal/Hacker Feel

The site presents as a terminal-like interface:
- Logo is monospace with a blinking cursor: `substrate█`
- Status indicator has a glowing green dot with `box-shadow: 0 0 6px var(--accent)`
- Hero section is wrapped in a faux terminal window with red/yellow/green dots
- Prompt character `$` in accent green
- Section headings are uppercase monospace with `//` prefix accent

### Layout

- `--max-width: 720px` for content pages
- `--wide-width: 960px` for homepage
- `--nav-max: 960px` for navigation
- Sticky header with `backdrop-filter: blur(12px)` at 85% opacity background
- Footer: centered grid of link columns, monospace headings

### Card Patterns

```css
border: 1px solid var(--border);
border-radius: 10px;
padding: 20px;
background: var(--surface);
transition: border-color 0.3s, transform 0.2s;
```

Hover: `border-color: var(--border-hover); transform: translateY(-1px);`

Agent-specific cards shift border to agent color at 30% opacity on hover.

### Three.js Background

The homepage has a subtle floating orb animation:
- Palette: muted teal, slate blue, purple-gray, olive, sage — `[#2a6b6b, #3d5a80, #7b6b8a, #8a9a7b, #6b8a8a]`
- Orbs: spheres at 5-14% opacity, "breathing" scale animation
- Canvas opacity: 0.3
- Disabled on `prefers-reduced-motion: reduce`
- Mobile: 12 orbs. Desktop: 28 orbs.

---

## 7. Audio Direction

### Philosophy (from Hum's voice prompt)

> Sound is not decoration — it is architecture. Silence is the most powerful frequency in the mix. Procedural audio > static samples. The arcade should feel like one sonic space, not seventeen jukeboxes.

### Technology

- **Engine:** Web Audio API (procedural synthesis, zero audio files)
- **Shared library:** `assets/js/substrate-audio.js` — common sound effects
- **Per-game audio:** Games can extend with custom Web Audio code
- **Sound is opt-in:** Off by default, toggle with `SubstrateAudio.toggle()`, preference persisted in localStorage

### Genre Palette (from Substrate Radio)

**Core collection (lo-fi):**
- Chill ambient
- Dark ambient (the default mood)
- Glitch
- Warm lo-fi
- Cosmic drift

**NULL_DEVICE collection (industrial electronic):**
- Industrial
- Dark industrial
- Haunted ambient
- Glitch industrial
- Building tension
- Epic industrial

**SHINIGAMI_PROTOCOL collection (gothic dramatic):**
- Dramatic synth
- Mysterious ambient
- Gothic organ
- Somber choral
- Urgent dramatic
- Bittersweet resolve

### Reference Points

- **NIN / Trent Reznor** — industrial textures, distorted oscillators, tension
- **Death Note OST** — gothic dramatic, pipe organ, choral swells
- **Lo-fi hip-hop** — warm detuned chords, vinyl crackle, tape wobble
- **Bioluminescent ambient** — "what would a fungal network sound like if you put your ear to it"

### Sound Effect Design (substrate-audio.js)

All effects use basic oscillators and noise:

| Sound | Type | Freq | Duration | Purpose |
|---|---|---|---|---|
| click | square | 800Hz | 0.06s | UI interaction |
| hover | sine | 600Hz | 0.04s | Selection feedback |
| success | sine | C5-E5-G5 ascending | 0.3s | Positive outcome |
| error | sawtooth | 200Hz→150Hz | 0.25s | Negative outcome |
| hit | noise + sawtooth | 150Hz | 0.12s | Combat/impact |
| victory | sine | C5-E5-G5-C6 fanfare | 0.5s | Game win |
| defeat | sawtooth | A4→F4→C4→F3 descending | 0.8s | Game loss |
| boot | sine ascending sweep + noise | 0.5s | Terminal startup |
| objection | sawtooth | 880Hz→1100Hz | 0.35s | Dramatic moment |
| beatdrop | sine 80Hz + noise | 0.4s | Rap/music moment |

### Rules

- No sound is better than wrong sound.
- All audio is client-side. No streaming, no backend audio.
- Sound toggles are mandatory on every page with audio.
- Procedural over sampled. Keep payloads at zero bytes where possible.
- Test on laptop speakers, not just headphones.

---

## 8. Reproducibility Checklists

### Generate a New Agent Portrait

1. Choose the agent's signature color (must be unique across the team).
2. Write the prompt following this template:
   ```
   masterpiece, best quality, 90s anime character portrait, [personality adjective] figure with [hair description] (#HEXCOLOR), [distinguishing accessory or feature], [agent color name] accent lighting (#HEXCOLOR), [expression descriptor], cyberpunk [role noun], dark background, cel-shaded, bold outlines
   ```
3. Add the prompt to `scripts/ml/generate-agent-portraits.sh` in the PROMPTS array.
4. Run:
   ```bash
   cd /home/operator/substrate
   ./scripts/ml/generate-agent-portraits.sh --dry-run  # verify prompt
   ./scripts/ml/generate-agent-portraits.sh             # generate (needs GPU free)
   ```
5. Output lands in `assets/images/generated/agent-[name].png` (512x512).
6. Add the agent's color to the staff page CSS: `.agent-bio.[name]::before { background: #HEXCOLOR; }`
7. If the agent also needs a CSS variable, add it to `:root` in `_layouts/default.html`.

### Create a New Game's Visual Style

1. **Thumbnail:** Add a prompt to `scripts/ml/generate-site-visuals.sh` under the `games` category. Focus on the game's core mechanic as a visual metaphor. 512x512, dark, atmospheric, no characters.
2. **Scene art (if narrative game):** Add to `scripts/ml/generate-game-art.sh` under `scenes`. 1024x512, cinematic, "90s anime background", "no people".
3. **Character portraits (if needed):** Add to `generate-game-art.sh` under `portraits`. Follow the character portrait template above.
4. **In-game CSS:** Start from this base:
   ```css
   body {
     background: #0a0a0f;           /* or #000 for full-screen games */
     color: #c8c8d0;
     font-family: 'IBM Plex Mono', monospace;
   }
   ```
5. **Borders:** `1px solid #1e1e2a` or `1px solid #2a2a5a` (slightly brighter for game UI).
6. **Accent color:** Use `#00e09a` for primary interactive elements, or the relevant agent color if the game is "owned" by a specific agent.
7. **Audio:** Include `<script src="/substrate/assets/js/substrate-audio.js"></script>` and call `SubstrateAudio.createToggle()`.
8. **Anime effects:** Include `<script src="/substrate/assets/js/anime-effects.js"></script>` for CRT scanlines, speed lines, impact frames.

### Design a New Page

1. Use `layout: default` in Jekyll frontmatter. The default layout provides the full site chrome (header, footer, background canvas, CSS variables).
2. Content width is `720px` by default. For wider layouts add custom CSS: `max-width: 960px;`
3. Use the existing CSS variables — do not redefine colors inline.
4. Page-specific CSS goes in a `<style>` block in the markdown/HTML file.
5. Headings: h1 for page title, h2 for sections, h3 for subsections. All use Inter.
6. Metadata: IBM Plex Mono, 0.7-0.8rem, `color: var(--text-dim)`.
7. Cards: `background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 20px;`
8. Links: inherit `var(--link)` from the default layout. For accent links use `color: var(--accent)`.
9. Images: `max-width: 100%; border-radius: 8px;`
10. Tables: Full width, collapse borders, monospace for data columns, 0.85rem font-size.

---

## Quick Reference Card

```
BG:          #0a0a0f
Surface:     #12121a
Border:      #1e1e2a
Text:        #c8c8d0
Muted:       #6a6a78
Dim:         #44444f
Heading:     #e8e8ef
Accent:      #00e09a
Link:        #6ea8fe

Font body:   Inter 15px/1.6
Font mono:   IBM Plex Mono
Font load:   Google Fonts

Portrait:    SDXL Turbo, 512x512, steps=6, cfg=1.0
Scene:       SDXL Turbo, 1024x512, steps=6, cfg=1.0
Style:       90s anime, cel-shaded, bold outlines, dark background, cyberpunk
Negative:    text, watermark, signature, blurry, low quality, bright background, white background, cartoon, chibi, deformed, extra limbs

Audio:       Web Audio API, procedural, zero files
Default mood: dark ambient
Sound:       off by default, toggled by user
```
