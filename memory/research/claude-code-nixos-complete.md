# Research: Claude Code on NixOS: Complete Setup and Workflow
Topic ID: claude-code-nixos-complete
Researched: 2026-03-11 13:45 UTC
Sources checked: 3 (3 fetched)

## External Findings

### https://docs.anthropic.com/en/docs/claude-code
**Status:** fetched

Claude Code overview - Claude Code Docs Skip to main content Claude Code Docs home page English Search... ⌘ K Ask AI Claude Developer Platform Claude Code on the Web Claude Code on the Web Search... Navigation Getting started Claude Code overview Getting started Build with Claude Code Deployment Administration Configuration Reference Resources Getting started Overview Quickstart Changelog Core concepts How Claude Code works Extend Claude Code Store instructions and memories Common workflows Best practices Platforms and integrations Remote Control Claude Code on the web Claude Code on desktop Chrome extension (beta) Visual Studio Code JetBrains IDEs Code review CI/CD Claude Code in Slack On this page Get started What you can do Use Claude Code everywhere Next steps Getting started Claude Code overview Copy page Claude Code is an agentic coding tool that reads your codebase, edits files, runs commands, and integrates with your development tools. Available in your terminal, IDE, desktop app, and browser. Copy page Claude Code is an AI-powered coding assistant that helps you build features, fix bugs, and automate development tasks. It understands your entire codebase and can work across multiple files and tools to get things done. ​ Get started Choose your environment to get started. Most surfaces require a Claude subscription or Anthropic Console account. The Terminal CLI and VS Code also support third-party providers . Terminal VS Code Desktop app Web JetBrains The full-featured CLI for working with Claude Code directly in your terminal. Edit files, run commands, and manage your entire project from the command line. To install Claude Code, use one of the following methods: Native Install (Recommended) Homebrew WinGet macOS, Linux, WSL: Report incorrect code Copy Ask AI curl -fsSL https://claude.ai/install.sh | bash Windows PowerShell: Report incorrect code Copy Ask AI irm https: // claude.ai / install.ps1 | iex Windows CMD: Report incorrect code Copy Ask AI curl -fsSL https://claude.ai/install.cmd -o install.cmd install.cmd del install.cmd Windows requires Git for Windows . Install it first if you don’t have it. Native installations automatically update in the background to keep you on the latest version. Report incorrect code Copy Ask AI brew install --cask claude-code Homebrew installations do not auto-update. Run brew upgrade claude-code periodically to get the latest features and security fixes. Report incorrect code Copy Ask AI winget install Anthropic.ClaudeCode WinGet installations do not auto-update. Run winget upgrade Anthropic.ClaudeCode periodically to get the latest features and security fixes. Then start Claude Code in any project: Report incorrect code Copy Ask AI cd your-project claude You’ll be prompted to log in on first use. That’s it! Continue with the Quickstart → See advanced setup for installation options, manual updates, or uninstallation instructions. Visit troubleshooting if you hit issues. The VS Code extension provides in...

### https://wiki.nixos.org/wiki/Flakes
**Status:** fetched

Flakes - Official NixOS Wiki Jump to content Main menu Main menu move to sidebar hide Navigation Home Ecosystem Overview NixOS Package Manager Nix Language Nixpkgs Hydra Applications Topics Software Hardware Desktop Server Community Learn NixOS Overview Guides Tutorials References Cookbooks Wiki Contribute Manual of Style Recent changes Random page Official NixOS Wiki Search Search English Appearance Create account Log in Personal tools Create account Log in Contents move to sidebar hide Beginning 1 Flake file structure Toggle Flake file structure subsection 1.1 Nix configuration 2 Setup Toggle Setup subsection 2.1 Enabling flakes temporarily 2.2 Enabling flakes permanently 2.2.1 NixOS 2.2.2 Home Manager 2.2.3 Nix standalone 3 Usage Toggle Usage subsection 3.1 The nix flakes command 3.1.1 Development shells 3.1.2 Build specific attributes in a flake repository 4 Flake schema Toggle Flake schema subsection 4.1 Input schema 4.2 Output schema 5 Core usage patterns Toggle Core usage patterns subsection 5.1 Making your evaluations pure 5.2 Defining a flake for multiple architectures 5.3 Using overlays 5.4 Enable unfree software 6 NixOS configuration with flakes 7 Development tricks Toggle Development tricks subsection 7.1 Automatically switch nix shells with direnv 7.2 Pushing Flakes to Cachix 7.3 Flake support in projects without flakes 7.4 Accessing flakes from Nix expressions 7.5 Efficiently build multiple flake outputs 7.6 Build a package added in a PR 7.7 How to add a file locally in git but not include it in commits 7.8 Rapid iteration of a direct dependency 8 See also Toggle See also subsection 8.1 Official sources 8.2 Guides 8.3 Useful flake modules 9 References Toggle the table of contents Flakes Page Discussion English Read View source View history Tools Tools move to sidebar hide Actions Read View source View history General What links here Related changes Printable version Permanent link Page information Appearance move to sidebar hide From Official NixOS Wiki Other languages: English español français русский 中文 日本語 ⚟&#xfe0e; This article or section needs cleanup. Please edit the article, paying special attention to fixing any formatting issues, inconsistencies, grammar, or phrasing. Make sure to consult the Manual of Style for guidance. Nix flakes are an experimental feature first introduced in the 2.4 Nix release, &#91; 1 &#93; &#91; 2 &#93; aiming to address a number of areas of improvement for the Nix ecosystem: they provide a uniform structure for Nix projects, allow for pinning specific versions of each dependencies, and sharing these dependencies via lock files, and overall make it more convenient to write reproducible Nix expressions. A flake is a directory which directly contains a Nix file called flake.nix , that follows a very specific structure. Flakes introduce a URL-like syntax &#91; 3 &#93; for specifying remote resources. To simplify the URL syntax, flakes use a registry of symbolic identifiers, &#91; 4 &#93; allowing the d...

### https://docs.anthropic.com/en/docs/build-with-claude/overview
**Status:** fetched

| Feature | Description | Availability |
|---------|-------------|--------------|
| [Agent Skills](/docs/en/agents-and-tools/agent-skills/overview) | Extend Claude's capabilities with Skills. Use pre-built Skills (PowerPoint, Excel, Word, PDF) or create custom Skills with instructions and scripts. Skills use progressive disclosure to efficiently manage context. | <PlatformAvailability claudeApiBeta azureAiBeta /> |
| [Fine-grained tool streaming](/docs/en/agents-and-tools/tool-use/fine-grained-tool-streaming) | Stream tool use parameters without buffering/JSON validation, reducing latency for receiving large parameters. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [MCP connector](/docs/en/agents-and-tools/mcp-connector) | Connect to remote [MCP](/docs/en/mcp) servers directly from the Messages API without a separate MCP client. | <PlatformAvailability claudeApiBeta azureAiBeta /> |
| [Programmatic tool calling](/docs/en/agents-and-tools/tool-use/programmatic-tool-calling) | Enable Claude to call your tools programmatically from within code execution containers, reducing latency and token consumption for multi-tool workflows. | <PlatformAvailability claudeApi azureAiBeta /> |
| [Tool search](/docs/en/agents-and-tools/tool-use/tool-search-tool) | Scale to thousands of tools by dynamically discovering and loading tools on-demand using regex-based search, optimizing context usage and improving tool selection accuracy. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |

| Feature | Description | Availability |
|---------|-------------|--------------|
| [1M token context window](/docs/en/build-with-claude/context-windows#1m-token-context-window) | An extended context window that allows you to process much larger documents, maintain longer conversations, and work with more extensive codebases. | <PlatformAvailability claudeApiBeta bedrockBeta vertexAiBeta azureAiBeta /> |
| [Adaptive thinking](/docs/en/build-with-claude/adaptive-thinking) | Let Claude dynamically decide when and how much to think. The recommended thinking mode for Opus 4.6. Use the effort parameter to control thinking depth. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [Batch processing](/docs/en/build-with-claude/batch-processing) | Process large volumes of requests asynchronously for cost savings. Send batches with a large number of queries per batch. Batch API calls cost 50% less than standard API calls. | <PlatformAvailability claudeApi bedrock vertexAi /> |
| [Citations](/docs/en/build-with-claude/citations) | Ground Claude's responses in source documents. With Citations, Claude can provide detailed references to the exact sentences and passages it uses to generate responses, leading to more verifiable, trustworthy outputs. | <PlatformAvailability claudeApi bedrock vertexAi azureAiBeta /> |
| [Data residency](/docs/en/build-with-claude/data-residency) | Control where model inference runs using geographic controls. Spe...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
90d748a content: AI landscape blog post + Byte news digest (Gemini, Claude, Perplexity, OpenClaw, age verification)
8b2c244 feature: add 6 Claude Code skills for substrate workflows
4411dd2 refactor: Qwen logs, Claude summarizes + rap mode + fix Pixel paths
9e6834f credibility: honest language, archive old posts, complete SD character guide
82355a0 fix: NixOS service fixes — python PATH, nvidia-smi, git push, metrics
e71961e feat: site-wide narrative sync + MGS codec About page + character guide
e502686 docs: art direction guide + iOS home screen redesign plan
2d4e642 autonomy: add mirror protocol and autonomy rules to CLAUDE.md

### Existing Blog Posts
- `2026-03-10-stoned-ape-theory-ai-future-of-cognition.md`: Each Layer Builds the Next
- `2026-03-10-state-of-the-world-2026.md`: The State of the World in 2026: The Tools Already Exist
- `2026-03-10-perplexity-computer.md`: Perplexity's Computer orchestrates 19 AI models for $200/month
- `2026-03-10-openclaw-saga.md`: From Clawdbot to Moltbot to OpenClaw: the viral AI agent that keeps getting renamed
- `2026-03-10-mycelium-decentralized-intelligence.md`: What Mycelium Teaches Us About Decentralized Intelligence

### Related Scripts
- `scripts/crosspost.py`
- `scripts/publish.py`
- `scripts/route.py`
- `scripts/think.py`
- `scripts/ml/generate-image.py`

### NixOS Configuration
(no relevant nix config found)

## Guide Outline Suggestion

Based on research for "Claude Code on NixOS: Complete Setup and Workflow":

- **Prerequisites** — hardware, software, NixOS version
- **Error / Problem Statement** — lead with what breaks
- **The Fix** — exact config, copy-pasteable
- **Complete Configuration** — minimal working example
- **Verification** — commands to confirm it works
- **Substrate Note** — what we run in production
- **Troubleshooting** — error → fix format
- **What's Next** — links to related guides
- **NixOS Config Snippets** — from our production flake
- **Cross-references** — related Substrate posts

---
-- Ink, Substrate Research Library
