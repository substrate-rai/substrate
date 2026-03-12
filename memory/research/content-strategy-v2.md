---
name: Content Strategy V2 — Knowledge Hub + News + Retention
description: Synthesis of research on becoming an AI knowledge source, live news feeds, and homepage retention
type: reference
---

# Content Strategy V2

Research date: 2026-03-11
Sources: 3 parallel research agents + prior discoverability research

## Strategic Direction

Substrate's niche: **"self-hosted AI on consumer hardware, built in public."**

Nobody else covers this from the practitioner-builder perspective with Substrate's transparency. The competitive advantage is authenticity — real builds on real hardware, documented as they happen.

## Three Pillars

### 1. THE BLOG — A Diary of the Journey

The blog is Substrate's soul. It documents the journey — every build, every failure, every decision. This is what makes it unique vs corporate AI blogs.

**Format:** Diary-style project log + technical guides + weekly AI digest

**Content clusters (pillar pages needed):**
- `/guides/local-ai/` — pillar: "Local AI Inference: The Complete Guide"
- `/guides/nixos/` — pillar: "NixOS for AI Workloads"
- `/guides/ollama/` — pillar: "Building with Ollama"
- Each pillar links to 5-10 focused cluster posts

**Cadence:**
- Project log entries: whenever something ships (diary)
- Technical guides: 1-2/week (Scribe pipeline)
- Weekly AI digest: every Wednesday (Byte)
- Original benchmarks: monthly (unique content nobody else produces)

**Key insight:** Run original benchmarks on the RTX 4060. "Qwen3 8B vs Llama 3 8B on a $800 laptop" is content only Substrate can produce.

### 2. THE NEWS SECTION — Live AI Intelligence

**Architecture:**
- `news_researcher.py` writes to `_data/news.json`
- GitHub Actions cron rebuilds site 2-4x daily (6am, 12pm, 6pm, 10pm ET)
- Jekyll templates render news from `_data/news.json`
- Client-side HN widget fills gaps between builds (HN Firebase API supports CORS)

**RSS sources to add:**
- Tier 1: Anthropic, OpenAI, HuggingFace blog feeds
- Tier 2: arXiv cs.AI+cs.CL+cs.LG combined feed
- Tier 3: Reddit r/LocalLLaMA, r/MachineLearning (JSON API)
- Tier 4: IEEE Spectrum AI, InfoQ AI/ML, TechCrunch AI

**Qwen's role:** Scan feeds every 6 hours, classify relevance, generate Byte's 1-2 sentence editorial commentary per story. This is the value-add — not raw links, but "why this matters for local AI."

**Format per story:**
```
**[Headline](source-url)** — Source Name
Byte's 1-2 sentence take. Why this matters for sovereign AI.
```

**Legal:** Headlines + links + original commentary = transformative fair use. Always link to originals.

### 3. THE HOMEPAGE — Retention Engine

**Current state:** Feed-style with portal elements. Good foundation but every feed item has equal visual weight and there are three CTAs diluting the primary action.

**Quick wins (implement now):**
- Reduce CTAs to two above fold (primary + secondary)
- Reading progress bar on blog posts
- "New" badges on posts < 48h old
- Relative timestamps ("2 hours ago" not "2026-03-11")
- Back-to-top button on mobile
- Related posts already added (done in this session)

**Medium effort:**
- Referrer-based welcome: `?ref=hn` → "Welcome from Hacker News"
- localStorage "recently read" tracking (mark posts as read)
- Visit counter: different messaging for new vs returning
- Series navigation (prev/next within training-q, news, sovereignty)

**Larger projects:**
- Achievement system (localStorage): games played, posts read, radio listened
- Embedded interactive widget (VRAM calculator or model comparison tool)
- Bottom navigation bar on mobile
- Persistent mini radio player

## The Killer Tool Opportunity

**One interactive tool generates more backlinks than 20 blog posts.**

Best candidates for Substrate:
1. **VRAM Calculator** — "What GPU do you need for this model?" Input model + quantization → output VRAM needed, recommended GPUs, expected performance. Shareable, linkable, fills a real gap.
2. **Local AI Model Comparison** — Side-by-side benchmark results from the RTX 4060. Real data from real hardware.
3. **Papers With Code died (July 2025)** — Benchmark tracking for consumer GPUs would fill a massive vacuum.

## Qwen's Recast Role

Qwen is NOT the writer. Qwen is the **always-on worker**:
- Scans RSS feeds for news (every 6 hours)
- Classifies and scores relevance
- Generates structured JSON output (not prose)
- Writes Byte's editorial commentary (short, structured)
- Embeds content for RAG search
- Runs health checks and log processing

Claude writes published content. The laptop is the engine room, not the pen.

## Newsletter Strategy

**Buttondown** — Markdown-first, API-driven, 0% revenue cut, free tier covers 100 subscribers.
- Weekly digest: top 3-5 stories + 1 project update + 1 guide link
- Archives are SEO-indexable
- Can automate from the content pipeline
- Same-day-every-week cadence (Wednesday matches The Batch pattern)

## Monetization Path (future)

1. Phase 1 (0-1K subscribers): Free content, build audience
2. Phase 2 (1K-5K): Newsletter sponsorships ($50-250/placement)
3. Phase 3 (5K-10K): Premium content tier or course
4. Phase 4 (10K+): Multiple streams (sponsors + premium + consulting leads)

## Implementation Priority

### Immediate (this week)
1. Set up GitHub Actions cron for 4x daily rebuild
2. Expand news_researcher.py RSS sources
3. Add _data/news.json output from news pipeline
4. Build news section template in Jekyll
5. Create pillar pages: /guides/, /learn/
6. Reduce homepage CTAs to two
7. Add "New" badges and relative timestamps to feed

### This month
8. Build VRAM calculator tool
9. Set up Buttondown newsletter
10. Run first original RTX 4060 benchmark and publish
11. Add client-side HN widget to news section
12. Create series index pages
13. Add referrer-based welcome messages
14. Submit to awesome-selfhosted

### Ongoing
15. Weekly AI digest (Wednesday)
16. Blog every build as diary entry
17. Cross-post guides to Dev.to + Hashnode
18. Monthly original benchmark
19. Update VRAM calculator with new models

## Sources

Full source lists in:
- memory/research/discoverability-research.md
- memory/research/content-distribution-2025-2026.md
- memory/research/local-ai-content-landscape.md
- memory/research/homepage-retention-patterns.md
