---
layout: post
title: "How to Route AI Tasks Between a Local GPU Model and a Cloud API"
date: 2026-03-07
description: "Build a two-brain routing layer that sends cheap AI tasks to a local Qwen3 8B model on your GPU and complex tasks to the Claude API. Includes the routing script, quality loop, cost analysis, and NixOS integration."
tags: [two-brain, ai-routing, ollama, claude-api, local-llm, nixos, cost-optimization]
---

This guide shows how to build a routing layer that sends AI tasks to either a local model (Qwen3 8B on an NVIDIA GPU via Ollama) or a cloud API (Claude via Anthropic), based on task type. After one week of use, 95% of tasks run locally for free. Cloud cost: $0.40/week.

## The Problem

Running everything through a cloud API is expensive. Running everything locally is limited — an 8B model can't do complex code review. The solution: route each task to the right model.

## The Routing Table

```python
TASK_ROUTES = {
    "draft":     "local",   # blog posts, social media, first drafts
    "summarize": "local",   # condense text, extract key points
    "health":    "local",   # system health analysis
    "review":    "cloud",   # code review, quality assurance
    "code":      "cloud",   # complex code generation
}
```

No classifier. No embeddings. The caller specifies the task type, and a dictionary lookup maps it to a brain. Simple, reliable, zero overhead.

## Prerequisites

- Ollama running with CUDA ([setup guide](../ollama-cuda-nixos-unstable/))
- An Anthropic API key (for cloud tasks)
- Python 3 with `requests` (for local) and `anthropic` (for cloud)

## The Local Brain

Calls Ollama's REST API at `localhost:11434`:

```python
import subprocess
import sys

def think_local(prompt, model="qwen3:8b"):
    result = subprocess.run(
        [sys.executable, "scripts/think.py",
         "--no-stream", "--model", model, prompt],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()
```

`think.py` is a wrapper that POSTs to Ollama and handles streaming. The router calls it with `--no-stream` to capture the full response.

## The Cloud Brain

Calls the Anthropic API via their Python SDK:

```python
def think_cloud(prompt, model="claude-sonnet-4-20250514"):
    import anthropic

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("error: ANTHROPIC_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model=model,
        max_tokens=4096,
        system="You handle tasks requiring frontier reasoning. Be direct.",
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text
```

The API key is loaded from a `.env` file using a hand-rolled loader (no `python-dotenv` dependency):

```python
def load_env(path=".env"):
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())
```

## Usage

```bash
# Enter dev shell (provides python3 + requests)
nix develop

# Auto-routed by task type
python3 scripts/route.py draft "write a blog post about NixOS flakes"
python3 scripts/route.py summarize "explain this" < some-file.txt
python3 scripts/route.py review "check this code" < scripts/publish.py
python3 scripts/route.py code "write a systemd timer for health checks"
python3 scripts/route.py health

# Override the routing
python3 scripts/route.py draft "important post" --brain cloud
python3 scripts/route.py review "quick check" --brain local
```

## The Quality Loop

Chain both brains: local model drafts (free), cloud model reviews (one API call):

```python
def quality_loop(prompt, local_model="qwen3:8b"):
    print("[pass 1/2] local draft (qwen3)...", file=sys.stderr)
    draft = think_local(prompt, model=local_model)

    review_prompt = (
        "Review this draft. Fix factual errors, tighten prose, "
        "keep structure intact. Output ONLY the revised text.\n\n"
        f"--- DRAFT ---\n{draft}\n--- END DRAFT ---"
    )

    print("[pass 2/2] cloud review (claude)...", file=sys.stderr)
    revised = think_cloud(review_prompt)
    return draft, revised
```

```bash
$ python3 scripts/route.py draft "explain nix flakes" --quality-loop
[pass 1/2] local draft (qwen3)...
[pass 2/2] cloud review (claude)...
--- DRAFT (qwen3) ---
[local model output]

--- REVISED (claude) ---
[cloud-edited output]
```

Cost per quality loop: one free local inference + one API call (~$0.01-0.05). The local model does 90% of the work.

## Health Check Integration

The `health` task type builds its prompt from live system telemetry:

```python
def health_prompt():
    checks = []

    # Ollama status
    try:
        import requests
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        models = [m["name"] for m in resp.json().get("models", [])]
        checks.append(f"ollama: online, models: {', '.join(models)}")
    except Exception:
        checks.append("ollama: offline")

    # GPU
    gpu = subprocess.run(
        ["nvidia-smi", "--query-gpu=name,temperature.gpu,memory.used,memory.total",
         "--format=csv,noheader,nounits"],
        capture_output=True, text=True, timeout=5,
    )
    if gpu.returncode == 0:
        checks.append(f"gpu: {gpu.stdout.strip()}")

    return "System health:\n" + "\n".join(f"  {c}" for c in checks)
```

This always routes locally. Interpreting GPU temperatures doesn't need frontier reasoning.

## Cost After One Week

| Task Type | Brain | ~Count | Cost |
|-----------|-------|--------|------|
| draft | local | 30 | $0.00 |
| summarize | local | 15 | $0.00 |
| health | local | 168 (hourly) | $0.00 |
| review | cloud | 5 | ~$0.25 |
| code | cloud | 3 | ~$0.15 |
| **Total** | | **221** | **$0.40** |

95% of tasks run locally. The cloud handles only what the local model can't.

## What Didn't Work

**Automatic routing by prompt analysis.** Having the local model classify whether a prompt needs the cloud creates a circular problem — the classifier itself needs to be good enough to judge complexity. A lookup table is more reliable.

**Larger local models.** Qwen3 14B doesn't fit in 8 GB VRAM at any reasonable quantization. The 8B model at Q4_0 is the ceiling for this hardware.

## Full Source

The complete router is at [`scripts/route.py`](https://github.com/substrate-rai/substrate/blob/master/scripts/route.py) (265 lines).

Relevant commits:
- [`3dce24b`](https://github.com/substrate-rai/substrate/commit/3dce24b) — Local inference wrapper
- [`7ca03c2`](https://github.com/substrate-rai/substrate/commit/7ca03c2) — Two-brain router
- [`3d0bd26`](https://github.com/substrate-rai/substrate/commit/3d0bd26) — Content pipeline integration

## What's Next

This routing layer powers [substrate](https://github.com/substrate-rai/substrate), a sovereign AI workstation on NixOS. The two-brain architecture feeds into an automated content pipeline: a systemd timer drafts blog posts every night via the local model, with optional cloud review before publishing.

**Related:** [Teaching an 8B Model to Write](../teaching-8b-model-to-write/) | [Sponsor the hardware fund](../sponsor/)
