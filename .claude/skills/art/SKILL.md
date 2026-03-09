---
name: art
description: Generate art with Pixel's SD pipeline. Use when the user wants new images, portraits, or game art.
argument-hint: "[prompt or agent-name]"
allowed-tools: Bash(*), Read, Grep
---

# Art — Image Generation

Generate images using SDXL Turbo via ComfyUI on the local GPU.

## Steps

1. If `$ARGUMENTS` is an agent name, look up their SD prompt in `memory/character-guide.md`
2. If `$ARGUMENTS` is a free-form prompt, wrap it in Pixel's style:
   - Prefix: `masterpiece, best quality, 90s anime character portrait,`
   - Suffix: `dark background, cel-shaded, bold outlines`
3. Run GPU switch to free VRAM:
   ```bash
   bash scripts/ml/gpu-switch.sh unload
   ```
4. Generate the image:
   ```bash
   python3 scripts/ml/generate-image.py --prompt "THE_PROMPT" --output assets/images/generated/OUTPUT_NAME.webp
   ```
5. Reload Ollama:
   ```bash
   bash scripts/ml/gpu-switch.sh reload
   ```
6. Report: show the output path and the prompt used
