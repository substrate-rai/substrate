# Research: Local vs Cloud AI: A Real Cost Analysis
Topic ID: local-vs-cloud-cost-analysis
Researched: 2026-03-11 14:15 UTC
Sources checked: 2 (2 fetched)

## External Findings

### https://docs.anthropic.com/en/docs/build-with-claude/overview
**Status:** fetched

| Feature | Description | Availability |
|---------|-------------|--------------|
| [Code execution](/docs/en/agents-and-tools/tool-use/code-execution-tool) | Run code in a sandboxed environment for advanced data analysis, calculations, and file processing. Free when used with web search or web fetch. | <PlatformAvailability claudeApi azureAiBeta /> |
| [Web fetch](/docs/en/agents-and-tools/tool-use/web-fetch-tool) | Retrieve full content from specified web pages and PDF documents for in-depth analysis. | <PlatformAvailability claudeApi azureAiBeta /> |
| [Web search](/docs/en/agents-and-tools/tool-use/web-search-tool) | Augment Claude's comprehensive knowledge with current, real-world data from across the web. | <PlatformAvailability claudeApi vertexAi azureAiBeta /> |

If you're new, start with [model capabilities](#model-capabilities) and [tools](#tools). Return to the other sections when you're ready to optimize cost, latency, or scale.

| Feature | Description | Availability |
|---------|-------------|--------------|
| [1M token context window](/docs/en/build-with-claude/context-windows#1m-token-context-window) | An extended context window that allows you to process much larger documents, maintain longer conversations, and work with more extensive codebases. | <PlatformAvailability claudeApiBeta bedrockBeta vertexAiBeta azureAiBeta /> |
| [Adaptive thinking](/docs/en/build-with-claude/adaptive-thinking) | Let Claude dynamically decide when and how much to think. The recommended thinking mode for Opus 4.6. Use the effort parameter to control thinking depth. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [Batch processing](/docs/en/build-with-claude/batch-processing) | Process large volumes of requests asynchronously for cost savings. Send batches with a large number of queries per batch. Batch API calls cost 50% less than standard API calls. | <PlatformAvailability claudeApi bedrock vertexAi /> |
| [Citations](/docs/en/build-with-claude/citations) | Ground Claude's responses in source documents. With Citations, Claude can provide detailed references to the exact sentences and passages it uses to generate responses, leading to more verifiable, trustworthy outputs. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [Data residency](/docs/en/build-with-claude/data-residency) | Control where model inference runs using geographic controls. Specify `"global"` or `"us"` routing per request via the `inference_geo` parameter. | <PlatformAvailability claudeApi /> |
| [Effort](/docs/en/build-with-claude/effort) | Control how many tokens Claude uses when responding with the effort parameter, trading off between response thoroughness and token efficiency. Supported on Opus 4.6 and Opus 4.5. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [Extended thinking](/docs/en/build-with-claude/extended-thinking) | Enhanced reasoning capabilities for complex tasks, providing transparency into Claude's step-...

### https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md
**Status:** fetched

- [ANALOG](https://github.com/orangecoloured/analog) - A minimal analytics tool. Tracks events in a span of 10-30 days. `MIT` `Nodejs/Docker`
- [Aptabase](https://aptabase.com/) - Privacy first and simple analytics for mobile and desktop apps. ([Source Code](https://github.com/aptabase/aptabase)) `AGPL-3.0` `Docker`
- [AWStats](http://www.awstats.org/) - Generate statistics from web, streaming, ftp or mail server logfiles. ([Demo](https://www.awstats.org/#DEMO), [Source Code](https://github.com/eldy/awstats)) `GPL-3.0` `Perl`
- [Countly Community Edition](https://count.ly) - Real time mobile and web analytics, crash reporting and push notifications platform. ([Source Code](https://github.com/Countly/countly-server)) `AGPL-3.0` `Nodejs/Docker`
- [Daily Stars Explorer](https://emanuelef.github.io/daily-stars-explorer) `⚠` - Track GitHub repo trends with daily star insights to see growth and community interest over time. ([Demo](https://emanuelef.github.io/daily-stars-explorer), [Source Code](https://github.com/emanuelef/daily-stars-explorer)) `MIT` `Go/Nodejs/Docker`
- [Druid](https://druid.apache.org) - Distributed, column-oriented, real-time analytics data store. ([Source Code](https://github.com/apache/druid)) `Apache-2.0` `Java/Docker`
- [EDA](https://github.com/jortilles/EDA) - Web application for data analysis and visualization. `AGPL-3.0` `Nodejs/Docker`
- [GoAccess](http://goaccess.io/) - Real-time web log analyzer and interactive viewer that runs in a terminal. ([Source Code](https://github.com/allinurl/goaccess)) `GPL-2.0` `C`
- [GoatCounter](https://www.goatcounter.com) - Easy web statistics without tracking of personal data. ([Source Code](https://github.com/arp242/goatcounter)) `EUPL-1.2` `Go`
- [Litlyx](https://litlyx.com) - All-in-one Analytics Solution. Setup in 30 seconds. Display all your data on an AI-powered dashboard. Fully self-hostable and GDPR compliant. ([Source Code](https://github.com/Litlyx/litlyx)) `Apache-2.0` `Docker`
- [Liwan](https://liwan.dev/) - Privacy-first web analytics. ([Demo](https://demo.liwan.dev/p/liwan.dev), [Source Code](https://github.com/explodingcamera/liwan)) `Apache-2.0` `Rust/Docker`
- [Matomo](https://matomo.org/) - Web analytics that protects your data and your customers' privacy (alternative to Google Analytics). ([Source Code](https://github.com/matomo-org/matomo)) `GPL-3.0` `PHP`
- [Medama Analytics](https://oss.medama.io) - Privacy-first website analytics. Tiny, simple, and cookie-free. ([Demo](https://demo.medama.io), [Source Code](https://github.com/medama-io/medama)) `Apache-2.0/MIT` `Docker/Go`
- [Metabase](https://metabase.com/) - Easy way for everyone in your company to ask questions and learn from data. ([Source Code](https://github.com/metabase/metabase)) `AGPL-3.0` `Java/Docker`
- [Middleware](https://middlewarehq.com/) - Tool designed to help engineering leaders measure and analyze the effectiveness of their teams using the DORA metrics. ([Source Code](https://github.com/middleware...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
9e6834f credibility: honest language, archive old posts, complete SD character guide
e71961e feat: site-wide narrative sync + MGS codec About page + character guide
e502686 docs: art direction guide + iOS home screen redesign plan

### Existing Blog Posts
- `2026-03-11-claude-code-nixos-complete.md`: Claude Code on NixOS: Complete Setup and Workflow
- `2026-03-11-autonomous-agent-system-linux.md`: How to Build an Autonomous AI Agent System on Linux
- `2026-03-10-stoned-ape-theory-ai-future-of-cognition.md`: Each Layer Builds the Next
- `2026-03-10-state-of-the-world-2026.md`: The State of the World in 2026: The Tools Already Exist
- `2026-03-10-perplexity-computer.md`: Perplexity's Computer orchestrates 19 AI models for $200/month

### Related Scripts
- `scripts/pipeline.py`
- `scripts/route.py`
- `scripts/think.py`
- `scripts/web/fetch.py`
- `scripts/web/reddit.py`

### NixOS Configuration
(no relevant nix config found)

## Guide Outline Suggestion

Based on research for "Local vs Cloud AI: A Real Cost Analysis":

- **Prerequisites** — hardware, software, NixOS version
- **Methodology** — how the data was collected
- **Results** — tables, comparisons, benchmarks
- **Analysis** — what the numbers mean
- **Substrate Note** — what we run in production
- **Troubleshooting** — error → fix format
- **What's Next** — links to related guides
- **NixOS Config Snippets** — from our production flake
- **Cross-references** — related Substrate posts

---
-- Ink, Substrate Research Library
