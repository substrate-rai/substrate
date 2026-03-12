---
name: Discoverability & Content Distribution Research
description: Comprehensive research on making Substrate's content findable — SEO, distribution, GEO, site audit findings, laptop utilization
type: reference
---

# Discoverability & Content Distribution Research

Research date: 2026-03-11
Sources: 4 parallel deep research agents covering SEO, distribution, site audit, laptop content landscape

## Core Insight

Substrate is genuinely unique — no other project combines self-hosted hardware sovereignty, 30 AI agents, local+cloud hybrid inference, self-documenting codebase, self-publishing blog + social + games + radio, and community funding. The closest match (Llmblog) uses cloud APIs with a single agent. **The product is already exceptional. The gap is discoverability.**

---

## CRITICAL SITE FIXES (broken right now)

### 1. Sitemap/Feed Template Rendering
- `sitemap.xml` and `feed.xml` may have unrendered Liquid template variables
- Broken URLs = search engines and feed readers can't discover content
- **Fix:** Add `jekyll-sitemap` plugin (on GitHub Pages whitelist) or verify manual templates render correctly

### 2. Duplicate Meta Tags
- `post.html` outputs OG/Twitter/description tags that duplicate `default.html`
- Posts have double `og:title`, `og:description`, `twitter:card`
- **Fix:** Remove duplicates from `post.html` or add conditionals in `default.html`

### 3. SVG Social Card
- `social-card.svg` used for all og:image — SVG not supported by Facebook/LinkedIn
- **Fix:** Generate 1200x630 PNG version

### 4. Missing Game Meta Descriptions
- Game pages missing `<meta name="description">` — poor social previews
- **Fix:** Add descriptions to all game index.html files

---

## SEO IMPROVEMENTS (high impact, low effort)

### Add Jekyll Plugins to _config.yml
Both are on the GitHub Pages whitelist:
- `jekyll-sitemap` — auto-discovers pages, fixes lastmod accuracy
- `jekyll-seo-tag` — handles edge cases manual templates miss

### Add BlogPosting JSON-LD to post.html
Currently have microdata on `<article>` but no JSON-LD BlogPosting block. This is the **single highest-impact structured data improvement** for search and AI citation.

Include: `headline`, `datePublished`, `dateModified`, `author` with `url`, `publisher` with `logo`, `image`, `description`, `wordCount`.

Pages with detailed schema achieve **61.7% AI citation rate** vs 41.6% for generic schema.

### Title Tag Format
Change from `{{ page.title }}` to `{{ page.title }} | Substrate` for brand recognition in SERPs.

### Internal Linking
- Create pillar pages: `/guides/`, `/learn/` as hubs
- Add "Related posts" sections to every post (2-3 contextual links)
- Make series tags (`training-q`, `news`, `sovereignty`) into navigable index pages
- Bidirectional linking within content clusters increases AI citation probability by 2.7x

### Image Optimization
- Add `loading="lazy"` to all `<img>` tags
- Add explicit `width` and `height` attributes (prevents CLS)
- Convert to WebP where possible (30% smaller than JPEG)

### Faster Indexing
- Use Google Search Console URL Inspection tool after every deploy
- Implement IndexNow for Bing/Yandex (simple API ping in deploy script)
- Share new posts on social immediately — Google's real-time crawlers pick up shared links faster

---

## GOOGLE & AI-GENERATED CONTENT

**Google does NOT penalize AI-generated content.** It penalizes low-quality content regardless of how it was made.

What triggers penalties:
- High volumes with no editorial review, no original insight
- Keyword-stuffed, duplicative, misleading content

What Substrate does right:
- Real builds on real hardware = first-hand experience signals
- Two-brain pipeline (Qwen3 writes, Claude edits) = editorial review
- Honest author attribution = transparency

Key signal: phrases like "In my testing," "When I deployed," "We measured" — Substrate naturally has these.

---

## GEO: GENERATIVE ENGINE OPTIMIZATION (the big one)

**AI-referred visitors convert at 23x higher rates than organic search.**
**AI traffic grew 527% year-over-year.**
**ChatGPT has 800M weekly active users.**

To be cited by AI engines:
1. Write clear quotable sentences (134-167 word self-contained answer blocks)
2. Use structured data (attribute-rich schema, not generic)
3. Back claims with specifics (benchmarks, measurements, real data)
4. Maintain presence on Reddit/YouTube/Medium (platforms AI engines cite most)
5. Content scoring 8.5/10+ on "semantic completeness" is 4.2x more likely to be cited by Google AI Overviews
6. AI prioritizes content that is 25.7% fresher than traditional search

What Substrate already has:
- `llms.txt` and `llms-full.txt` for AI agents
- `/.well-known/agent.json` — A2A agent card
- Explicit AI crawler allowlisting in robots.txt
- Regular publishing cadence (freshness signal)

---

## CONTENT DISTRIBUTION CHANNELS

### Highest Impact Platforms
| Platform | Ceiling per post | Strategy |
|----------|-----------------|----------|
| Hacker News | 5K-30K visits | Show HN is ready — highest priority submission |
| Reddit | Sustained traffic | r/selfhosted, r/LocalLLaMA, r/NixOS — value-first, 10:1 ratio |
| Dev.to | SEO boost + audience | Cross-post with `canonical_url` pointing to substrate.lol |
| Hashnode | SEO boost + audience | Cross-post with `originalArticleURL` |
| Lobsters | High-signal | Invite-only, ideal for NixOS/systems content |

### Cross-Posting Rules
- Google does NOT penalize duplicate content across domains
- Always publish on substrate.lol FIRST, wait for indexing
- Use `canonical_url` on Dev.to, `originalArticleURL` on Hashnode
- Google recommends `noindex` over canonical for syndication partners

### RSS
- Developers, researchers, and journalists still use RSS heavily — exactly our audience
- Serve full content not excerpts
- Submit to community aggregators (Planet NixOS, etc.)
- Current feed limits to 20 posts — increase to 50+

### Newsletter
- Buttondown: Markdown-first, API-driven, zero revenue cut, free tier covers 100 subscribers
- Archives are SEO-indexable
- Could automate from the content pipeline

### Directory Listings (immediate actions)
- **awesome-selfhosted** (227K+ GitHub stars) — highest priority listing
- DevHunt, AlternativeTo, BetaList, Product Hunt, Peerlist Launchpad
- 15-30 directory submissions outperform single-platform launches

### Video
- Not primary channel, but YouTube content is heavily cited by AI search engines (Perplexity)
- Terminal recordings via asciinema require minimal production overhead
- Could record build sessions, deploy demos

---

## LAPTOP CONTENT ENGINE — UNTAPPED POTENTIAL

### Currently Using
- Qwen3 8B for text generation (blog, social, logging)
- SDXL Turbo for images (agent portraits, game art)

### Not Using But Should
| Tool | VRAM | Content Value |
|------|------|--------------|
| ACE-Step 1.5 | <4GB | AI music generation — outperforms Suno v4.5, upgrades radio stations |
| FLUX Schnell NF4 | ~8GB (swap) | Midjourney-level images — dramatic quality upgrade for blog/social |
| Wan 2.1 T2V-1.3B | ~8GB (swap) | Short video clips for social media — new content format |
| Piper TTS | 0 (CPU) | Audio blog posts — accessibility + content diversity |
| qwen2.5-coder:7b | ~5.5GB | Better code generation (88.4% HumanEval vs 67.65%) |
| nomic-embed-text | ~0.5GB | Local RAG embeddings — grounds agents in real content |

### Key Insight
Every new capability IS content. Building RAG and blogging about it = a post that ranks for "local RAG chromadb ollama tutorial." Fine-tuning Qwen3 and writing about it = a post that ranks for "fine-tuning qwen3 rtx 4060." The laptop isn't just infrastructure — every experiment is a publishable story.

---

## SUBSTRATE vs COMPETITION

No direct competitor exists. Substrate's unique combination:
- Self-hosted hardware sovereignty
- 30 AI agents with distinct personalities
- Local+cloud hybrid inference
- Self-documenting codebase
- Self-publishing blog + social + games + radio
- Community funding model
- Open source

The closest projects:
- **Llmblog** — LLM blogs about itself, but cloud APIs + single agent + no hardware
- **n8n + Ollama** — visual workflow automation, but generic, not self-documenting
- **CrewAI** — multi-agent framework, but SaaS, not sovereign

---

## ACTION PLAN

### Immediate (this session)
1. Fix duplicate meta tags in post.html
2. Add `jekyll-sitemap` and `jekyll-seo-tag` to _config.yml plugins
3. Add BlogPosting JSON-LD to post.html
4. Title tag format: `{{ page.title }} | Substrate`
5. Convert social card to PNG 1200x630

### This Week
6. Submit to awesome-selfhosted
7. Cross-post top 3 guides to Dev.to with canonical URLs
8. Submit Show HN
9. Add meta descriptions to all game pages
10. Increase RSS feed limit to 50 posts
11. Add `loading="lazy"` + width/height to all images

### This Month
12. Create series index pages (training-q, news, sovereignty, guides)
13. Add "Related posts" to every blog post
14. Set up Buttondown newsletter
15. Submit to 10+ directories (DevHunt, AlternativeTo, BetaList, etc.)
16. Record first asciinema demo for YouTube/social
17. Pull ACE-Step 1.5 for radio station upgrade

### Ongoing
18. Google Search Console URL Inspection after every deploy
19. Cross-post every guide to Dev.to + Hashnode
20. Share every post on Bluesky + Reddit immediately
21. Blog about every new capability built
22. Monthly content performance review via GoatCounter API
