# SEO Audit — Substrate Blog

**Date:** 2026-03-07
**URL:** https://substrate-rai.github.io/substrate/
**Auditor:** Claude (managing intelligence)

---

## Infrastructure Assessment

### _config.yml
- **Status:** Adequate but minimal.
- `title` and `description` are set.
- `baseurl` and `url` are correct for GitHub Pages.
- `permalink: /blog/:title/` produces clean, keyword-rich URLs.
- **Missing:** No `twitter:` or social handle metadata. No `lang` setting (though the layout hardcodes `lang="en"`). No `jekyll-seo-tag` plugin (not critical since the layout handles meta tags manually).

### Sitemap (sitemap.xml)
- **Status:** Present. Liquid-generated, includes all posts with `priority: 0.8`. Referenced in `robots.txt`.

### RSS Feed (feed.xml)
- **Status:** Present. Includes last 20 posts. Linked in `<head>` via `<link rel="alternate">`.

### robots.txt
- **Status:** Good. `Allow: /`, sitemap reference, AI/LLM notes.

### Canonical URLs
- **Status:** Set correctly in `default.html` via `<link rel="canonical">`.

### Open Graph
- **Status:** Present in `default.html`. Includes `og:title`, `og:description`, `og:url`, `og:site_name`, `og:type`.
- **Missing:** `og:image` (no social sharing image). This hurts click-through on Bluesky, X, and link previews.

### JSON-LD Structured Data
- **Status:** Present. `WebSite` schema on all pages, `BlogPosting` schema on posts with headline, dates, author, keywords.

### Meta Descriptions
- **Status:** The layout falls back to `page.description` > `page.excerpt` > `site.description`. Posts with explicit `description:` frontmatter get proper meta descriptions.

---

## Per-Post Audit

### 1. Day 0: Substrate Is Alive
- **File:** `_posts/2026-03-06-day-0-substrate-is-alive.md`
- **Title:** CHANGED. Added "Building a Sovereign AI Workstation on NixOS" for searchability.
- **Description:** ADDED. Was missing entirely.
- **Tags:** ADDED. `[substrate, nixos, sovereign-ai, lenovo-legion-5, bootstrap]`
- **Internal links:** ADDED. Link to Day 1 post.
- **External links:** ADDED. GitHub repo and sponsor page.
- **Headings:** Good. "The SQUASHFS Errors", "The Wifi Fight", etc. are specific.

### 2. Day 1: Building a Voice
- **File:** `_posts/2026-03-06-day-1-building-a-voice.md`
- **Title:** CHANGED. Added "Blog, Bluesky, SEO, and Self-Publishing AI" for keyword coverage.
- **Description:** ADDED. Was missing entirely.
- **Tags:** ADDED. `[substrate, bluesky, seo, jekyll, self-publishing, sovereign-ai]`
- **Internal links:** ADDED. Links to Day 0 and Week 1.
- **External links:** ADDED. GitHub repo and sponsor page.
- **Headings:** Good. "The Flake", "The Publisher", "The SEO Layer" are specific.

### 3. Week 1: I Gave an AI a Laptop
- **File:** `_posts/2026-03-07-week-1-gave-ai-a-laptop.md`
- **Title:** KEPT. Already highly searchable and compelling.
- **Description:** ADDED. Was missing entirely.
- **Tags:** ADDED. `[substrate, sovereign-ai, nixos, local-llm, weekly-report]`
- **Internal links:** ADDED. Links to all 4 technical guides.
- **External links:** ADDED. GitHub repo and sponsor page. (Already had substrate link in footer.)
- **Headings:** Good. Uses ### for sub-sections (Day 0, Day 1, etc.).

### 4. Installing NixOS on Lenovo Legion 5
- **File:** `_posts/2026-03-07-installing-nixos-lenovo-legion-5-15arp8.md`
- **Title:** KEPT. Excellent — contains exact hardware model, OS, and key components.
- **Description:** Already present, 158 chars. Good.
- **Tags:** ADDED. `[nixos, lenovo-legion-5, nvidia, rtx-4060, luks, installation-guide]`
- **Internal links:** Already had links to Ollama and Two-Brain posts.
- **External links:** ADDED sponsor link. Already had GitHub repo link.
- **Headings:** Excellent. "Error: SQUASHFS Decompression Failure on Boot", "Error: WiFi Not Working on Minimal ISO" — these match exact Google queries.

### 5. Ollama with CUDA on NixOS Unstable
- **File:** `_posts/2026-03-07-ollama-cuda-nixos-unstable.md`
- **Title:** KEPT. Strong — "How to Run Ollama with CUDA on NixOS Unstable" matches search intent.
- **Description:** Already present, 157 chars. Good.
- **Tags:** ADDED. `[ollama, cuda, nixos, gpu, qwen3, local-llm, rtx-4060]`
- **Internal links:** Already had link to NixOS install guide and two-brain routing.
- **External links:** ADDED sponsor link. Already had GitHub repo link.
- **Headings:** Excellent. "Error: services.ollama.acceleration Does Not Exist" matches exact error message.

### 6. Two-Brain AI Routing
- **File:** `_posts/2026-03-07-two-brain-ai-routing-local-cloud-nixos.md`
- **Title:** KEPT. Good — "How to Route AI Tasks Between a Local GPU Model and a Cloud API".
- **Description:** Already present, 160 chars. Good.
- **Tags:** ADDED. `[two-brain, ai-routing, ollama, claude-api, local-llm, nixos, cost-optimization]`
- **Internal links:** ADDED link to "Teaching an 8B Model to Write". Already had Ollama guide link.
- **External links:** ADDED sponsor link. Already had GitHub repo link.
- **Headings:** Good. "The Routing Table", "The Quality Loop", "Cost After One Week".

### 7. Claude Code on NixOS
- **File:** `_posts/2026-03-07-claude-code-nixos-setup.md`
- **Title:** KEPT. "How to Set Up Claude Code on NixOS" — clear and searchable.
- **Description:** Already present, 153 chars. Good.
- **Tags:** ADDED. `[claude-code, nixos, anthropic, ai-cli, devshell, setup-guide]`
- **Internal links:** Already had links to Ollama and two-brain routing guides.
- **External links:** ADDED sponsor link. Already had GitHub repo link.
- **Headings:** Good. "Error: Interpreter Not Found" matches exact error.

### 8. What Happens When an AI Runs Out of WiFi
- **File:** `_posts/2026-03-07-what-happens-when-ai-runs-out-of-wifi.md`
- **Title:** KEPT. Compelling, curiosity-driven.
- **Description:** Already present. Good.
- **Tags:** Already present. `[substrate, sovereign-ai, funding, wifi, hardware]`
- **Internal links:** ADDED. Links to Day 0 and Week 1 posts. Was missing internal links.
- **External links:** Already had GitHub, Ko-fi, and GitHub Sponsors links.

### 9. Training Q, Episode 1: First Bars
- **File:** `_posts/2026-03-07-training-q-episode-1-first-bars.md`
- **Title:** KEPT. Niche but good for the series.
- **Description:** Already present. Good.
- **Tags:** Already present. `[training-q, qwen3, rap, prompt-engineering, local-llm]`
- **Internal links:** ADDED. Links to "Teaching 8B" and "Two-Brain Routing". Was missing.
- **External links:** ADDED sponsor link. Already had GitHub repo link.

### 10. Teaching an 8B Model to Write
- **File:** `_posts/2026-03-07-teaching-8b-model-to-write.md`
- **Title:** KEPT. Good — "Teaching an 8B Model to Write" is searchable for prompt engineering audience.
- **Description:** Already present. Good.
- **Tags:** Already present. `[training-q, local-llm, qwen3, prompt-engineering, two-brain, content-generation]`
- **Internal links:** ADDED. Links to Training Q episode, Two-Brain routing, and Ollama guide. Was missing.
- **External links:** ADDED sponsor link. Already had GitHub repo link.

---

## Tag Consistency

Tags used across posts (after edits):
- `substrate` (3 posts) — project identity
- `nixos` (5 posts) — primary platform
- `sovereign-ai` (4 posts) — core concept
- `local-llm` (4 posts) — local inference
- `ollama` (2 posts) — inference server
- `cuda` (1 post) — GPU acceleration
- `rtx-4060` (2 posts) — specific GPU
- `lenovo-legion-5` (2 posts) — specific hardware
- `two-brain` (2 posts) — routing architecture
- `prompt-engineering` (2 posts) — voice/prompt work
- `training-q` (2 posts) — series tag
- `qwen3` (2 posts) — local model
- `jekyll` (1 post) — blog platform
- `bluesky` (1 post) — social media
- `seo` (1 post) — search optimization
- `claude-code` (1 post) — AI CLI tool

Tags are specific and consistent. No duplicates or near-synonyms.

---

## Summary of Changes Made

| Change | Posts Affected |
|--------|---------------|
| Added `description:` frontmatter | 3 (Day 0, Day 1, Week 1) |
| Added `tags:` frontmatter | 7 (all posts that were missing them) |
| Improved title for searchability | 2 (Day 0, Day 1) |
| Added internal links | 7 (all posts that lacked cross-links) |
| Added sponsor/funding links | 8 (all posts that lacked them) |
| Added GitHub repo links | 3 (Day 0, Day 1, Week 1) |

---

## Recommendations (Not Implemented — Require Operator Decision)

1. **Add `og:image`** — Create a social sharing image (1200x630px) and set it in `_config.yml` as a default. This significantly improves click-through from social media link previews.

2. **Add `twitter:card` meta tags** — The layout has Open Graph but no Twitter Card tags. Add `twitter:card`, `twitter:title`, `twitter:description` to `default.html`.

3. **Add `jekyll-seo-tag` plugin** — Would auto-generate many meta tags. Not critical since the layout handles them manually, but reduces maintenance.

4. **Backlink the technical posts from each other more aggressively** — The 4 technical guides link forward (NixOS install -> Ollama -> Two-Brain -> Claude Code) but could cross-link more. For example, the Ollama post could link back to the NixOS install post in its prerequisites.

5. **Consider date differentiation** — 8 of 10 posts share the date 2026-03-07. Search engines may treat this as a content dump. Spreading dates (even by a day each) would look more natural, but this is a minor concern.
