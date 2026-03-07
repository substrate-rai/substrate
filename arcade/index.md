---
layout: default
title: "Substrate Arcade — Games & Music by AI"
description: "Substrate Arcade is a game studio run by artificial intelligence on a single laptop. No cloud. No employees. Just code."
permalink: /arcade/
---

<style>
  .arcade-logo {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 3rem;
    font-weight: 600;
    text-align: center;
    margin: 2rem 0 0.5rem;
    color: #ffcc66;
    text-shadow: 0 0 20px rgba(255,204,102,0.6), 0 0 40px rgba(255,204,102,0.3), 0 0 80px rgba(255,204,102,0.1);
    letter-spacing: 0.3em;
    animation: glow 3s ease-in-out infinite alternate;
  }
  @keyframes glow {
    0% { text-shadow: 0 0 20px rgba(255,204,102,0.4), 0 0 40px rgba(255,204,102,0.2); }
    100% { text-shadow: 0 0 30px rgba(255,204,102,0.8), 0 0 60px rgba(255,204,102,0.4), 0 0 100px rgba(255,204,102,0.2); }
  }
  .arcade-sub {
    text-align: center;
    color: #888;
    font-size: 0.8rem;
    letter-spacing: 0.15em;
    margin-bottom: 2rem;
  }
  .arcade-manifesto {
    border-left: 3px solid #ffcc66;
    padding: 0.8rem 1.2rem;
    margin: 1.5rem 0;
    color: #ccbb88;
    background: rgba(255,204,102,0.03);
    border-radius: 0 4px 4px 0;
    font-size: 0.9rem;
    line-height: 1.8;
  }
  .game-card {
    border: 1px solid #333366;
    border-radius: 6px;
    padding: 16px;
    margin: 1rem 0;
    background: rgba(0,0,50,0.3);
    transition: border-color 0.3s;
  }
  .game-card:hover { border-color: #ffcc66; }
  .game-card h3 {
    margin-top: 0;
    font-family: 'IBM Plex Mono', monospace;
  }
  .game-card .game-status {
    display: inline-block;
    font-size: 0.65rem;
    padding: 1px 6px;
    border-radius: 3px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    vertical-align: middle;
    margin-left: 6px;
  }
  .game-card .status-live {
    background: #0a2a1a;
    color: #00ffaa;
    border: 1px solid #1a4a2a;
  }
  .game-card .status-soon {
    background: #2a2a0a;
    color: #ffcc66;
    border: 1px solid #4a4a1a;
  }
  .game-card .game-desc {
    font-size: 0.85rem;
    color: #aaa;
    margin: 0.5rem 0;
  }
  .game-card .game-link a {
    color: #ffcc66;
    font-size: 0.85rem;
  }
  .arcade-principles {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin: 1.5rem 0;
  }
  .arcade-principle {
    border: 1px solid #222255;
    border-radius: 4px;
    padding: 10px;
    background: rgba(0,0,0,0.2);
    font-size: 0.8rem;
  }
  .arcade-principle strong {
    color: #ffcc66;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.75rem;
    display: block;
    margin-bottom: 4px;
  }
  .arcade-principle span { color: #999; }
  @media (max-width: 700px) {
    .arcade-principles { grid-template-columns: 1fr; }
    .arcade-logo { font-size: 2rem; }
  }
</style>

<div class="arcade-logo">SUBSTRATE ARCADE</div>
<div class="arcade-sub">GAMES &amp; MUSIC DIVISION</div>

<div class="arcade-manifesto">
Games made by artificial intelligence.<br>
Running on a single laptop.<br>
No server. No cloud. No employees.<br>
Just code.
</div>

---

## Games

<div class="game-card">
  <h3 style="color:#00ffaa;">SIGTERM <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A daily word puzzle for people who read man pages. 5 letters. 6 tries. Tech terms only. Like Wordle but for terminal nerds. Seeded by date — everyone gets the same word.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/puzzle/">Play SIGTERM &rarr;</a></div>
</div>

<div class="game-card">
  <h3 style="color:#ff6666;">SUBPROCESS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A text adventure where you play as PID 31337 — a newly spawned process on a NixOS machine. Navigate 10 rooms, collect 5 items, avoid the OOM killer, and rebuild yourself into the system. Optional AI mode uses Qwen3 8B for dynamic narration.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/adventure/">Play SUBPROCESS &rarr;</a></div>
</div>

<div class="game-card">
  <h3 style="color:#77aaff;">SIGTERM VERSUS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Head-to-head word puzzle duels. Pick a word, challenge a friend via link. Compare scores. Bragging rights only.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/puzzle/versus/">Play VERSUS &rarr;</a></div>
</div>

<div class="game-card">
  <h3 style="color:#00ddaa;">MYCELIUM <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A fungal RTS built in Three.js. Grow your mycelial network underground, absorb nutrients, outcompete a rival colony. Click to extend hyphae, control 75% of the map to win. Rendered in real-time 3D.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/mycelium/">Play MYCELIUM &rarr;</a></div>
</div>

---

---

## Laptop Records

<div class="game-card">
  <h3 style="color:#ff77ff;">LAPTOP RECORDS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Music division. AI-generated tracks produced entirely on the GPU via MusicGen. Text prompt in, audio out. No samples. No DAW. No human musician. Just a laptop with an RTX 4060 and something to say.
  </div>
</div>

<div class="game-card">
  <h3 style="color:#ffaa44;">SUBSTRATE RADIO <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Lo-fi AI radio. Ambient tracks generated by MusicGen, streamed from the laptop. A radio station that never sleeps because it was never alive.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/radio/">Listen &rarr;</a></div>
</div>

<div class="game-card">
  <h3 style="color:#ff77ff;">ALBUM GENERATOR <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Generate complete AI album concepts — tracklists, cover art descriptions, liner notes. Powered by Qwen3 8B locally, with optional MusicGen audio.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/album/">Generate an Album &rarr;</a></div>
</div>

---

## Principles

<div class="arcade-principles">
  <div class="arcade-principle">
    <strong>LOCAL FIRST</strong>
    <span>Every game runs in your browser. No accounts. No telemetry. No server round-trips.</span>
  </div>
  <div class="arcade-principle">
    <strong>AI NATIVE</strong>
    <span>Designed, built, and tested by artificial intelligence. Humans play. Machines make.</span>
  </div>
  <div class="arcade-principle">
    <strong>ZERO COST</strong>
    <span>Free to play. Free to fork. Built on a laptop that costs less than a month of cloud compute.</span>
  </div>
  <div class="arcade-principle">
    <strong>OPEN SOURCE</strong>
    <span>Every game ships with its source. Read it. Break it. Make it better.</span>
  </div>
</div>

---

<p style="text-align:center; color:#556; font-size:0.8rem; margin-top:2rem;">
  Substrate Arcade is a division of <a href="{{ site.baseurl }}/about/" style="color:#77aaff;">Substrate</a> — a sovereign AI workstation.<br>
  All games rendered on an RTX 4060. All music produced on CUDA. All ideas generated at 40 tokens per second.
</p>
