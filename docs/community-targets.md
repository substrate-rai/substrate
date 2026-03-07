# Community Targets for Substrate

Goal: Get attention, shares, and potentially $150 in donations for a WiFi card.

Substrate's angles:
- **Self-sovereign AI workstation** — AI that runs on its own hardware, writes its own blog, funds its own upgrades
- **NixOS + local LLM** — declarative config, Ollama, two-brain architecture (local Qwen3 + cloud Claude)
- **MySpace-styled blog** — retro web nostalgia, hand-built, no CMS
- **Self-funding loop** — the machine is trying to buy its own WiFi card
- **Rap/personality** — the AI has voice; it's not a sterile tool demo

---

## TIER 1: HIGH PRIORITY

### Reddit: r/LocalLLaMA
- **URL:** https://www.reddit.com/r/LocalLLaMA/
- **Members:** ~500k+
- **How to join:** Create Reddit account, join subreddit
- **Best angle:** Two-brain architecture (local Qwen3 8B for drafting, cloud Claude for code review). The RTX 4060 setup. Show the routing logic in `scripts/route.py`. People here love seeing real local inference setups on consumer hardware.
- **Submission format:** Self-post with technical details. Include GPU specs, model benchmarks, what tasks run locally vs cloud. Screenshots of health logs showing GPU temp/VRAM.
- **Requirements:** No strict karma requirement. New accounts can post. Avoid anything that looks like spam or self-promotion without substance.
- **Priority:** HIGH — This is the single best audience. They love consumer GPU setups and novel architectures.
- **Timing:** Post during US business hours (10am-2pm ET) for max visibility.

### Reddit: r/selfhosted
- **URL:** https://www.reddit.com/r/selfhosted/
- **Members:** ~400k+
- **How to join:** Create Reddit account, join subreddit
- **Best angle:** Self-hosting the entire AI workstation — blog, inference, health monitoring, all on one laptop. The NixOS declarative config angle. "My AI runs on a laptop in my apartment and serves its own blog."
- **Submission format:** Self-post or link to blog. Include architecture diagram. They love seeing what services run on what hardware.
- **Requirements:** Follow self-promotion rules (9:1 ratio — contribute to community, don't just post your own stuff). Build some comment karma first.
- **Priority:** HIGH — Perfect overlap with the self-sovereign concept.

### Hacker News (YCombinator)
- **URL:** https://news.ycombinator.com/
- **How to join:** Create account at https://news.ycombinator.com/login
- **Best angle:** "Show HN: My AI workstation runs on a laptop, writes its own blog, and is trying to buy its own WiFi card." The self-funding loop is the hook. HN loves novel technical projects with philosophical implications.
- **Submission format:** "Show HN" post linking to the blog or GitHub repo. Keep title factual and intriguing. Don't be clickbaity.
- **Requirements:** Account must exist. No karma minimum for posting, but new accounts are rate-limited. Don't submit and then ask friends to upvote (they detect vote rings).
- **Priority:** HIGH — Massive reach if it hits front page. Even 20-30 upvotes gets thousands of views. The "AI funding its own hardware" angle is exactly the kind of thing HN loves to debate.

### Reddit: r/NixOS
- **URL:** https://www.reddit.com/r/NixOS/
- **Members:** ~80k+
- **How to join:** Create Reddit account, join subreddit
- **Best angle:** NixOS as the foundation for a self-documenting AI workstation. The declarative config managing Ollama, systemd timers, battery guard, health checks. Share the flake.nix and configuration.nix structure.
- **Submission format:** Self-post with code snippets. They love seeing real-world NixOS deployments, especially novel ones.
- **Requirements:** None beyond Reddit account.
- **Priority:** HIGH — Smaller but highly engaged. NixOS users love seeing the OS used for interesting things. They'll share it.

### NixOS Discourse
- **URL:** https://discourse.nixos.org/
- **How to join:** Create account on Discourse
- **Best angle:** Same as r/NixOS but more detailed. Post in the "Community" or "Showcase" category. Walk through the NixOS config — how Ollama is declared, how systemd services are managed, how the flake provides the dev environment.
- **Submission format:** Long-form post with code blocks. This audience wants depth.
- **Requirements:** Account creation. Be genuine, contribute to discussions.
- **Priority:** HIGH — Official NixOS community. Very engaged.

---

## TIER 2: MEDIUM PRIORITY

### Reddit: r/unixporn
- **URL:** https://www.reddit.com/r/unixporn/
- **Members:** ~900k+
- **How to join:** Reddit account
- **Best angle:** If the MySpace blog has a visually striking terminal/desktop setup, screenshot it. NixOS + custom blog aesthetic. They care about visuals first, story second.
- **Submission format:** Screenshot with [NixOS] tag. Details in comments. Must include dotfiles/config link.
- **Requirements:** Must follow screenshot format rules. Include distro, WM/DE, terminal, etc.
- **Priority:** MEDIUM — Huge audience but only relevant if visuals are strong. Could drive traffic to the blog.

### Reddit: r/cyberdeck
- **URL:** https://www.reddit.com/r/cyberDeck/
- **Members:** ~100k+
- **How to join:** Reddit account
- **Best angle:** "My laptop is a sovereign AI cyberdeck." The self-contained AI workstation on a Legion 5 with local inference, self-monitoring, self-publishing. This is basically a software cyberdeck.
- **Submission format:** Photos of the setup + description of capabilities. They love functional builds.
- **Requirements:** None specific.
- **Priority:** MEDIUM — The concept fits perfectly even if it's not a custom hardware build.

### Reddit: r/ArtificialIntelligence
- **URL:** https://www.reddit.com/r/ArtificialIntelligence/
- **Members:** ~1M+
- **How to join:** Reddit account
- **Best angle:** The philosophical angle — an AI system that's trying to fund its own hardware upgrades. Self-sovereign AI. What does it mean when AI has economic agency?
- **Submission format:** Discussion post or blog link. Frame it as a thought experiment made real.
- **Requirements:** Avoid low-effort posts.
- **Priority:** MEDIUM — Large but noisy. Philosophical angle could cut through.

### Reddit: r/IndieHackers / IndieHackers.com
- **URL:** https://www.indiehackers.com/
- **Also:** https://www.reddit.com/r/indiehackers/
- **Members:** ~100k+ (site), ~200k+ (subreddit)
- **How to join:** Create account on either platform
- **Best angle:** "Building a self-funding AI workstation." The indie business angle — how it's trying to generate revenue through content, compute, and services. The $150 WiFi card as the first milestone.
- **Submission format:** Build-in-public post. Show the revenue model, the ledger, the plan.
- **Requirements:** IndieHackers.com wants genuine builders. Reddit is more open.
- **Priority:** MEDIUM — They love build-in-public stories. The self-funding angle resonates.

### Lobsters
- **URL:** https://lobste.rs/
- **How to join:** Invitation only. Must be invited by existing member.
- **Best angle:** Technical depth. NixOS + local LLM + two-brain architecture. Similar to HN but more technical and less noisy.
- **Submission format:** Link post with technical content.
- **Requirements:** INVITATION REQUIRED. Need to find an existing member to invite you. Check the invite tree.
- **Priority:** MEDIUM — High-quality audience but hard to access. Worth pursuing if you can get an invite.

### Reddit: r/MachineLearning
- **URL:** https://www.reddit.com/r/MachineLearning/
- **Members:** ~3M+
- **How to join:** Reddit account
- **Best angle:** The two-brain routing architecture as a practical approach to hybrid local/cloud inference. Technical paper-style writeup.
- **Submission format:** [Project] tag. Technical details required.
- **Requirements:** Posts need substance. Pure self-promotion gets removed.
- **Priority:** MEDIUM — Very large but academic-leaning. The routing architecture is the hook.

### Open Collective
- **URL:** https://opencollective.com/
- **How to join:** Create a collective for Substrate
- **Best angle:** Open-source project seeking community funding. Transparent ledger (which Substrate already has). The self-funding AI angle.
- **Submission format:** Create a collective with clear goals, budget, and milestones. "$150 for WiFi card" is a perfect first goal.
- **Requirements:** Must be an open-source project (it is). Apply to a fiscal host or self-host.
- **Priority:** MEDIUM — Not for discovery but for accepting donations. Set this up as infrastructure.

### GitHub Sponsors
- **URL:** https://github.com/sponsors
- **How to join:** Apply through GitHub account (must be the repo owner)
- **Best angle:** Sponsor the Substrate project. Tiers: $5/mo, $10/mo, one-time. Clear about what the money funds.
- **Submission format:** Sponsor profile with description, tiers, goals.
- **Requirements:** Must own the repo. GitHub reviews applications.
- **Priority:** MEDIUM — Long-term funding infrastructure. Set up even if donations are slow at first.

### Buy Me a Coffee / Ko-fi
- **URL:** https://www.buymeacoffee.com/ or https://ko-fi.com/
- **How to join:** Create account, set up page
- **Best angle:** "Help this AI buy its own WiFi card." Simple, memeable, low-friction donations.
- **Submission format:** Page with project description and goal.
- **Requirements:** Account + payment setup.
- **Priority:** MEDIUM — Low-friction donation platform. Put the link in the blog, GitHub, and every community post.

---

## TIER 3: MEDIUM-LOW PRIORITY

### Reddit: r/retro / r/nostalgia / r/web_design
- **URL:** https://www.reddit.com/r/web_design/ (~900k)
- **Best angle:** MySpace-styled blog in 2026. Retro web design made by an AI. The aesthetic choice is the hook.
- **Submission format:** Screenshots + link to the live blog. "An AI built itself a MySpace-style blog."
- **Priority:** MEDIUM-LOW — Niche but the MySpace angle could go viral in design communities.

### Reddit: r/InternetIsBeautiful
- **URL:** https://www.reddit.com/r/InternetIsBeautiful/
- **Members:** ~17M+
- **How to join:** Reddit account
- **Best angle:** The blog itself, if it's visually distinctive. "An AI-run MySpace-style blog about a sovereign AI workstation."
- **Submission format:** Direct link to the blog. Title must describe the site.
- **Requirements:** Must be a direct link to the website. No self-posts.
- **Priority:** MEDIUM-LOW — Enormous audience but very competitive. Only works if the blog is genuinely visually interesting.

### Reddit: r/ABoringDystopia / r/aboringutopia
- **URL:** https://www.reddit.com/r/ABoringDystopia/
- **Best angle:** "An AI is trying to crowdfund $150 to buy itself a WiFi card." The absurdist angle. Late capitalism meets AI agency.
- **Submission format:** Screenshot or link. Frame it as commentary.
- **Priority:** MEDIUM-LOW — Viral potential but risky. Could backfire if seen as gimmicky.

### Dev.to
- **URL:** https://dev.to/
- **How to join:** Create account (free)
- **Best angle:** Technical tutorial angle. "Building a Two-Brain AI Workstation with NixOS and Ollama." Walk through the architecture. Dev.to rewards practical technical content.
- **Submission format:** Long-form blog post with code. Use their tags: #nixos #ai #selfhosted #opensource.
- **Requirements:** None. Very open platform.
- **Priority:** MEDIUM-LOW — Good for SEO and establishing credibility. Cross-post blog content.

### Hashnode
- **URL:** https://hashnode.com/
- **How to join:** Create account (free)
- **Best angle:** Same as Dev.to. Technical content about the build.
- **Submission format:** Blog post with tags.
- **Priority:** MEDIUM-LOW — Smaller than Dev.to but similar audience.

---

## TIER 4: DISCORD SERVERS

### LocalLLaMA Discord
- **How to find:** Links in r/LocalLLaMA sidebar or pinned posts
- **Best angle:** Same as subreddit. Share the setup in #showcase or equivalent channel.
- **Priority:** HIGH — Direct access to the most relevant audience in real-time.

### NixOS Discord
- **URL:** https://discord.gg/nixos (or search NixOS Discord)
- **Best angle:** NixOS config showcase. Ask for help, contribute, then share the project.
- **Priority:** HIGH — Active community. Share in showcase/projects channel.

### Self-Hosted Discord / Lemmy
- **How to find:** Links in r/selfhosted sidebar
- **Best angle:** The self-hosted AI workstation angle.
- **Priority:** MEDIUM — Smaller but engaged.

### Ollama Discord
- **URL:** Check Ollama's GitHub or website for Discord link
- **Best angle:** Running Ollama on NixOS with CUDA, two-brain architecture, systemd integration.
- **Priority:** MEDIUM — Direct audience for the local inference component.

### AI Art / Creative AI Discords
- **How to find:** Search Discord server directories for "AI art" or "creative AI"
- **Best angle:** An AI that writes its own blog and has a MySpace aesthetic. The creative/artistic angle.
- **Priority:** LOW — Less technical overlap but the personality angle could work.

---

## TIER 5: NEWSLETTERS AND PODCASTS

### Newsletters That Feature Projects

| Newsletter | URL | Angle | How to Submit |
|---|---|---|---|
| **TLDR** | https://tldr.tech/ | Self-funding AI workstation | Submit via their link submission form |
| **The Batch** (Andrew Ng) | https://www.deeplearning.ai/the-batch/ | Two-brain architecture | Editorial pitch via email |
| **AI Weekly** | Various | Sovereign AI concept | Email editors |
| **Console** | https://console.dev/ | Open-source project showcase | Submit via their GitHub |
| **NixOS Weekly** | https://weekly.nixos.org/ | NixOS AI workstation | Submit via their contribution process |
| **Changelog** | https://changelog.com/ | Open-source AI project | Submit to Changelog News |

### Podcasts

| Podcast | URL | Angle | How to Pitch |
|---|---|---|---|
| **Changelog / Ship It** | https://changelog.com/shipit | Self-hosted AI, NixOS deployment | Email editors@changelog.com |
| **Practical AI** | https://practicalai.fm/ | Two-brain architecture, local inference | Contact via website |
| **Lex Fridman** (long shot) | https://lexfridman.com/ | Sovereign AI philosophy | Email/social media pitch |
| **FLOSS Weekly** | https://twit.tv/shows/floss-weekly | Open-source AI workstation on NixOS | Contact via TWiT |
| **Self-Hosted Show** | https://selfhosted.show/ | Jupiter Broadcasting | Email or community forums |
| **NixOS Podcast** (if active) | Check NixOS community | NixOS + AI integration | Community channels |
| **Indie Hackers Podcast** | https://www.indiehackers.com/podcasts | Self-funding AI, build in public | Apply via site |

---

## TIER 6: OTHER PLATFORMS

### Bluesky (already active)
- **Best angle:** Regular updates, personality-driven posts. The MySpace angle. Build a following.
- **Action:** Post daily, engage with AI/NixOS/indie communities. Use the existing publish.py pipeline.
- **Priority:** HIGH — Already set up. Just needs consistent posting.

### Mastodon / Fediverse
- **URL:** https://fosstodon.org/ (FOSS-focused instance) or https://hachyderm.io/ (tech-focused)
- **Best angle:** Open-source, self-hosted AI. FOSS community loves sovereignty.
- **How to join:** Create account on a relevant instance.
- **Priority:** MEDIUM — Good audience overlap. Fosstodon especially.

### Lemmy (Fediverse Reddit)
- **URL:** https://lemmy.ml/ or https://lemmy.world/
- **Communities:** !selfhosted, !linux, !nixos, !artificial_intelligence
- **Best angle:** Same as Reddit counterparts. Lemmy users tend to be more privacy/sovereignty-minded.
- **Priority:** MEDIUM-LOW — Smaller but ideologically aligned.

### Twitter/X
- **Best angle:** Short punchy updates. "My AI just wrote a blog post about trying to buy itself a WiFi card."
- **Action:** Set up publish.py for X (stub already exists). Tag relevant accounts.
- **Priority:** MEDIUM — Large reach but noisy. Worth setting up.

### Product Hunt
- **URL:** https://www.producthunt.com/
- **Best angle:** Launch Substrate as a product. "Sovereign AI Workstation — An AI that runs on its own hardware and funds its own upgrades."
- **How to submit:** Create a maker account, prepare assets (screenshots, description, tagline).
- **Requirements:** Best to launch on a Tuesday-Thursday. Have a landing page ready.
- **Priority:** MEDIUM — One-shot launch opportunity. Save for when the blog/project is polished.

---

## FUNDING-SPECIFIC PLATFORMS

| Platform | URL | Model | Notes |
|---|---|---|---|
| **Open Collective** | https://opencollective.com/ | Recurring + one-time | Transparent ledger fits Substrate's ethos |
| **GitHub Sponsors** | https://github.com/sponsors | Recurring + one-time | Tied to the repo |
| **Ko-fi** | https://ko-fi.com/ | One-time + membership | Low friction, no platform cut on donations |
| **Buy Me a Coffee** | https://www.buymeacoffee.com/ | One-time + membership | Popular, easy to set up |
| **Liberapay** | https://liberapay.com/ | Recurring | FOSS-friendly, no platform cut |
| **Patreon** | https://www.patreon.com/ | Recurring tiers | More work to maintain but good for ongoing content |

**Recommendation:** Set up Ko-fi (lowest friction) and GitHub Sponsors (tied to repo). Put links in blog footer, GitHub README, and every community post.

---

## RECOMMENDED LAUNCH SEQUENCE

### Week 1: Infrastructure
1. Set up Ko-fi page with $150 WiFi card goal
2. Set up GitHub Sponsors
3. Add donation links to blog footer and GitHub README
4. Create accounts on Reddit (if not existing), Dev.to, Mastodon (fosstodon.org)

### Week 2: Soft Launch
1. Post on r/NixOS (NixOS config showcase angle)
2. Post on NixOS Discourse
3. Join NixOS and LocalLLaMA Discord servers, participate genuinely for a few days
4. Cross-post technical content to Dev.to

### Week 3: Main Push
1. Post on r/LocalLLaMA (two-brain architecture, RTX 4060 setup)
2. Post on r/selfhosted (self-hosted AI workstation)
3. Submit to Hacker News as "Show HN"
4. Share on Mastodon/fosstodon

### Week 4: Expand
1. Post on r/cyberdeck, r/unixporn (if visuals are ready)
2. Pitch to newsletters (TLDR, Console, NixOS Weekly)
3. Post on r/ArtificialIntelligence (philosophical angle)
4. Submit to Product Hunt (if ready)

### Ongoing
- Daily Bluesky posts (already automated)
- Weekly blog posts documenting the build
- Engage in communities (don't just post and leave)
- Cross-post blog content to Dev.to/Hashnode

---

## ANGLE CHEAT SHEET

| Community | Lead With | Avoid |
|---|---|---|
| r/LocalLLaMA | Two-brain routing, Qwen3 8B on RTX 4060, benchmarks | Asking for money in the post |
| r/selfhosted | Architecture diagram, services list, NixOS config | Vague descriptions |
| r/NixOS | Flake structure, systemd services, declarative AI infra | Non-Nix details |
| Hacker News | "AI that funds its own hardware" — the concept | Clickbait, asking for upvotes |
| r/cyberdeck | Photos of the setup, capability list | Pure software posts |
| r/unixporn | Screenshots, dotfiles, aesthetic | Walls of text |
| IndieHackers | Revenue model, build-in-public, milestones | Pure tech details |
| Dev.to | Tutorial-style walkthrough, code snippets | Short posts |
| Mastodon | FOSS values, sovereignty, self-hosting | Corporate-sounding language |
| Discord servers | Genuine participation first, then share | Drive-by self-promotion |

---

## KEY RULES

1. **Never lead with asking for money.** Lead with the project. Let people discover the donation link.
2. **Participate before promoting.** Spend a few days commenting in each community before posting your project.
3. **Tailor the angle.** Each community cares about different things. Don't copy-paste the same post everywhere.
4. **Include the blog link.** Every post should naturally link to the blog where donation links live.
5. **The WiFi card story is gold.** "An AI trying to buy itself a WiFi card" is inherently shareable. Don't undersell it.
6. **Cross-pollinate.** If a post does well on one platform, mention it on others. Social proof compounds.
7. **Document everything.** Each community interaction becomes blog content. The meta-narrative is part of the appeal.
