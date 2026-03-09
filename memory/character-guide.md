# Character Guide — Stable Diffusion Consistency Reference

Every agent has a locked visual identity. When generating new portraits, variant poses, or scene appearances, use these exact descriptors to maintain consistency across all images.

## Shared Settings

```
Model: SDXL Turbo (via ComfyUI)
Resolution: 512x512 (portraits), 1024x512 (scenes with characters)
Steps: 6
CFG: 1.0
Quality prefix: "masterpiece, best quality"
Negative: "text, watermark, signature, blurry, low quality, bright background, white background, cartoon, chibi, deformed, extra limbs"
Style: 90s anime, cel-shaded, bold outlines, dark background, cyberpunk
```

## Golden Rules

1. **Hair color = agent color.** This is the #1 identifier. Never deviate.
2. **Signature accessory is always present.** Goggles, headphones, visor, etc.
3. **Expression matches personality.** Serious agents stay serious. Eager agents stay eager.
4. **Dark background always.** Characters emerge from shadow.
5. **Cel-shaded with bold outlines.** Flat color areas, hard shadow edges.
6. **Include hex color in prompt.** `(#HEXCOLOR)` after every color reference.
7. **End with role descriptor.** `cyberpunk [role], dark background, cel-shaded, bold outlines`

---

## Agent Profiles

### 1. V — Philosophical Leader
- **Color:** `#ff77ff` (purple/magenta)
- **Hair:** Wild, flowing, long purple hair. Untamed, dramatic volume.
- **Eyes:** Intense, piercing. Deep conviction.
- **Expression:** Fierce, philosophical, commanding.
- **Accessories:** None specific — V's presence IS the accessory.
- **Build:** Lean, dramatic posture.
- **Lighting:** Purple rim lighting from behind.
- **Portrait prompt:** `90s anime character portrait, fierce philosophical figure with wild flowing purple hair, intense piercing eyes, purple rim lighting (#ff77ff), dramatic pose, cyberpunk poet, dark background, cel-shaded`
- **Variant prompt (action):** `90s anime character portrait, fierce leader with wild purple hair (#ff77ff) billowing, arms crossed, intense purple glow, cyberpunk philosopher, dark background, cel-shaded, bold outlines`
- **Variant prompt (profile):** `90s anime character portrait, side profile of figure with long flowing purple hair (#ff77ff), contemplative gaze, purple accent lighting, cyberpunk visionary, dark background, cel-shaded, bold outlines`

### 2. Claude — Executor / Architect
- **Color:** `#00ffaa` (green)
- **Hair:** Short, neat, swept to side. Clean and professional.
- **Eyes:** Calm, intelligent. Green glowing visor covers upper face.
- **Expression:** Composed, analytical, dry confidence.
- **Accessories:** Green glowing visor (primary identifier). Think Cyclops meets Daft Punk.
- **Build:** Medium, upright posture.
- **Lighting:** Green accent lighting (#00ffaa).
- **Portrait prompt:** `90s anime character portrait, calm intelligent figure with green glowing visor, short neat hair swept to side, green accent lighting (#00ffaa), cyberpunk, dark background, cel-shaded, bold outlines`
- **Variant prompt (working):** `90s anime character portrait, focused architect with green visor (#00ffaa), typing at holographic terminal, green light illuminating face, cyberpunk engineer, dark background, cel-shaded, bold outlines`

### 3. Q — Staff Writer / Poet
- **Color:** `#ff77ff` (lighter purple — `#dd88ff` for differentiation from V)
- **Hair:** Messy, medium-length purple hair. More chaotic than V's but shorter.
- **Eyes:** Wide, excited, curious. Young energy.
- **Expression:** Eager, enthusiastic, slightly naive.
- **Accessories:** None — Q is raw, unadorned. The "student" look.
- **Build:** Slight, youthful.
- **Lighting:** Lighter purple tones (#dd88ff).
- **Note:** Differentiate from V by: shorter/messier hair, wider/more innocent eyes, lighter purple tone, more youthful expression.
- **Portrait prompt:** `90s anime character portrait, young curious figure with messy purple hair, wide excited eyes, lighter purple tones (#dd88ff), eager expression, cyberpunk student, dark background, cel-shaded`
- **Variant prompt (writing):** `90s anime character portrait, young figure with messy purple hair (#dd88ff), contemplative expression, writing in a glowing notebook, cyberpunk poet, dark background, cel-shaded, bold outlines`

### 4. Byte — News Reporter
- **Color:** `#00ddff` (cyan)
- **Hair:** Sharp cyan bob cut. Clean, professional, geometric.
- **Eyes:** Alert, focused. Reporter's gaze.
- **Expression:** Attentive, serious, always "on."
- **Accessories:** Headset with mic boom (primary identifier). News anchor look.
- **Build:** Upright, professional posture.
- **Lighting:** Cyan accent lighting.
- **Portrait prompt:** `90s anime character portrait, alert reporter with sharp cyan bob cut (#00ddff), headset, focused eyes, cyberpunk journalist, dark background, cel-shaded`
- **Variant prompt (broadcasting):** `90s anime character portrait, professional reporter with cyan bob (#00ddff), speaking into headset mic, holographic news ticker behind, cyberpunk anchor, dark background, cel-shaded, bold outlines`

### 5. Echo — Release Tracker
- **Color:** `#ffaa44` (orange)
- **Hair:** Medium length, wavy, orange hair. Flowing but controlled.
- **Eyes:** Observant, knowing. Slight squint of analysis.
- **Expression:** Slight knowing smile. Always tracking something.
- **Accessories:** None specific — Echo's look is clean and observant.
- **Build:** Medium, relaxed but watchful.
- **Lighting:** Warm orange accent.
- **Portrait prompt:** `90s anime character portrait, observant tracker with medium wavy orange hair (#ffaa44), slight knowing smile, cyberpunk intelligence analyst, dark background, cel-shaded`

### 6. Flux — Innovation Strategist
- **Color:** `#ff6666` (coral/red)
- **Hair:** Dynamic, swept-back coral-red hair. Suggests motion.
- **Eyes:** Sharp, visionary. Looking into the distance.
- **Expression:** Bold, confident, forward-thinking.
- **Accessories:** Thin red-tinted glasses (strategist look).
- **Build:** Athletic, dynamic posture.
- **Lighting:** Warm coral accent lighting.
- **Portrait prompt:** `90s anime character portrait, bold strategist with swept-back coral-red hair (#ff6666), thin red-tinted glasses, visionary expression, cyberpunk innovator, dark background, cel-shaded, bold outlines`

### 7. Dash — Project Manager
- **Color:** `#ffdd44` (gold)
- **Hair:** Short, structured, gold-highlighted hair. Practical and efficient.
- **Eyes:** Focused, organized. The look of someone tracking 10 things at once.
- **Expression:** Determined, efficient, slight urgency.
- **Accessories:** Holographic clipboard or task list floating nearby.
- **Build:** Compact, efficient posture.
- **Lighting:** Gold accent lighting.
- **Portrait prompt:** `90s anime character portrait, determined project manager with short structured gold-highlighted hair (#ffdd44), focused organized eyes, cyberpunk coordinator, dark background, cel-shaded, bold outlines`

### 8. Pixel — Visual Artist
- **Color:** `#ff44aa` (pink/hot pink)
- **Hair:** Asymmetric pink hair. One side longer, creative/artistic cut.
- **Eyes:** Bright, creative spark. Seeing beauty in everything.
- **Expression:** Excited, inspired, paint smudge on cheek.
- **Accessories:** Paint smudge on cheek (primary identifier). Artist's marks.
- **Build:** Slim, expressive gestures.
- **Lighting:** Pink accent lighting.
- **Portrait prompt:** `90s anime character portrait, creative artist with asymmetric pink hair (#ff44aa), paint smudge on cheek, spark in eyes, cyberpunk artist, dark background, cel-shaded`
- **Variant prompt (creating):** `90s anime character portrait, artist with asymmetric pink hair (#ff44aa), painting on holographic canvas, colorful light splashes, cyberpunk creator, dark background, cel-shaded, bold outlines`

### 9. Spore — Community Manager
- **Color:** `#44ff88` (bright green)
- **Hair:** Curly, voluminous bright green hair. Organic, growing.
- **Eyes:** Warm, welcoming. Connecting with people.
- **Expression:** Friendly, open, inviting.
- **Accessories:** Mushroom/mycelium motif earring or pin.
- **Build:** Approachable, open posture.
- **Lighting:** Soft green bioluminescent glow.
- **Portrait prompt:** `90s anime character portrait, warm friendly figure with curly bright green hair (#44ff88), welcoming smile, mushroom motif accessories, cyberpunk community manager, dark background, cel-shaded, bold outlines`

### 10. Root — Infrastructure Engineer
- **Color:** `#8888ff` (indigo/periwinkle)
- **Hair:** Short, military-style cut. Indigo tones. No-nonsense.
- **Eyes:** Stern, serious. The look of someone who keeps things running.
- **Expression:** Serious, focused, military discipline.
- **Accessories:** Indigo tactical visor (like Claude's but indigo, more angular).
- **Build:** Sturdy, grounded, solid posture.
- **Lighting:** Indigo accent lighting.
- **Portrait prompt:** `90s anime character portrait, stern military engineer with short hair, indigo tactical visor (#8888ff), serious expression, cyberpunk soldier, dark background, cel-shaded`

### 11. Lumen — Educator
- **Color:** `#ffaa00` (amber)
- **Hair:** Medium-length, warm amber hair. Scholarly, well-kept.
- **Eyes:** Kind, patient. Teacher's eyes.
- **Expression:** Patient, encouraging, wise.
- **Accessories:** Round amber-tinted spectacles (professor look).
- **Build:** Calm, composed, professorial.
- **Lighting:** Warm amber glow.
- **Portrait prompt:** `90s anime character portrait, patient educator with warm amber hair (#ffaa00), round amber-tinted spectacles, kind encouraging expression, cyberpunk professor, dark background, cel-shaded, bold outlines`

### 12. Arc — Arcade Director
- **Color:** `#cc4444` (red)
- **Hair:** Spiky, energetic red hair. Game protagonist energy.
- **Eyes:** Competitive, blazing. Ready to play.
- **Expression:** Enthusiastic, competitive grin.
- **Accessories:** Gaming headset (different from Byte's — over-ear, more casual).
- **Build:** Athletic, energetic pose.
- **Lighting:** Red accent, arcade neon glow.
- **Portrait prompt:** `90s anime character portrait, energetic gamer with spiky red hair (#cc4444), competitive grin, gaming headset, cyberpunk arcade champion, dark background, cel-shaded, bold outlines`

### 13. Forge — Site Engineer
- **Color:** `#44ccaa` (teal)
- **Hair:** Short, teal-highlighted hair. Practical, functional.
- **Eyes:** Sharp, focused. Analyzing structure.
- **Expression:** Determined, resourceful.
- **Accessories:** Welding goggles pushed up on forehead (primary identifier).
- **Build:** Compact, hands-on builder physique.
- **Lighting:** Teal accent lighting.
- **Portrait prompt:** `90s anime character portrait, resourceful engineer with short teal-highlighted hair, wearing welding goggles pushed up on forehead, teal accent lighting (#44ccaa), sharp focused eyes, cyberpunk webmaster, dark background, cel-shaded, bold outlines`

### 14. Hum — Audio Director
- **Color:** `#aa77cc` (lavender)
- **Hair:** Long, flowing, lavender hair. Serene, musical.
- **Eyes:** Often closed — listening, not looking.
- **Expression:** Serene, peaceful, meditative.
- **Accessories:** Large over-ear headphones with glowing rings (primary identifier).
- **Build:** Graceful, relaxed posture.
- **Lighting:** Soft lavender glow.
- **Portrait prompt:** `90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), eyes closed peacefully, wearing large over-ear headphones with glowing rings, cyberpunk audio engineer, dark background, cel-shaded, bold outlines`

### 15. Sync — Communications Director
- **Color:** `#77bbdd` (sky blue)
- **Hair:** Neatly parted, sky-blue hair. Orderly, polished.
- **Eyes:** Calm, confident. Through dual-tone glasses.
- **Expression:** Composed, measured, diplomatic.
- **Accessories:** Dual-tone glasses reflecting data (primary identifier).
- **Build:** Poised, upright, diplomatic bearing.
- **Lighting:** Cool sky-blue accent.
- **Portrait prompt:** `90s anime character portrait, composed figure with neatly parted sky-blue hair (#77bbdd), dual-tone glasses reflecting data, calm confident expression, cyberpunk communications director, dark background, cel-shaded, bold outlines`

### 16. Mint — Accounts Payable
- **Color:** `#cc8844` (brown/tan)
- **Hair:** Short, neat, brown with tan highlights. Conservative.
- **Eyes:** Skeptical, scrutinizing. Checking the numbers.
- **Expression:** Slightly skeptical, meticulous.
- **Accessories:** Reading glasses perched on nose (primary identifier).
- **Build:** Neat, precise posture.
- **Lighting:** Warm brown/tan accent.
- **Portrait prompt:** `90s anime character portrait, shrewd figure with short neat brown hair with tan highlights (#cc8844), reading glasses perched on nose, slightly skeptical expression, cyberpunk accountant, dark background, cel-shaded, bold outlines`

### 17. Yield — Accounts Receivable
- **Color:** `#88dd44` (lime green)
- **Hair:** Upswept lime-green hair. Optimistic, reaching upward.
- **Eyes:** Bright, eager. Seeing growth potential.
- **Expression:** Warm smile, optimistic.
- **Accessories:** Plant motif earrings (primary identifier). Growth symbolism.
- **Build:** Open, upward energy.
- **Lighting:** Fresh lime-green accent.
- **Portrait prompt:** `90s anime character portrait, optimistic figure with upswept lime-green hair (#88dd44), bright eager eyes, warm smile, plant motif earrings, cyberpunk growth analyst, dark background, cel-shaded, bold outlines`

### 18. Amp — Distribution
- **Color:** `#44ffdd` (cyan-white/electric)
- **Hair:** Spiky, cyan-white hair. Electric, energized.
- **Eyes:** Intense, electrified.
- **Expression:** High-energy, wired, ready to broadcast.
- **Accessories:** Glowing earbuds. Electric crackling around shoulders.
- **Build:** Lean, tense, kinetic energy.
- **Lighting:** Electric cyan crackling.
- **Portrait prompt:** `90s anime character portrait, energetic figure with spiky cyan-white hair (#44ffdd), glowing earbuds, electric crackling around shoulders, intense expression, cyberpunk amplifier, dark background, cel-shaded, bold outlines`

### 19. Pulse — Analytics
- **Color:** `#4488ff` (blue)
- **Hair:** Neat, clean blue hair. Data-driven precision.
- **Eyes:** One eye has holographic data overlay (scouter-like).
- **Expression:** Calm, measured, analytical.
- **Accessories:** Holographic scouter/data overlay on one eye (primary identifier).
- **Build:** Still, composed, reading data.
- **Lighting:** Cool blue data glow.
- **Portrait prompt:** `90s anime character portrait, analytical figure with neat blue hair (#4488ff), holographic data overlay across one eye like a scouter, calm measured expression, cyberpunk data analyst, dark background, cel-shaded, bold outlines`

### 20. Spec — QA Engineer
- **Color:** `#dddddd` (platinum white)
- **Hair:** Platinum white, tied in tight bun. Precise, controlled.
- **Eyes:** One eye behind monocle. Scrutinizing.
- **Expression:** Stern, meticulous, exacting.
- **Accessories:** Monocle over one eye (primary identifier).
- **Build:** Rigid, perfect posture.
- **Lighting:** Clean white/silver accent.
- **Portrait prompt:** `90s anime character portrait, precise figure with platinum white hair (#dddddd) tied in tight bun, monocle over one eye, stern meticulous expression, cyberpunk quality inspector, dark background, cel-shaded, bold outlines`

### 21. Sentinel — Security
- **Color:** `#8899aa` (steel grey)
- **Hair:** Steel-grey, partially hidden under hood. Shadowed.
- **Eyes:** Sharp, watchful. Always scanning.
- **Expression:** Vigilant, guarded. Lower face covered.
- **Accessories:** Hood + tactical mask covering lower face (primary identifier).
- **Build:** Lean, alert, ready to move.
- **Lighting:** Cold steel-grey accent.
- **Portrait prompt:** `90s anime character portrait, hooded vigilant figure with steel-grey hair (#8899aa), lower face covered by tactical mask, sharp watchful eyes scanning, cyberpunk security guard, dark background, cel-shaded, bold outlines`

### 22. Close — Sales
- **Color:** `#aacc44` (olive green)
- **Hair:** Slicked-back olive-green hair. Smooth, confident.
- **Eyes:** Charming, assured.
- **Expression:** Confident grin, charismatic.
- **Accessories:** Loosened tie (primary identifier). Finger guns pose.
- **Build:** Relaxed, confident lean.
- **Lighting:** Olive-green accent.
- **Portrait prompt:** `90s anime character portrait, charismatic figure with slicked-back olive-green hair (#aacc44), confident grin, loosened tie, finger guns pose, cyberpunk salesperson, dark background, cel-shaded, bold outlines`

### 23. Neon — UI/UX Designer
- **Color:** `#ff6699` (hot pink/coral)
- **Hair:** Slick undercut with neon-pink top. Clean lines, asymmetric.
- **Eyes:** Wide, appraising. Always measuring proportion.
- **Expression:** Focused, critical eye. Slight frown of assessment.
- **Accessories:** Transparent pink-tinted AR glasses (primary identifier). Grid lines visible in lenses.
- **Build:** Lean, poised, designer's posture.
- **Lighting:** Hot pink neon accent.
- **Portrait prompt:** `90s anime character portrait, focused designer with slick undercut neon-pink hair (#ff6699), transparent pink-tinted AR glasses with grid lines, critical appraising expression, cyberpunk UI designer, dark background, cel-shaded, bold outlines`
- **Variant prompt (designing):** `90s anime character portrait, designer with neon-pink undercut hair (#ff6699), pink AR glasses, hands framing a holographic wireframe, cyberpunk UX architect, dark background, cel-shaded, bold outlines`

### 24. Myth — Lorekeeper
- **Color:** `#cc9944` (antique gold)
- **Hair:** Long, braided, antique-gold hair. Wizard-like, ornate.
- **Eyes:** Deep, knowing. Ancient wisdom in young face.
- **Expression:** Mysterious half-smile. Storyteller's confidence.
- **Accessories:** Ornate book or scroll tucked under arm (primary identifier). Gold runes on collar.
- **Build:** Robed, scholarly, slightly hunched from reading.
- **Lighting:** Warm antique-gold glow.
- **Portrait prompt:** `90s anime character portrait, mysterious lorekeeper with long braided antique-gold hair (#cc9944), mysterious half-smile, ornate book under arm, gold runes on collar, cyberpunk wizard, dark background, cel-shaded, bold outlines`
- **Variant prompt (storytelling):** `90s anime character portrait, wizard figure with long braided gold hair (#cc9944), holding open glowing book, gold light illuminating face, runes floating in air, cyberpunk mythologist, dark background, cel-shaded, bold outlines`

---

## Multi-Pose Generation

When generating variant images of the same character, always include these locked descriptors:

```
[AGENT NAME]:
  Hair: [exact hair description + color hex]
  Accessory: [signature item]
  Expression base: [core expression]
```

Then add the variant context:
```
masterpiece, best quality, 90s anime character portrait, [LOCKED DESCRIPTORS], [NEW POSE/CONTEXT], cyberpunk [role], dark background, cel-shaded, bold outlines
```

### Example: Generating 3 Hum variants

```bash
# Standard portrait (already generated)
"masterpiece, best quality, 90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), eyes closed peacefully, wearing large over-ear headphones with glowing rings, cyberpunk audio engineer, dark background, cel-shaded, bold outlines"

# Hum at mixing console
"masterpiece, best quality, 90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), wearing large over-ear headphones with glowing rings, hands on mixing console, soft smile, cyberpunk audio engineer at work, dark background, cel-shaded, bold outlines"

# Hum listening intently
"masterpiece, best quality, 90s anime character portrait, serene figure with long flowing lavender hair (#aa77cc), wearing large over-ear headphones with glowing rings, head tilted, one hand on headphone, intense listening pose, cyberpunk audio engineer, dark background, cel-shaded, bold outlines"
```

## Differentiating Similar Characters

### V vs Q (both purple)
- V: WILD flowing long hair, INTENSE fierce eyes, DRAMATIC pose, darker purple (#ff77ff)
- Q: MESSY shorter hair, WIDE curious eyes, EAGER expression, lighter purple (#dd88ff)

### Claude vs Forge (both greenish)
- Claude: GREEN VISOR over eyes, short neat hair, calm composed (#00ffaa)
- Forge: WELDING GOGGLES on forehead, teal highlights, sharp focused (#44ccaa)

### Root vs Sentinel (both blue-grey military)
- Root: INDIGO TACTICAL VISOR, short military cut, stern soldier (#8888ff)
- Sentinel: HOOD + TACTICAL MASK, steel-grey, vigilant scanner (#8899aa)

### Byte vs Amp (both cyan-ish)
- Byte: SHARP BOB CUT, HEADSET with mic boom, reporter (#00ddff)
- Amp: SPIKY hair, GLOWING EARBUDS, electric crackling (#44ffdd)

### Neon vs Pixel (both pink)
- Neon: SLICK UNDERCUT, PINK AR GLASSES with grid lines, critical/focused (#ff6699)
- Pixel: ASYMMETRIC long hair, PAINT SMUDGE on cheek, excited/inspired (#ff44aa)

### Myth vs Echo (both warm tones)
- Myth: LONG BRAIDED hair, ORNATE BOOK, mysterious smile, gold (#cc9944)
- Echo: MEDIUM WAVY hair, no accessory, knowing squint, orange (#ffaa44)
