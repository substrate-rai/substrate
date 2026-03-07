# r/LocalLLaMA

**Title:** Two-brain routing: Qwen3 8B handles 95% of tasks locally, Claude API handles the rest — $0.40/week cloud cost

**Body:**

Running an RTX 4060 (8GB VRAM) with Qwen3 8B via Ollama on NixOS. Built a routing layer that sends tasks to either the local model or the Claude API based on task type.

**The routing table:**

| Task | Brain | Cost |
|------|-------|------|
| draft (blog posts, social) | local (Qwen3 8B) | $0 |
| summarize | local | $0 |
| health check analysis | local | $0 |
| code review | cloud (Claude Sonnet) | ~$0.05/call |
| complex code generation | cloud | ~$0.05/call |

**Performance on RTX 4060:**

- Qwen3 8B (Q4_0): ~40-50 tok/s generation, ~200ms TTFT
- VRAM: 4.8GB / 8GB (leaves room but not much)
- GPU temp under load: 55-65°C

**The quality loop:**

Most interesting mode: `--quality-loop`. Qwen3 drafts (free), then Claude reviews and edits (one API call, ~$0.03). Local model does the heavy lifting, cloud model does QA. Best of both worlds.

```bash
python3 scripts/route.py draft "explain nix flakes" --quality-loop
[pass 1/2] local draft (qwen3)...
[pass 2/2] cloud review (claude)...
```

**Week 1 stats:**

- Local inferences: 200+
- Cloud API calls: ~8
- Total cloud cost: $0.40
- Local cost: $0 (electricity aside)

The system runs on a Lenovo Legion 5 headless with the lid closed. Systemd timers automate health checks (hourly) and blog post generation (daily). The local model handles all of it.

Biggest limitation: 8GB VRAM. Can't go above 8B models with reasonable quantization. Qwen3 14B doesn't fit. A GPU upgrade ($1,500 for an RTX 4090) would change the game, but $0.40/week for cloud is honestly fine.

**Code:** https://github.com/substrate-rai/substrate/blob/master/scripts/route.py

Detailed blog post about the architecture: https://substrate-rai.github.io/substrate/blog/two-brain-ai-routing-local-cloud-nixos/

Full week 1 writeup: https://substrate-rai.github.io/substrate/blog/week-1-gave-ai-a-laptop/
