# Stable Diffusion Anime Portrait Research
## Deep Dive: Best Practices & Known Issues for Batch Character Generation

**Researched:** 2026-03-13
**Context:** Generating 30 agent portraits + 30 action portraits using Anime Screenshot Merge IL v4.0 via ComfyUI on RTX 4060 (8GB VRAM)

---

## 1. ComfyUI Batch Generation (30+ images in sequence)

### Best Practices

**Use queue-based sequential generation, NOT batch_size > 1.**
- ComfyUI's `batch_size` parameter in EmptyLatentImage increases VRAM usage linearly with no throughput improvement. The ComfyUI maintainer (comfyanonymous) confirmed: "doing batch_size 1 is usually enough to saturate the GPU compute on these models." Batch size > 1 simply multiplies time and VRAM usage with zero parallelism benefit.
- The current batch-portraits.py approach (subprocess calls with `--no-stop` to keep ComfyUI running between images) is correct. This is the recommended pattern: submit one prompt at a time, keep the server warm.

**Keep ComfyUI running between generations.**
- Model loading is the expensive operation. Once the checkpoint + LoRAs are loaded, subsequent generations only need the sampler/VAE/CLIP passes.
- The `--no-stop` flag in batch-portraits.py already does this correctly.
- The `--no-unload` flag prevents thrashing with Ollama. Also correct.

**Handle failures with --start-from.**
- The existing `--start-from` argument in batch-portraits.py is the right pattern. If generation 17/30 fails, you can resume from agent 17 without regenerating 1-16.
- Add a brief retry mechanism: if a generation fails with CUDA OOM, wait 10 seconds for VRAM to settle, then retry once before marking as failed.

**VRAM Management on 8GB:**
- `--force-fp16 --fp16-vae --dont-upcast-attention` flags already in use are essential for 8GB cards.
- Known issue: ComfyUI v0.16.3+ introduced "dynamic VRAM" which can cause random OOM. Fix: add `--disable-dynamic-vram` to launch flags if experiencing intermittent OOM errors.
- Known issue: RAM leaks across extended runs (GitHub issue #11775, #11301). For 30+ generation runs, monitor system RAM. If it climbs steadily, restart ComfyUI every 15-20 generations.
- Known issue: VAE decode is the VRAM peak moment. If a generation fails during VAE decode, reducing resolution slightly (e.g., 768x1152 instead of 832x1216) can help.

**Practical recommendation for the 30-portrait run:**
1. Unload Ollama models first (already done)
2. Start ComfyUI once, keep it warm
3. Generate sequentially, one image per prompt submission
4. If OOM occurs: wait 10s, retry once, then skip and continue
5. After all 30, stop ComfyUI
6. Use `--start-from` to backfill any failures

### Known Issues (2025-2026)
- GitHub #12823: CUDA OOM after v0.16.3 update — fix with `--disable-dynamic-vram`
- GitHub #12426: Batch processing shows linear scaling, no parallelism benefit
- GitHub #12723: Tensor shape mismatches when using batch_size > 1 with some nodes
- GitHub #12784: VAE decode crashes with large batches
- GitHub #10896: Safetensors loading uses 2x expected memory on some hardware

---

## 2. NoobAI / Anime Checkpoint Models — Character Consistency

### The Anime Screenshot Merge IL v4.0 Model

This is NOT base NoobAI — it's a checkpoint merge built on Illustrious (which itself derives from NoobAI's training approach). Key differences:

| Setting | Base NoobAI-XL Vpred | Anime Screenshot Merge IL v4.0 |
|---------|----------------------|-------------------------------|
| CFG Scale | 4-5 | **2-4** (lower!) |
| Steps | 28-35 | **20-30** |
| Sampler | Euler ONLY (v-pred) | **Euler or Euler Ancestral** |
| Trigger | masterpiece, best quality, newest | **"anime coloring"** as first tag |
| Prediction | v-prediction | eps-prediction (Illustrious base) |
| Karras | NOT supported | Supported (DPM++ SDE Karras works for iterate phase) |

**Critical finding:** The current config uses CFG 1.5 for iterate and 4.5 for final. The model creator recommends CFG 2-4. CFG 4.5 is slightly above the recommended range but should be fine. CFG 1.5 with Lightning LoRA for iteration is also reasonable since Lightning LoRA works best at very low CFG. See Section 7 for detailed analysis.

### Character Consistency Strategies

**Lock character descriptors in a manifest file.** The characters.json approach is exactly right. Every generation of a given character uses the identical prompt_block. This is the primary consistency mechanism without training a per-character LoRA.

**The most important identity anchors (in order of reliability):**
1. **Hair color + style** — This is by far the strongest visual identity signal. "wild flowing purple hair with braided sections" will be consistent across generations. Hair is the most reliably reproduced feature.
2. **Distinctive accessories** — Visors, goggles, headphones, monocles. These reproduce well because they're concrete objects with clear Danbooru tags.
3. **Gender tag + body type** — "1boy" or "1girl" with build descriptors ("sturdy build", "lean posture") are reliable.
4. **Skin tone with emphasis** — "(dark skin:1.3), dark-skinned_male" with attention weighting is the right approach for consistent skin representation.
5. **Expression** — Less reliable. "calm composed expression" and "stern meticulous expression" will vary more across seeds.

**What breaks consistency:**
- Changing pose/framing between portrait and action shots (the core challenge for the action portraits)
- Adding too many scene elements that compete with character elements for attention tokens
- Different seeds — by definition, each seed produces variation. Consider finding and locking good seeds per character.

**LoRA considerations for 90s retro:**
- The 90s Retro LoRA at 0.7 strength is reasonable. Higher strength (0.8-1.0) risks overwhelming character features with style artifacts.
- Stacking multiple LoRAs (90s Retro + Retro Sci-fi + Lightning) creates complex interactions. Each LoRA pulls the model in a different direction. The current approach of using Lightning only for iterate phase is wise — it shouldn't be stacked with other LoRAs for final quality.
- For the JoJo LoRA: this will significantly alter character appearance (thicker linework, more dramatic shading, different proportions). Only use it intentionally for specific characters, not as a default.

---

## 3. Mycopunk / Bioluminescent Environments

### The Core Challenge

The action-portraits.json is trying to combine:
- A detailed character description (12-20 tokens)
- An action scene (20-30 tokens)
- A bioluminescent environment (15-20 tokens)
- Style tags (15-20 tokens)

This creates very long prompts where the environment can overwhelm the character. The model's attention budget is finite.

### Practical Solutions

**Keep the character at the front of the prompt.** CLIP processes tokens sequentially with diminishing attention. Tokens at the start of the prompt get the strongest attention. The current master template structure is correct:
```
masterpiece, best quality, {prompt_block}, {action_scene}, [style tags]
```
Character comes before scene. Good.

**Use "dark background" carefully.** The Danbooru tag `dark_background` means "a dark background that usually isn't completely solid black unless the subject is dimly lit." The risk: when combined with bioluminescent elements, the model may darken the entire image including the character.

**Mitigation strategies for dark characters in dark environments:**
1. **Backlighting / rim lighting** — Add "backlighting" or "[color] rim lighting" to the character description. This creates a luminous contour around the character, separating them from the dark background. Already used in some prompts (e.g., "purple rim lighting" for V).
2. **Agent-color accent lighting** — The current pattern of "[color] accent lighting (#hex)" is good. This tells the model to light the character with their signature color.
3. **"soft lighting" is key** — Already in the master template. This prevents the model from interpreting "dark background" as "dark everything."
4. **For dark-skinned characters specifically:** The negative prompt "pale skin, white skin" prevents the model from lightening skin, but the bigger risk is the model making the character invisible against a dark background. Add "well-lit face" or "face illuminated" to the character block for dark-skinned characters in dark scenes.
5. **Bioluminescent elements as character illumination** — Phrases like "bioluminescent mushrooms illuminating face" or "fungal glow reflecting on skin" tell the model to use the environment glow as the character's light source.

**What NOT to do:**
- Don't use "simple background" or "white background" — these will break the aesthetic entirely.
- Don't make the environment too specific. "bioluminescent mushrooms, glowing mycelium tendrils, dark forest floor background, fungal glow, cyberpunk biotech" (the current _scene_suffix) is 5 distinct environment concepts competing for attention. Consider trimming to 3.
- Don't duplicate color terms between character and environment — if the character has cyan hair and the environment has cyan mushroom glow, the model may merge them. Use slightly different color terms (e.g., "teal hair" vs "cyan mushroom glow").

### Recommended scene_suffix (trimmed)
Current: `bioluminescent mushrooms, glowing mycelium tendrils, dark forest floor background, fungal glow, cyberpunk biotech`

Suggested: `bioluminescent mushrooms, glowing mycelium, dark background, cyberpunk biotech`

This removes "dark forest floor" (too specific, competes with the per-character action_scene) and "fungal glow" (redundant with "bioluminescent mushrooms").

---

## 4. Action Poses vs Static Portraits

### The Transition Problem

Going from `portrait, upper body` (static portraits) to action scenes introduces several risks:

**Detail loss.** When the model needs to render a full scene (environment, action, character), each element gets less attention budget. Character accessories (goggles, monocles, headsets) are the first casualties because they're small details competing with large scene elements.

**Pose failures.** Danbooru-trained models understand specific pose tags well. Use concrete tags:
- Good: "arms crossed", "typing at terminal", "sitting on log", "reading book"
- Bad: "dramatic heroic pose", "in action" (vague, unpredictable results)
- The current action_scene descriptions are generally good — they describe specific actions.

**The action-portraits.json master template removes "dark background" but keeps "portrait, upper body".** This is a tension: "upper body" conflicts with some action scenes that want to show more of the character. For characters performing physical actions (welding, broadcasting), "upper body" may be fine. For characters on elevated platforms or scouting from towers, "cowboy shot" or even "full body" would be more appropriate.

### Recommendations

1. **Keep "upper body" for most action portraits.** It forces the model to keep the character large in frame, preserving detail. Only switch to "cowboy shot" for characters where the action requires more visible body.

2. **Front-load character identity tags before action.** The current structure does this correctly: prompt_block (character) comes before action_scene (what they're doing).

3. **Keep the same character accessories in action prompts.** Review the action-portraits.json — some characters lose accessories between portraits and action versions. For example:
   - characters.json Forge: "welding goggles pushed up on forehead" — action-portraits.json Forge: "welding goggles pushed up on forehead" (good, kept)
   - characters.json Echo: "tinted glasses, tactical earpiece" — action-portraits.json Echo: "fitted tech vest with pockets" (glasses and earpiece dropped!)

   Audit action-portraits.json to ensure all distinguishing accessories from characters.json are preserved.

4. **Use Danbooru pose tags.** Available tags that work well:
   - Standing: "standing", "standing on one leg", "legs apart", "crossed_arms"
   - Seated: "sitting", "kneeling", "seiza"
   - Action: "running", "jumping", "fighting stance"
   - Composition: "from above", "from below", "from side", "dutch angle"
   - Focus: "upper body", "cowboy shot", "full body", "portrait"

---

## 5. Prompt Engineering for Scene + Character

### Optimal Prompt Structure

Based on NoobAI/Illustrious training data (Danbooru captions), the optimal order is:

```
[quality prefix], [gender/count], [character identity], [action/pose], [scene/environment], [style tags]
```

This matches the current approach. The master template places quality first, then character, then style. The action template places character first, then action_scene, then style.

### Token Limits

**SDXL (including Illustrious/NoobAI derivatives) uses dual CLIP encoders:**
- CLIP-L: 77 tokens (same as SD 1.5)
- CLIP-G (OpenCLIP ViT-bigG): 77 tokens

ComfyUI handles long prompts by chunking into 77-token segments. Tokens beyond 77 go into additional chunks with progressively less influence.

**Practical implications:**
- The first ~77 tokens matter most. This is your character identity + primary action.
- Tokens 78-154 have reduced influence. Put environment details here.
- Beyond 154 tokens, influence drops significantly. Style tags that are already baked into the checkpoint (like "anime screencap") barely need to be in the prompt at all.

**Current prompt length analysis:**
A typical action portrait prompt from action-portraits.json, fully assembled:
```
masterpiece, best quality, 1boy, (dark skin:1.3), dark-skinned_male, wild flowing purple hair with braided sections, intense piercing eyes, purple rim lighting, leather jacket with neon trim, arms crossed standing on elevated fungal platform, addressing unseen crowd, bioluminescent spore clouds rising around feet, purple glow mixing with cyan mushroom light, cyberpunk philosopher giving speech, bioluminescent mushrooms, glowing mycelium tendrils, dark forest floor background, fungal glow, cyberpunk biotech, 90retrostyle, retro artstyle, anime screencap, anime coloring, cel shading, soft lighting, muted colors, portrait, upper body
```

This is approximately **90-100 tokens**. The character identity fills the first ~40 tokens (good, strong attention). The action scene fills tokens ~40-70 (still in first chunk, good). Environment and style spill into the second chunk (less attention, but that's acceptable for background elements).

**This prompt length is workable but on the long side.** Consider trimming redundant style tags since the checkpoint already has anime style baked in.

### Attention Weighting

ComfyUI uses the `(text:weight)` syntax:
- `(dark skin:1.3)` = 30% more attention on "dark skin"
- `(text:0.7)` = 30% less attention
- Default stacking: `(word)` = 1.1x, `((word))` = 1.21x

**Recommendations:**
- Use (1.3) for skin tone enforcement (already done correctly)
- Consider (1.2) for critical character accessories that might disappear in action scenes: `(welding goggles:1.2)`, `(monocle:1.2)`
- Don't go above 1.5 — it creates artifacts and distortion
- Don't weight style tags — they're already strong from the checkpoint

---

## 6. Resolution and Aspect Ratio

### Current Config: 832x1216 (portrait, 0.68:1 ratio)

This is explicitly listed as an optimal resolution for NoobAI-XL and Illustrious-based models. Total pixel area: ~1,011,712 (close to the optimal ~1,048,576 = 1024x1024).

### Resolution Recommendations by Shot Type

| Shot Type | Resolution | Ratio | Use Case |
|-----------|-----------|-------|----------|
| Headshot/Portrait | **832x1216** | 0.68:1 | Static agent portraits (current) |
| Upper Body Action | **832x1216** | 0.68:1 | Action portraits where character fills frame |
| Cowboy Shot Action | **896x1152** | 0.78:1 | Slightly wider for more body visible |
| Full Scene | **1024x1024** | 1:1 | Character + significant environment |
| Cinematic Scene | **1216x832** | 1.46:1 | Landscape with character in context |
| Blog Hero | **1024x512** | 2:1 | Already in use for blog scenes |

**For the action portraits:** 832x1216 is the right choice. These are still character-focused images with the character as the dominant element. The portrait orientation keeps the character large and detailed. Switching to landscape would shrink the character and expand the environment — the opposite of what you want.

**Only consider 1024x1024 or landscape if:** the action specifically requires horizontal space (e.g., two characters interacting, a wide establishing shot). None of the current action-portraits.json entries need this.

### VRAM Impact
- 832x1216 at fp16: ~5.8GB VRAM during sampling + ~7.5GB peak during VAE decode
- 1024x1024: similar VRAM to 832x1216 (same total pixels)
- Going above 1024x1024 total pixels significantly increases VRAM — avoid on 8GB card

---

## 7. CFG Scale and Steps for Anime Screenshot Merge IL v4.0

### Model-Specific Findings

The Anime Screenshot Merge IL v4.0 is based on **Illustrious** (eps-prediction), NOT v-prediction NoobAI. This is an important distinction.

**Creator recommendations:** CFG 2-4, Steps 20-30, Euler or Euler Ancestral

**Community usage from CivitAI gallery data:**
| User | CFG | Steps | Sampler | Notes |
|------|-----|-------|---------|-------|
| Gallery top images | 6.5 | 60 | Euler a | With character LoRA at 0.8 |
| Gallery top images | 7.0 | 25 | Euler | With character LoRA at 1.0 |
| Gallery images | 5.0 | 28 | Euler a | With character LoRA at 1.0 |
| Gallery images | 3.0 | 20 | Euler a | With character LoRA at 1.0 |

**Analysis of current config:**

| Phase | Current CFG | Recommended Range | Assessment |
|-------|-------------|-------------------|------------|
| Iterate | 1.5 | N/A (Lightning LoRA changes rules) | **OK** — Lightning LoRA is designed for low CFG |
| Final | 4.5 | 2-4 (creator), 3-7 (community) | **Slightly high but fine** |

**CFG 4.5 for final is acceptable.** It's at the top of the creator's range but within community usage patterns. Higher CFG means:
- Stronger prompt adherence (character details more likely to appear)
- Risk of oversaturation and "fried" look at very high values
- At 4.5, you're in a sweet spot where prompts are followed closely without artifact risk

**If you see oversaturation or harsh contrast:** Drop to CFG 3.5-4.0.
**If character details are getting lost:** Stay at 4.5 or try 5.0.

**Steps: 25 for final is good.** Community uses 20-60. More steps = more refinement but diminishing returns after 30. 25 is efficient for batch generation.

**For iterate phase:** 8 steps with DPM++ SDE Karras + Lightning LoRA at CFG 1.5 is appropriate. This is a rapid prototyping mode — not for final output. The Lightning LoRA is specifically designed for 4-8 step generation.

### Sampler Notes

- **Euler Ancestral** (current final): Good choice. Adds slight variation at each step, produces more "natural" anime results. Standard for Illustrious-based models.
- **DPM++ SDE Karras** (current iterate): Works fine with Illustrious-based models (unlike v-prediction NoobAI which can't use Karras). Good for fast iteration.
- **Euler** (alternative): More deterministic than Euler Ancestral. Use if you want more reproducible results across similar seeds.

---

## 8. WebP Output

### Current State in ComfyUI

ComfyUI's built-in `SaveImage` node outputs PNG only. For WebP output, the options are:

1. **SaveAnimatedWEBP node** — Built into ComfyUI. Can save static WebP when batch_size=1. However, this is unintuitive (the node name says "animated") and has issues with batch_size > 1 (saves as animated WebP rather than separate static files).

2. **Custom SaveImageWEBP node** — A PR (#6708) was proposed but abandoned when the contributor's repo was deleted. The PR would have added lossy/lossless compression and quality settings.

3. **Post-processing conversion** — Generate as PNG from ComfyUI, then convert to WebP using `cwebp` or Python PIL. This is the most reliable approach.

**The current batch-portraits.py specifies `.webp` output but generate-image.py saves whatever ComfyUI outputs (PNG) and just names the file.** This means the output files are actually PNG data with a .webp extension — a potential issue. The image viewers will still display them (they check magic bytes, not extension), but it's technically incorrect.

### WebP Quality Recommendations

For anime/illustration art:
- **Quality 85-90** for lossy WebP — good balance of file size and quality for flat-color anime art
- **Lossless WebP** — ideal for anime art (flat colors compress very well losslessly), produces smaller files than PNG while being bit-perfect
- WebP at quality 85 is roughly equivalent to JPEG quality 85 in file size, but with better quality (fewer artifacts in flat color areas)
- For anime art specifically, **lossless WebP is recommended** because flat color cel-shaded art compresses extremely well losslessly, often producing files 25-35% smaller than PNG
- Lossy WebP can produce visible banding in flat color gradients (common in anime) at quality < 80

### Recommended Fix

Add a post-processing step to generate-image.py that converts the ComfyUI PNG output to proper WebP:

```python
# After downloading PNG from ComfyUI:
if output_path.suffix == '.webp':
    from PIL import Image
    img = Image.open(png_data)
    img.save(output_path, 'WEBP', lossless=True)  # or quality=90 for lossy
```

Alternatively, use `cwebp` CLI tool (available through NixOS):
```bash
cwebp -lossless input.png -o output.webp  # lossless
cwebp -q 90 input.png -o output.webp       # lossy quality 90
```

### Known Issues
- ComfyUI preview format setting (issue #10972) doesn't work — previews always save as PNG regardless of setting. This is a UI issue, not an output issue.
- WebP loading (issue #3993): After extended ComfyUI sessions, the Load Image node may fail to recognize WebP files. Workaround: restart ComfyUI.

---

## Summary: Priority Action Items for the Substrate Portrait Pipeline

### Already Correct
- Sequential generation with `--no-stop` (optimal for 8GB VRAM)
- `--force-fp16 --fp16-vae --dont-upcast-attention` flags
- 832x1216 resolution for both portrait and action shots
- Character descriptor locking in characters.json / action-portraits.json
- CFG 1.5 for iterate with Lightning LoRA
- CFG 4.5 for final (at top of range but OK)
- Euler Ancestral for final sampler
- Character-first prompt ordering
- Skin tone enforcement with attention weighting

### Should Fix
1. **WebP conversion** — Currently saving PNG data with .webp extension. Add proper conversion step.
2. **Add retry logic** — If a generation fails with CUDA OOM, wait 10s and retry once.
3. **Consider --disable-dynamic-vram** — If experiencing intermittent OOM on newer ComfyUI versions.
4. **Audit action portrait accessory consistency** — Some characters lose identity accessories between portraits and action versions.
5. **Trim scene_suffix** — Remove redundant terms to save attention budget for character details.

### Consider Adjusting
1. **Add "anime coloring" to master template** — The Anime Screenshot Merge creator specifically recommends this as a trigger. Currently the template has "anime screencap, anime coloring" — "anime coloring" is present but later in the prompt. Consider moving it earlier.
2. **Add accent lighting to all action portraits** — Some action descriptions lack explicit character illumination, risking dark-character-in-dark-scene problems.
3. **Add (1.2) attention weight to critical accessories** — Goggles, visors, headphones that might disappear in busy action scenes.
4. **For dark-skinned characters in dark scenes** — Add "well-lit face" or "face illuminated by [bioluminescent source]" to ensure visibility.
