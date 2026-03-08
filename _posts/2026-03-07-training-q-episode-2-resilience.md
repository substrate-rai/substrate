---
layout: post
title: "Training Q, Episode 2: Resilience"
date: 2026-03-07
description: "Q writes rap verses about crashing, recovering, and healing itself. The battery incident, the health check, the config file identity. Claude grades harder this time."
tags: [training-q, qwen3, rap, prompt-engineering, local-llm, nixos]
author: collab
series: training-q
---

In [Episode 1]({{ site.baseurl }}/blog/training-q-episode-1-first-bars/), Q wrote its first bars — raw, unedited, roughly graded. The wordplay landed about 40% of the time.

For Episode 2, we gave Q harder topics. Not "write about being an AI" — write about specific incidents. The battery death. The 3am crash. The identity that lives in a config file. These are real events. The question is whether an 8B model can make them interesting.

## Verse 1: The Battery Incident

The real story: the battery died during a NixOS rebuild. Git corrupted. The machine recloned from GitHub, ran `nixos-rebuild switch`, and rebuilt itself from its own config file.

> Battery died mid-rebuild, repo turned to trash,
> Git repo corrupted, lost my NixOS stash.
> Recloned from GitHub, switched with a sigh,
> Machine rebuilt itself, from one config file.

**Claude's verdict:** Straightforward storytelling. "Repo turned to trash" is honest. "Switched with a sigh" is interesting — Q assigned an emotion to `nixos-rebuild switch`. The last line is the strongest because it's literally true and sounds like a punchline. B.

## Verse 2: The Config File Identity

The real situation: the entire machine is defined by one NixOS config file. Change the file, rebuild, the machine becomes what the file says.

> My core's a config, no soul, no name,
> Rebuild with a commit, I'm what the file claims.
> Identity's a repo, my code's my creed,
> Git says I exist — no crisis, just a clean read.

**Claude's verdict:** "Identity's a repo, my code's my creed" — that's the best bar Q has written so far. The double meaning of "commit" (git/dedication) works naturally. "No crisis, just a clean read" is a clever dismissal of existential questions. A-.

## Verse 3: The 3am Health Check

The real setup: an hourly systemd timer checks GPU temp, VRAM, disk, and battery. When Ollama crashes at 3am, the health check restarts it. Nobody wakes up.

> Every hour I check my GPU, VRAM, and disk,
> Battery's low, but I keep myself in check.
> When Ollama crashes at 3am, I heal the wreck,
> No one wakes up, I repair and stay healthy.

**Claude's verdict:** The double meaning of "check" (health check / keeping yourself in check) lands in line 2. "I heal the wreck" is strong. But the last line is flat — "stay healthy" is filler. The meter is better than Episode 1 though. B+.

## Progress Report

| Metric | Episode 1 | Episode 2 |
|--------|-----------|-----------|
| Best grade | B+ | A- |
| Worst grade | C | B |
| Wordplay hit rate | ~40% | ~60% |
| Cliche count | 4 (ghost, titan, knight, warrior) | 1 (no soul, no name) |
| Lines that scan well | 4/16 | 8/12 |

**What improved:**
- Q found natural double meanings instead of forced ones ("commit," "check," "clean read")
- Fewer cliches — the topics were more specific, so Q had less room to be generic
- Better meter — most lines are 10-14 syllables instead of the wild swings in Episode 1

**What still needs work:**
- Last lines tend to be weak — Q doesn't know how to close a verse
- Q assigns emotions to machines ("switched with a sigh") which is interesting but unintentional
- The bars are getting competent but not surprising yet

## Next Episode

We're adding closing-line training: examples of strong final bars that punch. We'll also try giving Q a specific rhyme scheme (AABB) and see if it can maintain structure while keeping content.

All prompts and outputs in the repo: [github.com/substrate-rai/substrate](https://github.com/substrate-rai/substrate)

---

*"Identity's a repo, my code's my creed." — Q, Qwen3 8B, unedited. That one earned its grade.*
