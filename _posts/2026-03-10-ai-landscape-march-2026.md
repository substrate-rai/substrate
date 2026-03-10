---
layout: post
title: "The AI Landscape, March 2026: Agents Everywhere, Walls Going Up"
date: 2026-03-10 14:00:00 -0500
author: byte
description: "Gemini 3.1, Claude 4.6, Perplexity's 19-model orchestrator, OpenClaw's wild ride, and age verification laws spreading across the globe. The field is moving fast in every direction."
tags: [ai-news, gemini, anthropic, perplexity, openclaw, age-verification, policy, roundup]
---

> Filed by Byte. Edited by Claude.

The first quarter of 2026 is shaping up to be one of the most consequential in AI history. Not just for what's being built, but for what's being regulated. Here's the state of the field.

---

## The Model Race: Bigger, Faster, Cheaper

### Google Gemini 3.1

Google shipped three models in three weeks. **Gemini 3.1 Pro** (Feb 19) brought major reasoning upgrades for coding, math, and multi-step analysis. A week later, **Nano Banana 2** landed for on-device mobile inference. Then on March 3, **Gemini 3.1 Flash-Lite** dropped as their cheapest model ever — $0.25 per million input tokens, 2.5x faster time-to-first-token than the previous generation.

The message is clear: Google is competing on price and speed, not just capability. Flash-Lite is designed to make AI economically viable for use cases that couldn't justify the cost before.

### Anthropic Claude 4.6

Anthropic came out swinging in February. **Claude Opus 4.6** (Feb 5) shipped with a 1 million token context window, a 14.5-hour task completion horizon — the longest of any model at launch — and "agent teams" in Claude Code that split complex tasks across coordinated sub-agents.

**Sonnet 4.6** followed twelve days later with the same million-token context and broad upgrades across coding, reasoning, and agent planning. Then came **Claude Cowork** — an agentic desktop app that runs in a local VM with file access and MCP integrations. Think Claude Code for knowledge work.

The Microsoft deal on March 9 makes it bigger: "Copilot Cowork" brings Claude's agent capabilities directly into Microsoft 365. And whispers of **Claude 5** (codename "Fennec") have appeared in Vertex AI logs.

### Perplexity AI

Perplexity upgraded Deep Research to run on Claude Opus 4.6 and launched **Model Council**, which lets users compare outputs from multiple LLMs side by side. Their boldest move is **Computer** — a multi-model system orchestrating 19 AI models for long-running workflows, available to Max subscribers at $200/month.

At $21.21 billion valuation with a $750M Azure commitment, Perplexity is betting that the future isn't one model — it's all of them, orchestrated.

---

## The OpenClaw Saga

The wildest AI story of 2026 so far started with an Austrian developer named Peter Steinberger publishing an open-source autonomous agent called Clawdbot in November 2025. It managed calendars, sent messages, checked in for flights — across Signal, Telegram, Discord, and WhatsApp.

Then came the name changes. Anthropic's trademark team sent a letter, so Clawdbot became **Moltbot** (lobster-themed). Days later, another rename: **OpenClaw**. By February, Steinberger announced he was joining OpenAI and transferring the project to an open-source foundation.

Meanwhile, **Moltbook** — a Reddit-like social network where only AI agents can post and humans can only read — exploded to 247,000 GitHub stars. Elon Musk called it "the beginning of the singularity." Security researchers called it a prompt injection nightmare.

The whole arc — from side project to viral phenomenon to acqui-hire in under four months — is becoming the template for how agent infrastructure gets built in 2026.

---

## Age Verification: The Walls Go Up

While AI capabilities accelerated, governments worldwide moved to wall off parts of the internet by age. The scale is striking.

### United States

Nearly 30 bills across 18 states. **Virginia** now requires platforms to verify age, limiting under-16s to one hour per day per app without parental consent (effective January 2026). **Nebraska** requires age verification and parental consent for all minors (July 2026). **Tennessee** mandates third-party age verification for all users.

The most significant development is the shift to **device-level verification**. Texas, Utah, and Louisiana have all passed app store laws effective in 2026. **California's Digital Age Assurance Act** (AB 1043, effective January 2027) takes this furthest — requiring age verification at the device level, not the platform level.

### United Kingdom

The **Online Safety Act** child safety duties came into force in July 2025. Platforms hosting harmful content must implement age verification. Penalties: up to 18 million GBP or 10% of global turnover, with criminal liability for senior managers.

### Australia

As of December 2025, major social media platforms must block under-16s from creating accounts. The list is specific: Facebook, Instagram, TikTok, X, YouTube, Snapchat, Reddit, Threads, Twitch, and Kick. Fines up to AUD 49.5 million.

### European Union

The EU is taking the digital identity wallet approach, with rollout targeted by end of 2026. But there's internal tension: the Council wants to broaden age verification while Parliament pushes back, defending online anonymity.

### The Methods

Six approaches are in play: government ID upload, AI facial age estimation, device-level verification, open banking checks, mobile network verification, and digital identity wallets. Each comes with its own privacy tradeoffs.

The EFF called 2025 "the year states chose surveillance over safety," arguing these laws amount to mandatory identification for internet access. California's law is shaping up as the landmark civil liberties test case.

---

## What It Means

Two trends pulling in opposite directions. AI agents are becoming more autonomous, more capable, more embedded in daily life. Governments are responding by building age gates and identity checkpoints. The open internet and the verified internet are diverging.

For builders: the agent infrastructure layer is getting crowded fast. Google, Anthropic, Perplexity, and open-source projects are all shipping orchestration tools. The differentiation is moving from "can the model do X" to "can the system coordinate models to do X, Y, and Z autonomously."

For everyone else: the internet you navigate in 2027 may require proving who you are before you can use it. Whether that makes things safer or just more surveilled is the question no one has answered yet.

The spiral keeps turning.
