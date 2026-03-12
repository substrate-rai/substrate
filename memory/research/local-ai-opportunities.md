---
name: Local AI Opportunities
description: Deep research on untapped capabilities for Qwen3 8B + RTX 4060 beyond current usage
type: reference
---

# Local AI Opportunities — RTX 4060 8GB + Qwen3 8B

Research date: 2026-03-11

## 1. Local RAG (highest impact)

Stack: nomic-embed-text (~0.5GB VRAM via Ollama) + ChromaDB (disk/RAM) + Qwen3 8B (~5.5GB). Total ~6GB, fits with headroom.

- Ollama has `/api/embed` endpoint for embeddings
- nomic-embed-text: 137M params, surpasses OpenAI text-embedding-ada-002
- Index `_posts/`, `memory/`, `docs/` into ChromaDB
- Agents query vector store for context before generating — reduces hallucination structurally
- Query latency: 1-3 seconds

## 2. Structured JSON Output

Since Ollama v0.5, pass JSON Schema to `format` parameter for grammar-constrained output. Model literally cannot produce invalid JSON. Every agent producing structured data should use this.

```python
response = chat(messages=[...], format=MySchema.model_json_schema())
```

## 3. Log Anomaly Detection

Extend health-check.sh with Qwen3 pass:
- Pipe `journalctl --since "1 hour ago"` through Qwen3 at temperature=0.1
- Structured JSON output with anomaly categories (13 types: auth failures, resource exhaustion, service crashes, etc.)
- Write alerts to `memory/alerts/`
- Root (infra engineer) agent role

## 4. Piper TTS (zero GPU cost)

CPU-only TTS, already in nixpkgs (`piper-tts`). 10x real-time on CPU. Zero VRAM.

Uses:
- Audio blog posts (accessibility + content diversity)
- Radio station narration (real speech instead of procedural audio)
- Q reading haiku aloud

## 5. Ollama Modelfiles

Bake agent personalities into named model variants:
```
ollama create substrate-byte -f Modelfile.byte
```
Eliminates per-request system prompt overhead. Cleaner context window.

## 6. GoatCounter Analytics Agent

GoatCounter has an API. Weekly script: fetch traffic → Qwen3 interprets top pages, referral sources, LLM crawler patterns → `memory/analytics/`. Feed into content strategy. Pulse agent role.

## 7. Pull qwen2.5-coder:7b

88.4% HumanEval (vs Qwen3 8B's 67.65%). Better for code generation tasks. Same VRAM footprint. Swap as needed.

## 8. RSS Feed Enhancement

Adopt ollama-feed-summarizer pattern for news_researcher.py. More RSS sources, `summary` preset, auto-generate daily digests. Tool: github.com/rb81/ollama-feed-summarizer

---

## VRAM-Swapping Opportunities (can't run alongside Qwen3)

Design as sequential pipelines: unload LLM → run task → reload LLM.

| Tool | VRAM | Use |
|------|------|-----|
| FLUX Schnell NF4 | ~8GB | Better images than SDXL Turbo |
| faster-whisper large-v3-turbo | ~4GB | Speech-to-text (operator voice notes) |
| XTTS v2 | ~2GB | Voice cloning from 6-second sample |
| CogVideoX 1.3B FP8 | ~6-8GB | 2-4 sec video clips, 480p |

---

## Qwen3 8B Key Findings

- Matches Qwen2.5 **14B** on most benchmarks (punches above weight)
- ~15,000 dead vocabulary tokens (~10% of vocab) — can't fix, just know it
- Korean tokens: 60% hallucination rate — avoid Korean content
- Tool calling has "pangu spacing" bug (inserts spaces in arguments)
- Greedy decoding causes infinite loops — always use temperature >= 0.6
- Required sampling: thinking mode temp=0.6/top_p=0.95/top_k=20, non-thinking temp=0.7/top_p=0.8/top_k=20
- Thinking mode boosts complex tasks ~2x but costs tokens
- Qwen3-Embedding-8B exists (separate model, #1 on MTEB multilingual) but can't run via standard Ollama tag

## Fine-Tuning (feasible on this hardware)

Peer-reviewed: arXiv:2509.12229 — LoRA/QLoRA on RTX 4060 case study.

- QLoRA 4-bit + Unsloth: fits 7B models, batch size 1-2
- Use FP16 not BF16 (BF16 degrades on RTX 4060)
- PagedAdamW optimizer: 25% throughput boost
- Could fine-tune Qwen3 on Substrate's blog posts + memory files

## Priority Ranking

1. Local RAG (ChromaDB + nomic-embed) — Medium effort, High impact
2. Structured JSON output in agents — Low effort, High impact
3. Log anomaly detection — Low effort, Medium impact
4. Piper TTS — Low effort, Medium impact
5. GoatCounter analytics agent — Low effort, Medium impact
6. Modelfiles for agents — Low effort, Low impact
7. Pull qwen2.5-coder:7b — Trivial effort, Medium impact
8. Fine-tune on own writing — High effort, High impact (save for later)

## Sources

- Qwen3 Technical Report: arxiv.org/abs/2505.09388
- RTX 4060 LoRA Case Study: arxiv.org/abs/2509.12229
- Ollama Embedding Models: ollama.com/blog/embedding-models
- Ollama Feed Summarizer: github.com/rb81/ollama-feed-summarizer
- Continue.dev Ollama Guide: docs.continue.dev/guides/ollama-guide
- CrewAI LLM Docs: docs.crewai.com/en/concepts/llms
- Piper TTS: github.com/rhasspy/piper
- n8n Self-Hosted AI Starter Kit: github.com/n8n-io/self-hosted-ai-starter-kit
