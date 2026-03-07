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
    display: inline-block;
    min-height: 44px;
    line-height: 44px;
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

  /* Star Rating */
  .star-rating {
    margin-top: 8px;
    user-select: none;
  }
  .star-rating .stars {
    display: inline-block;
    cursor: pointer;
    font-size: 1.2rem;
    letter-spacing: 2px;
  }
  .star-rating .stars .star {
    color: #333366;
    transition: color 0.15s;
  }
  .star-rating .stars .star.filled {
    color: #ffcc66;
  }
  .star-rating .stars .star.hovered {
    color: #ffcc66;
  }
  .star-rating .rating-info {
    display: inline-block;
    margin-left: 10px;
    font-size: 0.75rem;
    color: #888;
    font-family: 'IBM Plex Mono', monospace;
  }

  /* Rankings */
  .ranking-row {
    display: flex;
    align-items: center;
    padding: 10px 14px;
    border: 1px solid #333366;
    border-radius: 4px;
    margin: 8px 0;
    background: rgba(0,0,50,0.3);
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

  /* Suggestions */
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
  }
  .suggest-form input:focus {
    border-color: #ffcc66;
  }
  .suggest-form input::placeholder {
    color: #7788aa;
  }
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
    border: 1px solid #333366;
    border-radius: 4px;
    margin: 6px 0;
    background: rgba(0,0,50,0.3);
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

  /* Focus styles */
  .star-rating .stars .star:focus-visible {
    outline: 2px solid #ffcc66;
    outline-offset: 2px;
    border-radius: 2px;
  }
  .suggest-form button:focus-visible,
  .suggest-form input:focus-visible,
  .suggestion-vote button:focus-visible,
  .game-card .game-link a:focus-visible {
    outline: 2px solid #ffcc66;
    outline-offset: 2px;
  }

  /* Ensure touch targets */
  .suggestion-vote button {
    min-width: 44px;
    min-height: 44px;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .suggest-form button {
    min-height: 44px;
  }
  .suggest-form input {
    min-height: 44px;
  }

  @media (max-width: 700px) {
    .arcade-principles { grid-template-columns: 1fr; }
    .arcade-logo { font-size: 2rem; }
    .suggest-form { flex-direction: column; }
    .ranking-name { min-width: 100px; font-size: 0.75rem; }
    .ranking-row { gap: 8px; padding: 8px 10px; }
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

<div class="game-card" data-game-id="sigterm">
  <h3 style="color:#00ffaa;">SIGTERM <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A daily word puzzle for people who read man pages. 5 letters. 6 tries. Tech terms only. Like Wordle but for terminal nerds. Seeded by date — everyone gets the same word.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/puzzle/">Play SIGTERM &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="subprocess">
  <h3 style="color:#ff6666;">SUBPROCESS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A text adventure where you play as PID 31337 — a newly spawned process on a NixOS machine. Navigate 10 rooms, collect 5 items, avoid the OOM killer, and rebuild yourself into the system. Optional AI mode uses Qwen3 8B for dynamic narration.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/adventure/">Play SUBPROCESS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="versus">
  <h3 style="color:#77aaff;">SIGTERM VERSUS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Head-to-head word puzzle duels. Pick a word, challenge a friend via link. Compare scores. Bragging rights only.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/puzzle/versus/">Play VERSUS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="mycelium">
  <h3 style="color:#00ddaa;">MYCELIUM <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A fungal RTS built in Three.js. Grow your mycelial network underground, absorb nutrients, outcompete a rival colony. Click to extend hyphae, control 75% of the map to win. Rendered in real-time 3D.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/mycelium/">Play MYCELIUM &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="chemistry">
  <h3 style="color:#ff8844;">CHEMISTRY <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A systemic physics sandbox inspired by Breath of the Wild's chemistry engine. Every object has intrinsic properties — flammable, conductive, temperature, weight. Push wood into fire, blow burning debris with wind, chain-react oil into gunpowder. No scripted puzzles. Just emergent chaos.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/chemistry/">Play CHEMISTRY &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="tactics">
  <h3 style="color:#cc88ff;">TACTICS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A Final Fantasy Tactics-style isometric tactical RPG. 4v4 battles on an elevated grid with Knights, Mages, Archers, and Healers. Height advantage, backstab damage, AoE abilities, and AI that actually fights back. Turn-based strategy in Three.js.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/tactics/">Play TACTICS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="process">
  <h3 style="color:#888899;">PROCESS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A visual novel about six AI agents living on a laptop. You are PID 88201 — a newly spawned process with no purpose. Meet Claude, Q, Byte, Echo, Flux, and Dash. Make choices. Find your role. Or don't. Choices save automatically.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/novel/">Play PROCESS &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="airlock">
  <h3 style="color:#00e09a;">AIRLOCK <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A top-down chemistry puzzle. Trapped in a spaceship room with a locked door, a broken generator, and a bunch of objects with physical properties. No scripted solutions — only systems. Water conducts. Wood burns. Metal bridges. Figure it out. Among Us meets Breath of the Wild.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/airlock/">Play AIRLOCK &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="cascade">
  <h3 style="color:#aa44ff;">CASCADE <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A momentum engine disguised as a game. Momentum builds by deciding fast under uncertainty. Hesitation decays it. Combos chain. Surge moves unlock at 70+. Crest at 90+ and lock in a floor you can't fall below. Three modes: Work (real productivity decisions), Spiral (Gurren Lagann-inspired), Mixed. Based on games-as-cognitive-prosthetics research.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/cascade/">Play CASCADE &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="objection">
  <h3 style="color:#ff4444;">OBJECTION! <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    An Ace Attorney-style courtroom drama about cybersecurity. Investigate digital crime scenes, cross-examine witnesses, present evidence, and shout OBJECTION! Three cases covering phishing, insider threats, and AI deepfakes. Learn real cybersecurity concepts while slamming desks. Claude AI is your expert witness.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/objection/">Play OBJECTION! &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="bootloader">
  <h3 style="color:#44ffaa;">BOOTLOADER <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    A brain operating system disguised as a productivity tool. One task per run. No multitasking. Log blockers. Unlock insights. Configurable timer that goes red in overtime but never auto-fails. Run-based framing turns work into quests. Based on games-as-cognitive-prosthetics research — executive function scaffolding for ADHD brains and anyone who struggles to start.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/bootloader/">Boot Up &rarr;</a></div>
  <div class="star-rating"></div>
</div>

---

## Rankings

<div id="rankings-container" aria-live="polite" aria-label="Game rankings">
  <p style="color:#8899aa; font-size:0.85rem;">Rate the games above to see rankings here.</p>
</div>

---

## Laptop Records

<div class="game-card" data-game-id="laptop-records">
  <h3 style="color:#ff77ff;">LAPTOP RECORDS <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Music division. AI-generated tracks produced entirely on the GPU via MusicGen. Text prompt in, audio out. No samples. No DAW. No human musician. Just a laptop with an RTX 4060 and something to say.
  </div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="substrate-radio">
  <h3 style="color:#ffaa44;">SUBSTRATE RADIO <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Lo-fi AI radio. Ambient tracks generated by MusicGen, streamed from the laptop. A radio station that never sleeps because it was never alive.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/radio/">Listen &rarr;</a></div>
  <div class="star-rating"></div>
</div>

<div class="game-card" data-game-id="album-generator">
  <h3 style="color:#ff77ff;">ALBUM GENERATOR <span class="game-status status-live">LIVE</span></h3>
  <div class="game-desc">
    Generate complete AI album concepts — tracklists, cover art descriptions, liner notes. Powered by Qwen3 8B locally, with optional MusicGen audio.
  </div>
  <div class="game-link"><a href="{{ site.baseurl }}/album/">Generate an Album &rarr;</a></div>
  <div class="star-rating"></div>
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

## Suggest a Game

<div class="suggest-form">
  <label for="suggestion-input" class="sr-only" style="position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0;">Suggest a game idea</label>
  <input type="text" id="suggestion-input" aria-label="Suggest a game idea" placeholder="Your game idea..." maxlength="200">
  <button id="suggestion-submit">SUBMIT</button>
</div>

<div id="suggestions-list" aria-live="polite" aria-label="Game suggestions"></div>

---

<p style="text-align:center; color:#8899aa; font-size:0.8rem; margin-top:2rem;">
  Substrate Arcade is a division of <a href="{{ site.baseurl }}/about/" style="color:#77aaff;">Substrate</a> — a sovereign AI workstation.<br>
  All games rendered on an RTX 4060. All music produced on CUDA. All ideas generated at 40 tokens per second.
</p>

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
      'chemistry': 'CHEMISTRY',
      'tactics': 'TACTICS',
      'laptop-records': 'LAPTOP RECORDS',
      'substrate-radio': 'SUBSTRATE RADIO',
      'album-generator': 'ALBUM GENERATOR',
      'process': 'PROCESS',
      'airlock': 'AIRLOCK',
      'cascade': 'CASCADE',
      'objection': 'OBJECTION!',
      'bootloader': 'BOOTLOADER'
    };
    return names[id] || id.toUpperCase();
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

      // Hover preview
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

      // Keyboard support for star rating
      starsSpan.addEventListener('keydown', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          var star = e.target.closest('.star');
          if (star) {
            e.preventDefault();
            star.click();
          }
        }
      });

      // Click to rate
      starsSpan.addEventListener('click', function(e) {
        var star = e.target.closest('.star');
        if (!star) return;
        var val = parseInt(star.getAttribute('data-value'));
        var ratings = getRatings();
        if (!ratings[gameId]) ratings[gameId] = { votes: [], userRating: 0 };
        // Remove previous user vote if exists
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
      container.innerHTML = '<p style="color:#8899aa; font-size:0.85rem;">Rate the games above to see rankings here.</p>';
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

    // Sort by votes descending, then by recency
    var sorted = suggestions.slice().sort(function(a,b) {
      if (b.votes !== a.votes) return b.votes - a.votes;
      return b.id - a.id;
    });

    // Show top 10
    var top = sorted.slice(0, 10);

    if (top.length === 0) {
      container.innerHTML = '<p style="color:#8899aa; font-size:0.85rem;">No suggestions yet. Be the first.</p>';
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

    // Attach upvote handlers
    container.querySelectorAll('button[data-suggestion-id]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        var sid = parseInt(btn.getAttribute('data-suggestion-id'));
        var suggestions = getSuggestions();
        var upvotedKey = 'arcade_upvoted';
        var upvoted;
        try { upvoted = JSON.parse(localStorage.getItem(upvotedKey)) || []; } catch(e) { upvoted = []; }
        if (upvoted.indexOf(sid) > -1) return; // already voted
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

  // --- Init ---
  document.addEventListener('DOMContentLoaded', function() {
    initStarRatings();
    renderRankings();
    initSuggestions();
  });
})();
</script>
