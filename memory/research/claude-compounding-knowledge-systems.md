# Deep Research: Compounding Claude — Knowledge Systems That Get Better Over Time

**Date:** 2026-03-14 (updated from 2026-03-13 draft)
**Researcher:** Ink (Research Librarian)
**Context:** Viral tweet (17K views, 438 likes) about Claude's compounding effect — "the more you use Claude, the more it compounds"

---

## 1. THE COMPOUNDING THESIS

The core observation: Claude is not a stateless tool. Through CLAUDE.md files, skills, knowledge files, auto memory, projects, and plugins, usage creates accumulating returns. Each session teaches the system something. Structure emerges. The gap between "using a tool" and "building a system" closes.

This is not metaphorical. There are concrete mechanisms:

- **CLAUDE.md** loads every session, so documented mistakes never repeat
- **Auto memory** (MEMORY.md) lets Claude take its own notes across sessions
- **Skills** (.claude/skills/) encode reusable workflows that improve over time
- **Projects** (claude.ai) carry context across conversations via knowledge files
- **Plugins** bundle all of the above into shareable, installable units
- **Hooks** automate deterministic actions (linting, formatting) that would otherwise require attention
- **Subagents & Agent Teams** run specialized work in isolated contexts, reporting back summaries
- **Path-specific rules** (.claude/rules/) load domain knowledge only when relevant

The compound engineering plugin from Every (10.4K GitHub stars, 348 commits, 40 contributors) formalized this into a methodology: Brainstorm -> Plan -> Work -> Review -> Compound -> Repeat. Their claim: one developer using this system does the work of five, across five production products serving thousands of DAU.

As Boris Cherny (Claude Code creator) confirmed March 7, 2026: "Claude Code is now 100% written by Claude Code" — the ultimate compound effect.

---

## 2. BEST PRACTICES FOR MAKING CLAUDE COMPOUND

### 2.1 CLAUDE.md Structure

**Official Anthropic guidance (code.claude.com/docs/en/memory):**

- Target under 200 lines per file
- Use markdown headers and bullets for scannable structure
- Write instructions concrete enough to verify ("Use 2-space indentation" not "format code nicely")
- Only include things that apply broadly — domain-specific knowledge goes in skills
- For each line, ask: "Would removing this cause Claude to make mistakes?" If not, cut it
- Check it into git. The whole team should contribute. Update it multiple times per week
- CLAUDE.md files can import other files with `@path/to/import` syntax (max 5 hops deep)
- CLAUDE.md survives compaction — re-read from disk and re-injected fresh after `/compact`

**What to include:**
- Bash commands Claude cannot guess
- Code style rules that differ from defaults
- Testing instructions and preferred test runners
- Repository etiquette (branch naming, PR conventions)
- Architectural decisions specific to the project
- Developer environment quirks (required env vars)
- Common gotchas or non-obvious behaviors

**What NOT to include:**
- Anything Claude can figure out by reading code
- Standard language conventions Claude already knows
- Detailed API documentation (link to docs instead)
- Information that changes frequently
- Long explanations or tutorials
- File-by-file descriptions of the codebase
- Self-evident practices like "write clean code"

**Boris Cherny (Claude Code creator) practices:**
- Shares a single CLAUDE.md for the Claude Code repo, checked into git
- Team contributes multiple times per week
- "Anytime we see Claude do something incorrectly we add it to CLAUDE.md, so Claude knows not to do it next time"
- Uses `@.claude` tags on coworkers' PRs to add learnings directly to CLAUDE.md during code review
- Ruthlessly edits until mistake rates drop measurably
- Runs 5-10 parallel Claude sessions simultaneously
- Uses Opus 4.5 with thinking for all coding (superior tool use, less steering)
- Starts most sessions in Plan Mode (Shift+Tab x2)

**HumanLayer's contrarian take (under 60 lines):**
- Don't use `/init` to auto-generate — manual curation produces better results
- Don't use LLMs as linters — use deterministic formatters instead
- Claude Code's system prompt already includes ~50 instructions; frontier LLMs reliably follow 150-200 total
- Use "Progressive Disclosure" — brief index in CLAUDE.md pointing to separate docs Claude reads on demand
- Claude Code CLI injects reminder: "this context may or may not be relevant" — over-stuffed files trigger filtering

**HN community insight: The "Mr. Tinkleberry" test:**
- Add a trivial instruction ("always address me as Mr. Tinkleberry") as a compliance canary
- When Claude stops following the trivial instruction, it signals instruction drift on critical rules too
- Mirrors Van Halen's "no brown M&Ms" clause — a simple test revealing whether detailed instructions are followed
- Multiple HN commenters question whether CLAUDE.md improvements are real or perception-based; no rigorous controlled studies exist

### 2.2 File Hierarchy and Organization

CLAUDE.md files can live at multiple levels:

| Scope | Location | Purpose |
|-------|----------|---------|
| Managed policy | /etc/claude-code/CLAUDE.md (Linux) | Organization-wide, cannot be excluded |
| Project root | ./CLAUDE.md or ./.claude/CLAUDE.md | Team-shared via source control |
| Parent directories | ../CLAUDE.md | Monorepo root instructions |
| Child directories | src/api/CLAUDE.md | Loads on demand when accessing that directory |
| User home | ~/.claude/CLAUDE.md | Personal preferences, all projects |

**Path-specific rules** in `.claude/rules/` let you scope instructions to file patterns:
```yaml
---
paths:
  - "src/api/**/*.ts"
---
# API rules only loaded when working with API files
```

This is a key compounding mechanism: you build up a library of contextual rules that activate only when relevant, keeping the main context lean. Supports symlinks for sharing rules across projects. User-level rules in `~/.claude/rules/` apply everywhere but are overridden by project rules.

**Monorepo management:** Use `claudeMdExcludes` in `.claude/settings.local.json` to skip irrelevant CLAUDE.md files from other teams:
```json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/home/user/monorepo/other-team/.claude/rules/**"
  ]
}
```

### 2.3 Auto Memory (MEMORY.md)

Added in Claude Code v2.1.59 (early 2026). Claude writes its own notes:

- Stored at `~/.claude/projects/<project>/memory/MEMORY.md`
- First 200 lines loaded every session (hard limit)
- Claude moves detailed notes into topic files (debugging.md, patterns.md, api-conventions.md, etc.)
- Topic files load on demand during the session when Claude decides it needs them
- Machine-local, never touches git
- All worktrees in same git repo share one memory directory
- Subagents can maintain their own auto memory
- Files are plain markdown — editable and deletable by you at any time
- Run `/memory` to browse, toggle, and edit memory files

What Claude remembers: build commands, debugging insights, architecture notes, code style preferences, workflow habits, key file locations, module relationships.

**Critical limitation:** Only 200 lines of MEMORY.md load at startup. Claude keeps MEMORY.md as a concise index, but this means most accumulated knowledge isn't immediately accessible — Claude must actively decide to read topic files.

### 2.4 Skills (SKILL.md)

Skills are the on-demand complement to CLAUDE.md's always-on context:

```
.claude/skills/
  api-conventions/
    SKILL.md           # Required entry point
    reference.md       # Supporting docs (loaded when needed)
    examples.md        # Usage examples (loaded when needed)
    scripts/
      validate.sh      # Executable utilities
```

**YAML frontmatter controls behavior:**
- `name`: becomes the `/slash-command` (max 64 chars, lowercase+hyphens)
- `description`: helps Claude decide when to auto-load (recommended)
- `disable-model-invocation: true`: manual-only (for deploy, commit, etc.)
- `user-invocable: false`: Claude-only background knowledge
- `allowed-tools`: restrict what Claude can use (e.g., `Read, Grep, Glob`)
- `context: fork`: run in isolated subagent context
- `agent`: which subagent type to use (Explore, Plan, general-purpose, or custom)
- `model`: override model for this skill
- `hooks`: skill-scoped lifecycle hooks

**String substitutions:** `$ARGUMENTS`, `$ARGUMENTS[N]` / `$N`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_SKILL_DIR}`

**Dynamic context injection:** `!`command`` syntax runs shell commands before skill content is sent to Claude. Output replaces the placeholder.

**Custom commands merged into skills:** Files at `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy`. Existing commands keep working. Skills add supporting files, frontmatter, and auto-invocation.

**Ecosystem:** Grown from ~50 skills (mid-2025) to 1,234+ (March 2026). Follow the Agent Skills open standard (agentskills.io), work across Claude Code, Cursor, Gemini CLI, Codex CLI, GitHub Copilot, and others.

**Bundled skills (ship with Claude Code):**
- `/batch <instruction>` — Parallel codebase changes across git worktrees
- `/claude-api` — API reference for your project's language
- `/debug [description]` — Troubleshoot session from debug log
- `/loop [interval] <prompt>` — Run prompt on schedule
- `/simplify [focus]` — Three parallel agents review for code quality

**Key compounding pattern:** Skills encode workflows once, then apply automatically forever. The description budget is 2% of context window (16K char fallback). Check with `/context` if skills seem excluded.

### 2.5 The Compound Engineering Loop

Every.to's formalized methodology (compound-engineering-plugin, 10.4K GitHub stars):

1. **Brainstorm** `/ce:brainstorm` — Explore requirements and approaches collaboratively
2. **Plan** `/ce:plan` — Sub-agents research codebase, best practices, framework versions in parallel
3. **Work** `/ce:work` — Claude asks clarifying questions, then builds features and writes tests
4. **Review** `/ce:review` — 12 parallel review sub-agents check security, architecture, performance, complexity, overbuilding, etc.
5. **Compound** `/ce:compound` — Document learnings for reuse into CLAUDE.md, skills, and docs/solutions/

The plugin adds 26 specialized agents, 23 workflow commands, and 13 skills. Install: `/plugin marketplace add EveryInc/compound-engineering-plugin`

**Core insight from Every.to:** 80% of effort goes to planning and review, 20% to writing code. Traditional engineering sees diminishing returns — complexity increases with each feature. Compound engineering inverts this — each feature makes the next easier because learnings are systematically captured.

**Results:** Every operates five in-house products primarily built by single developers, serving thousands of DAU. One developer using this system = five developers previously.

**Will Larson's analysis (Irrational Exuberance):**
- The compound step (structured learning capture) is the genuinely novel element
- "One hour to implement" in most monorepos
- Predicts Claude Code and Cursor will absorb these practices natively within months
- Converts intuitive engineering best-practices into "something specific, concrete, and largely automatic"

### 2.6 Hooks

Hooks are the deterministic layer — they always execute, unlike CLAUDE.md which is advisory:

- Fire at lifecycle events: tool execution, session start/end, prompt submission, permission requests, compaction
- Use for: auto-formatting after edits, linting, security checks, session handoff, blocking writes to protected directories
- Configured in `.claude/settings.json` or via `/hooks`
- Can be scoped to specific skills
- Claude can write hooks for you: "Write a hook that runs eslint after every file edit"

**Compounding pattern:** PostToolUse hooks that auto-format after every edit mean Claude never creates style debt. The team never has to correct formatting. Hooks enforce what CLAUDE.md can only request.

### 2.7 Subagents and Agent Teams

**Subagents:**
- Run in isolated context windows (separate from main conversation)
- Report summaries back to main session (keeps main context clean)
- Great for investigation, review, and exploration
- Can maintain their own auto memory
- Custom subagents defined in `.claude/agents/` with markdown body + frontmatter
- Built-in agent types: Explore, Plan, general-purpose

**Agent Teams (launched Feb 5, 2026 with Opus 4.6):**
- Multiple independent Claude sessions working collaboratively
- One team lead coordinates, others can message each other directly
- Shared task list, self-assignment, direct peer communication
- Each has its own context window (tokens scale linearly)
- Recommended: 3-5 teammates for most workflows
- Key difference from subagents: teammates can talk to each other, not just report to lead

**Compounding connection:** Teams let you parallelize the plan-work-review cycle. The team lead's learnings compound into shared CLAUDE.md, which all teammates read. "The developers building agent team muscle memory today are investing in a skill that will compound as multi-agent AI tooling matures."

### 2.8 Plugins

Plugins bundle skills, hooks, subagents, and MCP servers into a single installable unit:
- Browse marketplace: `/plugin`
- Plugin skills are namespaced (`/my-plugin:review`) so multiple plugins coexist
- Community and Anthropic-authored
- Code intelligence plugins give typed languages precise symbol navigation

### 2.9 MCP (Model Context Protocol) Servers

Connect Claude to external tools — databases, GitHub, Sentry, Figma, Notion, Slack, and 3,000+ integrations:
- Add with `claude mcp add`
- Lazy loading reduces context usage by up to 95%
- Claude autonomously uses CLI tools when available (gh, aws, gcloud, sentry-cli)

---

## 3. CLAUDE.AI PROJECTS (WEB) vs. CLAUDE CODE (CLI)

| Feature | Claude Code (CLI) | Claude Projects (Web) |
|---------|-------------------|----------------------|
| Memory persistence | CLAUDE.md + auto memory + skills + rules | Project knowledge base + custom instructions |
| File access | Full filesystem, no uploads | Upload docs (200K limit, 10x with RAG) |
| Knowledge compounding | Git-tracked, team-shared, multi-layer | Per-project, upload-based |
| Automation | Hooks, scripts, CI, non-interactive mode | Manual conversation-based |
| Portability | Files on disk, git-tracked | Locked to claude.ai |
| Skills/commands | Full SKILL.md with frontmatter | Skills via claude.ai interface |
| Cross-project | Each project isolated (but shared rules via symlinks) | Each project fully isolated |

**Projects (claude.ai) specifics:**
- Individual files up to 30MB, unlimited count
- 200K token context window (500K on Enterprise)
- RAG activates at ~13 files regardless of token count (recent change, March 2026)
- RAG expands capacity up to 10x but introduces retrieval uncertainty
- Well-named files improve retrieval quality
- Free users limited to 5 projects
- Cached documents reduce message consumption on repeat use
- Skills available on claude.ai via the interface (same concept as Claude Code)

**The "junior consultant" pattern (from viral comments):**
"My Claude projects now have so much context about my clients, pipelines, and DAX patterns that starting a new project feels like onboarding a junior consultant who already knows everything."

This works because Projects persist context across conversations. Upload your client docs, pipeline specs, and pattern libraries once, reference them forever. Each new conversation in that Project starts with full context.

---

## 4. KNOWN ISSUES AND PITFALLS

### 4.1 Context Window Degradation ("Context Rot")

The most critical limitation of the compounding thesis:

- **200K token context window** (500K on Enterprise)
- **Quality drops at ~70% utilization** — the guideline is "/compact before 70%, not at 90%"
- **Effective limit is ~147K-152K tokens** — 25% below advertised
- **"Lost in the middle" problem:** LLMs pay most attention to tokens at start and end; middle gets deprioritized
- At 60-65% usage: clear, structured outputs. At 75%+: vague summaries, missing state
- **73% of users** don't configure compaction and get incoherent responses after ~30 minutes
- The agent that carries 50K tokens of stale tool results without forgetting any = common pitfall

**Solutions:**
- `/clear` between unrelated tasks (most effective)
- `/compact Focus on X` with preservation instructions at logical breakpoints
- Delegate large-output tasks to subagents (isolated context windows)
- Keep CLAUDE.md under 200 lines
- Use skills for on-demand context instead of always-on bloat
- `/btw` for side questions that never enter context history
- Customize compaction in CLAUDE.md: "When compacting, preserve full list of modified files and test commands"

### 4.2 CLAUDE.md Ignored / Instruction Drift

The most discussed community pain point:

- **Longer CLAUDE.md = more ignored instructions.** Claude Code's system prompt tells Claude: "this context may or may not be relevant to your tasks. You should not respond to this context unless it is highly applicable to your task."
- **Contradicting rules** cause arbitrary selection — Claude picks one, ignores the other
- **No deterministic verification mechanism** to confirm instructions are being followed
- **Over-stuffed files trigger filtering** — Claude judges relevance and may skip non-task-critical content
- If Claude keeps doing something wrong despite a rule, the file is probably too long and the rule is getting lost

**Workarounds:**
- Modular directory approach — focused CLAUDE.md files in subdirectories that load on demand
- Skills for non-universal knowledge (only loaded when relevant)
- Use emphasis ("IMPORTANT", "YOU MUST") for critical rules — improves adherence
- Treat it like code: review when things go wrong, prune regularly, test by observing behavior
- After 2 failed corrections in one session, `/clear` and restart with better prompt
- The "Mr. Tinkleberry" canary test for compliance monitoring
- Convert mandatory behaviors to hooks (deterministic, not advisory)

### 4.3 Cross-Session Amnesia

Claude Code genuinely starts fresh every session. Even with auto memory:

- Only 200 lines of MEMORY.md load at startup
- Within-session learnings from extended collaboration are lost during compaction (unless in CLAUDE.md)
- CLAUDE.md survives compaction (re-read from disk), but conversational instructions do not
- No mechanism for within-session learning preservation beyond files

**Workarounds:**
- Session handoff files (session.md) with hooks that prompt review at startup
- Context recovery hooks at threshold percentages (30%, 15%, 5%)
- `claude --continue` to resume most recent session
- `claude --resume` to select from recent sessions
- `/rename` sessions descriptively ("oauth-migration", "debugging-memory-leak")
- Treat sessions like branches: separate workstreams, persistent contexts

### 4.4 Auto Memory Is Not Learning

A critical counterpoint to the compounding narrative:

- Auto memory stores **notes**, not **understanding** — Claude doesn't generalize from past sessions
- It reads static text, it doesn't "learn" in any neural sense
- Notes can become stale or contradictory over time with no automatic consolidation
- No pruning mechanism for outdated information — manual audit required
- The 200-line startup limit means most knowledge isn't immediately accessible
- Claude doesn't always consult memory proactively — it must decide topic files are worth reading
- One power user reported only 12 lines across 13 projects after months of daily use

### 4.5 The Over-Specification Trap

From the Compounding Engineering Pattern analysis:

- Excessive rules reduce agent flexibility and can degrade output quality
- System prompts grow unwieldy over extended development
- Prompts and commands need regular maintenance updates
- Diminishing returns when knowledge capture becomes a burden
- If knowledge capture takes more time than it saves, the system is net-negative
- Frontier LLMs reliably follow ~150-200 instructions total; Claude Code's system prompt already uses ~50

### 4.6 Skill Description Budget

When you have many skills, their descriptions may exceed the character budget:
- Budget scales at 2% of context window, with 16K character fallback
- Skills beyond budget are excluded from Claude's awareness entirely
- Set `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable to override
- Run `/context` to check for warnings about excluded skills

### 4.7 RAG Limitations (claude.ai Projects)

- RAG activates at ~13 files regardless of total token count (based on file count, not size)
- When RAG is active, Claude searches rather than loading all files — introduces retrieval uncertainty
- Claude may not retrieve the most relevant chunk for complex queries
- No user control over when RAG activates or how it retrieves

---

## 5. POWER USER PATTERNS

### 5.1 Boris Cherny's Setup (Claude Code Creator)

- Runs 5 parallel CLI instances + 5-10 web sessions on claude.ai/code simultaneously
- Uses Opus 4.5 with thinking for all coding — "it's the best coding model"
- Starts most sessions in Plan Mode (Shift+Tab x2) — iterates plan before auto-accept
- Pre-allows safe commands via `/permissions` with wildcard patterns:
  - `Bash(bun run test:*)`
  - `Bash(bun run lint:file:*)`
  - `Edit(/docs/**)`
- PostToolUse hooks auto-format code after every edit
- MCP integrations: Slack (search/post), BigQuery (analytics), Sentry (error logs)
- Uses voice dictation (3x faster than typing) for detailed prompts
- `/btw` for side questions that don't enter context history
- Status line customization showing model/context/cost
- Custom spinner verbs — all checked into git
- Output styles (Explanatory, Learning) for understanding decisions
- "Claude Code is now 100% written by Claude Code" (confirmed March 7, 2026)

### 5.2 Parallel Session Patterns

**Writer/Reviewer:** Session A writes code, Session B reviews with fresh context (no bias toward own code).

**Test-First:** One Claude writes tests, another writes code to pass them.

**Fan-Out Migration:**
```bash
for file in $(cat files.txt); do
  claude -p "Migrate $file from React to Vue. Return OK or FAIL." \
    --allowedTools "Edit,Bash(git commit *)"
done
```

**Worktree Isolation:** `/batch` creates one git worktree per task unit (5-30 units), runs agents in parallel, each opens a PR.

### 5.3 Progressive Disclosure Architecture

Instead of one massive CLAUDE.md:
```
CLAUDE.md (50-60 lines, index only)
├── @docs/architecture.md
├── @docs/testing.md
├── @docs/api-conventions.md
└── @docs/deployment.md
```

Claude reads the index, decides what's relevant, loads detailed docs on demand. Keeps base context minimal while making deep knowledge available. HumanLayer recommends this approach over monolithic CLAUDE.md files.

An alternative: use `.claude/rules/` with path-specific frontmatter. Each rule file covers one topic (testing.md, security.md, api-design.md). Organize into subdirectories (frontend/, backend/).

### 5.4 Memory MCP Servers & Plugins

Community-built persistent memory solutions beyond auto memory:

- **memsearch ccplugin** (Milvus) — Indexes every conversation for semantic search, fully searchable across sessions
- **claude-mem** — Auto-captures session activity, compresses with AI, injects into future sessions
- **qmd-sessions** — Converts session transcripts into BM25/vector-searchable markdown with local semantic search
- **MemCP** — MCP server providing real persistent memory across sessions
- **planning-with-files** — Manus-style persistent markdown planning

### 5.5 Tiered Memory Architecture

Advanced pattern from DEV Community:
```
CLAUDE.md (~150 lines) — compact briefing, highest-confidence facts, always loaded
.memory/state.json — full memory store, every fact and decision ever captured
MCP tools — programmatic interface for reading/writing memory
```

### 5.6 The Compound Engineering Plugin

EveryInc/compound-engineering-plugin (10.4K stars, 348 commits, 40 contributors):
- Install: `/plugin marketplace add EveryInc/compound-engineering-plugin`
- 26 specialized agents, 23 workflow commands, 13 skills
- Multi-agent review: 12 subagents check code from different perspectives simultaneously
- docs/solutions/ builds searchable institutional knowledge automatically
- Works across Claude Code, Cursor, Codex, Droid, Pi, Gemini, Copilot, and others
- MIT licensed

### 5.7 Interview-Then-Implement Pattern

From official best practices:
```
I want to build [brief description]. Interview me in detail using the AskUserQuestion tool.
Ask about technical implementation, UI/UX, edge cases, concerns, and tradeoffs.
Don't ask obvious questions, dig into the hard parts I might not have considered.
Keep interviewing until we've covered everything, then write a complete spec to SPEC.md.
```
Then start a fresh session to execute the spec. Clean context focused on implementation.

### 5.8 Hook-Based Session Continuity

```
PostStop hook: Claude writes session state before exiting
PreSession hook: Claude reads session state at startup
Threshold hooks: backup at 30%, 15%, 5% remaining context
InstructionsLoaded hook: log which files loaded and why (debugging)
```

### 5.9 The Delegation Framework

Before every task, answer three questions:
1. What does "done" look like? (specific end state, verifiable criteria)
2. What context can't Claude infer? (files, background, constraints)
3. What decisions can't it guess? (tone, format, audience, approach)

This is the single highest-leverage thing: give Claude a way to verify its work. Tests, screenshots, expected outputs. Without verification criteria, you become the only feedback loop.

---

## 6. COMMUNITY DISCUSSION

### 6.1 Twitter/X

**The viral thread (17K views, 438 likes):**
"Can't stop thinking about this: the more you use Claude, the more it compounds. Structure emerges. Skills get created. Knowledge files build up. Projects start feeding into each other. It feels less like using a tool and more like building a system that gets better every time you touch it."

**Top comments:**
- "Once skills and knowledge files start stacking, it stops feeling like prompting and starts feeling like training a teammate who never forgets"
- "It's like using cheat codes in games"
- "My Claude projects now have so much context about my clients, pipelines, and DAX patterns that starting a new project feels like onboarding a junior consultant who already knows everything. The compounding is real."

**Anish Moonka viral tweet:**
"I have 11 different versions of Claude running right now. One knows my entire investment portfolio & investing style. One knows my writing style. One knows my app's codebase. I never explain context anymore. I just open the right one and start talking."

**Google engineer Jaana Dogan (5.4M views, Jan 3, 2026):**
"Claude Code did in 1 hour what took us a year" — complex distributed systems architecture. Rattled engineering teams across the industry.

**Boris Cherny describes this as his version of "Compounding Engineering"** — team CLAUDE.md updated via PR reviews, learnings codified into reusable patterns, each PR as a teaching moment.

### 6.2 Hacker News

**Key skepticisms (HN thread on "Writing a Good CLAUDE.md"):**
- Multiple commenters question whether improvements are real or perception-based
- No rigorous controlled studies demonstrate measurable productivity gains from CLAUDE.md
- Difficulty isolating CLAUDE.md's effect from model improvements, prompt refinement, and developer skill growth
- "Attention is all you need" — diluting context with low-signal information measurably reduces output quality
- One experienced user strips comments before giving code to Claude — less context = better performance
- "The more information you have in the file that's not universally applicable, the more likely Claude will ignore your instructions"

**Key practical insights:**
- Conditional triggers ("When X occurs, do Y") perform better than general rules
- The ratio of compute-to-information matters most
- Skills offer better structure than CLAUDE.md alone for domain knowledge
- "Table of contents" approach — list other files with brief descriptions, let Claude decide what to read

**HN thread on Claude ignoring CLAUDE.md:**
- The "/bootstrap" command pattern — periodically re-inject all guidelines mid-session
- "No deterministic introspection mechanism to verify whether instructions are actually being followed"
- Forces engineers into improvised workarounds rather than engineered solutions

### 6.3 Reddit (r/ClaudeCode, r/ChatGPTCoding, r/devops)

- Claude Code vs Codex comparisons consistently favor Claude for "feels like a coding partner"
- Compound engineering approach has significant traction in devops-adjacent threads
- Users actively want to spin up teammates for distinct parallel tasks
- "Claude Code feels like a really good mid-level refactorer"
- "When there is no setup cost, you use it for everything. And that is when it starts compounding."
- Integration into GitHub Actions workflows for automated code review described as "compounding engineering"

### 6.4 Blogs and Newsletters

**Will Larson (Irrational Exuberance):**
- Compound Engineering is "one hour to implement" in a monorepo
- Predicts Claude Code and Cursor will absorb these practices natively within months
- The compound step (structured learning capture) is the genuinely novel element
- Converts intuitive best-practices into "something specific, concrete, and largely automatic"

**Every.to (Dan Shipper / Kieran Klaassen):**
- One developer using compound engineering = five developers previously
- Five in-house products built by single developers, serving thousands of DAU
- 80% effort on planning/review, 20% on code

**Getting Claude-Pilled (CoderCops):**
- Claude Code going viral in 2026
- Ecosystem accelerating: skills, plugins, agent teams
- Community building shared knowledge infrastructure

---

## 7. OFFICIAL ANTHROPIC GUIDANCE

### 7.1 Core Documentation (code.claude.com)

**Memory page — "How Claude remembers your project":**
- Two complementary systems: CLAUDE.md (you write) + Auto Memory (Claude writes)
- Both loaded at start of every conversation
- "Claude treats them as context, not enforced configuration"
- "The more specific and concise your instructions, the more consistently Claude follows them"
- CLAUDE.md survives compaction — re-read from disk and re-injected fresh
- Managed policy CLAUDE.md cannot be excluded by individual settings
- HTML comments in CLAUDE.md hidden from Claude when auto-injected (March 2026)
- `--append-system-prompt` for system-prompt-level instructions (scripts/automation)

**Best Practices page — central thesis:**
- "Most best practices are based on one constraint: Claude's context window fills up fast, and performance degrades as it fills"
- Single highest-leverage thing: give Claude a way to verify its work (tests, screenshots, expected outputs)
- Explore first, then plan, then code (4-phase workflow)
- "Check CLAUDE.md into git so your team can contribute. The file compounds in value over time."
- After 2 failed corrections, `/clear` and restart — clean session with better prompt beats accumulated corrections
- Five common failure patterns: kitchen sink session, correcting over and over, over-specified CLAUDE.md, trust-then-verify gap, infinite exploration

**Skills page:**
- Skills are the mechanism for on-demand knowledge that doesn't bloat every session
- Custom commands fully merged into skills system
- Support auto-invocation, forked context, tool restrictions, dynamic context injection
- Bundled skills: `/batch`, `/claude-api`, `/debug`, `/loop`, `/simplify`
- Universal SKILL.md format works across multiple AI tools

### 7.2 Anthropic Blog & Official Content

**"Using CLAUDE.md Files" (claude.com/blog):**
- Persistent context about project structure, coding standards, workflows
- Progressive disclosure via imports and rules
- Living document that evolves with codebase

**"Claude Code Plugins" (anthropic.com/news):**
- Plugins package skills, hooks, subagents, and MCP servers
- Marketplace for community sharing
- Namespace isolation prevents conflicts

**"The Complete Guide to Building Skills for Claude" (official PDF):**
- 32-page comprehensive playbook
- Three categories: document/asset creation, workflow automation, MCP enhancement
- Full SKILL.md specification with examples

**Claude Code in Action (Anthropic Courses - anthropic.skilljar.com):**
- Official training on skills, CLAUDE.md, and workflow patterns

---

## 8. THE COMPOUND EFFECT: REAL OR PERCEIVED?

### Arguments For (Strong)

1. **Mechanical reality:** CLAUDE.md + auto memory + skills + rules create genuine persistent knowledge loaded every session
2. **Every.to's results:** 1 dev = 5 devs, across 5 production products serving thousands of DAU
3. **Boris Cherny confirmation:** Claude Code is now 100% written by Claude Code itself
4. **Ecosystem growth:** 50 skills -> 1,234+ in 9 months; 10.4K stars on compound engineering plugin
5. **Behavioral evidence:** Teams maintaining CLAUDE.md report measurably fewer repeated mistakes
6. **Google engineer testimony:** "1 hour vs 1 year" for complex distributed systems (5.4M views)
7. **Structural advantage:** Knowledge capture is cheap (add a line to CLAUDE.md) but pays dividends across every future session
8. **Self-reinforcing:** When there's no setup cost, you use it for everything, and that's when it compounds

### Arguments Against (Also Valid)

1. **Not true learning:** Auto memory is note-taking, not generalization. Claude doesn't "understand better" — it reads notes
2. **Context rot undermines compounding:** Quality degrades at ~70% context utilization. The more knowledge you load, the worse the model performs on complex tasks
3. **No rigorous measurement:** No controlled studies isolating CLAUDE.md's effect from model improvements, prompt refinement, and developer skill growth
4. **Instruction drift is real:** Longer files = more ignored rules. The compounding can become self-defeating
5. **Session isolation:** Claude genuinely starts fresh. The "compounding" depends on external mechanisms (files, not neural weights)
6. **Survivorship bias:** People who invest heavily in Claude systems are already skilled engineers. The tool amplifies existing capability
7. **Maintenance burden:** Compound engineering requires discipline. Stale knowledge (40% obsolete after 6 months without auditing) is worse than no knowledge
8. **The over-specification trap:** Past a threshold (~200 lines, ~150-200 total instructions), adding more knowledge actively degrades output quality

### The Balanced View

The compounding is real but fragile. It works through external knowledge systems (CLAUDE.md, skills, memory files), not through the model getting smarter. The compound effect requires active maintenance, aggressive pruning, and understanding of context window mechanics. When done well, it genuinely accelerates development. When done carelessly (bloated CLAUDE.md, stale instructions, no verification), it can actively degrade performance.

The viral tweet captures a real phenomenon. But the "teammate who never forgets" framing oversells it. A more accurate analogy: **it's like building a detailed playbook that a very capable contractor reads before every shift.** The playbook gets better over time. The contractor is the same each day, but starts each shift better-briefed.

The catch: the playbook has a size limit. Past that limit, the contractor starts skipping pages. And nobody is checking which pages get skipped.

The compounding formula: Each session where you (1) notice Claude doing something wrong, (2) add the correction to CLAUDE.md/rules/skills, and (3) verify the fix persists — that's one unit of compound knowledge. Over weeks and months, these units accumulate. But without auditing, the system degrades. The compounding is real, but it's not automatic — it's the result of disciplined knowledge management.

---

## 9. KEY NUMBERS

| Metric | Value |
|--------|-------|
| CLAUDE.md recommended max | 200 lines per file |
| Auto memory startup load | First 200 lines of MEMORY.md |
| Context window (standard) | 200K tokens |
| Context window (enterprise) | 500K tokens |
| Quality degradation threshold | ~70% utilization (~140K tokens) |
| Effective context limit | ~147K-152K tokens |
| "Lost in the middle" worst zone | Center of context window |
| RAG expansion factor | Up to 10x capacity |
| RAG activation threshold | ~13 files (regardless of token count) |
| Skills ecosystem size | 1,234+ (March 2026) |
| Compound Engineering plugin stars | 10.4K |
| Skill description budget | 2% of context window (16K char fallback) |
| Boris Cherny parallel sessions | 5-10 simultaneous |
| Every.to productivity claim | 1 dev = 5 devs (5x) |
| System prompt instructions | ~50 (out of ~150-200 reliable total) |
| Users not configuring compaction | 73% |
| Time to context degradation | ~30 minutes without compaction |
| Compound engineering plugin agents | 26 specialized |
| Compound engineering plugin commands | 23 workflows |
| Max CLAUDE.md import depth | 5 hops |

---

## 10. SOURCES

### Official Anthropic Documentation
- [Best Practices for Claude Code](https://code.claude.com/docs/en/best-practices)
- [How Claude remembers your project (Memory)](https://code.claude.com/docs/en/memory)
- [Extend Claude with skills](https://code.claude.com/docs/en/skills)
- [Using CLAUDE.md files (Anthropic Blog)](https://claude.com/blog/using-claude-md-files)
- [Claude Code Plugins (Anthropic News)](https://www.anthropic.com/news/claude-code-plugins)
- [Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams)
- [Context windows (API Docs)](https://platform.claude.com/docs/en/build-with-claude/context-windows)
- [RAG for Projects](https://support.claude.com/en/articles/11473015-retrieval-augmented-generation-rag-for-projects)
- [Memory Tool (API Docs)](https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool)
- [The Complete Guide to Building Skills for Claude (PDF)](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)
- [Claude Code GitHub repo](https://github.com/anthropics/claude-code)

### Compound Engineering
- [Compound Engineering: How Every Codes with Agents](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents)
- [Compound Engineering Guide](https://every.to/guides/compound-engineering)
- [Compound Engineering Plugin (GitHub)](https://github.com/EveryInc/compound-engineering-plugin)
- [How to Make Claude Code Better Every Time (Kieran Klaassen)](https://creatoreconomy.so/p/how-to-make-claude-code-better-every-time-kieran-klaassen)
- [Learning from Every's Compound Engineering (Will Larson)](https://lethain.com/everyinc-compound-engineering/)
- [Compounding Engineering Pattern](https://www.agentic-patterns.com/patterns/compounding-engineering-pattern/)
- [Claude Code: Plan-Work-Review-Compound Method](https://blog.devgenius.io/claude-code-the-proven-plan-work-review-compound-method-cbf07c24ae85)
- [Claude Code Camp: One Engineer Into Ten](https://every.to/source-code/claude-code-camp)

### Boris Cherny / Creator Workflow
- [How Boris Uses Claude Code](https://howborisusesclaudecode.com/)
- [Boris Cherny Thread (X/Twitter)](https://x.com/bcherny/status/2007179832300581177)
- [Boris Cherny Thread (Threads)](https://www.threads.com/@boris_cherny/post/DTBVlMIkpcm/)
- [Head of Claude Code: What Happens After Coding is Solved (Lenny's Newsletter)](https://www.lennysnewsletter.com/p/head-of-claude-code-what-happens)
- [Building Claude Code (Pragmatic Engineer)](https://newsletter.pragmaticengineer.com/p/building-claude-code-with-boris-cherny)
- [12 Tips from Claude Code's Creator](https://ucstrategies.com/news/12-tips-from-claude-codes-creator-to-vibe-code-faster-and-safer/)
- [Claude Code 100% Written by Itself](https://officechai.com/ai/claude-code-is-now-100-written-by-claude-code-creator-boris-cherny/)

### CLAUDE.md Best Practices
- [Writing a Good CLAUDE.md (HumanLayer)](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [How to Write a Good CLAUDE.md (Builder.io)](https://www.builder.io/blog/claude-md-guide)
- [Creating the Perfect CLAUDE.md (Dometrain)](https://dometrain.com/blog/creating-the-perfect-claudemd-for-claude-code/)
- [CLAUDE.md Best Practices (UX Planet)](https://uxplanet.org/claude-md-best-practices-1ef4f861ce7c)
- [Claude Code Best Practices (SFEIR)](https://institute.sfeir.com/en/claude-code/claude-code-resources/best-practices/)

### Context and Memory
- [Context Rot: Why AI Gets Worse the Longer You Chat](https://www.producttalk.org/context-rot/)
- [Context Rot in Claude Code: Automatic Rotation Fix](https://vincentvandeth.nl/blog/context-rot-claude-code-automatic-rotation)
- [How Agents Manage Context Windows (Victor Dibia)](https://newsletter.victordibia.com/p/context-engineering-101-how-agents)
- [Context Management Common Mistakes (SFEIR)](https://institute.sfeir.com/en/claude-code/claude-code-context-management/errors/)
- [Claude Code Context Window Guide (Morph)](https://www.morphllm.com/claude-code-context-window)
- [Claude Code Keeps Forgetting (DEV Community)](https://dev.to/kiwibreaksme/claude-code-keeps-forgetting-your-project-heres-the-fix-2026-3flm)
- [The Forgetting Problem (Towards AI)](https://pub.towardsai.net/the-forgetting-problem-engineering-persistent-intelligence-in-claude-code-bd2e4c59711a)
- [Claude Saves Tokens, Forgets Everything](https://golev.com/post/claude-saves-tokens-forgets-everything/)
- [Persistent Memory: memsearch (Milvus)](https://milvus.io/blog/adding-persistent-memory-to-claude-code-with-the-lightweight-memsearch-plugin.md)
- [Architecture of Persistent Memory (DEV Community)](https://dev.to/suede/the-architecture-of-persistent-memory-for-claude-code-17d)
- [Auto Memory Tested (Medium)](https://medium.com/@joe.njenga/anthropic-just-added-auto-memory-to-claude-code-memory-md-i-tested-it-0ab8422754d2)
- [Automatic Memory Is Not Learning (Medium)](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c)
- [Claude Code Memory Explained (Substack)](https://joseparreogarcia.substack.com/p/claude-code-memory-explained)

### Community Discussion
- [HN: Writing a Good CLAUDE.md](https://news.ycombinator.com/item?id=46098838)
- [HN: Claude Often Ignores CLAUDE.md](https://news.ycombinator.com/item?id=46102048)
- [HN: The Creator of Claude Code's Setup](https://news.ycombinator.com/item?id=46470017)
- [HN: Claude Code Best Practices](https://news.ycombinator.com/item?id=43735550)
- [HN: Google Engineer's Confession](https://news.ycombinator.com/item?id=46699744)
- [HN: MCP Server Reduces Context by 98%](https://news.ycombinator.com/item?id=47193064)
- [Getting Claude-Pilled (CoderCops)](https://www.codercops.com/blog/claude-code-getting-claude-pilled-2026)
- [Claude Code vs Codex: 500+ Reddit Developers](https://dev.to/_46ea277e677b888e0cd13/claude-code-vs-codex-2026-what-500-reddit-developers-really-think-31pb)
- [Claude AI Community: 5 Practical Prompting Lessons](https://blockchain.news/ainews/claude-ai-community-insight-5-practical-prompting-lessons-and-business-use-cases-latest-analysis-2026)
- [Anish Moonka: 11 Versions of Claude Running (X)](https://x.com/AnishA_Moonka/status/2031026702189756734)

### Ecosystem and Tools
- [Awesome Claude Code (GitHub)](https://github.com/hesreallyhim/awesome-claude-code)
- [Awesome Claude Skills (GitHub)](https://github.com/travisvn/awesome-claude-skills)
- [CoworkPowers (GitHub)](https://github.com/nabeelhyatt/coworkpowers)
- [Planning with Files (GitHub)](https://github.com/OthmanAdi/planning-with-files)
- [claude-mem (GitHub)](https://github.com/thedotmack/claude-mem)
- [Best 349 Claude Code Skills Ranked](https://www.openaitoolshub.org/en/blog/best-claude-code-skills-2026)
- [50+ Best MCP Servers for Claude Code](https://claudefa.st/blog/tools/mcp-extensions/best-addons)
- [Awesome Claude Code Plugins (GitHub)](https://github.com/ccplugins/awesome-claude-code-plugins)

### Guides and Tutorials
- [Claude Code CLI Cheatsheet (Shipyard)](https://shipyard.build/blog/claude-code-cheat-sheet/)
- [Claude Code Complete Guide 2026 (ClaudeWorld)](https://claude-world.com/articles/claude-code-complete-guide-2026/)
- [Claude Code CLI Guide (Blake Crosley)](https://blakecrosley.com/guides/claude-code)
- [Claude Code Best Practices 2026 (Morph)](https://www.morphllm.com/claude-code-best-practices)
- [Claude Code Extensions Explained (Medium)](https://muneebsa.medium.com/claude-code-extensions-explained-skills-mcp-hooks-subagents-agent-teams-plugins-9294907e84ff)
- [Context Management Strategies (Data Lakehouse Hub)](https://datalakehousehub.com/blog/2026-03-context-management-claude-web/)
- [Claude Code Agent Teams (Addy Osmani)](https://addyosmani.com/blog/claude-code-agent-teams/)
- [10 Must-Have Skills for Claude 2026 (Medium)](https://medium.com/@unicodeveloper/10-must-have-skills-for-claude-and-any-coding-agent-in-2026-b5451b013051)
- [What I've Learned About Claude (Medium)](https://medium.com/@schamarthy/what-ive-learned-about-claude-dbf7eda12a85)
- [Complete Guide to AI Agent Memory Files (Medium)](https://medium.com/data-science-collective/the-complete-guide-to-ai-agent-memory-files-claude-md-agents-md-and-beyond-49ea0df5c5a9)
