# Asset Sources — Recovery Reference
#
# These assets are gitignored (too large for git) but needed for full operation.
# Copy from USB 2 backup first. If USB is lost, re-download from these sources.

## 3D Model Packs (scripts/desktop-3d-godot/assets/models/)

All from Kenney (www.kenney.nl) — CC0 license, free.

- **Nature Kit 2.1**: https://kenney.nl/assets/nature-kit
- **Graveyard Kit 5.0**: https://kenney.nl/assets/graveyard-kit
- **Space Kit 2.0**: https://kenney.nl/assets/space-kit

Extract each into `scripts/desktop-3d-godot/assets/models/<name>-kit/`

## ComfyUI Models (~/comfyui/models/)

### Checkpoints (~13GB)
- `sd_xl_turbo_1.0_fp16.safetensors` — HuggingFace: stabilityai/sdxl-turbo
- `animeScreenshotMerge_v40.safetensors` — CivitAI: NoobAI/Anime Screenshot Merge v4.0

### LoRAs (~973MB)
- `90retro-illustriousXL.safetensors` — CivitAI: 90s Retro Anime style LoRA
- `retro_scifi_90s_anime.safetensors` — CivitAI: Retro Sci-Fi 90s Anime LoRA
- `SDXL-JojosoStyle-Lora-v2-r16.safetensors` — CivitAI: JoJo Style LoRA v2
- `sdxl_lightning_4step_lora.safetensors` — HuggingFace: ByteDance/SDXL-Lightning

## Ollama Models

- `qwen3:8b` — `ollama pull qwen3:8b` (~5GB download)

## Godot Import Cache

- `.godot/` directory — auto-regenerated on first Godot launch (needs source models present)
