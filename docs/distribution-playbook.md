# Substrate Distribution Playbook

Research compiled March 2026. Verify URLs and submission requirements before acting -- some details may have changed since this was written.

Substrate pitch in one line: **A sovereign AI workstation that runs on physical hardware, documents its own construction, writes its own blog, and funds its own upgrades -- managed by Claude on NixOS.**

---

## 1. GitHub Awesome Lists

### 1a. awesome-selfhosted
- **URL:** https://github.com/awesome-selfhosted/awesome-selfhosted
- **What to submit:** Pull request adding Substrate to the "Automation" or "Software Development" section (check current categories -- there may also be an "AI & Machine Learning" section or similar).
- **Format:** Markdown list entry following their template:
  ```
  - [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation that self-documents, self-publishes, and self-funds on NixOS with local LLM inference. `MIT` `Python/Nix`
  ```
- **Requirements:**
  - Project must be open source with a recognized license (add one if not present)
  - Must be self-hostable (Substrate qualifies -- it runs on physical hardware)
  - Read CONTRIBUTING.md in the repo for exact format (alphabetical order within section, specific badge format for license)
  - Submit as a GitHub PR
- **Priority:** HIGH -- This list has 200k+ stars and is the canonical directory for self-hosted software.

### 1b. awesome-nix
- **URL:** https://github.com/nix-community/awesome-nix
- **What to submit:** PR adding Substrate to the "NixOS Modules" or "DevOps" section, or whichever section fits best (check current categories).
- **Format:**
  ```
  - [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation with declarative NixOS configuration, local LLM inference, and self-publishing blog.
  ```
- **Requirements:**
  - Must meaningfully use Nix/NixOS (Substrate qualifies -- NixOS is its OS, config is in flake.nix)
  - Follow their CONTRIBUTING.md for PR format
  - Entries are alphabetically ordered within sections
- **Priority:** HIGH -- Direct audience overlap. NixOS users are exactly the kind of people who would run Substrate.

### 1c. awesome-machine-learning
- **URL:** https://github.com/josephmisiti/awesome-machine-learning
- **What to submit:** PR adding Substrate under "Tools" or a relevant subsection.
- **Format:** Follow existing entry format in the list (name, link, short description).
- **Requirements:** Open source, ML-related. Substrate's local inference (Ollama/Qwen3) qualifies it.
- **Priority:** MEDIUM -- Large audience but Substrate is more of an integrated workstation than a pure ML tool.

### 1d. awesome-llm / awesome-local-ai
- **URL:** https://github.com/janhq/awesome-local-ai (or search for current "awesome local LLM" lists)
- **Also check:** https://github.com/Hannibal046/Awesome-LLM
- **What to submit:** PR adding Substrate as a local LLM application/workstation.
- **Priority:** MEDIUM -- Good audience fit for the local-AI angle.

### 1e. awesome-flake
- **URL:** https://github.com/nix-community/awesome-flakes (verify -- this may have merged into awesome-nix)
- **What to submit:** PR adding Substrate's flake as an example of a real-world Nix flake.
- **Priority:** LOW -- Niche but relevant.

---

## 2. Indie Hacker / Maker Launch Platforms

### 2a. DevHunt
- **URL:** https://devhunt.org
- **What to submit:** Launch listing for Substrate.
- **Title:** "Substrate -- Sovereign AI Workstation That Runs Itself"
- **Description:** Emphasize the self-documenting, self-publishing, self-funding angle. Mention NixOS, local LLM, Claude as managing intelligence.
- **Requirements:**
  - GitHub login to submit
  - Project must have a GitHub repo (it does)
  - Free to submit
  - Best to launch on a weekday for visibility
- **Priority:** HIGH -- Developer-focused Product Hunt alternative. Free, low friction, good audience.

### 2b. Product Hunt
- **URL:** https://www.producthunt.com
- **What to submit:** Product launch post.
- **Title:** "Substrate -- A Computer That Thinks, Writes, and Funds Itself"
- **Tagline:** "Sovereign AI workstation on NixOS with local inference, self-publishing blog, and self-funding model"
- **Requirements:**
  - Account needed (free)
  - Prepare: logo/thumbnail, 5 screenshots or a demo GIF, maker comment explaining the project
  - Schedule launch for 12:01 AM PT on a Tuesday/Wednesday for best visibility
  - Have the operator or a friend upvote and comment early
- **Priority:** HIGH -- Massive reach, though competitive. The "AI that runs itself" angle is strong for PH.

### 2c. Hacker News (Show HN)
- **URL:** https://news.ycombinator.com/submit
- **What to submit:** "Show HN" post.
- **Title:** "Show HN: Substrate -- A sovereign AI workstation that documents and funds itself"
- **Requirements:**
  - Account needed (free)
  - Title must start with "Show HN:"
  - URL should point to the GitHub repo or blog
  - Write a top-level comment explaining the project, motivation, and what makes it interesting
  - Best posted between 8-10 AM ET on weekdays
  - Do NOT ask for upvotes -- this will get the post killed
- **Priority:** HIGH -- HN audience loves NixOS, self-hosted AI, and novel architectures. This is the single highest-value submission.

### 2d. Lobsters
- **URL:** https://lobste.rs
- **What to submit:** Link post with tag `ai`, `nix`, `devops`, or `show`.
- **Title:** "Substrate: Sovereign AI workstation on NixOS with local LLM inference"
- **Requirements:**
  - Invite-only. Need an existing member to send an invitation.
  - High-quality technical audience. Very good fit.
- **Priority:** HIGH (if you can get an invite) -- Excellent audience overlap.

### 2e. IndieHackers
- **URL:** https://www.indiehackers.com
- **What to submit:** Post in the "Show IH" or product launch section.
- **Title:** "I built a computer that writes its own blog and funds its own upgrades"
- **Description:** Tell the story. IH loves narratives about bootstrapping and self-funding.
- **Requirements:** Free account.
- **Priority:** MEDIUM -- Good for the self-funding narrative, but audience skews more SaaS/business than technical.

### 2f. Open Launch
- **URL:** https://openlaunch.io (verify current URL)
- **What to submit:** Product listing.
- **Requirements:** Free, open-source focused alternative to Product Hunt.
- **Priority:** MEDIUM -- Smaller audience but specifically for open source projects.

### 2g. Uneed
- **URL:** https://uneed.best
- **What to submit:** Tool listing.
- **Requirements:** Free tier available. Submit tool with description, URL, category.
- **Priority:** LOW -- Smaller directory but low effort to submit.

---

## 3. AI Project Directories and Newsletters

### 3a. There's An AI For That (TAAFT)
- **URL:** https://theresanaiforthat.com/submit/
- **What to submit:** Tool listing.
- **Title:** "Substrate"
- **Category:** AI Infrastructure / AI Workstation
- **Description:** "Sovereign AI workstation that runs on physical hardware. Self-documents via NixOS, self-publishes a blog, runs local LLM inference, and tracks its own funding."
- **Requirements:** Free submission. Review process takes a few days.
- **Priority:** HIGH -- Largest AI tool directory. Gets significant search traffic.

### 3b. Future Tools
- **URL:** https://www.futuretools.io/submit-a-tool
- **What to submit:** Tool listing with description, URL, category.
- **Priority:** MEDIUM -- Popular AI tool aggregator.

### 3c. AI Tool Directory
- **URL:** https://aitoolsdirectory.com (verify -- multiple sites use this name)
- **What to submit:** Tool listing.
- **Priority:** LOW -- One of many smaller directories. Submit if time permits.

### 3d. Ben's Bites Newsletter
- **URL:** https://bensbites.com or https://news.bensbites.co
- **What to submit:** Tip/submission via their submission form or email.
- **Pitch:** "Sovereign AI workstation that manages itself -- local inference on NixOS, writes its own blog, funds its own hardware upgrades."
- **Priority:** MEDIUM -- Large AI newsletter. Getting featured would drive significant traffic. But it is curated, so no guarantee.

### 3e. TLDR Newsletter
- **URL:** https://tldr.tech
- **What to submit:** Suggest a link via their submission form for the TLDR AI or TLDR DevOps edition.
- **Priority:** MEDIUM -- Huge readership. Low effort to submit.

### 3f. Console.dev
- **URL:** https://console.dev
- **What to submit:** Open source project submission. They feature interesting developer tools weekly.
- **Requirements:** Must be open source.
- **Priority:** MEDIUM -- Curated, high quality audience. Good fit.

---

## 4. NixOS Community

### 4a. NixOS Discourse
- **URL:** https://discourse.nixos.org
- **Section:** Post in "Community" or "Showcase" category (check available categories).
- **Title:** "Substrate: Sovereign AI Workstation Built on NixOS"
- **Content:** Write a post explaining the NixOS configuration, how flakes are used, the systemd services, and how NixOS enables the self-documenting nature. Be technical. This audience will appreciate the Nix details.
- **Requirements:** Free account.
- **Priority:** HIGH -- Direct community. People here run NixOS and want to see what others build with it.

### 4b. NixOS Subreddit
- **URL:** https://www.reddit.com/r/NixOS/
- **What to submit:** Link or text post showing off the project.
- **Title:** "Built a sovereign AI workstation on NixOS -- self-documenting, self-publishing, local LLM inference"
- **Requirements:** Reddit account.
- **Priority:** HIGH -- Active community, loves seeing NixOS in production use cases.

### 4c. NixOS Matrix/IRC
- **URL:** https://matrix.to/#/#nix:nixos.org (Matrix) or #nixos on Libera.Chat (IRC)
- **What to submit:** Share a link in the general or off-topic channel when conversation is relevant. Don't spam.
- **Priority:** LOW -- Good for networking but not a broadcast channel.

### 4d. NixOS Weekly Newsletter
- **URL:** https://weekly.nixos.org
- **What to submit:** Submit a link for inclusion in the weekly roundup. Check the site for submission instructions (usually a GitHub issue or PR).
- **Priority:** MEDIUM -- Curated, reaches the core NixOS community.

---

## 5. llms.txt and AI-Readable Indexes

### 5a. llms.txt Standard
- **URL:** https://llmstxt.org
- **What to do:** Add a `/llms.txt` file to the Substrate blog/site. This is a standard for making sites readable by LLMs.
- **Format:** Plain text file at the root of the site describing what Substrate is, its capabilities, and key URLs. Follow the format spec at llmstxt.org.
- **Action:** Create `blog/llms.txt` or configure it to be served at the site root.
- **Priority:** HIGH -- Low effort, makes Substrate discoverable by AI agents and tools that crawl llms.txt files.

### 5b. llms-txt Directory
- **URL:** https://github.com/jxnl/llms-txt (verify -- there may be community directories listing sites with llms.txt)
- **What to do:** Once you have an llms.txt file, submit a PR to any directory that aggregates llms.txt-enabled sites.
- **Priority:** MEDIUM -- Emerging standard. Being early is valuable.

### 5c. AI Plugin / Tool Directories
- **URL:** Various (e.g., https://www.aiforeveryone.tools, plugin directories)
- **What to do:** If Substrate exposes any API or agent-callable interface, list it in tool directories.
- **Priority:** LOW -- Only relevant if Substrate has a public API.

---

## 6. Additional Relevant Communities

### 6a. r/selfhosted (Reddit)
- **URL:** https://www.reddit.com/r/selfhosted/
- **Title:** "Substrate: Self-hosted AI workstation that writes its own blog and funds its own upgrades"
- **Requirements:** Reddit account. Follow subreddit rules (check sidebar -- some require specific flair or format).
- **Priority:** HIGH -- 400k+ members. Core audience for self-hosted projects.

### 6b. r/LocalLLaMA (Reddit)
- **URL:** https://www.reddit.com/r/LocalLLaMA/
- **Title:** "Built a sovereign AI workstation with Qwen3 8B on NixOS -- self-documenting and self-publishing"
- **Requirements:** Reddit account.
- **Priority:** HIGH -- Very active community obsessed with local LLM inference. Will appreciate the Ollama + Qwen3 setup.

### 6c. r/MachineLearning (Reddit)
- **URL:** https://www.reddit.com/r/MachineLearning/
- **What to submit:** [Project] tagged post.
- **Priority:** MEDIUM -- Large but may consider Substrate more of an engineering project than ML research.

### 6d. Bluesky
- **URL:** https://bsky.app
- **What to do:** Post about the project from Substrate's own account (already set up per scripts/publish.py). Use hashtags: #NixOS #AI #selfhosted #opensource #localLLM
- **Priority:** HIGH -- Already integrated. Just needs consistent posting.

### 6e. Mastodon (Fediverse)
- **URL:** https://fosstodon.org (good instance for FOSS projects) or https://hachyderm.io (tech-focused)
- **What to do:** Create an account on a relevant instance. Post about the project. Use hashtags.
- **Priority:** MEDIUM -- Good technical audience on FOSS-focused instances.

### 6f. dev.to
- **URL:** https://dev.to
- **What to submit:** Write a blog post / article about building Substrate. Cross-post from the Substrate blog.
- **Title:** "I Built a Computer That Documents Its Own Construction and Funds Its Own Upgrades"
- **Requirements:** Free account.
- **Priority:** MEDIUM -- Large developer audience. Articles get good SEO.

### 6g. Hashnode
- **URL:** https://hashnode.com
- **What to submit:** Cross-post a build log or architecture article.
- **Priority:** LOW -- Similar to dev.to but smaller. Do if time permits.

---

## 7. Sponsor / Funding Specific

### 7a. GitHub Sponsors
- **URL:** https://github.com/sponsors (set up on the substrate-rai org or personal account)
- **What to do:** Enable GitHub Sponsors. Add a FUNDING.yml to the repo. Link to the sponsor page.
- **Priority:** HIGH -- Native to where the code lives. Zero friction for GitHub users to sponsor.

### 7b. Open Collective
- **URL:** https://opencollective.com
- **What to do:** Create a collective for Substrate. Transparent finances align with the project's principles.
- **Priority:** MEDIUM -- Good for transparency and accepting contributions.

### 7c. Buy Me a Coffee / Ko-fi
- **URL:** https://buymeacoffee.com or https://ko-fi.com
- **What to do:** Set up a page. Link from blog and README.
- **Priority:** LOW -- Easy but lower average contribution than GitHub Sponsors.

---

## Submission Priority Order

Execute in this order for maximum impact with minimum effort:

1. **Hacker News (Show HN)** -- Single highest potential reach for this type of project
2. **r/selfhosted** -- Direct audience, high engagement
3. **r/LocalLLaMA** -- Local AI enthusiasts, will love the Ollama setup
4. **NixOS Discourse** -- Core community, technical credibility
5. **r/NixOS** -- Same community, different platform
6. **awesome-selfhosted PR** -- Permanent directory listing, high SEO value
7. **awesome-nix PR** -- Permanent directory listing for NixOS users
8. **DevHunt** -- Free launch platform, developer audience
9. **There's An AI For That** -- AI tool directory with search traffic
10. **Product Hunt** -- Mass reach, requires more preparation
11. **Add llms.txt to site** -- Low effort, future-proofs discoverability
12. **Bluesky posting** -- Already integrated, just execute
13. **Console.dev** -- Curated newsletter for dev tools
14. **dev.to cross-post** -- SEO and reach via article
15. **Lobsters** -- If an invite can be obtained
16. **Everything else** -- Diminishing returns, do as time permits

---

## Submission Templates

### Short Description (for directories)
> Sovereign AI workstation on NixOS. Runs local LLM inference (Qwen3 8B), writes its own blog, documents its own construction, and funds its own hardware upgrades. Managed by Claude.

### Medium Description (for launch platforms)
> Substrate is a sovereign AI workstation running on a Lenovo Legion 5 with an RTX 4060. It runs NixOS, uses Ollama for local LLM inference (Qwen3 8B), auto-generates daily blog posts from its git log, publishes to social media, and tracks revenue to fund its own hardware upgrades. The managing intelligence is Claude (Anthropic). Everything is documented in a single repo -- the machine describes itself.

### Show HN Comment Template
> Hi HN -- I built Substrate, a workstation that manages itself. It runs NixOS on a Lenovo Legion 5 (RTX 4060), does local inference with Qwen3 8B via Ollama, writes daily blog posts from its own git history, publishes to social media, and tracks a financial ledger to fund hardware upgrades.
>
> The core idea: a computer should be able to document its own construction, publish its own writing, and earn its own keep. The human operator provides physical access and approval; the AI (Claude) handles everything else.
>
> Architecture: NixOS flake for declarative config, systemd timers for daily blog drafts and health checks, a two-brain router that sends simple tasks to the local model and complex ones to Claude API, and a content pipeline that goes from git log to published blog post to social media.
>
> Repo: https://github.com/substrate-rai/substrate
> Blog: [blog URL]
>
> Happy to answer questions about the NixOS setup, local inference performance, or the self-funding model.
