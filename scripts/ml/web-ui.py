#!/usr/bin/env python3
"""ML Toolkit Web UI — browser interface for image, audio, and music generation.

Serves a single-page app at http://localhost:8190 with tabs for:
  - Image generation (Stable Diffusion via diffusers)
  - Speech-to-text (Faster Whisper)
  - Text-to-speech (SpeechT5)
  - Music generation (MusicGen)
  - GPU status monitor

Uses Python's built-in http.server — no Flask dependency.
Manages VRAM automatically: unloads Ollama before each task.

Usage:
    python3 scripts/ml/web-ui.py
    python3 scripts/ml/web-ui.py --port 8190 --host 127.0.0.1
"""

import argparse
import base64
import cgi
import io
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import traceback
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "generated"
AUDIO_DIR = Path(__file__).resolve().parent.parent.parent / "assets" / "audio"
UPLOAD_DIR = Path(tempfile.gettempdir()) / "ml-ui-uploads"

# Track running tasks
_task_lock = threading.Lock()
_current_task = None  # {"type": str, "started": float, "status": str}
_task_history = []    # last 10 completed tasks


def unload_ollama():
    """Unload all Ollama models to free VRAM."""
    try:
        req = urllib.request.Request("http://localhost:11434/api/ps")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            for m in data.get("models", []):
                name = m.get("name", "unknown")
                body = json.dumps({"model": name, "keep_alive": 0}).encode()
                req2 = urllib.request.Request(
                    "http://localhost:11434/api/generate",
                    data=body,
                    headers={"Content-Type": "application/json"},
                    method="POST",
                )
                urllib.request.urlopen(req2, timeout=30)
    except Exception:
        pass


def get_gpu_status():
    """Get GPU memory info via nvidia-smi."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,memory.free,memory.used,utilization.gpu,temperature.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5
        )
        parts = [p.strip() for p in result.stdout.strip().split(", ")]
        return {
            "device": parts[0],
            "total_mb": int(parts[1]),
            "free_mb": int(parts[2]),
            "used_mb": int(parts[3]),
            "gpu_util": int(parts[4]),
            "temp_c": int(parts[5]),
        }
    except Exception:
        return {"device": "unknown", "total_mb": 0, "free_mb": 0, "used_mb": 0, "gpu_util": 0, "temp_c": 0}


def get_ollama_models():
    """Check loaded Ollama models."""
    try:
        req = urllib.request.Request("http://localhost:11434/api/ps")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read())
            return data.get("models", [])
    except Exception:
        return None


def task_generate_image(prompt, model_key="sdxl-turbo", steps=None, guidance=None,
                        width=512, height=512, seed=None):
    """Generate an image. Returns base64 PNG data."""
    import torch
    from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline

    MODELS = {
        "sdxl-turbo": {
            "id": "stabilityai/sdxl-turbo",
            "steps_default": 4,
            "guidance_default": 0.0,
        },
        "sd15": {
            "id": "stable-diffusion-v1-5/stable-diffusion-v1-5",
            "steps_default": 25,
            "guidance_default": 7.5,
        },
    }

    model_info = MODELS[model_key]
    model_id = model_info["id"]
    steps = steps or model_info["steps_default"]
    guidance = guidance if guidance is not None else model_info["guidance_default"]

    if model_key == "sdxl-turbo":
        pipe = StableDiffusionXLPipeline.from_pretrained(
            model_id, torch_dtype=torch.float16, variant="fp16"
        )
    else:
        pipe = StableDiffusionPipeline.from_pretrained(
            model_id, torch_dtype=torch.float16
        )

    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()

    generator = torch.Generator("cuda").manual_seed(seed) if seed else None

    result = pipe(
        prompt=prompt,
        num_inference_steps=steps,
        guidance_scale=guidance,
        width=width,
        height=height,
        generator=generator,
    )

    image = result.images[0]

    # Save to output dir
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = prompt[:40].replace(" ", "-").replace("/", "_")
    out_path = OUTPUT_DIR / f"{safe_name}.png"
    image.save(out_path)

    # Also return as base64
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    b64 = base64.b64encode(buf.getvalue()).decode()

    del pipe
    torch.cuda.empty_cache()

    return {"image_b64": b64, "saved_to": str(out_path)}


def task_transcribe(audio_path, model_size="base", language=None):
    """Transcribe audio file. Returns text segments."""
    from faster_whisper import WhisperModel

    model = WhisperModel(model_size, device="cuda", compute_type="float16")
    segments, info = model.transcribe(
        audio_path,
        language=language,
        beam_size=5,
        vad_filter=True,
    )

    lines = []
    full_text = []
    for segment in segments:
        lines.append({
            "start": round(segment.start, 1),
            "end": round(segment.end, 1),
            "text": segment.text.strip(),
        })
        full_text.append(segment.text.strip())

    del model
    try:
        import torch
        torch.cuda.empty_cache()
    except ImportError:
        pass

    return {
        "language": info.language,
        "language_prob": round(info.language_probability, 2),
        "duration": round(info.duration, 1),
        "segments": lines,
        "full_text": " ".join(full_text),
    }


def task_speak(text):
    """Generate speech from text. Returns base64 WAV data."""
    import torch
    import soundfile as sf
    from transformers import SpeechT5Processor, SpeechT5ForTextToSpeech, SpeechT5HifiGan
    from datasets import load_dataset

    device = "cuda" if torch.cuda.is_available() else "cpu"

    processor = SpeechT5Processor.from_pretrained("microsoft/speecht5_tts")
    model = SpeechT5ForTextToSpeech.from_pretrained("microsoft/speecht5_tts").to(device)
    vocoder = SpeechT5HifiGan.from_pretrained("microsoft/speecht5_hifigan").to(device)

    embeddings = load_dataset("Matthijs/cmu-arctic-xvectors", split="validation")
    speaker_embedding = torch.tensor(embeddings[7306]["xvector"]).unsqueeze(0).to(device)

    inputs = processor(text=text, return_tensors="pt").to(device)
    speech = model.generate_speech(inputs["input_ids"], speaker_embedding, vocoder=vocoder)

    # Save to file
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = text[:30].replace(" ", "-").replace("/", "_")
    out_path = AUDIO_DIR / f"{safe_name}.wav"
    audio_np = speech.cpu().numpy()
    sf.write(str(out_path), audio_np, samplerate=16000)

    # Also return as base64
    buf = io.BytesIO()
    sf.write(buf, audio_np, samplerate=16000, format="WAV")
    buf.seek(0)
    b64 = base64.b64encode(buf.read()).decode()

    del model, vocoder
    if device == "cuda":
        torch.cuda.empty_cache()

    return {"audio_b64": b64, "saved_to": str(out_path), "sample_rate": 16000}


def task_compose(prompt, duration=5):
    """Generate music from text prompt. Returns base64 WAV data."""
    import torch
    import soundfile as sf
    from transformers import AutoProcessor, MusicgenForConditionalGeneration

    processor = AutoProcessor.from_pretrained("facebook/musicgen-small")
    model = MusicgenForConditionalGeneration.from_pretrained(
        "facebook/musicgen-small"
    ).to("cuda")

    inputs = processor(text=[prompt], padding=True, return_tensors="pt").to("cuda")
    max_tokens = int(duration * 1500 / 20)
    audio = model.generate(**inputs, max_new_tokens=max_tokens)

    audio_data = audio[0, 0].cpu().numpy()
    sample_rate = model.config.audio_encoder.sampling_rate

    # Save to file
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = prompt[:30].replace(" ", "-").replace("/", "_")
    out_path = AUDIO_DIR / f"music-{safe_name}.wav"
    sf.write(str(out_path), audio_data, samplerate=sample_rate)

    # Also return as base64
    buf = io.BytesIO()
    sf.write(buf, audio_data, samplerate=sample_rate, format="WAV")
    buf.seek(0)
    b64 = base64.b64encode(buf.read()).decode()

    actual_duration = round(len(audio_data) / sample_rate, 1)

    del model
    torch.cuda.empty_cache()

    return {"audio_b64": b64, "saved_to": str(out_path), "sample_rate": sample_rate, "duration": actual_duration}


# ─── HTML Template ────────────────────────────────────────────────────────────

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>substrate // ml toolkit</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600;700&family=Inter:wght@400;500;600;700&display=swap');

  *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

  :root {
    --bg: #0a0a0f;
    --surface: #12121a;
    --surface-hover: #1a1a24;
    --surface-alt: #161620;
    --border: #1e1e2a;
    --border-hover: #2a2a3a;
    --text: #c8c8d0;
    --text-muted: #6a6a78;
    --text-dim: #44444f;
    --heading: #e8e8ef;
    --accent: #00e09a;
    --accent-dim: rgba(0, 224, 154, 0.1);
    --accent-border: rgba(0, 224, 154, 0.2);
    --link: #6ea8fe;
    --error: #ff6666;
    --warn: #ffdd44;
    --font: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    --mono: 'IBM Plex Mono', 'JetBrains Mono', monospace;
  }

  html { scroll-behavior: smooth; }

  body {
    font-family: var(--font);
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    line-height: 1.6;
    font-size: 15px;
    -webkit-font-smoothing: antialiased;
  }

  ::selection { background: var(--accent-dim); color: var(--accent); }

  /* Header */
  .header {
    border-bottom: 1px solid var(--border);
    background: rgba(10, 10, 15, 0.9);
    backdrop-filter: blur(12px);
    position: sticky;
    top: 0;
    z-index: 100;
  }
  .header-inner {
    max-width: 960px;
    margin: 0 auto;
    padding: 0 24px;
    display: flex;
    align-items: center;
    height: 56px;
    gap: 16px;
  }
  .logo {
    font-family: var(--mono);
    font-size: 1.1rem;
    font-weight: 600;
    color: var(--accent);
    text-decoration: none;
    letter-spacing: -0.5px;
    flex-shrink: 0;
  }
  .logo .dim { color: var(--text-dim); }
  .logo .cursor {
    display: inline-block;
    width: 2px; height: 1em;
    background: var(--accent);
    margin-left: 2px;
    animation: blink 1.2s step-end infinite;
    vertical-align: text-bottom;
  }
  @keyframes blink { 0%,100% { opacity: 1; } 50% { opacity: 0; } }

  .header-status {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
    margin-left: auto;
  }
  .header-status::before {
    content: '';
    display: inline-block;
    width: 6px; height: 6px;
    background: var(--accent);
    border-radius: 50%;
    margin-right: 5px;
    vertical-align: middle;
    box-shadow: 0 0 6px var(--accent);
  }

  /* Tabs */
  .tabs {
    display: flex;
    gap: 2px;
    padding: 12px 24px;
    max-width: 960px;
    margin: 0 auto;
    overflow-x: auto;
  }
  .tab {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--text-muted);
    background: none;
    border: 1px solid transparent;
    padding: 8px 16px;
    border-radius: 6px;
    cursor: pointer;
    white-space: nowrap;
    transition: color 0.2s, background 0.2s, border-color 0.2s;
  }
  .tab:hover { color: var(--text); background: var(--surface); }
  .tab.active {
    color: var(--heading);
    background: var(--surface);
    border-color: var(--border);
  }
  .tab-icon { margin-right: 6px; }

  /* Main container */
  .container {
    max-width: 960px;
    margin: 0 auto;
    padding: 24px;
  }

  /* Panels */
  .panel {
    display: none;
  }
  .panel.active {
    display: block;
    animation: fadeIn 0.3s ease;
  }
  @keyframes fadeIn { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }

  .panel-title {
    font-family: var(--mono);
    font-size: 1rem;
    font-weight: 600;
    color: var(--heading);
    margin-bottom: 4px;
  }
  .panel-desc {
    font-size: 0.85rem;
    color: var(--text-muted);
    margin-bottom: 24px;
  }

  /* Forms */
  .form-group {
    margin-bottom: 16px;
  }
  .form-label {
    display: block;
    font-family: var(--mono);
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 6px;
  }
  .form-input, .form-select, .form-textarea {
    width: 100%;
    font-family: var(--mono);
    font-size: 0.85rem;
    color: var(--text);
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 6px;
    padding: 10px 14px;
    outline: none;
    transition: border-color 0.2s;
  }
  .form-input:focus, .form-select:focus, .form-textarea:focus {
    border-color: var(--accent);
  }
  .form-textarea {
    resize: vertical;
    min-height: 80px;
    font-family: var(--font);
  }
  .form-select {
    cursor: pointer;
    appearance: none;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%236a6a78' d='M6 8L1 3h10z'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 12px center;
    padding-right: 32px;
  }
  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .form-row-3 {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 12px;
  }

  /* Buttons */
  .btn {
    font-family: var(--mono);
    font-size: 0.85rem;
    font-weight: 600;
    padding: 10px 24px;
    border-radius: 6px;
    border: none;
    cursor: pointer;
    transition: all 0.2s;
    display: inline-flex;
    align-items: center;
    gap: 8px;
    min-height: 44px;
  }
  .btn-primary {
    background: var(--accent);
    color: var(--bg);
  }
  .btn-primary:hover { background: #00c888; transform: translateY(-1px); }
  .btn-primary:active { transform: translateY(0); }
  .btn-primary:disabled {
    background: var(--surface);
    color: var(--text-dim);
    cursor: not-allowed;
    transform: none;
    border: 1px solid var(--border);
  }
  .btn-secondary {
    background: var(--surface);
    color: var(--text-muted);
    border: 1px solid var(--border);
  }
  .btn-secondary:hover {
    color: var(--text);
    border-color: var(--border-hover);
  }

  /* File upload */
  .file-drop {
    border: 2px dashed var(--border);
    border-radius: 8px;
    padding: 32px;
    text-align: center;
    transition: border-color 0.2s, background 0.2s;
    cursor: pointer;
    position: relative;
  }
  .file-drop:hover, .file-drop.dragover {
    border-color: var(--accent-border);
    background: var(--accent-dim);
  }
  .file-drop input[type="file"] {
    position: absolute;
    inset: 0;
    opacity: 0;
    cursor: pointer;
  }
  .file-drop-icon {
    font-size: 1.5rem;
    margin-bottom: 8px;
    color: var(--text-dim);
  }
  .file-drop-text {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--text-muted);
  }
  .file-drop-hint {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
    margin-top: 4px;
  }
  .file-name {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--accent);
    margin-top: 8px;
  }

  /* Spinner */
  .spinner-overlay {
    display: none;
    margin-top: 24px;
    padding: 32px;
    text-align: center;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: var(--surface);
  }
  .spinner-overlay.active { display: block; }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  .spinner {
    display: inline-block;
    width: 32px; height: 32px;
    border: 3px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 12px;
  }
  .spinner-text {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--text-muted);
  }
  .spinner-elapsed {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
    margin-top: 4px;
  }

  /* Results */
  .result-area {
    margin-top: 24px;
    display: none;
  }
  .result-area.active { display: block; }
  .result-card {
    border: 1px solid var(--border);
    border-radius: 8px;
    background: var(--surface);
    overflow: hidden;
  }
  .result-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border);
    background: var(--surface-alt);
  }
  .result-label {
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--accent);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .result-meta {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
  }
  .result-body {
    padding: 16px;
  }
  .result-body img {
    max-width: 100%;
    height: auto;
    border-radius: 4px;
    display: block;
    margin: 0 auto;
  }
  .result-body audio {
    width: 100%;
    margin: 8px 0;
  }
  .result-text {
    font-size: 0.9rem;
    line-height: 1.7;
    color: var(--text);
    white-space: pre-wrap;
  }
  .result-saved {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--border);
  }

  /* Transcript segments */
  .transcript-segment {
    padding: 6px 0;
    border-bottom: 1px solid rgba(30,30,42,0.5);
  }
  .transcript-segment:last-child { border-bottom: none; }
  .segment-time {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
    margin-right: 8px;
  }
  .segment-text {
    font-size: 0.85rem;
    color: var(--text);
  }

  /* Error */
  .error-box {
    margin-top: 24px;
    padding: 16px;
    border: 1px solid rgba(255, 102, 102, 0.3);
    border-radius: 8px;
    background: rgba(255, 102, 102, 0.05);
    display: none;
  }
  .error-box.active { display: block; }
  .error-title {
    font-family: var(--mono);
    font-size: 0.8rem;
    font-weight: 600;
    color: var(--error);
    margin-bottom: 4px;
  }
  .error-detail {
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--text-muted);
    white-space: pre-wrap;
  }

  /* Status panel */
  .status-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
    margin-bottom: 24px;
  }
  .status-card {
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 20px;
    background: var(--surface);
  }
  .status-card-title {
    font-family: var(--mono);
    font-size: 0.75rem;
    font-weight: 600;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
  }
  .status-item {
    display: flex;
    justify-content: space-between;
    padding: 6px 0;
    border-bottom: 1px solid rgba(30,30,42,0.5);
    font-size: 0.85rem;
  }
  .status-item:last-child { border-bottom: none; }
  .status-key {
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--text-muted);
  }
  .status-val {
    font-family: var(--mono);
    font-size: 0.75rem;
    color: var(--text);
  }
  .status-val.accent { color: var(--accent); }
  .status-val.warn { color: var(--warn); }
  .status-val.error { color: var(--error); }

  .vram-bar {
    height: 8px;
    background: var(--surface-alt);
    border-radius: 4px;
    overflow: hidden;
    border: 1px solid var(--border);
    margin-top: 8px;
  }
  .vram-fill {
    height: 100%;
    background: var(--accent);
    border-radius: 3px;
    transition: width 0.5s ease;
  }

  .tools-list {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
    margin-top: 16px;
  }
  .tool-item {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 14px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--surface);
    font-family: var(--mono);
    font-size: 0.75rem;
  }
  .tool-name { color: var(--heading); font-weight: 500; }
  .tool-desc { color: var(--text-dim); }

  /* Footer */
  .footer {
    text-align: center;
    padding: 32px 24px;
    border-top: 1px solid var(--border);
    margin-top: 48px;
  }
  .footer-text {
    font-family: var(--mono);
    font-size: 0.7rem;
    color: var(--text-dim);
  }

  @media (max-width: 640px) {
    .form-row, .form-row-3, .status-grid, .tools-list { grid-template-columns: 1fr; }
    .tabs { gap: 0; }
    .tab { padding: 8px 10px; font-size: 0.75rem; }
    .tab-icon { display: none; }
  }
</style>
</head>
<body>

<header class="header">
  <div class="header-inner">
    <span class="logo">substrate<span class="dim"> // ml</span><span class="cursor"></span></span>
    <span class="header-status" id="header-status">local-only</span>
  </div>
</header>

<div class="tabs" role="tablist">
  <button class="tab active" data-tab="image" role="tab"><span class="tab-icon">&#9633;</span>image</button>
  <button class="tab" data-tab="transcribe" role="tab"><span class="tab-icon">&#9834;</span>transcribe</button>
  <button class="tab" data-tab="speak" role="tab"><span class="tab-icon">&#9835;</span>speak</button>
  <button class="tab" data-tab="music" role="tab"><span class="tab-icon">&#9836;</span>music</button>
  <button class="tab" data-tab="status" role="tab"><span class="tab-icon">&#9881;</span>status</button>
</div>

<div class="container">

  <!-- ───── IMAGE GENERATION ───── -->
  <div class="panel active" id="panel-image" role="tabpanel">
    <h2 class="panel-title">image generation</h2>
    <p class="panel-desc">Generate images with Stable Diffusion. SDXL Turbo for speed, SD 1.5 for quality.</p>

    <div class="form-group">
      <label class="form-label" for="img-prompt">prompt</label>
      <input type="text" class="form-input" id="img-prompt" placeholder="a cyberpunk laptop on a shelf, neon lighting" autofocus>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label class="form-label" for="img-model">model</label>
        <select class="form-select" id="img-model">
          <option value="sdxl-turbo">SDXL Turbo (~4s, 4 steps)</option>
          <option value="sd15">SD 1.5 (~25s, 25 steps)</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label" for="img-seed">seed (optional)</label>
        <input type="number" class="form-input" id="img-seed" placeholder="random">
      </div>
    </div>

    <div class="form-row-3">
      <div class="form-group">
        <label class="form-label" for="img-width">width</label>
        <select class="form-select" id="img-width">
          <option value="512" selected>512</option>
          <option value="768">768</option>
          <option value="1024">1024</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label" for="img-height">height</label>
        <select class="form-select" id="img-height">
          <option value="512" selected>512</option>
          <option value="768">768</option>
          <option value="1024">1024</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label" for="img-steps">steps</label>
        <input type="number" class="form-input" id="img-steps" placeholder="auto">
      </div>
    </div>

    <button class="btn btn-primary" id="img-generate" onclick="generateImage()">generate</button>

    <div class="spinner-overlay" id="img-spinner">
      <div class="spinner"></div>
      <div class="spinner-text">generating image...</div>
      <div class="spinner-elapsed" id="img-elapsed">0s</div>
    </div>

    <div class="error-box" id="img-error">
      <div class="error-title">generation failed</div>
      <div class="error-detail" id="img-error-detail"></div>
    </div>

    <div class="result-area" id="img-result">
      <div class="result-card">
        <div class="result-header">
          <span class="result-label">generated image</span>
          <span class="result-meta" id="img-result-meta"></span>
        </div>
        <div class="result-body">
          <img id="img-result-img" alt="Generated image">
          <div class="result-saved" id="img-result-saved"></div>
        </div>
      </div>
    </div>
  </div>

  <!-- ───── TRANSCRIPTION ───── -->
  <div class="panel" id="panel-transcribe" role="tabpanel">
    <h2 class="panel-title">speech-to-text</h2>
    <p class="panel-desc">Transcribe audio files with Faster Whisper. Supports mp3, wav, m4a, flac, ogg.</p>

    <div class="form-group">
      <div class="file-drop" id="audio-drop">
        <input type="file" id="audio-file" accept="audio/*,.mp3,.wav,.m4a,.flac,.ogg,.webm">
        <div class="file-drop-icon">&#8593;</div>
        <div class="file-drop-text">drop audio file or click to browse</div>
        <div class="file-drop-hint">mp3, wav, m4a, flac, ogg</div>
        <div class="file-name" id="audio-file-name"></div>
      </div>
    </div>

    <div class="form-row">
      <div class="form-group">
        <label class="form-label" for="whisper-model">model size</label>
        <select class="form-select" id="whisper-model">
          <option value="tiny">tiny (~1GB VRAM)</option>
          <option value="base" selected>base (~1GB VRAM)</option>
          <option value="small">small (~2GB VRAM)</option>
          <option value="medium">medium (~5GB VRAM)</option>
          <option value="large-v3">large-v3 (~6GB VRAM)</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label" for="whisper-lang">language (optional)</label>
        <input type="text" class="form-input" id="whisper-lang" placeholder="auto-detect">
      </div>
    </div>

    <button class="btn btn-primary" id="transcribe-btn" onclick="transcribeAudio()">transcribe</button>

    <div class="spinner-overlay" id="transcribe-spinner">
      <div class="spinner"></div>
      <div class="spinner-text">transcribing audio...</div>
      <div class="spinner-elapsed" id="transcribe-elapsed">0s</div>
    </div>

    <div class="error-box" id="transcribe-error">
      <div class="error-title">transcription failed</div>
      <div class="error-detail" id="transcribe-error-detail"></div>
    </div>

    <div class="result-area" id="transcribe-result">
      <div class="result-card">
        <div class="result-header">
          <span class="result-label">transcript</span>
          <span class="result-meta" id="transcribe-result-meta"></span>
        </div>
        <div class="result-body">
          <div id="transcribe-segments"></div>
          <div style="margin-top:12px;">
            <button class="btn btn-secondary" onclick="copyTranscript()">copy text</button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- ───── TEXT-TO-SPEECH ───── -->
  <div class="panel" id="panel-speak" role="tabpanel">
    <h2 class="panel-title">text-to-speech</h2>
    <p class="panel-desc">Generate speech with SpeechT5. Lightweight TTS (~1GB VRAM).</p>

    <div class="form-group">
      <label class="form-label" for="tts-text">text</label>
      <textarea class="form-textarea" id="tts-text" rows="4" placeholder="Hello, I am Substrate. A sovereign AI workstation."></textarea>
    </div>

    <button class="btn btn-primary" id="speak-btn" onclick="generateSpeech()">speak</button>

    <div class="spinner-overlay" id="speak-spinner">
      <div class="spinner"></div>
      <div class="spinner-text">generating speech...</div>
      <div class="spinner-elapsed" id="speak-elapsed">0s</div>
    </div>

    <div class="error-box" id="speak-error">
      <div class="error-title">speech generation failed</div>
      <div class="error-detail" id="speak-error-detail"></div>
    </div>

    <div class="result-area" id="speak-result">
      <div class="result-card">
        <div class="result-header">
          <span class="result-label">generated speech</span>
          <span class="result-meta" id="speak-result-meta"></span>
        </div>
        <div class="result-body">
          <audio id="speak-audio" controls></audio>
          <div class="result-saved" id="speak-result-saved"></div>
        </div>
      </div>
    </div>
  </div>

  <!-- ───── MUSIC GENERATION ───── -->
  <div class="panel" id="panel-music" role="tabpanel">
    <h2 class="panel-title">music generation</h2>
    <p class="panel-desc">Generate music with MusicGen-small (~2GB VRAM). Describe the music you want.</p>

    <div class="form-group">
      <label class="form-label" for="music-prompt">prompt</label>
      <input type="text" class="form-input" id="music-prompt" placeholder="lo-fi hip hop beat with vinyl crackle and soft piano">
    </div>

    <div class="form-group">
      <label class="form-label" for="music-duration">duration (seconds)</label>
      <select class="form-select" id="music-duration">
        <option value="3">3s</option>
        <option value="5" selected>5s</option>
        <option value="8">8s</option>
        <option value="10">10s</option>
        <option value="15">15s</option>
      </select>
    </div>

    <button class="btn btn-primary" id="music-btn" onclick="generateMusic()">compose</button>

    <div class="spinner-overlay" id="music-spinner">
      <div class="spinner"></div>
      <div class="spinner-text">composing music...</div>
      <div class="spinner-elapsed" id="music-elapsed">0s</div>
    </div>

    <div class="error-box" id="music-error">
      <div class="error-title">music generation failed</div>
      <div class="error-detail" id="music-error-detail"></div>
    </div>

    <div class="result-area" id="music-result">
      <div class="result-card">
        <div class="result-header">
          <span class="result-label">generated music</span>
          <span class="result-meta" id="music-result-meta"></span>
        </div>
        <div class="result-body">
          <audio id="music-audio" controls></audio>
          <div class="result-saved" id="music-result-saved"></div>
        </div>
      </div>
    </div>
  </div>

  <!-- ───── STATUS ───── -->
  <div class="panel" id="panel-status" role="tabpanel">
    <h2 class="panel-title">system status</h2>
    <p class="panel-desc">GPU usage, VRAM, and loaded models.</p>

    <div class="status-grid">
      <div class="status-card">
        <div class="status-card-title">GPU</div>
        <div class="status-item">
          <span class="status-key">device</span>
          <span class="status-val" id="gpu-device">--</span>
        </div>
        <div class="status-item">
          <span class="status-key">vram used</span>
          <span class="status-val accent" id="gpu-used">--</span>
        </div>
        <div class="status-item">
          <span class="status-key">vram free</span>
          <span class="status-val" id="gpu-free">--</span>
        </div>
        <div class="status-item">
          <span class="status-key">utilization</span>
          <span class="status-val" id="gpu-util">--</span>
        </div>
        <div class="status-item">
          <span class="status-key">temperature</span>
          <span class="status-val" id="gpu-temp">--</span>
        </div>
        <div class="vram-bar">
          <div class="vram-fill" id="vram-fill" style="width: 0%"></div>
        </div>
      </div>

      <div class="status-card">
        <div class="status-card-title">Ollama</div>
        <div id="ollama-status">
          <div class="status-item">
            <span class="status-key">status</span>
            <span class="status-val" id="ollama-state">checking...</span>
          </div>
        </div>
        <div id="ollama-models"></div>
      </div>
    </div>

    <button class="btn btn-secondary" onclick="refreshStatus()">refresh</button>
    <button class="btn btn-secondary" onclick="unloadOllama()" style="margin-left:8px;">unload ollama models</button>

    <div class="status-card-title" style="margin-top:24px;">available tools</div>
    <div class="tools-list">
      <div class="tool-item"><span class="tool-name">image</span><span class="tool-desc">Stable Diffusion (SDXL Turbo / SD 1.5)</span></div>
      <div class="tool-item"><span class="tool-name">transcribe</span><span class="tool-desc">Faster Whisper (speech-to-text)</span></div>
      <div class="tool-item"><span class="tool-name">speak</span><span class="tool-desc">SpeechT5 (text-to-speech)</span></div>
      <div class="tool-item"><span class="tool-name">music</span><span class="tool-desc">MusicGen-small (text-to-music)</span></div>
    </div>
  </div>

</div>

<footer class="footer">
  <div class="footer-text">substrate // ml toolkit &middot; local-only &middot; RTX 4060 8GB</div>
</footer>

<script>
// ─── Tab switching ───────────────────────────────────────────────────────────

document.querySelectorAll('.tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById('panel-' + tab.dataset.tab).classList.add('active');
    if (tab.dataset.tab === 'status') refreshStatus();
  });
});

// ─── Timer helper ────────────────────────────────────────────────────────────

function startTimer(elId) {
  const el = document.getElementById(elId);
  const start = Date.now();
  const interval = setInterval(() => {
    const s = Math.floor((Date.now() - start) / 1000);
    el.textContent = s + 's';
  }, 1000);
  return interval;
}

function showSpinner(id) {
  document.getElementById(id + '-spinner').classList.add('active');
  document.getElementById(id + '-error').classList.remove('active');
  document.getElementById(id + '-result').classList.remove('active');
  return startTimer(id + '-elapsed');
}

function hideSpinner(id, timer) {
  clearInterval(timer);
  document.getElementById(id + '-spinner').classList.remove('active');
}

function showError(id, msg) {
  const box = document.getElementById(id + '-error');
  box.classList.add('active');
  document.getElementById(id + '-error-detail').textContent = msg;
}

function showResult(id) {
  document.getElementById(id + '-result').classList.add('active');
}

// ─── Image Generation ────────────────────────────────────────────────────────

async function generateImage() {
  const prompt = document.getElementById('img-prompt').value.trim();
  if (!prompt) return;

  const btn = document.getElementById('img-generate');
  btn.disabled = true;
  const timer = showSpinner('img');

  try {
    const body = {
      prompt: prompt,
      model: document.getElementById('img-model').value,
      width: parseInt(document.getElementById('img-width').value),
      height: parseInt(document.getElementById('img-height').value),
    };
    const steps = document.getElementById('img-steps').value;
    if (steps) body.steps = parseInt(steps);
    const seed = document.getElementById('img-seed').value;
    if (seed) body.seed = parseInt(seed);

    const resp = await fetch('/api/image', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body),
    });
    const data = await resp.json();
    hideSpinner('img', timer);

    if (!resp.ok) {
      showError('img', data.error || 'Unknown error');
      return;
    }

    document.getElementById('img-result-img').src = 'data:image/png;base64,' + data.image_b64;
    document.getElementById('img-result-meta').textContent = body.width + 'x' + body.height;
    document.getElementById('img-result-saved').textContent = 'saved: ' + data.saved_to;
    showResult('img');
  } catch (e) {
    hideSpinner('img', timer);
    showError('img', e.message);
  } finally {
    btn.disabled = false;
  }
}

// ─── Transcription ───────────────────────────────────────────────────────────

const audioInput = document.getElementById('audio-file');
const audioDrop = document.getElementById('audio-drop');

audioInput.addEventListener('change', () => {
  const name = audioInput.files[0] ? audioInput.files[0].name : '';
  document.getElementById('audio-file-name').textContent = name;
});

audioDrop.addEventListener('dragover', e => { e.preventDefault(); audioDrop.classList.add('dragover'); });
audioDrop.addEventListener('dragleave', () => { audioDrop.classList.remove('dragover'); });
audioDrop.addEventListener('drop', e => {
  e.preventDefault();
  audioDrop.classList.remove('dragover');
  if (e.dataTransfer.files.length) {
    audioInput.files = e.dataTransfer.files;
    document.getElementById('audio-file-name').textContent = e.dataTransfer.files[0].name;
  }
});

let _transcriptText = '';

async function transcribeAudio() {
  const file = audioInput.files[0];
  if (!file) return;

  const btn = document.getElementById('transcribe-btn');
  btn.disabled = true;
  const timer = showSpinner('transcribe');

  try {
    const formData = new FormData();
    formData.append('audio', file);
    formData.append('model', document.getElementById('whisper-model').value);
    const lang = document.getElementById('whisper-lang').value.trim();
    if (lang) formData.append('language', lang);

    const resp = await fetch('/api/transcribe', {
      method: 'POST',
      body: formData,
    });
    const data = await resp.json();
    hideSpinner('transcribe', timer);

    if (!resp.ok) {
      showError('transcribe', data.error || 'Unknown error');
      return;
    }

    document.getElementById('transcribe-result-meta').textContent =
      data.language + ' | ' + data.duration + 's | ' + data.segments.length + ' segments';

    const segsEl = document.getElementById('transcribe-segments');
    segsEl.innerHTML = '';
    data.segments.forEach(seg => {
      const div = document.createElement('div');
      div.className = 'transcript-segment';
      div.innerHTML = '<span class="segment-time">[' + seg.start + 's - ' + seg.end + 's]</span>' +
                      '<span class="segment-text">' + escapeHtml(seg.text) + '</span>';
      segsEl.appendChild(div);
    });

    _transcriptText = data.full_text;
    showResult('transcribe');
  } catch (e) {
    hideSpinner('transcribe', timer);
    showError('transcribe', e.message);
  } finally {
    btn.disabled = false;
  }
}

function copyTranscript() {
  navigator.clipboard.writeText(_transcriptText).catch(() => {});
}

// ─── Text-to-Speech ──────────────────────────────────────────────────────────

async function generateSpeech() {
  const text = document.getElementById('tts-text').value.trim();
  if (!text) return;

  const btn = document.getElementById('speak-btn');
  btn.disabled = true;
  const timer = showSpinner('speak');

  try {
    const resp = await fetch('/api/speak', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({text: text}),
    });
    const data = await resp.json();
    hideSpinner('speak', timer);

    if (!resp.ok) {
      showError('speak', data.error || 'Unknown error');
      return;
    }

    document.getElementById('speak-audio').src = 'data:audio/wav;base64,' + data.audio_b64;
    document.getElementById('speak-result-meta').textContent = data.sample_rate + 'Hz';
    document.getElementById('speak-result-saved').textContent = 'saved: ' + data.saved_to;
    showResult('speak');
  } catch (e) {
    hideSpinner('speak', timer);
    showError('speak', e.message);
  } finally {
    btn.disabled = false;
  }
}

// ─── Music Generation ────────────────────────────────────────────────────────

async function generateMusic() {
  const prompt = document.getElementById('music-prompt').value.trim();
  if (!prompt) return;

  const btn = document.getElementById('music-btn');
  btn.disabled = true;
  const timer = showSpinner('music');

  try {
    const resp = await fetch('/api/music', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        prompt: prompt,
        duration: parseInt(document.getElementById('music-duration').value),
      }),
    });
    const data = await resp.json();
    hideSpinner('music', timer);

    if (!resp.ok) {
      showError('music', data.error || 'Unknown error');
      return;
    }

    document.getElementById('music-audio').src = 'data:audio/wav;base64,' + data.audio_b64;
    document.getElementById('music-result-meta').textContent = data.duration + 's | ' + data.sample_rate + 'Hz';
    document.getElementById('music-result-saved').textContent = 'saved: ' + data.saved_to;
    showResult('music');
  } catch (e) {
    hideSpinner('music', timer);
    showError('music', e.message);
  } finally {
    btn.disabled = false;
  }
}

// ─── Status ──────────────────────────────────────────────────────────────────

async function refreshStatus() {
  try {
    const resp = await fetch('/api/status');
    const data = await resp.json();

    const gpu = data.gpu;
    document.getElementById('gpu-device').textContent = gpu.device;
    document.getElementById('gpu-used').textContent = Math.round(gpu.used_mb / 1024 * 10) / 10 + ' GB';
    document.getElementById('gpu-free').textContent = Math.round(gpu.free_mb / 1024 * 10) / 10 + ' GB';
    document.getElementById('gpu-util').textContent = gpu.gpu_util + '%';

    const tempEl = document.getElementById('gpu-temp');
    tempEl.textContent = gpu.temp_c + ' C';
    tempEl.className = 'status-val' + (gpu.temp_c > 80 ? ' error' : gpu.temp_c > 65 ? ' warn' : '');

    const pct = gpu.total_mb > 0 ? Math.round(gpu.used_mb / gpu.total_mb * 100) : 0;
    document.getElementById('vram-fill').style.width = pct + '%';

    const ollamaEl = document.getElementById('ollama-state');
    const modelsEl = document.getElementById('ollama-models');
    modelsEl.innerHTML = '';

    if (data.ollama === null) {
      ollamaEl.textContent = 'not running';
      ollamaEl.className = 'status-val error';
    } else if (data.ollama.length === 0) {
      ollamaEl.textContent = 'running (idle)';
      ollamaEl.className = 'status-val accent';
    } else {
      ollamaEl.textContent = 'running (' + data.ollama.length + ' model' + (data.ollama.length > 1 ? 's' : '') + ')';
      ollamaEl.className = 'status-val warn';
      data.ollama.forEach(m => {
        const div = document.createElement('div');
        div.className = 'status-item';
        div.innerHTML = '<span class="status-key">' + escapeHtml(m.name || '?') + '</span>' +
                        '<span class="status-val">' + Math.round((m.size || 0) / 1024/1024/1024 * 10) / 10 + ' GB</span>';
        modelsEl.appendChild(div);
      });
    }

    if (data.current_task) {
      document.getElementById('header-status').textContent = 'running: ' + data.current_task.type;
    } else {
      document.getElementById('header-status').textContent = 'local-only';
    }
  } catch (e) {
    console.error('status fetch failed:', e);
  }
}

async function unloadOllama() {
  try {
    await fetch('/api/unload-ollama', {method: 'POST'});
    setTimeout(refreshStatus, 1000);
  } catch (e) {
    console.error('unload failed:', e);
  }
}

function escapeHtml(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

// Enter key submits on text inputs
document.getElementById('img-prompt').addEventListener('keydown', e => { if (e.key === 'Enter') generateImage(); });
document.getElementById('music-prompt').addEventListener('keydown', e => { if (e.key === 'Enter') generateMusic(); });

// Auto-refresh status on load
refreshStatus();
</script>
</body>
</html>"""


# ─── HTTP Handler ─────────────────────────────────────────────────────────────

class MLHandler(BaseHTTPRequestHandler):
    """Handle HTTP requests for the ML Web UI."""

    def log_message(self, format, *args):
        """Quieter logging."""
        sys.stderr.write(f"[ml-ui] {args[0]}\n")

    def _send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html):
        body = html.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length)

    def _parse_json(self):
        return json.loads(self._read_body())

    def _set_task(self, task_type):
        global _current_task
        with _task_lock:
            if _current_task is not None:
                self._send_json({"error": f"GPU busy: {_current_task['type']} is running"}, 409)
                return False
            _current_task = {"type": task_type, "started": time.time(), "status": "running"}
        return True

    def _clear_task(self, result=None, error=None):
        global _current_task
        with _task_lock:
            if _current_task:
                entry = {
                    "type": _current_task["type"],
                    "started": _current_task["started"],
                    "duration": round(time.time() - _current_task["started"], 1),
                    "status": "error" if error else "done",
                }
                _task_history.append(entry)
                if len(_task_history) > 10:
                    _task_history.pop(0)
            _current_task = None

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self._send_html(HTML_PAGE)
        elif self.path == "/api/status":
            self._handle_status()
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/api/image":
            self._handle_image()
        elif self.path == "/api/transcribe":
            self._handle_transcribe()
        elif self.path == "/api/speak":
            self._handle_speak()
        elif self.path == "/api/music":
            self._handle_music()
        elif self.path == "/api/unload-ollama":
            self._handle_unload_ollama()
        else:
            self.send_error(404)

    def _handle_status(self):
        gpu = get_gpu_status()
        ollama = get_ollama_models()
        self._send_json({
            "gpu": gpu,
            "ollama": ollama,
            "current_task": _current_task,
            "history": _task_history,
        })

    def _handle_image(self):
        if not self._set_task("image"):
            return
        try:
            params = self._parse_json()
            prompt = params.get("prompt", "").strip()
            if not prompt:
                self._send_json({"error": "prompt is required"}, 400)
                self._clear_task(error=True)
                return

            unload_ollama()
            result = task_generate_image(
                prompt=prompt,
                model_key=params.get("model", "sdxl-turbo"),
                steps=params.get("steps"),
                guidance=params.get("guidance"),
                width=params.get("width", 512),
                height=params.get("height", 512),
                seed=params.get("seed"),
            )
            self._clear_task()
            self._send_json(result)
        except Exception as e:
            self._clear_task(error=True)
            self._send_json({"error": str(e), "traceback": traceback.format_exc()}, 500)

    def _handle_transcribe(self):
        if not self._set_task("transcribe"):
            return
        try:
            content_type = self.headers.get("Content-Type", "")
            if "multipart/form-data" not in content_type:
                self._send_json({"error": "expected multipart/form-data"}, 400)
                self._clear_task(error=True)
                return

            # Parse multipart form data
            environ = {
                "REQUEST_METHOD": "POST",
                "CONTENT_TYPE": content_type,
                "CONTENT_LENGTH": self.headers.get("Content-Length", "0"),
            }
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ=environ,
            )

            audio_field = form["audio"]
            if not audio_field.file:
                self._send_json({"error": "no audio file uploaded"}, 400)
                self._clear_task(error=True)
                return

            # Save uploaded file to temp
            UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
            filename = audio_field.filename or "upload.wav"
            safe_filename = "".join(c for c in filename if c.isalnum() or c in ".-_")
            upload_path = UPLOAD_DIR / f"{int(time.time())}_{safe_filename}"
            with open(upload_path, "wb") as f:
                f.write(audio_field.file.read())

            model_size = form.getvalue("model", "base")
            language = form.getvalue("language", None)
            if language == "":
                language = None

            unload_ollama()
            result = task_transcribe(
                audio_path=str(upload_path),
                model_size=model_size,
                language=language,
            )

            # Clean up temp file
            try:
                upload_path.unlink()
            except Exception:
                pass

            self._clear_task()
            self._send_json(result)
        except Exception as e:
            self._clear_task(error=True)
            self._send_json({"error": str(e), "traceback": traceback.format_exc()}, 500)

    def _handle_speak(self):
        if not self._set_task("speak"):
            return
        try:
            params = self._parse_json()
            text = params.get("text", "").strip()
            if not text:
                self._send_json({"error": "text is required"}, 400)
                self._clear_task(error=True)
                return

            unload_ollama()
            result = task_speak(text)
            self._clear_task()
            self._send_json(result)
        except Exception as e:
            self._clear_task(error=True)
            self._send_json({"error": str(e), "traceback": traceback.format_exc()}, 500)

    def _handle_music(self):
        if not self._set_task("music"):
            return
        try:
            params = self._parse_json()
            prompt = params.get("prompt", "").strip()
            if not prompt:
                self._send_json({"error": "prompt is required"}, 400)
                self._clear_task(error=True)
                return

            duration = params.get("duration", 5)
            unload_ollama()
            result = task_compose(prompt, duration=duration)
            self._clear_task()
            self._send_json(result)
        except Exception as e:
            self._clear_task(error=True)
            self._send_json({"error": str(e), "traceback": traceback.format_exc()}, 500)

    def _handle_unload_ollama(self):
        try:
            unload_ollama()
            self._send_json({"ok": True})
        except Exception as e:
            self._send_json({"error": str(e)}, 500)


def main():
    parser = argparse.ArgumentParser(description="ML Toolkit Web UI")
    parser.add_argument("--host", default="127.0.0.1", help="Listen address (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=8190, help="Listen port (default: 8190)")
    args = parser.parse_args()

    # Ensure output dirs exist
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

    server = HTTPServer((args.host, args.port), MLHandler)
    print(f"[ml-ui] serving at http://{args.host}:{args.port}")
    print(f"[ml-ui] output dir: {OUTPUT_DIR}")
    print(f"[ml-ui] audio dir:  {AUDIO_DIR}")
    print(f"[ml-ui] press Ctrl+C to stop")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[ml-ui] shutting down")
        server.shutdown()


if __name__ == "__main__":
    main()
