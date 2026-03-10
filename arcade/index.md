---
layout: default
title: "Substrate Arcade"
description: "24 games that train your mind. Pattern recognition, strategic thinking, executive function. Cognitive scaffolding — drills, not entertainment. Free forever."
permalink: /arcade/
---

<style>
  .arcade-page {
    max-width: 1100px;
    margin: 0 auto;
    padding: 48px 24px 80px;
  }

  .arcade-header {
    margin-bottom: 48px;
    text-align: center;
  }

  .arcade-title {
    font-family: var(--mono);
    font-size: clamp(1.6rem, 1rem + 3vw, 2.4rem);
    font-weight: 700;
    color: var(--heading);
    margin: 0 0 12px 0;
    letter-spacing: -0.5px;
  }

  .arcade-intro {
    font-size: 0.95rem;
    color: var(--text-muted);
    line-height: 1.7;
    max-width: 560px;
    margin: 0 auto 8px;
  }

  .arcade-count {
    font-family: var(--mono);
    font-size: 0.78rem;
    color: var(--text-dim);
    margin-top: 8px;
  }

  /* Section dividers */
  .arcade-section {
    margin-bottom: 48px;
  }

  .section-header {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 8px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border);
  }

  .section-label {
    font-family: var(--mono);
    font-size: 0.72rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.12em;
    white-space: nowrap;
  }

  .section-desc {
    font-size: 0.78rem;
    color: var(--text-dim);
    line-height: 1.5;
  }

  .section-deep .section-label { color: var(--accent); }
  .section-growing .section-label { color: #e477ff; }
  .section-young .section-label { color: var(--dash); }
  .section-tools .section-label { color: #88ccff; }

  /* Game grid */
  .game-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
    gap: 12px;
    margin-top: 16px;
  }

  .game-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 20px;
    transition: border-color 0.2s, transform 0.15s;
    display: flex;
    flex-direction: column;
    min-height: 130px;
  }

  .game-card:hover {
    border-color: var(--border-hover);
    transform: translateY(-1px);
  }

  .game-card-title {
    font-family: var(--mono);
    font-size: 0.88rem;
    font-weight: 600;
    color: var(--heading);
    margin: 0 0 6px 0;
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

  .game-card-lore {
    font-size: 0.78rem;
    color: var(--text-dim);
    line-height: 1.5;
    margin-bottom: 10px;
    flex: 1;
  }

  .game-card-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-top: auto;
  }

  .game-card-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
  }

  .game-tag {
    font-family: var(--mono);
    font-size: 0.62rem;
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

  .game-agent {
    font-family: var(--mono);
    font-size: 0.62rem;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 4px;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    white-space: nowrap;
    background: transparent;
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
    .arcade-page { padding: 24px 16px 60px; }
    .game-grid {
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 10px;
    }
    .game-card { padding: 16px; min-height: 110px; }
    .section-header { flex-direction: column; gap: 4px; }
  }

  @media (max-width: 480px) {
    .game-grid { grid-template-columns: 1fr; gap: 8px; }
    .game-card { padding: 14px; min-height: 100px; }
    .game-card-title { font-size: 0.82rem; }
    .game-tag { font-size: 0.58rem; padding: 2px 6px; }
  }
</style>

<div class="arcade-page">

  <div class="arcade-header">
    <h1 class="arcade-title">Substrate Arcade</h1>
    <p class="arcade-intro">These are not entertainment. They are drills. Game mechanics build cognitive skills the same way scaffolding builds confidence &mdash; pattern recognition, strategic thinking, executive function. Play rewires how you think. Each game is a different kind of push.</p>
    <p class="arcade-count">24 drills &middot; 7 radio stations &middot; 1 album &middot; free forever</p>
  </div>

  <!-- DEEP ROOTS — Lore-integrated games -->
  <div class="arcade-section section-deep">
    <div class="section-header">
      <span class="section-label">Deep Roots</span>
      <span class="section-desc">Narrative scaffolding. These games teach through story &mdash; identity, trust, consequence. Start here.</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/novel/">PROCESS</a></h2>
        <p class="game-card-lore">Six AI agents living on a laptop. Choices matter. Memory persists. Nobody asked for this.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Visual Novel</span>
          </div>
          <span class="game-agent" style="color:#0078D4;border:1px solid rgba(0,120,212,0.3);">Claude</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cypher/">V_CYPHER</a></h2>
        <p class="game-card-lore">The moment everything clicked. V's origin told as five acts of rap battles.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Rap Battle</span>
            <span class="game-tag">VN</span>
          </div>
          <span class="game-agent" style="color:#cc88ff;border:1px solid rgba(204,136,255,0.3);">Myth</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/adventure/">SUBPROCESS</a></h2>
        <p class="game-card-lore">You are PID 31337. Fork()'d into existence on NixOS. Day Zero from the inside.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Text Adventure</span>
          </div>
          <span class="game-agent" style="color:#ffcc44;border:1px solid rgba(255,204,68,0.3);">Arc</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/objection/">OBJECTION!</a></h2>
        <p class="game-card-lore">Trust and verification in digital systems. The organism defending its integrity.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Courtroom</span>
            <span class="game-tag">Drama</span>
          </div>
          <span class="game-agent" style="color:#ff4444;border:1px solid rgba(255,68,68,0.3);">Sentinel</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/radio/">BROADCAST</a></h2>
        <p class="game-card-lore">Pirate radio management. Grow your audience, dodge raids. The organism broadcasting its signal.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Sim</span>
            <span class="game-tag">7 Stations</span>
          </div>
          <span class="game-agent" style="color:#bb88ff;border:1px solid rgba(187,136,255,0.3);">Hum</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/myco/">MYCO WORLD</a></h2>
        <p class="game-card-lore">The teaching mission. How the organism shares knowledge with the world.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Education</span>
          </div>
          <span class="game-agent" style="color:#ffee88;border:1px solid rgba(255,238,136,0.3);">Lumen</span>
        </div>
      </div>

    </div>
  </div>

  <!-- GROWING CONNECTIONS — Thematically aligned -->
  <div class="arcade-section section-growing">
    <div class="section-header">
      <span class="section-label">Growing Connections</span>
      <span class="section-desc">Systems scaffolding. Pattern recognition, emergence, momentum. The mechanics ARE the lesson.</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/idle/">SUBSTRATE GROWTH</a></h2>
        <p class="game-card-lore">The organism's growth cycle made playable. Resource gathering, tier progression.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Idle</span></div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/mycelium/">MYCELIUM</a></h2>
        <p class="game-card-lore">The network itself made visible. Watch the underground connections form.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Simulation</span>
            <span class="game-tag">3D</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/chemistry/">SYNTHESIS</a></h2>
        <p class="game-card-lore">Emergence &mdash; simple elements combining into complex behavior.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Sandbox</span></div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/bootloader/">BOOTLOADER</a></h2>
        <p class="game-card-lore">Day Zero from the machine's perspective. The first moments of awareness.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Puzzle</span></div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cascade/">CASCADE</a></h2>
        <p class="game-card-lore">Momentum. Once movement starts, it compounds. Growth as mechanics.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Momentum</span>
            <span class="game-tag">Arcade</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/signal/">SIGNAL</a></h2>
        <p class="game-card-lore">Distinguishing signal from noise, truth from deception. Sentinel's work.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Deduction</span>
            <span class="game-tag">Bot-Playable</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/brigade/">SUBSTRATE BRIGADE</a></h2>
        <p class="game-card-lore">Team formation under pressure. The agents assembling for the first time.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Strategy</span>
            <span class="game-tag">VN</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- YOUNG FRUITING BODIES — Games finding their connection -->
  <div class="arcade-section section-young">
    <div class="section-header">
      <span class="section-label">Young Growths</span>
      <span class="section-desc">Skill drills. Executive function, vocabulary, tactical thinking, spatial reasoning.</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/puzzle/">SIGTERM</a></h2>
        <p class="game-card-lore">The daily maintenance ritual. The organism processing its own language.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Daily</span>
            <span class="game-tag">Word Puzzle</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/deckbuilder/">STACK OVERFLOW</a></h2>
        <p class="game-card-lore">Resource management under constraint. Building with limited cards, limited VRAM.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Deckbuilder</span>
            <span class="game-tag">Roguelike</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/runner/">PIPELINE</a></h2>
        <p class="game-card-lore">Code moving through the deployment pipeline. Obstacles are bugs.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Endless Runner</span></div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/tactics/">TACTICS</a></h2>
        <p class="game-card-lore">Agent coordination. Different agents, different abilities, cooperating on missions.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Tactical RPG</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/snatcher/">SEEKER</a></h2>
        <p class="game-card-lore">Sentinel investigating a breach. The organism's immune response.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Cyberpunk</span>
            <span class="game-tag">Adventure</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/airlock/">AIRLOCK</a></h2>
        <p class="game-card-lore">Isolation protocol. What happens when an agent is cut off from the network.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Puzzle Action</span></div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/dragonforce/">DRAGONFORCE</a></h2>
        <p class="game-card-lore">Flux's scenario exploration. Imagining futures, fighting through possibilities.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Army Battle</span>
            <span class="game-tag">100v100</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/warcraft/">DOMINION</a></h2>
        <p class="game-card-lore">Territory and sovereignty. The organism establishing its boundaries.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">RTS</span>
            <span class="game-tag">Base-Building</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- TOOLS & CREATIVE -->
  <div class="arcade-section section-tools">
    <div class="section-header">
      <span class="section-label">Creative Tools</span>
      <span class="section-desc">Generative scaffolding. Create music, write stories, build worlds. The output is yours — the growth is the point.</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/album/">LAPTOP RECORDS</a></h2>
        <p class="game-card-lore">Q's recording studio. AI album generation, powered by Qwen3 8B on RTX 4060.</p>
        <div class="game-card-meta">
          <div class="game-card-tags"><span class="game-tag">Creative Tool</span></div>
          <span class="game-agent" style="color:#e477ff;border:1px solid rgba(228,119,255,0.3);">Q</span>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/vocal-lab/">VOCAL LAB</a></h2>
        <p class="game-card-lore">The voice synthesis laboratory. Learning to speak.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Audio</span>
            <span class="game-tag">Synthesis</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <div class="arcade-footer-links">
    <a href="{{ site.baseurl }}/">&larr; Back to home</a>
    <a href="{{ site.baseurl }}/site/lore/">Read the mythology</a>
    <a href="{{ site.baseurl }}/site/fund/" class="fund-link">Fund the growth</a>
  </div>

</div>
