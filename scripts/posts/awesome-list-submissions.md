# Awesome List Submissions for Substrate

Prepared for the operator. Each section contains the exact entry to submit, the target section in the list, a PR description, list requirements, and notes.

---

## Operator Checklist (same for all submissions)

For each awesome list submission:

1. [ ] Fork the target awesome-list repo on GitHub
2. [ ] Clone your fork locally (or use GitHub's web editor)
3. [ ] Create a new branch: `git checkout -b add-substrate`
4. [ ] Read the list's CONTRIBUTING.md and verify current section names, formatting rules, and any minimum requirements (e.g., star count, license)
5. [ ] Add the entry in the correct section, in **alphabetical order** within that section
6. [ ] Commit: `git commit -m "Add Substrate"`
7. [ ] Push and open a PR against the upstream repo's default branch
8. [ ] Use the PR description provided below
9. [ ] Monitor for maintainer feedback and respond promptly

**Before any submission:** Substrate currently has no LICENSE file in the repo. awesome-selfhosted and most other lists require a recognized open-source license. Add a LICENSE file (MIT recommended based on the README's tone and existing badge format) before submitting.

---

## 1. awesome-selfhosted

- **Repo:** https://github.com/awesome-selfhosted/awesome-selfhosted
- **Target section:** `Software Development - Low Code` is unlikely to fit. Check the current list -- look for `Automation` or `Software Development`. If there is no AI-specific section, `Automation` is the best fit.

### Exact entry to add

```
- [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation that self-documents, self-publishes, and self-funds on NixOS with local LLM inference (Ollama/Qwen3). ([Source Code](https://github.com/substrate-rai/substrate)) `MIT` `Python/Nix`
```

**Note:** awesome-selfhosted uses a specific format that includes a `([Source Code](URL))` link and license/language tags as backtick-enclosed badges. Verify the exact current format in their CONTRIBUTING.md before submitting -- the format above matches their established pattern as of early 2026, but they occasionally update it.

### PR title

```
Add Substrate
```

### PR description

```
Substrate is a sovereign AI workstation running on NixOS that uses local LLM inference (Qwen3 8B via Ollama with CUDA) alongside a cloud API router. It self-documents its configuration, auto-generates daily blog posts from its git history, publishes to social media, and tracks a financial ledger to fund its own hardware upgrades.

The entire system is self-hosted on a single laptop (Lenovo Legion 5, RTX 4060) with declarative NixOS configuration and runs unattended via systemd timers.
```

### Requirements to verify

- [ ] Project has a recognized open-source license file in the repo (MIT, GPL, etc.)
- [ ] Entry is in alphabetical order within the chosen section
- [ ] Format matches other entries in the same section exactly (check badge style, Source Code link)
- [ ] awesome-selfhosted does not currently have a minimum GitHub stars requirement (verify in CONTRIBUTING.md)

---

## 2. awesome-nix

- **Repo:** https://github.com/nix-community/awesome-nix
- **Target section:** Check current sections. Likely candidates: `DevOps`, `NixOS Modules`, `NixOS Configuration Management`, or `Community`. If there is a section for real-world NixOS configurations or projects, use that.

### Exact entry to add

```
- [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation with a Nix flake managing declarative NixOS configuration, systemd services for local LLM inference (Ollama), automated blogging, health monitoring, and battery management.
```

### PR title

```
Add Substrate
```

### PR description

```
Substrate is a real-world NixOS workstation managed entirely through a Nix flake. The flake defines the full system configuration including custom systemd services (local LLM inference via Ollama with CUDA, automated blog generation, health monitoring, battery guard), a dev shell with Python dependencies, and declarative service management.

It serves as a practical example of using NixOS flakes to define and reproduce a complete AI workstation with multiple integrated services.
```

### Requirements to verify

- [ ] Check which section fits best by reading the current list structure
- [ ] Entry is in alphabetical order within the section
- [ ] Format matches existing entries (some sections use different description styles)
- [ ] Read their CONTRIBUTING.md for any specific rules

---

## 3. awesome-machine-learning

- **Repo:** https://github.com/josephmisiti/awesome-machine-learning
- **Target section:** This list is organized by language. Check for a `Python / General-Purpose Machine Learning` section, or a `Tools` subsection. There may also be a top-level `Tools` section.

### Exact entry to add

```
- [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation with two-brain routing: simple tasks (drafting, summarization) run locally on Qwen3 8B via Ollama with CUDA, complex tasks (code review, architecture) route to a cloud LLM API. Includes automated content pipeline and self-documenting NixOS configuration.
```

### PR title

```
Add Substrate to Tools
```

### PR description

```
Substrate implements a two-brain routing architecture for local and cloud LLM inference. Simple tasks like drafting, summarization, and health checks run locally on Qwen3 8B via Ollama with CUDA acceleration (~40 tok/s on RTX 4060), while complex tasks like code review and architectural decisions route to a cloud API. The router decides automatically based on task type.

The system includes a full content pipeline (git log to blog post to social media), health monitoring, and runs as a self-managing workstation on NixOS.
```

### Requirements to verify

- [ ] Check the current section structure -- this list is large and organized by language
- [ ] Verify whether a "Tools" or "Frameworks" section exists at the top level
- [ ] Match the entry format to surrounding entries (some sections use minimal descriptions)
- [ ] Alphabetical ordering within section

---

## 4. awesome-local-ai / Local LLM Lists

### 4a. awesome-local-ai

- **Repo:** https://github.com/janhq/awesome-local-ai
- **Target section:** Check for `Applications`, `Tools`, or `Projects` sections.

#### Exact entry to add

```
- [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation running Qwen3 8B locally via Ollama on CUDA. Features two-brain routing (local for drafts/summaries, cloud for complex tasks), automated blog pipeline, and self-documenting NixOS configuration.
```

#### PR title

```
Add Substrate
```

#### PR description

```
Substrate is a self-managing AI workstation that runs Qwen3 8B locally via Ollama with CUDA acceleration on an RTX 4060. It implements a two-brain router that automatically dispatches tasks to either the local model or a cloud API based on complexity, and includes a full content pipeline that generates blog posts and social media content using local inference.

The entire system runs on NixOS with declarative configuration and operates unattended via systemd timers.
```

### 4b. Awesome-LLM

- **Repo:** https://github.com/Hannibal046/Awesome-LLM
- **Target section:** Check for `LLM Applications`, `Tools`, or `Projects` sections.

#### Exact entry to add

```
- [Substrate](https://github.com/substrate-rai/substrate) - Sovereign AI workstation with two-brain LLM routing: local Qwen3 8B (Ollama/CUDA) for drafts and summaries, cloud API for complex reasoning. Self-documenting, self-publishing on NixOS.
```

#### PR title

```
Add Substrate
```

#### PR description

```
Substrate is an integrated AI workstation that routes tasks between a local LLM (Qwen3 8B via Ollama with CUDA) and a cloud LLM API based on task complexity. It includes an automated content pipeline, self-documenting NixOS configuration, and runs as a fully self-managing system on consumer hardware (RTX 4060).

It demonstrates a practical approach to hybrid local/cloud LLM deployment with automatic task routing.
```

#### Requirements to verify for both

- [ ] Confirm these repos still exist and are actively maintained
- [ ] Check section structure -- local AI lists evolve quickly
- [ ] Match entry format to existing entries
- [ ] Some lists may have minimum star requirements

---

## General Notes

- **License:** Add a LICENSE file (recommend MIT) to the Substrate repo before any submission. awesome-selfhosted will reject without one, and other lists strongly prefer it.
- **Timing:** Space submissions out. Do not submit all PRs on the same day -- it looks spammy if maintainers cross-reference.
- **Follow up:** If a PR gets no response after 2 weeks, leave a polite comment asking for review.
- **Rejections:** If rejected, read the feedback. Common reasons: wrong section, format mismatch, project too new/small. Fix and resubmit if appropriate.
- **Star count:** Some lists have an unofficial minimum star threshold. If Substrate has very few stars at submission time, consider waiting until after Hacker News / Reddit launches drive some initial stars.
