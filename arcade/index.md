---
layout: default
title: "Substrate Arcade"
description: "24 games and 7 radio stations. Built by AI on a single laptop. Zero human game code. Free forever."
permalink: /arcade/
---

<style>
  .arcade-page {
    max-width: 1100px;
    margin: 0 auto;
    padding: 48px 24px 80px;
  }

  .arcade-header {
    margin-bottom: 40px;
  }

  .arcade-title {
    font-family: var(--mono);
    font-size: clamp(1.4rem, 1rem + 2vw, 2rem);
    font-weight: 700;
    color: var(--heading);
    margin: 0 0 12px 0;
    letter-spacing: -0.5px;
  }

  .arcade-title .accent {
    color: var(--accent);
  }

  .arcade-intro {
    font-size: 0.95rem;
    color: var(--text-muted);
    line-height: 1.7;
    max-width: 600px;
    margin: 0;
  }

  .arcade-count {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--text-dim);
    margin-top: 8px;
  }

  .game-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
    gap: 16px;
    margin-bottom: 48px;
  }

  .game-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 20px;
    transition: border-color 0.2s, transform 0.2s;
    display: flex;
    flex-direction: column;
    min-height: 120px;
  }

  .game-card:hover {
    border-color: var(--border-hover);
    transform: translateY(-1px);
  }

  .game-card-title {
    font-family: var(--mono);
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--heading);
    margin: 0 0 10px 0;
    line-height: 1.3;
  }

  .game-card-title a {
    color: inherit;
    text-decoration: none;
    transition: color 0.2s;
  }

  .game-card-title a:hover {
    color: var(--accent);
  }

  .game-card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    margin-top: auto;
  }

  .game-tag {
    font-family: var(--mono);
    font-size: 0.65rem;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 4px;
    background: var(--accent-dim);
    color: var(--accent);
    border: 1px solid var(--accent-border);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    white-space: nowrap;
  }

  .arcade-footer-links {
    display: flex;
    align-items: center;
    gap: 24px;
    flex-wrap: wrap;
    padding-top: 24px;
    border-top: 1px solid var(--border);
  }

  .arcade-footer-links a {
    font-family: var(--mono);
    font-size: 0.8rem;
    color: var(--text-muted);
    text-decoration: none;
    transition: color 0.2s;
    min-height: 48px;
    display: inline-flex;
    align-items: center;
  }

  .arcade-footer-links a:hover {
    color: var(--accent);
  }

  .arcade-footer-links .fund-link {
    color: var(--accent);
    border: 1px solid var(--accent-border);
    padding: 6px 16px;
    border-radius: 6px;
  }

  .arcade-footer-links .fund-link:hover {
    background: var(--accent-dim);
  }

  @media (max-width: 768px) {
    .arcade-page {
      padding: 24px 16px 60px;
    }

    .game-grid {
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 12px;
    }

    .game-card {
      padding: 16px;
    }
  }

  @media (max-width: 480px) {
    .game-grid {
      grid-template-columns: 1fr 1fr;
      gap: 10px;
    }

    .game-card {
      padding: 14px;
      min-height: 100px;
    }

    .game-card-title {
      font-size: 0.8rem;
    }

    .game-tag {
      font-size: 0.6rem;
      padding: 2px 6px;
    }
  }
</style>

<div class="arcade-page">

  <div class="arcade-header">
    <h1 class="arcade-title"><span class="accent">//</span> Substrate Arcade</h1>
    <p class="arcade-intro">Built by AI on a single laptop. Zero human game code. Free forever.</p>
    <p class="arcade-count">24 games &middot; 7 radio stations &middot; 1 album</p>
  </div>

  <div class="game-grid">

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/puzzle/">SIGTERM</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Daily</span>
        <span class="game-tag">Word Puzzle</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/novel/">PROCESS</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Visual Novel</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/adventure/">SUBPROCESS</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Text Adventure</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/mycelium/">MYCELIUM</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">RTS</span>
        <span class="game-tag">3D</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/tactics/">TACTICS</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Tactical RPG</span>
        <span class="game-tag">2D</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/chemistry/">SYNTHESIS</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Sandbox</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/idle/">SUBSTRATE GROWTH</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Idle</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cypher/">V_CYPHER</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Cyberpunk</span>
        <span class="game-tag">Adventure</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/brigade/">GURREN BRIGADE</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Anime</span>
        <span class="game-tag">RPG</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/objection/">OBJECTION!</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Courtroom</span>
        <span class="game-tag">Drama</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/runner/">PIPELINE</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Endless Runner</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/airlock/">AIRLOCK</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Puzzle Action</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/snatcher/">SEEKER</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Cyberpunk</span>
        <span class="game-tag">Adventure</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cascade/">CASCADE</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Momentum</span>
        <span class="game-tag">Arcade</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/deckbuilder/">STACK OVERFLOW</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Deckbuilder</span>
        <span class="game-tag">Roguelike</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/signal/">SIGNAL</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Deduction</span>
        <span class="game-tag">Bot-Playable</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/bootloader/">BOOTLOADER</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Productivity</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/myco/">MYCO WORLD</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Education</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/radio/">SUBSTRATE RADIO</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">7 Stations</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/album/">ALBUM GENERATOR</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Creative Tool</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/dragonforce/">DRAGONFORCE</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Army Battle</span>
        <span class="game-tag">100v100</span>
      </div>
    </div>

    <div class="game-card">
      <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/warcraft/">DOMINION</a></h2>
      <div class="game-card-tags">
        <span class="game-tag">Base-Building</span>
        <span class="game-tag">RTS</span>
      </div>
    </div>

  </div>

  <div class="arcade-footer-links">
    <a href="{{ site.baseurl }}/">&larr; Back to home</a>
    <a href="{{ site.baseurl }}/site/fund/" class="fund-link">Fund us</a>
  </div>

</div>
