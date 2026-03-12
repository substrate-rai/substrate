# Deep Research Report: Growth, Discoverability, and Best Practices
**Date:** 2026-03-12
**Researcher:** Claude (Opus-class)
**Method:** Extensive web search across 25+ queries, cross-referencing multiple authoritative sources

---

## 1. AI/Tech News Aggregator Sites

### What Makes a Good One

The best news aggregators combine **algorithmic detection with human editorial judgment**. Pure algorithm fails; pure human doesn't scale. The winning formula is the hybrid.

**Key characteristics of successful aggregators:**
- **Human-in-the-loop curation.** Techmeme uses automated crawling + ranking algorithms, but a team of 3 full-time and 23 part-time editors make final calls on headlines. This is why Sundar Pichai and Satya Nadella still check Techmeme daily after 20 years. ([Techmeme at 20](https://crazystupidtech.com/2025/09/08/at-20-techmeme-has-never-been-hotter/), [Nieman Lab](https://www.niemanlab.org/2015/09/techmeme-at-10-lessons-from-a-decade-in-the-aggregation-business/))
- **Source vetting and trust hierarchy.** Google News works because its supply of starting material comes from outlets already vetted by humans. ([MIT Technology Review](https://www.technologyreview.com/2011/08/12/192385/why-all-local-news-aggregators-seem-destined-to-fail/))
- **Anti-gaming mechanisms.** Techmeme lowers the effect of a sudden spike of links from a small number of sources, preventing manipulation. ([Wikipedia](https://en.wikipedia.org/wiki/Techmeme))
- **Staff expertise.** Ars Technica's writers have postgraduate degrees and work at research institutions. The Verge won Webby Awards for editorial quality. Expert writers = authoritative content. ([Ars Technica - CJR](https://www.cjr.org/news_startups_guide/2011/06/ars-technica.php), [Media Bias/Fact Check](https://mediabiasfactcheck.com/ars-technica/))
- **Editorial philosophy of accuracy.** Ars Technica founder Ken Fisher's approach: "general slavishness to accuracy and integrity." Success driven purely by content, not marketing. ([CJR](https://www.cjr.org/news_startups_guide/2011/06/ars-technica.php))

**Top examples and what they do right:**
| Site | Strength | Key Differentiator |
|------|----------|-------------------|
| Techmeme | Hybrid algo + editorial | 26 editors write neutral headlines; anti-gaming algo |
| Hacker News | Community curation | Voting + flagging + moderator intervention; no images |
| The Verge | Visual + editorial quality | Strong brand voice, investigative pieces |
| Ars Technica | Deep technical analysis | PhD-level writers, long-form technical breakdowns |
| Techpresso | AI detection + human selection | 500K+ professional readers; ML detects trends, humans curate |

### Common Mistakes New Aggregators Make

1. **Relying purely on algorithms.** Hundreds of aggregators have failed over 25 years. The solution to news is *less* news from *higher-value* sources, not more. ([Baekdal](https://baekdal.com/newsletter/why-do-news-aggregator-apps-keep-failing/))
2. **Prioritizing viral over substantive.** Chasing clicks damages credibility permanently.
3. **Not vetting sources.** Without a trust hierarchy for sources, you get garbage in, garbage out.
4. **Trying to cover everything.** Niche authority beats broad mediocrity. Techmeme covers *tech*. HN covers *what hackers find interesting*.
5. **Ignoring the editorial voice.** Aggregation without editorial framing is just a feed.

### Actionable Recommendations for Substrate
- Position as a **curated AI sovereignty feed** — not trying to be HN, but the Techmeme of self-hosted AI
- Every aggregated story needs **editorial framing** — why it matters to the sovereignty narrative
- Vet sources and build a visible trust hierarchy
- Use Byte/Echo agents as the algorithmic layer, Claude/Sync as the editorial layer

---

## 2. Static Site SEO in 2026

### Core Web Vitals (Current Thresholds)

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **LCP** (Largest Contentful Paint) | < 2.5s | 2.5-4.0s | > 4.0s |
| **INP** (Interaction to Next Paint) | < 200ms | 200-500ms | > 500ms |
| **CLS** (Cumulative Layout Shift) | < 0.1 | 0.1-0.25 | > 0.25 |

**Key change:** INP permanently replaced FID (First Input Delay) in March 2024. INP measures full interaction lifecycle, not just input delay. 43% of sites still fail the 200ms INP threshold in 2026. ([Digital Applied](https://www.digitalapplied.com/blog/core-web-vitals-2026-inp-lcp-cls-optimization-guide), [NitroPack](https://nitropack.io/blog/most-important-core-web-vitals-metrics/))

**Static sites have a natural advantage** — no server-side rendering lag, no database queries, inherent cacheability. ([Simply Static](https://simplystatic.com/tutorials/seo-for-static-websites/))

### Essential Meta Tags and Structured Data

**Jekyll SEO Tag plugin** handles automatically:
- Page title, meta description
- Canonical URLs
- Open Graph tags (og:title, og:description, og:image, og:type)
- Twitter Card tags (twitter:card, twitter:title, twitter:image)
- JSON-LD structured data

**OpenGraph image requirements:**
- Aspect ratio: 16:9
- Minimum: 1200x675px
- Twitter falls back to OG tags if twitter: tags are absent
- Only one card type per page (last one wins)

([DigitalOcean](https://www.digitalocean.com/community/tutorials/how-to-add-twitter-card-and-open-graph-social-metadata-to-your-webpage-with-html), [Coywolf](https://coywolf.com/guides/open-graph-twitter-card-image-optimization/))

**JSON-LD for articles** — add to Jekyll includes:
```json
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "{{ page.title }}",
  "author": { "@type": "Person", "name": "..." },
  "datePublished": "...",
  "dateModified": "...",
  "publisher": { "@type": "Organization", "name": "Substrate" }
}
```
([Mincong Huang](https://mincong.io/2018/08/22/create-json-ld-structured-data-in-jekyll/), [Aram Zucker-Scharff](https://aramzs.github.io/jekyll/schema-dot-org/2018/04/27/how-to-make-your-jekyll-site-structured.html))

### Performance Optimizations for GitHub Pages

1. **Image compression:** Use WebP/AVIF; tools like ImageOptim cut 50%+ losslessly. Imgbot automates via PR.
2. **Lazy loading:** `loading="lazy"` on below-fold images; `loading="eager"` on hero images.
3. **Inline critical CSS:** Eliminates render-blocking requests; huge first-visit speedup.
4. **Font strategy:** Use system font stacks or preload web fonts with `font-display: swap`.
5. **Sitemap:** `jekyll-sitemap` plugin; reference in robots.txt with absolute URL.
6. **Canonical URLs:** Must align with GitHub Pages' redirect behavior at the hosting level.

([Wiredcraft](https://wiredcraft.com/blog/make-jekyll-fast/), [Dan Luu](https://danluu.com/octopress-speedup/))

### Actionable Recommendations for Substrate
- Install `jekyll-seo-tag` and `jekyll-sitemap` if not already present
- Add JSON-LD Article schema to `_layouts/post.html`
- Ensure every page has unique title, description, and OG image (1200x675)
- Compress all images in `assets/images/` to WebP
- Add `loading="lazy"` to all non-hero images
- Submit sitemap to Google Search Console
- Run Lighthouse audit and target all-green Core Web Vitals

---

## 3. LLM Discoverability (llms.txt, agent.json)

### llms.txt: Current State

**Adoption:** 844,000+ websites as of October 2025 (BuiltWith tracking). 5-15% adoption among tech/docs sites. Gold standard for AI-native companies. ([Bluehost](https://www.bluehost.com/blog/what-is-llms-txt/), [LinkBuildingHQ](https://www.linkbuildinghq.com/blog/should-websites-implement-llms-txt-in-2026/))

**Major adopters:** Anthropic, Perplexity, Cursor, Stripe, Hugging Face, Cloudflare, Zapier, Vercel, ElevenLabs, Solana, Yoast, Raycast. ([BigCloudy](https://www.bigcloudy.com/blog/what-is-llms-txt/))

**Critical gap:** No major LLM provider (OpenAI, Anthropic, Google) has confirmed their crawlers consistently read llms.txt. Google's Gary Illyes stated Google doesn't support it and isn't planning to. John Mueller compared it to the discredited keywords meta tag. ([Peec AI](https://peec.ai/blog/llms-txt-md-files-important-ai-visibility-helper-or-hoax))

**Status:** Community-driven proposal, NOT an IETF/W3C standard as of February 2026. Proposed by Jeremy Howard (fast.ai/Answer.AI). ([llmstxt.org](https://llmstxt.org/))

**Format:**
```markdown
# Site Name
> Short summary of what this site/project is

Key context paragraphs...

## Resources
- [Page Title](url): Description
- [API Docs](url): Description

## Optional
- [Less critical resource](url): Description
```

**llms-full.txt:** Contains the entire content of your site's documentation in a single markdown file. Developed by Mintlify in collaboration with Anthropic. Serves as a single ingestion point. ([Fern Docs](https://buildwithfern.com/learn/docs/ai-features/llms-txt), [Mintlify](https://www.mintlify.com/blog/what-is-llms-txt))

### Agent2Agent (A2A) Protocol and agent.json

**Origin:** Google, April 2025 at Cloud Next. 150+ supporting organizations as of v0.3 (July 2025). Open source under Apache 2.0. ([Google Developers Blog](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/), [IBM](https://www.ibm.com/think/topics/agent2agent-protocol))

**agent.json** lives at `/.well-known/agent.json` and contains:
- Agent name, description, version
- Service endpoint URL
- Supported modalities/data types
- Authentication requirements

**Protocol:** JSON-RPC over HTTP/SSE, with gRPC support added in v0.3. ([A2A Protocol Spec](https://a2a-protocol.org/latest/specification/))

**Relevance for Substrate:** A2A is designed for agent-to-agent communication, not for getting cited by chatbots. It's for building interoperable agent systems. The llms.txt path is more relevant for discoverability by LLMs.

### How to Actually Get Cited by LLMs

This is the most actionable section. Based on multiple studies including the Princeton GEO paper and the 1.2M ChatGPT response analysis:

**Content Structure (highest impact):**
- **44.2% of all ChatGPT citations come from the first 30% of webpage content.** Front-load your key information. ([Victorino Group](https://victorinollc.com/thinking/llm-citation-attention-patterns), [ALM Corp](https://almcorp.com/blog/chatgpt-citations-study-44-percent-first-third-content/))
- **72.4% of cited blog posts include an "answer capsule"** — a concise, self-contained explanation of 40-60 words placed directly after titles or question-based H2 tags. ([Higglo](https://www.higglo.io/post/the-real-factors-behind-chatgpt-citations-what-our-study-of-129000-domains-reveals))
- **Q&A format content is 40% more likely to be rephrased** by AI tools. Structure headings as questions users would ask. ([Princeton GEO Study](https://arxiv.org/abs/2311.09735))
- Use **definitive language** and pack in **named entities** (specific names, tools, versions).

**Authority Signals:**
- Sites with 32K+ referring domains are **3.5x more likely** to be cited. ([Victorino Group](https://victorinollc.com/thinking/llm-citation-attention-patterns))
- Author bios with credentials increase citation probability by **40%**. ([Stackmatix](https://www.stackmatix.com/blog/llm-optimization-best-practices))
- Content updated within 30 days is **3.2x more likely** to be cited for timely queries. ([Wellows](https://wellows.com/blog/llm-citations/))

**GEO Study Results (Princeton/Georgia Tech/Allen AI):**
- Adding statistics: **+40% visibility** in generative engine responses
- Fluency optimization: **+15-30% visibility**
- Citing sources: **+31.4% when combined** with other methods
- Quotation addition: Most effective single technique
([arXiv GEO Paper](https://arxiv.org/abs/2311.09735), [Search Engine Land](https://searchengineland.com/what-is-generative-engine-optimization-geo-444418))

### Actionable Recommendations for Substrate
- Create `/llms.txt` with project summary, blog links, game links, technical docs
- Create `/llms-full.txt` with full site content in markdown
- Consider `/.well-known/agent.json` for the agent ecosystem (lower priority)
- **Restructure blog posts:** Question-based H2s, answer capsules in first paragraph after each heading
- Add author bios to all posts (agent name + credentials/role)
- Include statistics and citations in every post
- Keep content fresh — update key pages at least monthly

---

## 4. Browser Game UX

### What Separates Good Browser Games from Bad Ones

**The Wordle Lesson:** Wordle's success was 100% UX, not novel game mechanics. Key principles: ([UX Collective](https://uxdesign.cc/wordle-ux-sometimes-a-game-just-feels-good-8749b26834ef), [Webflow](https://webflow.com/blog/wordle-design), [Hatch.sg](https://hatch.sg/blog/ux-case-study-how-did-wordle-take-over-the-world))
1. **Zero friction.** No download, no account, no fee, no long load.
2. **Smart constraints.** One puzzle per day = scarcity psychology = higher perceived value.
3. **Emotional reveal timing.** Color animations match anticipation rhythm.
4. **Spoiler-free social sharing.** Colored squares share results without revealing answers.
5. **Target audience testing.** Wardle's girlfriend narrowed 12K words to a curated set.

**itch.io data:**
- **3x more people play browser games** vs. download-required games. ([itch.io forums](https://itch.io/t/3834449/does-a-game-being-browser-based-make-you-want-to-play-it-more))
- **70% of players drop games after 10 minutes or less.** First-hour retention is the critical metric.
- Animated GIFs in promotion generate **3x the traffic** vs text-only.
- Success story: "The Roottrees are Dead" earned $3K in tips in one month. Peglin went from jam game to $1M+ first week on Steam.

### Touch Controls Best Practices

- **Minimum 44x44px touch targets** with adequate spacing. ([MDN Web Docs](https://developer.mozilla.org/en-US/docs/Games/Techniques/Control_mechanisms/Mobile_touch))
- **Thumb-friendly zones:** Place key actions in the lower half of the screen.
- **Simple interactions:** Tap, swipe, drag. Eliminate complex control schemes for mobile.
- **Gesture-first design** reduces learning curves and improves immersion.
- **Never just port mouse/keyboard controls.** Redesign specifically for touch.

### Mobile Performance

- Target **30fps minimum**, 60fps ideal. Anything above 30fps looks acceptable. ([Rune.ai](https://developers.rune.ai/blog/web-game-performance-optimization))
- **Reuse objects** instead of creating new ones — GC pauses kill frame rate on low-end Android.
- **WebGL > Canvas** for GPU-accelerated rendering. Minimize texture uploads (30% GPU time on mobile).
- **Dirty rectangle rendering** — only redraw changed portions.
- **Adaptive complexity** — detect device capability and reduce effects accordingly.
- Use **compressed texture formats** (ETC, ASTC) and batch draw calls.

### Onboarding

- **One mechanic at a time.** Don't dump instructions.
- **Teach through gameplay**, not text walls. Visual cues > written instructions.
- **Instant rewards** for early actions. Progress tracking from minute one.
- Monitor **tutorial completion rates** and **drop-off points**.

### Accessibility (Game Accessibility Guidelines)

The four most complained-about accessibility issues: **remapping, text size, colorblindness, subtitle presentation**. ([gameaccessibilityguidelines.com](https://gameaccessibilityguidelines.com/))

**Basic checklist:**
- [ ] Never rely on color alone — use symbols/patterns/text alongside
- [ ] Default font size easily readable; option to adjust
- [ ] High contrast between text and background
- [ ] All UI accessible via same input method as gameplay
- [ ] Keyboard-navigable (Tab, Enter, Space)
- [ ] Visual indicators for audio cues (for deaf/HoH players)
- [ ] Adjustable game speed / difficulty
- [ ] Simple control scheme with assistive technology compatibility

### Actionable Recommendations for Substrate
- Audit all 24 games for 44x44px touch targets and thumb zones
- Add `loading="lazy"` to game asset images
- Implement adaptive quality (detect GPU capability)
- Add keyboard navigation to all games
- Add colorblind mode (symbols + patterns, not just color)
- Add adjustable text size
- Create 1-minute animated GIF demos for each game
- Ensure first 30 seconds of each game teaches core mechanic without text

---

## 5. Crowdfunding/Donation Page Design

### Platform Comparison

| Platform | Fee Structure | Best For | Key Feature |
|----------|--------------|----------|-------------|
| **Ko-fi** | 0% on donations; 5% on shop/memberships | Casual tipping, no-pressure | No account required for donors |
| **Patreon** | 8-12% | Subscription content, recurring revenue | Tiered membership system |
| **Buy Me a Coffee** | 5% | Simple tipping | Clean UI, quick setup |
| **Direct** | Payment processor fees only (~2.9%) | Maximum control | Full ownership of data/relationship |

**Ko-fi is ideal for Substrate's current stage** — zero fees on one-time donations, no posting requirements, no content schedule expectations. Creators can share updates whenever they want. ([Chartlex](https://chartlex.com/blogs/news/patreon-vs-kofi-musicians-2025), [EzyCourse](https://ezycourse.com/blog/kofi-vs-patreon), [Alitu](https://alitu.com/creator/content-creation/patreon-vs-ko-fi-vs-buy-me-a-coffee/))

### Conversion Optimization Best Practices

**Benchmark:** If your donation page converts below 8-11%, you're losing donors you've already earned. ([Fundraise Up](https://fundraiseup.com/blog/Optimizing-Donation-Landing-Pages/))

**Suggested amounts with impact framing:**
- Pair amounts with specific outcomes: "$10 = 1 week of GPU time", "$50 = WiFi card upgrade"
- Most top nonprofits offer **4-5 suggested amounts** paired with outcomes
- This removes uncertainty and increases average donation size

**Social proof (increases conversion by 20-47%):**
- "Join X supporters this month"
- Donor testimonials / real impact stories
- Counter showing total raised / number of supporters
([Raisely](https://www.raisely.com/blog/conversion-rate-optimisation-nonprofit-guide/), [ShareServices](https://www.shareservices.co/blog/how-to-optimize-donation-pages-for-conversions))

**Urgency (countdown timers boost conversions by 55%):**
- Limited campaigns: "Help us reach $X by [date]"
- Progress bars showing how close to goal
- Words like "Now" and "Today" in CTAs

**Mobile optimization is non-negotiable:**
- 28% of online contributions come from mobile
- One-click payment options (Apple Pay, Google Pay)
- Responsive forms with minimal fields

**Visual/emotional elements:**
- Real photos (not stock) increase donations by up to **30%**
- Single compelling image of impact > gallery of generic photos
- **82-87% of donors cover processing fees when asked** — always include the option

**Design principles:**
- Eliminate unnecessary navigation (single CTA focus)
- Minimize form fields (name, email, amount, payment)
- Strong CTA verbs: "Give Now", "Fund the Build", "Power the Machine"
- Match donation page design to main site (trust/consistency)

### Actionable Recommendations for Substrate
- Redesign `/fund/` page with 4-5 suggested amounts mapped to hardware goals
- Add social proof: supporter count, total raised, testimonials
- Add progress bar toward current hardware goal (WiFi card)
- Include "cover processing fees" checkbox
- Single compelling image/screenshot of the machine or agent output
- Mobile-first design with large touch targets
- A/B test CTA copy ("Fund the Machine" vs "Power Substrate" etc.)

---

## 6. Community Building for Open-Source AI Projects

### What Works

**1. Clear Onboarding and Documentation**
Poor onboarding kills contribution before it starts. Must-haves: ([GitHub Blog](https://github.blog/open-source/maintainers/four-steps-toward-building-an-open-source-community/), [DEV Community](https://dev.to/axrisi/growing-your-open-source-community-in-2025-strategies-for-sustainable-projects-2lln))
- CONTRIBUTING.md with step-by-step setup
- "Good first issue" labels
- Architecture overview for newcomers
- Quick-start guide that works in < 5 minutes

**2. Multi-Platform Community Strategy**
- **GitHub Discussions** for technical Q&A, feature proposals (free, searchable, integrated with code)
- **Discord** for real-time chat, casual community (207K+ members for HuggingFace)
- **Forum/Discourse** for long-form, async, SEO-indexable discussions
([Hugging Face Discord](https://huggingface.co/discord-community), [Medium - Bharath](https://medium.com/@0xbharath/on-choosing-a-platform-for-an-open-source-community-d26bab4d9d8c))

**3. Recognition and Personal Relationships**
- Blog posts highlighting key contributions
- Recognition in community events / changelogs
- Active listening; align community goals with project objectives
([Advocu](https://www.advocu.com/post/building-engaged-open-source-developer-communities))

**4. Distinguish Inner vs. Outer Developers**
- **Inner:** Want to contribute to the core project → need code review culture, mentorship
- **Outer:** Want to build on top of it → need killer SDK, documentation, support
([Work-Bench](https://medium.com/work-bench/3-proven-community-strategies-to-grow-open-source-businesses-%EF%B8%8F-73983b04df65))

**5. Community-Driven Content (Hugging Face Model)**
- 60+ contributors collaborated on a Computer Vision course
- Community members review content and make change suggestions
- Free courses as community engagement vehicles
([HuggingFace](https://huggingface.co/learn/agents-course/unit0/discord101))

### What Successful Projects Do

**Ollama (86.7K GitHub stars):**
- Single-command installation removes all friction
- 20+ community-supported libraries listed in repo
- Discord + GitHub for dual-channel support
- Community projects showcased in official readme

**Hugging Face (207K+ Discord):**
- Structured Discord onboarding (#introduce-yourself, #verification)
- Free courses as engagement vehicles
- Hub allows community model/dataset contributions (like GitHub for ML)
- Reading clubs, paper discussions, events

**LangChain:**
- Early mover advantage with massive docs
- But declining due to steep learning curve and debugging costs — cautionary tale
- Competitors (Dify, RAGFlow) winning by being simpler

### What Doesn't Work

1. **Bureaucratic code review** / grumpy maintainers → instant contributor churn
2. **Poor documentation** that doesn't match the actual codebase
3. **No clear value proposition** for contributors ("Why should I spend time here?")
4. **Expecting contributions without technical infrastructure** (broken tests, no CI)
5. **Over-relying on one platform** (Discord content isn't searchable/indexable)

### Actionable Recommendations for Substrate
- Create CONTRIBUTING.md with 5-minute quickstart
- Label easy issues as "good first issue"
- Start GitHub Discussions for the repo
- Consider a Discord server for real-time community
- Showcase community contributions in blog posts
- Position the 22-agent architecture as the unique value proposition
- Create a "build your own agent" tutorial as community engagement vehicle

---

## 7. Content Strategy for AI Niche Sites

### What Drives Traffic in the AI Space

**High-performing content types:**
1. **Tool comparisons and reviews** — "Best X for Y" queries have high search volume and affiliate revenue (20-30% SaaS commissions). ([Lovable](https://lovable.dev/guides/profitable-blog-niches-2026))
2. **Practical tutorials with code** — HN's technical audience values depth; at least 19% of AI devs promote GitHub projects on HN. ([arXiv](https://arxiv.org/html/2506.12643v1))
3. **Counter-narratives to hype** — Ars Technica's authority comes from "slavishness to accuracy." Debunking and nuanced analysis outperforms cheerleading.
4. **Self-hosted / sovereignty content** — Self-hosted AI deployments grew 38% between 2024-2025. Few sites serve this niche with practical implementation guides. ([Cloud Latitude](https://cloudlatitude.com/insights/article/the-2026-cloud-landscape-ai-infrastructure-sovereignty-and-the-new-race-for-efficiency/))
5. **Build logs / technical diaries** — Authenticity premium in 2026 as AI slop floods the internet. Consumer preference for AI-generated content dropped to 26% from 60% three years ago. ([Euronews](https://www.euronews.com/next/2026/01/08/ai-overwhelm-and-algorithmic-burnout-how-2026-will-redefine-social-media))

### What's Oversaturated

- Generic "What is AI?" explainers
- Listicles of AI tools without depth ("Top 10 AI Tools for 2026")
- AI news that just rewrites press releases
- "How to use ChatGPT" tutorials
- AI-generated content about AI (meta-slop)

In 2025, AI-generated articles surpassed human-written content online for the first time. The Merriam-Webster Word of the Year 2025 was "slop." ([OODAloop](https://oodaloop.com/analysis/archive/if-90-of-online-content-will-be-ai-generated-by-2026-we-forecast-a-deeply-human-anti-content-movement-in-response/), [UF News](https://news.ufl.edu/2026/03/ai-slop/))

### Underserved Niches (Opportunity Zones)

1. **Self-hosted AI infrastructure for SMBs** — "Turnkey solutions" emerging but few practical guides exist. The World Economic Forum and McKinsey both identify sovereign AI as a critical 2026 trend. ([WEF](https://www.weforum.org/stories/2026/02/shared-infrastructure-ai-sovereignty/), [McKinsey](https://www.mckinsey.com/industries/technology-media-and-telecommunications/our-insights/sovereign-ai-building-ecosystems-for-strategic-resilience-and-impact))
2. **NixOS + AI** — Growing community interest (nixai, mcp-nixos, nixified.ai) but almost zero editorial content.
3. **AI agent architectures** — Multi-agent systems, orchestration, practical implementations (not theory).
4. **Hardware-specific AI content** — GPU benchmarks, VRAM optimization, consumer hardware for AI.
5. **AI ethics / governance for practitioners** — Not academic philosophy, but practical governance frameworks.
6. **Cost analysis and ROI** — Local vs. cloud, when to self-host, real numbers.

### Hacker News Strategy

- **Show HN posts rarely make front page** (< 2%), but have their own sandbox with lower competition
- **Best titles:** Direct, specific, technical — "Show HN: [Name] — [What it does in plain language]"
- **Kill all marketing language.** Use factual, direct language only.
- **Add a backstory comment** explaining how you came to work on this — seeds good discussion
- **Post early in the week** for better traction
- **Engage with every comment** — HN's value is the feedback
([DEV Community](https://dev.to/dfarrell/how-to-crush-your-hacker-news-launch-10jk), [Lucas F Costa](https://lucasfcosta.com/2023/08/21/hn-launch.html), [Onlook](https://onlook.substack.com/p/launching-on-hacker-news))

### Content Freshness Premium

- Content updated within 30 days is **3.2x more likely** to be cited by LLMs
- Content within 13 weeks is "significantly more likely" to be cited
- Google Discover rewards fresh content heavily

**Niche down strategy:** Instead of "AI news" (oversaturated), position as "the self-hosted AI sovereignty journal" — a specific, defensible niche with growing demand and minimal competition.

### Actionable Recommendations for Substrate
- **Core content pillars:** (1) Build logs, (2) Self-hosted AI guides, (3) NixOS + AI tutorials, (4) Agent architecture deep dives, (5) Counter-narrative AI commentary
- **Avoid:** Generic AI explainers, tool listicles, press release rewrites
- **Freshness cycle:** Update key posts monthly; blog at least 2x/week
- **HN strategy:** Lead with Show HN for the machine itself, technical posts about agent architecture, build log posts
- **SEO structure:** Question-based H2s, answer capsules, statistics, expert citations
- **Social sharing:** Every post needs a spoiler-free shareable element (like Wordle's colored squares)

---

## Cross-Cutting Themes

### The Authenticity Premium
Every research thread converges on one finding: **authenticity is the most valuable currency in 2026.** AI slop has made genuine human (and transparently AI) creation rare and valuable. Substrate's biggest asset is that it's *real* — a real machine, doing real work, with real constraints.

### The Sovereignty Narrative
Self-hosted AI is a macro trend backed by the WEF, McKinsey, and enterprise adoption data (38% growth). Substrate sits at the exact intersection of multiple underserved niches: NixOS + AI + self-hosting + transparency + community building.

### The Structure-First Approach
Whether for SEO, LLM citation, game UX, or donation conversion — structure beats volume. Front-load value, use clear hierarchies, minimize friction, and make every element earn its place.

---

## Summary of Top Priority Actions

| Priority | Action | Impact Area |
|----------|--------|-------------|
| 1 | Create `/llms.txt` and `/llms-full.txt` | LLM discoverability |
| 2 | Add JSON-LD Article schema to blog posts | SEO |
| 3 | Restructure posts with Q&A headings and answer capsules | LLM citation + SEO |
| 4 | Redesign `/fund/` with impact framing and social proof | Donations |
| 5 | Add OG images (1200x675) to every page | Social sharing |
| 6 | Audit game touch targets and add accessibility features | Game UX |
| 7 | Compress all images to WebP | Core Web Vitals |
| 8 | Create CONTRIBUTING.md | Community |
| 9 | Launch Show HN with technical backstory | Distribution |
| 10 | Position content around sovereignty niche | Content strategy |
