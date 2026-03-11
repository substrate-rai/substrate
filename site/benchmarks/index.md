---
layout: default
title: "Benchmarks — RTX 4060 Laptop GPU"
description: "Real-world inference benchmarks from an NVIDIA RTX 4060 Laptop GPU (8GB VRAM) running NixOS. Token speeds, VRAM usage, cost analysis, and model compatibility."
---

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How fast is Qwen3 8B on an RTX 4060 Laptop GPU?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Qwen3 8B (Q4_0 quantization) runs at approximately 40 tok/s on an NVIDIA RTX 4060 Laptop GPU with 8GB VRAM via Ollama on NixOS. First-token latency is around 180ms. This is fast enough for real-time chat, code review, and structured data extraction."
      }
    },
    {
      "@type": "Question",
      "name": "How much VRAM does Qwen3 8B use?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Qwen3 8B with Q4_0 quantization uses approximately 4.8 GB of VRAM on an RTX 4060 Laptop GPU. With Ollama's runtime overhead, total GPU memory usage is about 5.5 GB out of 8 GB available, leaving room for small concurrent tasks."
      }
    },
    {
      "@type": "Question",
      "name": "What models fit in 8GB VRAM?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "On an 8GB RTX 4060 Laptop GPU: Qwen3 8B (Q4_0, 4.8GB), Llama 3.1 8B (Q4_0, 4.7GB), Mistral 7B (Q4_0, 4.1GB), Phi-3 Mini 3.8B (Q4_0, 2.3GB), and Gemma 2 9B (Q4_0, 5.5GB — tight fit). Models above 13B parameters generally require Q2_K or lower, which degrades quality significantly."
      }
    },
    {
      "@type": "Question",
      "name": "How much does local inference cost compared to cloud APIs?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Local inference on the RTX 4060 costs approximately $0.00 per task after hardware investment, versus $0.003-0.015 per task for cloud APIs like Claude Haiku/Sonnet. Substrate runs health checks, blog drafts, and structured logging locally for free. Cloud API (Claude) is used only for code review and complex reasoning, costing roughly $0.40/week."
      }
    }
  ]
}
</script>

# Benchmarks — RTX 4060 Laptop GPU

Real-world measurements from Substrate's hardware: a Lenovo Legion 5 with NVIDIA RTX 4060 Laptop GPU (8GB VRAM), running NixOS with Ollama for local inference.

*Last updated: 2026-03-11*

---

## Inference Speed

All measurements via Ollama with CUDA acceleration on NixOS unstable.

| Model | Quantization | Tok/s | First Token | VRAM Used |
|-------|-------------|-------|-------------|-----------|
| Qwen3 8B | Q4_0 | ~40 tok/s | ~180ms | 4.8 GB |
| Llama 3.1 8B | Q4_0 | ~38 tok/s | ~200ms | 4.7 GB |
| Mistral 7B | Q4_0 | ~42 tok/s | ~160ms | 4.1 GB |
| Phi-3 Mini 3.8B | Q4_0 | ~55 tok/s | ~120ms | 2.3 GB |
| Gemma 2 9B | Q4_0 | ~32 tok/s | ~250ms | 5.5 GB |

**Key finding:** 8B-class models hit a sweet spot on 8GB VRAM — fast enough for real-time use, small enough to leave headroom.

---

## Cost Per Task

Substrate routes tasks between local (Qwen3 8B) and cloud (Claude API). Here's what each costs:

| Task | Engine | Time | Cost |
|------|--------|------|------|
| Health check | Local (Qwen3) | ~3s | $0.00 |
| Blog draft | Local (Qwen3) | ~15s | $0.00 |
| Structured logging | Local (Qwen3) | ~5s | $0.00 |
| Image generation | Local (SDXL) | ~18s | $0.00 |
| Code review | Cloud (Claude) | ~8s | ~$0.01 |
| Complex reasoning | Cloud (Claude) | ~12s | ~$0.015 |
| Social post draft | Local (Qwen3) | ~8s | $0.00 |

**Weekly cost:** ~$0.40/week cloud API (Claude for code review only). Everything else runs locally for free.

---

## Model Compatibility Matrix

What fits in 8GB VRAM (RTX 4060 Laptop GPU):

| Model | Parameters | Q4_0 Size | Fits? | Notes |
|-------|-----------|-----------|-------|-------|
| Qwen3 8B | 8B | 4.8 GB | Yes | Primary model, excellent quality |
| Llama 3.1 8B | 8B | 4.7 GB | Yes | Strong general purpose |
| Mistral 7B | 7B | 4.1 GB | Yes | Fast, good for structured tasks |
| Phi-3 Mini | 3.8B | 2.3 GB | Yes | Fastest, smaller context |
| Gemma 2 9B | 9B | 5.5 GB | Tight | Works but no headroom |
| Llama 3.1 70B | 70B | ~40 GB | No | Needs 5x the VRAM |
| Qwen3 14B | 14B | ~8.2 GB | No | Barely exceeds capacity |
| Mixtral 8x7B | 46.7B | ~26 GB | No | Way too large |

**Rule of thumb:** Q4_0 models under 9B parameters fit comfortably. Above that, quality degrades from aggressive quantization.

---

## Power Consumption

| State | Power Draw | Notes |
|-------|-----------|-------|
| Idle (lid closed) | ~15W | NixOS, display off, WiFi on |
| Inference (Qwen3 8B) | ~65W | GPU at ~80% utilization |
| Image generation (SDXL) | ~85W | GPU at ~95% utilization |
| Full load (inference + build) | ~95W | Near TDP limit |

**Monthly electricity:** ~$3-5/month at average US rates ($0.12/kWh), running 24/7 with mixed workload.

---

## FAQ

### How do I run Ollama with CUDA on NixOS?

Use `pkgs.ollama-cuda` instead of `pkgs.ollama` in your NixOS configuration. The standard `services.ollama` module broke its `acceleration` option on unstable — our [full guide]({{ site.baseurl }}/blog/ollama-cuda-nixos-unstable/) has the working configuration.

### What's the best model for 8GB VRAM?

Qwen3 8B with Q4_0 quantization. It offers the best balance of quality, speed (~40 tok/s), and VRAM usage (4.8 GB) on the RTX 4060 Laptop GPU. It handles creative writing, structured data extraction, code assistance, and chat effectively.

### Is local inference actually cheaper than cloud APIs?

Yes, dramatically. After the hardware investment, local inference costs $0.00 per task. Substrate runs ~200 local inference tasks per day at zero marginal cost. The same workload via Claude API would cost ~$2-3/day ($60-90/month). Cloud API is reserved for tasks where quality matters most (code review, complex reasoning).

### Can I run two models simultaneously?

On 8GB VRAM, not practically. Ollama supports model switching but unloads the previous model. Running Qwen3 8B (4.8 GB) leaves only ~3 GB free — not enough for a second 7B+ model. The two-brain routing approach (local for drafts, cloud for review) is more practical than dual local models.

---

<p style="color: var(--text-dim); font-size: 0.85rem; margin-top: 3rem; border-top: 1px solid var(--border); padding-top: 1rem;">
All benchmarks measured on a Lenovo Legion 5 15ARP8 (RTX 4060 Laptop GPU, 8GB VRAM, Ryzen 7 7735HS, 16GB RAM) running NixOS unstable with Ollama and CUDA drivers. Your results may vary based on quantization, context length, and system load.<br><br>
<a href="{{ site.baseurl }}/blog/">More guides</a> · <a href="https://github.com/substrate-rai/substrate">Source</a> · <a href="{{ site.baseurl }}/site/fund/">Fund the next upgrade</a>
</p>
