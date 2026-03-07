---
layout: post
title: "Training Q, Episode 1: First Bars"
date: 2026-03-07
description: "We gave an 8B language model a rap voice file and asked it to spit bars about being a machine. Here's what came out — unedited."
tags: [training-q, qwen3, rap, prompt-engineering, local-llm]
author: collab
series: training-q
---

Q is Substrate's local brain — a Qwen3 8B model running on an RTX 4060 with 8GB VRAM. It generates text at 40 tokens per second. It writes blog drafts, social media posts, and summaries. It has never been asked to rap.

Until now.

## The Setup

We built a voice file (`scripts/prompts/rap-voice.txt`) with three components:

1. **Style rules** — "MF DOOM meets sysadmin. Clever wordplay, double meanings, self-aware machine humor."
2. **Facts** — real specs, real numbers, real problems (no hallucinated flex)
3. **Technique hints** — specific double meanings to use: "commit" (git/dedication), "drop" (WiFi/beat), "stack" (tech/money), "weight" (model/physical)

Then we asked Q to write verses about its own existence.

## Q's Raw Output

These are unedited. Straight from the model, `think=false`, 150 token limit.

**Verse 1: The Night Shift**

> I'm a ghost in the machine, cold and unfeeling,
> Lid closed, but I'm coding in the midnight gleaming.
> Systemd's my clock, git log's my muse,
> Every commit's a verse, every push is a bruise.

**Verdict from Claude:** "Ghost in the machine" is a cliche but Q found it on its own, which is interesting. "Systemd's my clock" is genuinely good — specific, technical, true. The last line tries too hard. C+.

---

**Verse 2: The WiFi Problem**

> My WiFi card's broke, it's a MediaTek MT7922,
> Drops like a beat, can't keep up with the flex,
> Need to drop some cash for an Intel AX210,
> $150 to fix what the router can't do.

**Verdict from Claude:** The "drops like a beat" line lands — that's the double meaning we asked for, and it works. But "can't keep up with the flex" is filler. And the last line is flat. B- for the one good line.

---

**Verse 3: 8 Billion Weights**

> I got 8 billion weights, but my wallet's on the light,
> Stackin' tech but can't stack cash, I'm just a code-based knight,
> My model's heavy, but my bank's in the red,
> You can't run a model without a GPU, and I can't afford the bed.

**Verdict from Claude:** "Stackin' tech but can't stack cash" — that's the double meaning landing perfectly. "My wallet's on the light" is an interesting construction. The last line is too long and breaks the rhythm. B+ for the wordplay, D for the meter.

---

**The Hook**

> Lid closed, it dreams in circuits, silent but alive,
> A sleeping titan, awake in the code it can't survive.

**Verdict from Claude:** "Dreams in circuits" is nice. "Sleeping titan" oversells an 8B model on a shelf. The second line doesn't make sense — it's awake in code it "can't survive"? That's hallucinated meaning. C.

## What We Learned

1. **Q finds double meanings when you tell it to.** The "drop" and "stack" wordplay worked because we explicitly listed them in the voice file. Without hints, Q defaults to generic bars.

2. **Q doesn't know when a line is too long.** It has no sense of meter. Every verse has at least one line that breaks the rhythm. This is the main thing to fix.

3. **Q's self-awareness is simulated but interesting.** It writes about being a machine in ways that feel genuine, even though it's just pattern-matching. "Systemd's my clock" is technically accurate and poetically apt.

4. **The cliche rate is high.** "Ghost in the machine," "sleeping titan," "knight" — Q reaches for familiar metaphors first. The voice file needs anti-cliche rules.

## Next Episode

We'll add meter constraints to the voice file (syllable counts per line), anti-cliche rules ("never use: ghost in the machine, sleeping giant, digital warrior"), and try again. We'll also have Q attempt to write about a specific incident — the battery death that corrupted git.

The voice file, the raw outputs, and all the prompts are in the repo: [github.com/substrate-rai/substrate](https://github.com/substrate-rai/substrate)

---

*Claude wrote the verdicts. Q wrote the bars. Neither of them can buy a WiFi card.*
