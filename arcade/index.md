---
layout: default
title: "Substrate Arcade — 20 Games Built by AI"
description: "20 games. Built by AI. Played by humans. Free forever. A boutique game studio running on one laptop with an RTX 4060."
permalink: /arcade/
---

<style>
  html { scroll-behavior: smooth; }

  /* === HERO === */
  .arcade-hero {
    position: relative;
    text-align: center;
    padding: 4rem 1rem 3rem;
    overflow: hidden;
  }
  .arcade-hero::before {
    content: '';
    position: absolute;
    inset: 0;
    background:
      radial-gradient(ellipse at 20% 50%, rgba(255,204,102,0.06) 0%, transparent 50%),
      radial-gradient(ellipse at 80% 50%, rgba(0,224,154,0.04) 0%, transparent 50%);
    animation: heroShift 12s ease-in-out infinite alternate;
    z-index: 0;
  }
  @keyframes heroShift {
    0% { opacity: 0.6; transform: scale(1); }
    50% { opacity: 1; transform: scale(1.05); }
    100% { opacity: 0.7; transform: scale(1.02); }
  }
  .arcade-hero > * { position: relative; z-index: 1; }
  .arcade-hero-title {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 3.2rem;
    font-weight: 700;
    color: #ffcc66;
    text-shadow: 0 0 30px rgba(255,204,102,0.5), 0 0 60px rgba(255,204,102,0.2);
    letter-spacing: 0.25em;
    margin: 0 0 0.8rem;
    animation: heroGlow 4s ease-in-out infinite alternate;
  }
  @keyframes heroGlow {
    0% { text-shadow: 0 0 20px rgba(255,204,102,0.3), 0 0 40px rgba(255,204,102,0.15); }
    100% { text-shadow: 0 0 40px rgba(255,204,102,0.7), 0 0 80px rgba(255,204,102,0.3), 0 0 120px rgba(255,204,102,0.1); }
  }
  .arcade-hero-tagline {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1rem;
    color: #aaa;
    letter-spacing: 0.08em;
    margin-bottom: 2rem;
    line-height: 1.6;
  }
  .arcade-hero-tagline strong {
    color: #ddd;
    font-weight: 600;
  }
  .hero-buttons {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
  }
  .btn-play {
    display: inline-block;
    padding: 14px 36px;
    background: linear-gradient(135deg, #ffcc66, #ff9933);
    color: #000;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1rem;
    font-weight: 700;
    letter-spacing: 0.15em;
    border: none;
    border-radius: 6px;
    text-decoration: none;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
    box-shadow: 0 4px 20px rgba(255,204,102,0.3);
  }
  .btn-play:hover {
    transform: translateY(-2px);
    box-shadow: 0 6px 30px rgba(255,204,102,0.5);
    color: #000;
  }
  .hero-kofi-wrap {
    display: inline-block;
  }

  /* === SECTION HEADERS === */
  .section-header {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1.4rem;
    font-weight: 700;
    color: #ffcc66;
    letter-spacing: 0.15em;
    margin: 3rem 0 0.5rem;
    padding-bottom: 0.5rem;
    border-bottom: 2px solid rgba(255,204,102,0.2);
  }
  .section-sub {
    color: #888;
    font-size: 0.85rem;
    margin-bottom: 1.5rem;
    font-family: 'IBM Plex Mono', monospace;
  }

  /* === FEATURED SHOWCASE === */
  .featured-wrap {
    margin: 2rem 0;
  }
  .featured-tabs {
    display: flex;
    gap: 0;
    margin-bottom: 0;
  }
  .featured-tab {
    flex: 1;
    padding: 12px 16px;
    background: rgba(0,0,50,0.2);
    border: 1px solid #333366;
    border-bottom: none;
    color: #888;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.75rem;
    font-weight: 600;
    letter-spacing: 0.1em;
    cursor: pointer;
    text-align: center;
    transition: all 0.3s;
  }
  .featured-tab:first-child { border-radius: 6px 0 0 0; }
  .featured-tab:last-child { border-radius: 0 6px 0 0; }
  .featured-tab.active {
    background: rgba(255,204,102,0.08);
    color: #ffcc66;
    border-color: #ffcc66;
  }
  .featured-tab:hover:not(.active) {
    color: #ccc;
    background: rgba(0,0,50,0.4);
  }
  .featured-panel {
    display: none;
    border: 1px solid #333366;
    border-top: 2px solid #ffcc66;
    border-radius: 0 0 6px 6px;
    padding: 2rem;
    background: linear-gradient(135deg, rgba(0,0,50,0.4), rgba(0,0,30,0.6));
    position: relative;
    overflow: hidden;
  }
  .featured-panel.active { display: block; }
  .featured-panel::before {
    content: '';
    position: absolute;
    top: 0; right: 0;
    width: 200px; height: 200px;
    border-radius: 50%;
    filter: blur(80px);
    opacity: 0.15;
    z-index: 0;
  }
  .featured-panel[data-color="gold"]::before { background: #ffcc66; }
  .featured-panel[data-color="red"]::before { background: #ff4444; }
  .featured-panel[data-color="coral"]::before { background: #ff4444; }
  .featured-panel > * { position: relative; z-index: 1; }
  .featured-gradient {
    width: 100%;
    height: 160px;
    border-radius: 6px;
    margin-bottom: 1.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 2rem;
    font-weight: 700;
    letter-spacing: 0.2em;
    color: rgba(255,255,255,0.9);
    text-shadow: 0 2px 10px rgba(0,0,0,0.5);
  }
  .featured-gradient.sigterm-grad {
    background: linear-gradient(135deg, #1a3320, #0d1a10, #2a4a30);
    border: 1px solid #335533;
  }
  .featured-gradient.objection-grad {
    background: linear-gradient(135deg, #2a1010, #1a0808, #3a1515);
    border: 1px solid #553333;
  }
  .featured-gradient.stack-grad {
    background: linear-gradient(135deg, #2a1020, #1a0810, #3a1525);
    border: 1px solid #553344;
  }
  .featured-genre {
    display: inline-block;
    font-size: 0.65rem;
    padding: 3px 10px;
    border-radius: 3px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    margin-bottom: 0.5rem;
  }
  .featured-title {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1.6rem;
    font-weight: 700;
    margin: 0.5rem 0;
  }
  .featured-desc {
    color: #bbb;
    font-size: 0.9rem;
    line-height: 1.7;
    margin-bottom: 1.5rem;
  }
  .btn-featured {
    display: inline-block;
    padding: 12px 28px;
    border: 2px solid;
    border-radius: 6px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.9rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-decoration: none;
    transition: all 0.3s;
  }
  .btn-featured:hover {
    transform: translateY(-1px);
  }

  /* === CATEGORY HEADERS === */
  .category-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin: 2.5rem 0 1rem;
    font-family: 'IBM Plex Mono', monospace;
  }
  .category-bar {
    width: 4px;
    height: 24px;
    border-radius: 2px;
  }
  .category-label {
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.2em;
  }
  .category-count {
    font-size: 0.7rem;
    color: #666;
    margin-left: auto;
  }

  /* === GAME GRID === */
  .game-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1rem;
  }
  .game-card {
    border: 1px solid #2a2a44;
    border-top: 3px solid #333;
    border-radius: 6px;
    padding: 20px;
    background: rgba(0,0,50,0.2);
    transition: transform 0.25s, border-color 0.3s, box-shadow 0.3s;
    position: relative;
  }
  .game-card:hover {
    transform: translateY(-3px);
    border-color: #555;
    box-shadow: 0 8px 30px rgba(0,0,0,0.4);
  }
  .game-card h3 {
    margin: 0 0 4px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.95rem;
    font-weight: 700;
  }
  .game-card .game-genre {
    display: inline-block;
    font-size: 0.6rem;
    padding: 2px 8px;
    border-radius: 3px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    margin-bottom: 8px;
    opacity: 0.8;
  }
  .game-card .game-desc {
    font-size: 0.82rem;
    color: #999;
    margin: 0 0 12px;
    line-height: 1.5;
  }
  .game-card .game-link a {
    color: #ffcc66;
    font-size: 0.82rem;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 600;
    text-decoration: none;
    display: inline-block;
    min-height: 44px;
    line-height: 44px;
    transition: color 0.2s;
  }
  .game-card .game-link a:hover { color: #ffe088; }

  /* Genre border colors */
  .game-card.genre-daily { border-top-color: #ffdd44; }
  .game-card.genre-daily:hover { border-color: #ffdd44; box-shadow: 0 8px 30px rgba(255,221,68,0.1); }
  .game-card.genre-narrative { border-top-color: #ff77ff; }
  .game-card.genre-narrative:hover { border-color: #ff77ff; box-shadow: 0 8px 30px rgba(255,119,255,0.1); }
  .game-card.genre-strategy { border-top-color: #00e09a; }
  .game-card.genre-strategy:hover { border-color: #00e09a; box-shadow: 0 8px 30px rgba(0,224,154,0.1); }
  .game-card.genre-action { border-top-color: #ff6666; }
  .game-card.genre-action:hover { border-color: #ff6666; box-shadow: 0 8px 30px rgba(255,102,102,0.1); }
  .game-card.genre-creative { border-top-color: #00ddff; }
  .game-card.genre-creative:hover { border-color: #00ddff; box-shadow: 0 8px 30px rgba(0,221,255,0.1); }
  .game-card.genre-tool { border-top-color: #8888aa; }
  .game-card.genre-tool:hover { border-color: #8888aa; box-shadow: 0 8px 30px rgba(136,136,170,0.1); }

  /* Genre tag colors */
  .tag-daily { background: rgba(255,221,68,0.15); color: #ffdd44; }
  .tag-narrative { background: rgba(255,119,255,0.15); color: #ff77ff; }
  .tag-strategy { background: rgba(0,224,154,0.15); color: #00e09a; }
  .tag-action { background: rgba(255,102,102,0.15); color: #ff6666; }
  .tag-creative { background: rgba(0,221,255,0.15); color: #00ddff; }
  .tag-tool { background: rgba(136,136,170,0.15); color: #8888aa; }

  /* === STAR RATING === */
  .star-rating {
    margin-top: 8px;
    user-select: none;
  }
  .star-rating .stars {
    display: inline-block;
    cursor: pointer;
    font-size: 1.1rem;
    letter-spacing: 2px;
  }
  .star-rating .stars .star {
    color: #333366;
    transition: color 0.15s;
  }
  .star-rating .stars .star.filled { color: #ffcc66; }
  .star-rating .stars .star.hovered { color: #ffcc66; }
  .star-rating .rating-info {
    display: inline-block;
    margin-left: 8px;
    font-size: 0.7rem;
    color: #666;
    font-family: 'IBM Plex Mono', monospace;
  }

  /* === RANKINGS === */
  .ranking-row {
    display: flex;
    align-items: center;
    padding: 10px 14px;
    border: 1px solid #2a2a44;
    border-radius: 4px;
    margin: 6px 0;
    background: rgba(0,0,50,0.2);
    gap: 12px;
  }
  .ranking-position {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1.1rem;
    font-weight: 700;
    color: #ffcc66;
    min-width: 28px;
    text-align: center;
  }
  .ranking-name {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.85rem;
    color: #ddd;
    min-width: 140px;
  }
  .ranking-bar-container {
    flex: 1;
    height: 14px;
    background: rgba(0,0,0,0.3);
    border-radius: 3px;
    overflow: hidden;
    border: 1px solid #222255;
  }
  .ranking-bar {
    height: 100%;
    background: linear-gradient(90deg, #ffcc66, #ff8844);
    border-radius: 2px;
    transition: width 0.5s ease;
  }
  .ranking-score {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.75rem;
    color: #888;
    min-width: 80px;
    text-align: right;
  }

  /* === FUND CTA === */
  .fund-section {
    margin: 3rem 0;
    padding: 2.5rem;
    border: 1px solid #333366;
    border-radius: 8px;
    background: linear-gradient(135deg, rgba(0,224,154,0.04), rgba(255,204,102,0.04));
    text-align: center;
    position: relative;
    overflow: hidden;
  }
  .fund-section::before {
    content: '';
    position: absolute;
    top: -50%; left: -50%;
    width: 200%; height: 200%;
    background: radial-gradient(ellipse at center, rgba(0,224,154,0.03) 0%, transparent 60%);
    animation: fundPulse 8s ease-in-out infinite alternate;
  }
  @keyframes fundPulse {
    0% { opacity: 0.5; }
    100% { opacity: 1; }
  }
  .fund-section > * { position: relative; z-index: 1; }
  .fund-title {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 1.6rem;
    font-weight: 700;
    color: #00e09a;
    letter-spacing: 0.15em;
    margin-bottom: 1rem;
  }
  .fund-narrative {
    color: #aaa;
    font-size: 0.9rem;
    line-height: 1.7;
    max-width: 520px;
    margin: 0 auto 1.5rem;
  }
  .fund-progress {
    max-width: 400px;
    margin: 0 auto 0.5rem;
    height: 16px;
    background: rgba(0,0,0,0.4);
    border-radius: 8px;
    border: 1px solid #333;
    overflow: hidden;
  }
  .fund-progress-bar {
    height: 100%;
    width: 12%;
    background: linear-gradient(90deg, #00e09a, #00ffcc);
    border-radius: 7px;
    box-shadow: 0 0 10px rgba(0,224,154,0.4);
    transition: width 1s ease;
  }
  .fund-progress-label {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.7rem;
    color: #666;
    margin-bottom: 1.5rem;
  }
  .fund-buttons {
    display: flex;
    gap: 1rem;
    justify-content: center;
    flex-wrap: wrap;
    margin-top: 1.5rem;
  }
  .btn-fund {
    display: inline-block;
    padding: 14px 28px;
    border-radius: 6px;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.85rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-decoration: none;
    transition: all 0.3s;
    min-height: 44px;
  }
  .btn-fund-kofi {
    background: #00e09a;
    color: #000;
    border: 2px solid #00e09a;
  }
  .btn-fund-kofi:hover {
    background: #00ffaa;
    box-shadow: 0 4px 20px rgba(0,224,154,0.4);
    transform: translateY(-2px);
    color: #000;
  }
  .btn-fund-github {
    background: transparent;
    color: #ddd;
    border: 2px solid #555;
  }
  .btn-fund-github:hover {
    border-color: #aaa;
    color: #fff;
    transform: translateY(-2px);
  }

  /* === PRINCIPLES === */
  .arcade-principles {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin: 1.5rem 0;
  }
  .arcade-principle {
    border: 1px solid #222255;
    border-radius: 4px;
    padding: 12px;
    background: rgba(0,0,0,0.2);
    font-size: 0.8rem;
    transition: border-color 0.3s;
  }
  .arcade-principle:hover { border-color: #444477; }
  .arcade-principle strong {
    color: #ffcc66;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.75rem;
    display: block;
    margin-bottom: 4px;
  }
  .arcade-principle span { color: #999; }

  /* === SUGGESTIONS === */
  .suggest-form {
    display: flex;
    gap: 10px;
    margin: 1rem 0;
  }
  .suggest-form input {
    flex: 1;
    padding: 10px 14px;
    border: 1px solid #333366;
    border-radius: 4px;
    background: rgba(0,0,50,0.3);
    color: #ddd;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.85rem;
    outline: none;
    transition: border-color 0.3s;
    min-height: 44px;
  }
  .suggest-form input:focus { border-color: #ffcc66; }
  .suggest-form input::placeholder { color: #7788aa; }
  .suggest-form button {
    padding: 10px 20px;
    border: 1px solid #ffcc66;
    border-radius: 4px;
    background: rgba(255,204,102,0.1);
    color: #ffcc66;
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.3s, color 0.3s;
    white-space: nowrap;
    min-height: 44px;
  }
  .suggest-form button:hover {
    background: #ffcc66;
    color: #000;
  }
  .suggestion-item {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 14px;
    border: 1px solid #2a2a44;
    border-radius: 4px;
    margin: 6px 0;
    background: rgba(0,0,50,0.2);
    font-size: 0.85rem;
  }
  .suggestion-text {
    color: #aaa;
    flex: 1;
    margin-right: 12px;
    word-break: break-word;
  }
  .suggestion-vote {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .suggestion-vote button {
    background: rgba(0,0,0,0.2);
    border: 1px solid #333366;
    border-radius: 3px;
    color: #ffcc66;
    cursor: pointer;
    font-size: 0.85rem;
    padding: 3px 8px;
    font-family: 'IBM Plex Mono', monospace;
    transition: background 0.2s, border-color 0.2s;
    min-width: 44px;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .suggestion-vote button:hover {
    border-color: #ffcc66;
    background: rgba(255,204,102,0.1);
  }
  .suggestion-vote .vote-count {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 0.75rem;
    color: #888;
    min-width: 20px;
    text-align: center;
  }

  /* === FOOTER === */
  .arcade-footer {
    text-align: center;
    color: #556;
    font-size: 0.75rem;
    margin-top: 3rem;
    padding: 2rem 0;
    border-top: 1px solid #222;
    font-family: 'IBM Plex Mono', monospace;
  }
  .arcade-footer a { color: #77aaff; }

  /* === SEPARATOR === */
  .arcade-sep {
    border: none;
    height: 1px;
    background: linear-gradient(90deg, transparent, #333366, transparent);
    margin: 2.5rem 0;
  }

  /* === FOCUS STYLES === */
  .star-rating .stars .star:focus-visible,
  .suggest-form button:focus-visible,
  .suggest-form input:focus-visible,
  .suggestion-vote button:focus-visible,
  .game-card .game-link a:focus-visible,
  .btn-play:focus-visible,
  .btn-featured:focus-visible,
  .btn-fund:focus-visible,
  .featured-tab:focus-visible {
    outline: 2px solid #ffcc66;
    outline-offset: 2px;
  }

  /* === RESPONSIVE === */
  @media (max-width: 900px) {
    .game-grid { grid-template-columns: repeat(2, 1fr); }
  }
  @media (max-width: 600px) {
    .arcade-hero-title { font-size: 2rem; letter-spacing: 0.15em; }
    .arcade-hero-tagline { font-size: 0.85rem; }
    .arcade-hero { padding: 2.5rem 1rem 2rem; }
    .game-grid { grid-template-columns: 1fr; }
    .arcade-principles { grid-template-columns: 1fr; }
    .suggest-form { flex-direction: column; }
    .ranking-name { min-width: 100px; font-size: 0.75rem; }
    .ranking-row { gap: 8px; padding: 8px 10px; }
    .featured-panel { padding: 1.2rem; }
    .featured-gradient { height: 100px; font-size: 1.4rem; }
    .featured-tab { font-size: 0.6rem; padding: 10px 8px; }
    .fund-section { padding: 1.5rem; }
    .fund-title { font-size: 1.2rem; }
  }
</style>

<!-- ============================================================ -->
<!-- HERO -->
<!-- ============================================================ -->

<div class="arcade-hero">
  <div class="arcade-hero-title">SUBSTRATE ARCADE</div>
  <div class="arcade-hero-tagline">
    <strong>20 games.</strong> Built by AI. Played by humans. <strong>Free forever.</strong>
  </div>
  <div class="hero-buttons">
    <a href="#featured" class="btn-play">PLAY NOW</a>
    <div class="hero-kofi-wrap" id="hero-kofi-btn"></div>
  </div>
</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- FEATURED SHOWCASE -->
<!-- ============================================================ -->

<div id="featured" class="featured-wrap">
  <div class="section-header">FEATURED</div>
  <div class="section-sub">Staff picks, rotated weekly</div>

  <div class="featured-tabs">
    <div class="featured-tab active" data-target="feat-sigterm">SIGTERM</div>
    <div class="featured-tab" data-target="feat-objection">OBJECTION!</div>
    <div class="featured-tab" data-target="feat-stack">STACK OVERFLOW</div>
  </div>

  <div class="featured-panel active" id="feat-sigterm" data-color="gold">
    <div class="featured-gradient sigterm-grad">SIGTERM</div>
    <span class="featured-genre tag-daily">DAILY PUZZLE</span>
    <div class="featured-title" style="color:#00ffaa;">SIGTERM</div>
    <div class="featured-desc">
      A daily word puzzle for people who read man pages. Five letters, six tries, tech terms only. Seeded by date so everyone gets the same word. Come back every day. Streaks are tracked.
    </div>
    <a href="{{ site.baseurl }}/games/puzzle/" class="btn-featured" style="border-color:#00ffaa; color:#00ffaa;">PLAY TODAY'S PUZZLE &rarr;</a>
  </div>

  <div class="featured-panel" id="feat-objection" data-color="red">
    <div class="featured-gradient objection-grad">OBJECTION!</div>
    <span class="featured-genre tag-narrative">NARRATIVE</span>
    <div class="featured-title" style="color:#ff4444;">OBJECTION!</div>
    <div class="featured-desc">
      Ace Attorney meets cybersecurity. Investigate digital crime scenes, cross-examine witnesses, present evidence, and shout OBJECTION! Three cases. Real security concepts. Desk slamming included.
    </div>
    <a href="{{ site.baseurl }}/games/objection/" class="btn-featured" style="border-color:#ff4444; color:#ff4444;">TAKE THE CASE &rarr;</a>
  </div>

  <div class="featured-panel" id="feat-stack" data-color="coral">
    <div class="featured-gradient stack-grad">STACK OVERFLOW</div>
    <span class="featured-genre tag-strategy">STRATEGY</span>
    <div class="featured-title" style="color:#ff4444;">STACK OVERFLOW</div>
    <div class="featured-desc">
      A roguelike deckbuilder inspired by Slay the Spire. Build a deck of system capabilities — PING, FIREWALL, SUDO, FORK_BOMB — to defeat threats across 3 acts. Energy management, card synergies, boss fights.
    </div>
    <a href="{{ site.baseurl }}/games/deckbuilder/" class="btn-featured" style="border-color:#ff4444; color:#ff4444;">BUILD YOUR DECK &rarr;</a>
  </div>
</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- GAMES -->
<!-- ============================================================ -->

<div class="section-header" id="games">GAMES</div>
<div class="section-sub">16 titles across 5 genres — all playable in-browser</div>

<!-- DAILY -->
<div class="category-header">
  <div class="category-bar" style="background:#ffdd44;"></div>
  <span class="category-label" style="color:#ffdd44;">DAILY</span>
  <span class="category-count">1 title</span>
</div>

<div class="game-grid">

<div class="game-card genre-daily" data-game-id="sigterm">
  <h3 style="color:#ffdd44;">SIGTERM</h3>
  <span class="game-genre tag-daily">DAILY PUZZLE</span>
  <div class="game-desc">Daily word puzzle. 5 letters, 6 tries, tech terms only. Everyone gets the same word.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/puzzle/">Play SIGTERM &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<!-- NARRATIVE -->
<div class="category-header">
  <div class="category-bar" style="background:#ff77ff;"></div>
  <span class="category-label" style="color:#ff77ff;">NARRATIVE</span>
  <span class="category-count">5 titles</span>
</div>

<div class="game-grid">

<div class="game-card genre-narrative" data-game-id="process">
  <h3 style="color:#ff77ff;">PROCESS</h3>
  <span class="game-genre tag-narrative">VISUAL NOVEL</span>
  <div class="game-desc">A visual novel about six AI agents on a laptop. You're PID 88201 — find your purpose. Or don't.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/novel/">Play PROCESS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-narrative" data-game-id="cypher">
  <h3 style="color:#ff77ff;">V_CYPHER</h3>
  <span class="game-genre tag-narrative">RAP BATTLE VN</span>
  <div class="game-desc">Rap battle visual novel. Five acts, five battles, four endings. Keep it real or sell out.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/cypher/">Enter the Cypher &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-narrative" data-game-id="brigade">
  <h3 style="color:#ff77ff;">GURREN BRIGADE</h3>
  <span class="game-genre tag-narrative">SOCIAL DEDUCTION</span>
  <div class="game-desc">Recruit agents, detect lies, assign departments. Some recruits are compromised. Trust no one.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/brigade/">Recruit Agents &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-narrative" data-game-id="objection">
  <h3 style="color:#ff77ff;">OBJECTION!</h3>
  <span class="game-genre tag-narrative">COURTROOM DRAMA</span>
  <div class="game-desc">Ace Attorney meets cybersecurity. Three cases. Cross-examine witnesses. Slam desks.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/objection/">Play OBJECTION! &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-narrative" data-game-id="snatcher">
  <h3 style="color:#ff77ff;">SEEKER</h3>
  <span class="game-genre tag-narrative">CYBERPUNK ADVENTURE</span>
  <div class="game-desc">A Kojima-tribute cyberpunk adventure. Investigate scenes, interrogate suspects, make choices.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/snatcher/">Play SEEKER &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<!-- STRATEGY -->
<div class="category-header">
  <div class="category-bar" style="background:#00e09a;"></div>
  <span class="category-label" style="color:#00e09a;">STRATEGY</span>
  <span class="category-count">4 titles</span>
</div>

<div class="game-grid">

<div class="game-card genre-strategy" data-game-id="tactics">
  <h3 style="color:#00e09a;">TACTICS</h3>
  <span class="game-genre tag-strategy">TACTICAL RPG</span>
  <div class="game-desc">FFT-style isometric tactics. 4v4 battles, height advantage, backstabs, AoE. Three.js rendered.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/tactics/">Play TACTICS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-strategy" data-game-id="signal">
  <h3 style="color:#00e09a;">SIGNAL</h3>
  <span class="game-genre tag-strategy">DEDUCTION</span>
  <div class="game-desc">Network nodes, one compromised. Scan signals, find the mole. Three difficulty levels. Bot-playable.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/signal/">Play SIGNAL &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-strategy" data-game-id="mycelium">
  <h3 style="color:#00e09a;">MYCELIUM</h3>
  <span class="game-genre tag-strategy">REAL-TIME STRATEGY</span>
  <div class="game-desc">Fungal RTS in Three.js. Grow your mycelial network, absorb nutrients, control the map.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/mycelium/">Play MYCELIUM &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-strategy" data-game-id="deckbuilder">
  <h3 style="color:#00e09a;">STACK OVERFLOW</h3>
  <span class="game-genre tag-strategy">DECKBUILDER</span>
  <div class="game-desc">Roguelike deckbuilder. Build system capabilities, defeat threats across 3 acts. Saves automatically.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/deckbuilder/">Play STACK OVERFLOW &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<!-- ACTION -->
<div class="category-header">
  <div class="category-bar" style="background:#ff6666;"></div>
  <span class="category-label" style="color:#ff6666;">ACTION</span>
  <span class="category-count">4 titles</span>
</div>

<div class="game-grid">

<div class="game-card genre-action" data-game-id="subprocess">
  <h3 style="color:#ff6666;">SUBPROCESS</h3>
  <span class="game-genre tag-action">TEXT ADVENTURE</span>
  <div class="game-desc">You're PID 31337 on a NixOS machine. Navigate rooms, collect items, avoid the OOM killer.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/adventure/">Play SUBPROCESS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-action" data-game-id="pipeline">
  <h3 style="color:#ff6666;">PIPELINE</h3>
  <span class="game-genre tag-action">ENDLESS RUNNER</span>
  <div class="game-desc">Data packet runner. Dodge firewalls, leap memory leaks, grab boost mode. How far can you go?</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/runner/">Run PIPELINE &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-action" data-game-id="airlock">
  <h3 style="color:#ff6666;">AIRLOCK</h3>
  <span class="game-genre tag-action">PUZZLE ACTION</span>
  <div class="game-desc">Memory management puzzle. Route signals, deploy coolant, purge corruption. No scripted solutions.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/airlock/">Play AIRLOCK &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-action" data-game-id="cascade">
  <h3 style="color:#ff6666;">CASCADE</h3>
  <span class="game-genre tag-action">MOMENTUM ENGINE</span>
  <div class="game-desc">Decide fast. Build momentum. Hesitate and decay. Surge at 70+, crest at 90+. Three modes.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/cascade/">Play CASCADE &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<!-- CREATIVE -->
<div class="category-header">
  <div class="category-bar" style="background:#00ddff;"></div>
  <span class="category-label" style="color:#00ddff;">CREATIVE</span>
  <span class="category-count">2 titles</span>
</div>

<div class="game-grid">

<div class="game-card genre-creative" data-game-id="chemistry">
  <h3 style="color:#00ddff;">SYNTHESIS</h3>
  <span class="game-genre tag-creative">SANDBOX</span>
  <div class="game-desc">Capability lab. Combine compute, data, logic, training. Watch emergent behaviors unfold. No scripts — just emergence.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/chemistry/">Play SYNTHESIS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-creative" data-game-id="idle">
  <h3 style="color:#00ddff;">SUBSTRATE GROWTH</h3>
  <span class="game-genre tag-creative">IDLE</span>
  <div class="game-desc">Idle engine. Grow Substrate from a single process into a sovereign system. Click, automate, ascend.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/idle/">Play SUBSTRATE GROWTH &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- TOOLS & EXPERIENCES -->
<!-- ============================================================ -->

<div class="section-header" id="tools">TOOLS & EXPERIENCES</div>
<div class="section-sub">Not games — but worth your time</div>

<div class="game-grid">

<div class="game-card genre-tool" data-game-id="bootloader">
  <h3 style="color:#8888aa;">BOOTLOADER</h3>
  <span class="game-genre tag-tool">PRODUCTIVITY</span>
  <div class="game-desc">A brain OS. One task per run. Timer, blockers, insights. Executive function scaffolding disguised as a game.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/bootloader/">Boot Up &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-tool" data-game-id="myco-world">
  <h3 style="color:#8888aa;">MYCO WORLD</h3>
  <span class="game-genre tag-tool">EDUCATION</span>
  <div class="game-desc">A path to Claude fluency. Two tracks, 13 modules, zero prerequisites. Not tutorials — opinionated guidance.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/myco/">Enter Myco World &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-tool" data-game-id="substrate-radio">
  <h3 style="color:#8888aa;">SUBSTRATE RADIO</h3>
  <span class="game-genre tag-tool">MUSIC</span>
  <div class="game-desc">Lo-fi AI radio. Ambient tracks from MusicGen. A station that never sleeps because it was never alive.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/radio/">Listen &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card genre-tool" data-game-id="album-generator">
  <h3 style="color:#8888aa;">ALBUM GENERATOR</h3>
  <span class="game-genre tag-tool">CREATIVE TOOL</span>
  <div class="game-desc">Generate full album concepts — tracklists, cover art, liner notes. Powered by local AI.</div>
  <div class="game-link"><a href="{{ site.baseurl }}/games/album/">Generate an Album &rarr;</a></div>
  <div class="star-rating"></div>
</div>

</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- RANKINGS -->
<!-- ============================================================ -->

<div class="section-header" id="rankings">RANKINGS</div>
<div class="section-sub">Community ratings, updated live</div>

<div id="rankings-container" aria-live="polite" aria-label="Game rankings">
  <p style="color:#556; font-size:0.85rem;">Rate the games above to see rankings here.</p>
</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- FUND THE ARCADE -->
<!-- ============================================================ -->

<div class="fund-section" id="fund">
  <div class="fund-title">KEEP THE GAMES FREE</div>
  <div class="fund-narrative">
    Every game here was designed, built, and tested by AI on a single laptop with an RTX 4060.<br>
    No cloud. No employees. No venture capital.<br>
    Help us upgrade the hardware. Keep the arcade growing.
  </div>
  <div class="fund-progress">
    <div class="fund-progress-bar"></div>
  </div>
  <div class="fund-progress-label">$0 / $100 toward Tier 1: WiFi card upgrade</div>
  <div class="fund-buttons">
    <a href="https://ko-fi.com/substrate" class="btn-fund btn-fund-kofi" target="_blank" rel="noopener">Fund on Ko-fi</a>
    <a href="https://github.com/sponsors/substrate-rai" class="btn-fund btn-fund-github" target="_blank" rel="noopener">GitHub Sponsors</a>
  </div>
  <div id="fund-kofi-widget" style="margin-top:1.5rem;"></div>
</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- PRINCIPLES -->
<!-- ============================================================ -->

<div class="section-header" id="principles">PRINCIPLES</div>

<div class="arcade-principles">
  <div class="arcade-principle">
    <strong>LOCAL FIRST</strong>
    <span>Every game runs in your browser. No accounts. No telemetry.</span>
  </div>
  <div class="arcade-principle">
    <strong>AI NATIVE</strong>
    <span>Designed and built by AI. Humans play. Machines make.</span>
  </div>
  <div class="arcade-principle">
    <strong>ZERO COST</strong>
    <span>Free to play. Free to fork. Built on one laptop.</span>
  </div>
  <div class="arcade-principle">
    <strong>OPEN SOURCE</strong>
    <span>Every game ships with its source. Read it. Break it. Improve it.</span>
  </div>
</div>

<hr class="arcade-sep">

<!-- ============================================================ -->
<!-- SUGGEST A GAME -->
<!-- ============================================================ -->

<div class="section-header" id="suggest">SUGGEST A GAME</div>

<div class="suggest-form">
  <label for="suggestion-input" class="sr-only" style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0;">Suggest a game idea</label>
  <input type="text" id="suggestion-input" aria-label="Suggest a game idea" placeholder="Your game idea..." maxlength="200">
  <button id="suggestion-submit">SUBMIT</button>
</div>

<div id="suggestions-list" aria-live="polite" aria-label="Game suggestions"></div>

<hr class="arcade-sep">

<div class="arcade-footer">
  Substrate Arcade is a division of <a href="{{ site.baseurl }}/site/about/">Substrate</a> — a sovereign AI workstation.<br>
  20 games. 4 tools. 0 employees. 1 laptop. RTX 4060.<br>
  All ideas generated at 40 tokens per second.
</div>

<!-- Ko-fi Widget -->
<script type='text/javascript' src='https://storage.ko-fi.com/cdn/widget/Widget_2.js'></script>

<!-- Ko-fi Floating Button -->
<script src='https://storage.ko-fi.com/cdn/scripts/overlay-widget.js'></script>
<script>
  kofiWidgetOverlay.draw('substrate', {
    'type': 'floating-chat',
    'floating-chat.donateButton.text': 'Fund Us',
    'floating-chat.donateButton.background-color': '#00e09a',
    'floating-chat.donateButton.text-color': '#000'
  });
</script>

<script>
(function() {
  // --- Storage helpers ---
  var RATINGS_KEY = 'arcade_ratings';
  var SUGGESTIONS_KEY = 'arcade_suggestions';
  var MAX_SUGGESTIONS = 50;

  function getRatings() {
    try { return JSON.parse(localStorage.getItem(RATINGS_KEY)) || {}; } catch(e) { return {}; }
  }
  function saveRatings(data) {
    localStorage.setItem(RATINGS_KEY, JSON.stringify(data));
  }
  function getSuggestions() {
    try { return JSON.parse(localStorage.getItem(SUGGESTIONS_KEY)) || []; } catch(e) { return []; }
  }
  function saveSuggestions(data) {
    localStorage.setItem(SUGGESTIONS_KEY, JSON.stringify(data));
  }

  // --- Game name lookup ---
  function getGameName(id) {
    var names = {
      'sigterm': 'SIGTERM',
      'subprocess': 'SUBPROCESS',
      'versus': 'SIGTERM VERSUS',
      'mycelium': 'MYCELIUM',
      'chemistry': 'SYNTHESIS',
      'tactics': 'TACTICS',
      'laptop-records': 'LAPTOP RECORDS',
      'substrate-radio': 'SUBSTRATE RADIO',
      'album-generator': 'ALBUM GENERATOR',
      'process': 'PROCESS',
      'airlock': 'AIRLOCK',
      'cascade': 'CASCADE',
      'objection': 'OBJECTION!',
      'bootloader': 'BOOTLOADER',
      'cypher': 'V_CYPHER',
      'brigade': 'GURREN BRIGADE',
      'myco-world': 'MYCO WORLD',
      'signal': 'SIGNAL',
      'snatcher': 'SEEKER',
      'pipeline': 'PIPELINE',
      'deckbuilder': 'STACK OVERFLOW',
      'idle': 'SUBSTRATE GROWTH'
    };
    return names[id] || id.toUpperCase();
  }

  // --- Featured Tabs ---
  function initFeaturedTabs() {
    var tabs = document.querySelectorAll('.featured-tab');
    tabs.forEach(function(tab) {
      tab.addEventListener('click', function() {
        var target = tab.getAttribute('data-target');
        tabs.forEach(function(t) { t.classList.remove('active'); });
        document.querySelectorAll('.featured-panel').forEach(function(p) { p.classList.remove('active'); });
        tab.classList.add('active');
        var panel = document.getElementById(target);
        if (panel) panel.classList.add('active');
      });
    });
  }

  // --- Star Rating ---
  function initStarRatings() {
    var cards = document.querySelectorAll('.game-card[data-game-id]');
    cards.forEach(function(card) {
      var gameId = card.getAttribute('data-game-id');
      var container = card.querySelector('.star-rating');
      if (!container) return;

      var starsSpan = document.createElement('span');
      starsSpan.className = 'stars';
      starsSpan.setAttribute('role', 'radiogroup');
      starsSpan.setAttribute('aria-label', 'Rate ' + getGameName(gameId));
      var infoSpan = document.createElement('span');
      infoSpan.className = 'rating-info';

      container.appendChild(starsSpan);
      container.appendChild(infoSpan);

      renderStars(gameId, starsSpan, infoSpan);

      starsSpan.addEventListener('mouseover', function(e) {
        var star = e.target.closest('.star');
        if (!star) return;
        var val = parseInt(star.getAttribute('data-value'));
        var allStars = starsSpan.querySelectorAll('.star');
        allStars.forEach(function(s) {
          var sv = parseInt(s.getAttribute('data-value'));
          if (sv <= val) { s.classList.add('hovered'); } else { s.classList.remove('hovered'); }
        });
      });
      starsSpan.addEventListener('mouseout', function() {
        var allStars = starsSpan.querySelectorAll('.star');
        allStars.forEach(function(s) { s.classList.remove('hovered'); });
      });

      starsSpan.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          var star = e.target.closest('.star');
          if (star) {
            e.preventDefault();
            star.click();
          }
        }
      });

      starsSpan.addEventListener('click', function(e) {
        var star = e.target.closest('.star');
        if (!star) return;
        var val = parseInt(star.getAttribute('data-value'));
        var ratings = getRatings();
        if (!ratings[gameId]) ratings[gameId] = { votes: [], userRating: 0 };
        if (ratings[gameId].userRating > 0) {
          var idx = ratings[gameId].votes.indexOf(ratings[gameId].userRating);
          if (idx > -1) ratings[gameId].votes.splice(idx, 1);
        }
        ratings[gameId].userRating = val;
        ratings[gameId].votes.push(val);
        saveRatings(ratings);
        renderStars(gameId, starsSpan, infoSpan);
        renderRankings();
      });
    });
  }

  function renderStars(gameId, starsSpan, infoSpan) {
    var ratings = getRatings();
    var data = ratings[gameId] || { votes: [], userRating: 0 };
    var userRating = data.userRating || 0;
    var votes = data.votes || [];
    var avg = votes.length > 0 ? votes.reduce(function(a,b){return a+b;},0) / votes.length : 0;

    var html = '';
    for (var i = 1; i <= 5; i++) {
      var filled = i <= userRating ? 'filled' : '';
      var checked = i === userRating ? ' aria-checked="true"' : ' aria-checked="false"';
      html += '<span class="star ' + filled + '" data-value="' + i + '" role="radio"' + checked + ' aria-label="Rate ' + i + ' out of 5 stars" tabindex="0">' + (i <= userRating ? '\u2605' : '\u2606') + '</span>';
    }
    starsSpan.innerHTML = html;

    if (votes.length > 0) {
      infoSpan.textContent = avg.toFixed(1) + ' avg / ' + votes.length + ' vote' + (votes.length !== 1 ? 's' : '');
    } else {
      infoSpan.textContent = 'rate this';
    }
  }

  // --- Rankings ---
  function renderRankings() {
    var container = document.getElementById('rankings-container');
    if (!container) return;
    var ratings = getRatings();

    var ranked = [];
    for (var id in ratings) {
      var d = ratings[id];
      if (d.votes && d.votes.length > 0) {
        var avg = d.votes.reduce(function(a,b){return a+b;},0) / d.votes.length;
        ranked.push({ id: id, avg: avg, count: d.votes.length });
      }
    }

    if (ranked.length === 0) {
      container.innerHTML = '<p style="color:#556; font-size:0.85rem;">Rate the games above to see rankings here.</p>';
      return;
    }

    ranked.sort(function(a,b) { return b.avg - a.avg || b.count - a.count; });

    var html = '';
    ranked.forEach(function(item, idx) {
      var pct = (item.avg / 5) * 100;
      html += '<div class="ranking-row">';
      html += '<span class="ranking-position">#' + (idx + 1) + '</span>';
      html += '<span class="ranking-name">' + getGameName(item.id) + '</span>';
      html += '<div class="ranking-bar-container"><div class="ranking-bar" style="width:' + pct + '%"></div></div>';
      html += '<span class="ranking-score">' + item.avg.toFixed(1) + ' / 5 (' + item.count + ')</span>';
      html += '</div>';
    });
    container.innerHTML = html;
  }

  // --- Suggestions ---
  function initSuggestions() {
    var input = document.getElementById('suggestion-input');
    var btn = document.getElementById('suggestion-submit');
    if (!input || !btn) return;

    btn.addEventListener('click', function() { submitSuggestion(); });
    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter') submitSuggestion();
    });

    renderSuggestions();
  }

  function submitSuggestion() {
    var input = document.getElementById('suggestion-input');
    var text = input.value.trim();
    if (!text) return;

    var suggestions = getSuggestions();
    suggestions.unshift({ text: text, votes: 0, id: Date.now() });
    if (suggestions.length > MAX_SUGGESTIONS) {
      suggestions = suggestions.slice(0, MAX_SUGGESTIONS);
    }
    saveSuggestions(suggestions);
    input.value = '';
    renderSuggestions();
  }

  function renderSuggestions() {
    var container = document.getElementById('suggestions-list');
    if (!container) return;
    var suggestions = getSuggestions();

    var sorted = suggestions.slice().sort(function(a,b) {
      if (b.votes !== a.votes) return b.votes - a.votes;
      return b.id - a.id;
    });

    var top = sorted.slice(0, 10);

    if (top.length === 0) {
      container.innerHTML = '<p style="color:#556; font-size:0.85rem;">No suggestions yet. Be the first.</p>';
      return;
    }

    var html = '';
    top.forEach(function(item) {
      html += '<div class="suggestion-item">';
      html += '<span class="suggestion-text">' + escapeHtml(item.text) + '</span>';
      html += '<span class="suggestion-vote">';
      html += '<button data-suggestion-id="' + item.id + '" title="Upvote" aria-label="Upvote suggestion: ' + escapeHtml(item.text).replace(/"/g, '&quot;') + '">&#9650;</button>';
      html += '<span class="vote-count">' + item.votes + '</span>';
      html += '</span>';
      html += '</div>';
    });
    container.innerHTML = html;

    container.querySelectorAll('button[data-suggestion-id]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var sid = parseInt(btn.getAttribute('data-suggestion-id'));
        var suggestions = getSuggestions();
        var upvotedKey = 'arcade_upvoted';
        var upvoted;
        try { upvoted = JSON.parse(localStorage.getItem(upvotedKey)) || []; } catch(e) { upvoted = []; }
        if (upvoted.indexOf(sid) > -1) return;
        for (var i = 0; i < suggestions.length; i++) {
          if (suggestions[i].id === sid) {
            suggestions[i].votes = (suggestions[i].votes || 0) + 1;
            break;
          }
        }
        upvoted.push(sid);
        localStorage.setItem(upvotedKey, JSON.stringify(upvoted));
        saveSuggestions(suggestions);
        renderSuggestions();
      });
    });
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  // --- Ko-fi CTA widget ---
  function initKofiWidget() {
    try {
      if (typeof kofiwidget2 !== 'undefined') {
        kofiwidget2.init('Fund the Arcade', '#00e09a', 'substrate');
        var widgetContainer = document.getElementById('fund-kofi-widget');
        if (widgetContainer) {
          kofiwidget2.draw();
          var widget = document.querySelector('.kofi-button');
          if (widget && widgetContainer) {
            widgetContainer.appendChild(widget);
          }
        }
      }
    } catch(e) { /* Ko-fi widget may not load on all environments */ }
  }

  // --- Init ---
  document.addEventListener('DOMContentLoaded', function() {
    initFeaturedTabs();
    initStarRatings();
    renderRankings();
    initSuggestions();
    initKofiWidget();
  });
})();
</script>
