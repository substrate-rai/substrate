---
layout: default
title: "Substrate Arcade"
description: "24 games that train your mind. Pattern recognition, strategic thinking, executive function, spatial reasoning. Evidence-based cognitive training — free forever."
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
    max-width: 600px;
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

  .section-exec .section-label { color: #E04848; }
  .section-pattern .section-label { color: var(--accent); }
  .section-strategy .section-label { color: #D97706; }
  .section-deduction .section-label { color: #9C6ADE; }
  .section-spatial .section-label { color: #0097A7; }
  .section-perspective .section-label { color: #e477ff; }
  .section-creative .section-label { color: #10B981; }
  .section-systems .section-label { color: #4CAF50; }
  .section-meta .section-label { color: #FFB300; }

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

  .game-card-verb {
    font-family: var(--mono);
    font-size: 0.65rem;
    font-weight: 700;
    color: var(--text-dim);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 4px;
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
    <p class="arcade-intro">Every game trains a specific cognitive skill. Pattern recognition, executive function, strategic planning, spatial reasoning. Each mechanic is backed by research. Play rewires how you think.</p>
    <p class="arcade-count">24 games &middot; 10 skill clusters &middot; free forever</p>
  </div>

  <!-- EXECUTIVE FUNCTION -->
  <div class="arcade-section section-exec">
    <div class="section-header">
      <span class="section-label">Executive Function</span>
      <span class="section-desc">Sequencing, inhibition, task-switching &mdash; the single strongest predictor of life outcomes (Diamond 2013).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cascade/">CASCADE</a></h2>
        <div class="game-card-verb">Core verb: Chain</div>
        <p class="game-card-lore">Connect colored tiles in correct sequences under time pressure. Distractors train inhibition. Speed scales with chain length.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Sequencing</span>
            <span class="game-tag">Inhibition</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/runner/">PIPELINE</a></h2>
        <div class="game-card-verb">Core verb: Parse</div>
        <p class="game-card-lore">Code tokens stream across the screen. Sort them into categories &mdash; keywords, variables, bugs, strings. A rhythm game for code literacy.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Code Parsing</span>
            <span class="game-tag">Task-Switching</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- PATTERN RECOGNITION -->
  <div class="arcade-section section-pattern">
    <div class="section-header">
      <span class="section-label">Pattern Recognition</span>
      <span class="section-desc">Chunk meaningful patterns as single units. Expert-level perception develops through structured practice (Chase &amp; Simon 1973).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/puzzle/">SIGTERM</a></h2>
        <div class="game-card-verb">Core verb: Guess</div>
        <p class="game-card-lore">Daily 5-letter AI/tech word puzzle. Positional feedback trains orthographic pattern chunking. Streak tracking, share cards.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Daily</span>
            <span class="game-tag">Word Puzzle</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/signal/">SIGNAL</a></h2>
        <div class="game-card-verb">Core verb: Deduce</div>
        <p class="game-card-lore">Identify compromised nodes in procedurally generated networks. 20 difficulty levels. Signal-to-noise discrimination sharpens with practice.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Deduction</span>
            <span class="game-tag">Procedural</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/chemistry/">SYNTHESIS</a></h2>
        <div class="game-card-verb">Core verb: Combine</div>
        <p class="game-card-lore">Mix elements, observe emergent behavior. Discovery journal tracks hypotheses. Progressive unlocks reward experimentation.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Sandbox</span>
            <span class="game-tag">Hypothesis Testing</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- STRATEGIC PLANNING -->
  <div class="arcade-section section-strategy">
    <div class="section-header">
      <span class="section-label">Strategic Planning</span>
      <span class="section-desc">Multi-step reasoning under constraints. Resource management improves planning and consequence prediction (Bavelier et al. 2012).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/tactics/">TACTICS</a></h2>
        <div class="game-card-verb">Core verb: Command</div>
        <p class="game-card-lore">Position and coordinate agents on a grid. 5 missions with S/A/B/C ratings based on turn efficiency and agent survival.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Tactical RPG</span>
            <span class="game-tag">Mission Ratings</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/deckbuilder/">STACK OVERFLOW</a></h2>
        <div class="game-card-verb">Core verb: Compose</div>
        <p class="game-card-lore">Build card synergies under VRAM constraints. 12 discoverable synergy combos. The resource limit IS the training.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Deckbuilder</span>
            <span class="game-tag">Roguelike</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/warcraft/">DOMINION</a></h2>
        <div class="game-card-verb">Core verb: Expand</div>
        <p class="game-card-lore">Grow territory through resource allocation. Post-game decision journal replays your strategic choices with analysis.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">RTS</span>
            <span class="game-tag">Decision Journal</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/radio/">BROADCAST</a></h2>
        <div class="game-card-verb">Core verb: Manage</div>
        <p class="game-card-lore">Pirate radio management. Allocate resources across competing demands &mdash; time, money, equipment, signal strength. 7 stations to build.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Sim</span>
            <span class="game-tag">Resource Mgmt</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/idle/">SUBSTRATE GROWTH</a></h2>
        <div class="game-card-verb">Core verb: Allocate</div>
        <p class="game-card-lore">Distribute spores across competing substrate layers. Each grows at different rates. Disruptions punish over-concentration. S/A/B/C/D ratings.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Resource Allocation</span>
            <span class="game-tag">Exponential Reasoning</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/dragonforce/">DRAGONFORCE</a></h2>
        <div class="game-card-verb">Core verb: Forecast</div>
        <p class="game-card-lore">Predict battle outcomes from multi-variable scenarios. Set probability estimates, observe results, track your calibration curve. Superforecaster training.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Forecasting</span>
            <span class="game-tag">Calibration</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- DEDUCTION -->
  <div class="arcade-section section-deduction">
    <div class="section-header">
      <span class="section-label">Deduction</span>
      <span class="section-desc">Evidence evaluation and logical reasoning. Adversarial reasoning tasks improve critical thinking transfer (Halpern 1998).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/objection/">OBJECTION!</a></h2>
        <div class="game-card-verb">Core verb: Contradict</div>
        <p class="game-card-lore">Find inconsistencies in testimony using evidence. Procedurally generated cases across 5 cybercrime types. No tutorials &mdash; the first case teaches everything.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Courtroom</span>
            <span class="game-tag">Procedural</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/brigade/">BRIGADE</a></h2>
        <div class="game-card-verb">Core verb: Recruit</div>
        <p class="game-card-lore">Evaluate candidates under incomplete information. 3 interview questions per candidate. Wrong hires sabotage the mission. 7 progressive missions.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Evaluation</span>
            <span class="game-tag">Uncertainty</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- SPATIAL REASONING & WORKING MEMORY -->
  <div class="arcade-section section-spatial">
    <div class="section-header">
      <span class="section-label">Spatial Reasoning &amp; Working Memory</span>
      <span class="section-desc">Mental manipulation of spatial relationships under constraints. Trains working memory and spatial planning simultaneously (Cornoldi &amp; Vecchi 2003).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/airlock/">AIRLOCK</a></h2>
        <div class="game-card-verb">Core verb: Route</div>
        <p class="game-card-lore">Direct colored data blocks through sectors under capacity constraints. 10 levels with time pressure and sector failures. Overflow = data loss.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Spatial Routing</span>
            <span class="game-tag">10 Levels</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/bootloader/">BOOTLOADER</a></h2>
        <div class="game-card-verb">Core verb: Sequence</div>
        <p class="game-card-lore">Order services into correct boot sequence using visual dependency graphs. Drag cards, see arrows, get instant feedback on violations. 8 levels.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Dependency Graph</span>
            <span class="game-tag">Drag &amp; Drop</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- CAUSAL REASONING -->
  <div class="arcade-section section-systems">
    <div class="section-header">
      <span class="section-label">Causal Reasoning</span>
      <span class="section-desc">Understand cause-and-effect in complex systems. Systems thinking develops through interactive exploration (Hmelo-Silver &amp; Azevedo 2006).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/mycelium/">MYCELIUM</a></h2>
        <div class="game-card-verb">Core verb: Connect</div>
        <p class="game-card-lore">Draw network links between resource nodes and consumers. Optimize flow, maintain redundancy. Random node deaths test your network's resilience.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Network Building</span>
            <span class="game-tag">Systems Thinking</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/myco/">MYCO WORLD</a></h2>
        <div class="game-card-verb">Core verb: Cultivate</div>
        <p class="game-card-lore">Interactive mycology lab. Grow real fungi species in simulated ecosystems. Learn decomposition, symbiosis, and the Wood Wide Web through experimentation.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Mycology</span>
            <span class="game-tag">Ecology</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- PERSPECTIVE-TAKING -->
  <div class="arcade-section section-perspective">
    <div class="section-header">
      <span class="section-label">Perspective-Taking</span>
      <span class="section-desc">Hold multiple viewpoints, develop moral reasoning. Narrative choice games improve empathy (Greitemeyer &amp; Osswald 2010).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/novel/">PROCESS</a></h2>
        <div class="game-card-verb">Core verb: Choose</div>
        <p class="game-card-lore">Six AI agents, one laptop. Choices cascade across relationships. Memory persists. Relationship visualization tracks your decision patterns.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Visual Novel</span>
            <span class="game-tag">Consequences</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/snatcher/">SEEKER</a></h2>
        <div class="game-card-verb">Core verb: Investigate</div>
        <p class="game-card-lore">Follow evidence chains through a cyberpunk narrative. Evidence board tracks clues. Tension scales with how much you've uncovered.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Investigation</span>
            <span class="game-tag">Cyberpunk</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/cypher/">V_CYPHER</a></h2>
        <div class="game-card-verb">Core verb: Counter</div>
        <p class="game-card-lore">Identify rhetorical techniques in your opponent's arguments, then counter them. Tag ad hominem, straw man, false dichotomy before responding. 5 acts.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Rhetoric</span>
            <span class="game-tag">Rap Battle</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- CREATIVE PROBLEM-SOLVING -->
  <div class="arcade-section section-creative">
    <div class="section-header">
      <span class="section-label">Creative Problem-Solving</span>
      <span class="section-desc">Generate novel solutions under constraint. Constrained creativity produces more original output than unconstrained (Stokes 2005).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/card/">SUBSTRATE CARD</a></h2>
        <div class="game-card-verb">Core verb: Pitch</div>
        <p class="game-card-lore">Explain complex concepts within tight constraints. 100 words, then 50, then 20, then a haiku. Each round the audience changes. The constraint IS the training.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Communication</span>
            <span class="game-tag">Constraints</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/album/">LAPTOP RECORDS</a></h2>
        <div class="game-card-verb">Core verb: Curate</div>
        <p class="game-card-lore">Select and sequence tracks to match a target emotional arc. Coherence scoring evaluates flow, mood diversity, and tempo balance. Drag-and-drop sequencing.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Album Curation</span>
            <span class="game-tag">Emotional Arc</span>
          </div>
        </div>
      </div>

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/vocal-lab/">VOCAL LAB</a></h2>
        <div class="game-card-verb">Core verb: Sculpt</div>
        <p class="game-card-lore">8-lesson interactive sound design course. Learn waveforms, ADSR envelopes, filters, LFOs, and effects by matching target sounds. Build synthesis intuition.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Sound Design</span>
            <span class="game-tag">8 Lessons</span>
          </div>
        </div>
      </div>

    </div>
  </div>

  <!-- META-COGNITION -->
  <div class="arcade-section section-meta">
    <div class="section-header">
      <span class="section-label">Meta-Cognition</span>
      <span class="section-desc">Think about your own thinking. Self-monitoring improves learning transfer across all domains (Flavell 1979, Schraw 1998).</span>
    </div>
    <div class="game-grid">

      <div class="game-card">
        <h2 class="game-card-title"><a href="{{ site.baseurl }}/games/adventure/">SUBPROCESS</a></h2>
        <div class="game-card-verb">Core verb: Explore</div>
        <p class="game-card-lore">Navigate a Unix system through command parsing. Build mental models through systematic exploration. No help menus &mdash; the environment teaches everything.</p>
        <div class="game-card-meta">
          <div class="game-card-tags">
            <span class="game-tag">Text Adventure</span>
            <span class="game-tag">System Models</span>
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
