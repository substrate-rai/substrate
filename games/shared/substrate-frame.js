/* Substrate Arcade — Shared Game Frame
   Auto-injects the Substrate top bar and music system into any game page.

   Usage: <script src="../shared/substrate-frame.js"></script>

   Configuration via data attributes on the script tag:
     data-title="GAME TITLE"
     data-lore="Short lore tagline"
     data-agent="AgentName"
     data-agent-color="#00e09a"
     data-song="songName"       (optional: override auto-detected song)
     data-no-audio="true"       (optional: skip audio entirely)
*/
(function() {
  var script = document.currentScript;
  var title = script.getAttribute('data-title') || document.title;
  var lore = script.getAttribute('data-lore') || '';
  var agent = script.getAttribute('data-agent') || '';
  var agentColor = script.getAttribute('data-agent-color') || '#0078D4';
  var noAudio = script.getAttribute('data-no-audio') === 'true';
  var songOverride = script.getAttribute('data-song') || '';

  // Resolve base path for shared scripts
  var src = script.src || '';
  var basePath = src.replace(/substrate-frame\.js.*$/, '');

  var bar = document.createElement('div');
  bar.className = 'substrate-bar';
  bar.innerHTML =
    '<div class="substrate-bar-left">' +
      '<a href="/arcade/" class="substrate-bar-logo">substrate</a>' +
      '<span class="substrate-bar-sep">/</span>' +
      '<span class="substrate-bar-title">' + title + '</span>' +
      (lore ? '<span class="substrate-bar-sep">&mdash;</span><span class="substrate-bar-lore">' + lore + '</span>' : '') +
    '</div>' +
    '<div class="substrate-bar-right">' +
      (!noAudio ? '<button class="substrate-bar-music" id="substrate-music-toggle" aria-label="Toggle music" title="Toggle music">&#9835;</button>' : '') +
      (agent ? '<span class="substrate-bar-agent" style="color:' + agentColor + '">' + agent + '</span>' : '') +
      '<a href="/arcade/">&larr; arcade</a>' +
    '</div>';

  // Inject bar
  document.body.insertBefore(bar, document.body.firstChild);

  // Add padding to body so game content isn't hidden behind bar
  document.body.style.paddingTop = (parseInt(getComputedStyle(document.body).paddingTop) || 0) + 36 + 'px';

  // ── Audio System ──────────────────────────────────────────────────────
  if (noAudio) return;

  // Determine song name: explicit override > game directory > agent leitmotif
  var songName = songOverride;
  if (!songName) {
    var pathMatch = window.location.pathname.match(/\/games\/([^\/]+)/);
    if (pathMatch) songName = pathMatch[1];
  }
  var agentSong = agent ? 'agent-' + agent.toLowerCase() : '';

  // Load snes-audio.js, then leitmotifs.js, then initialize
  function loadScript(url, cb) {
    var s = document.createElement('script');
    s.src = url;
    s.onload = cb;
    s.onerror = function() { if (cb) cb(); };
    document.head.appendChild(s);
  }

  loadScript(basePath + 'snes-audio.js', function() {
    loadScript(basePath + 'leitmotifs.js', function() {
      initAudio();
    });
  });

  function initAudio() {
    if (typeof SNESAudio === 'undefined') return;

    var music = new SNESAudio();
    var loaded = false;

    // Try game-specific song first, then agent leitmotif
    if (songName && music.loadSong(songName)) {
      loaded = true;
    } else if (agentSong && music.loadSong(agentSong)) {
      loaded = true;
    }

    if (!loaded) return;

    // Expose for games that need programmatic access
    window._substrateAudio = music;

    var btn = document.getElementById('substrate-music-toggle');
    if (!btn) return;

    var playing = false;

    // Check saved mute preference
    var wasMuted = false;
    try { wasMuted = localStorage.getItem('snes-audio-muted') === 'true'; } catch(e) {}

    btn.addEventListener('click', function() {
      if (!playing) {
        // First click: start playback (satisfies browser autoplay policy)
        music.setVolume(0.6);
        music.play();
        playing = true;
        if (wasMuted) {
          music.toggleMute();
          btn.classList.add('muted');
          btn.innerHTML = '&#9835;';
        } else {
          btn.classList.add('active');
          btn.innerHTML = '&#9835;';
        }
      } else {
        // Toggle mute
        music.toggleMute();
        if (music.isMuted()) {
          btn.classList.remove('active');
          btn.classList.add('muted');
        } else {
          btn.classList.remove('muted');
          btn.classList.add('active');
        }
      }
    });

    // Auto-start if user previously had music on
    if (!wasMuted) {
      // Wait for first user interaction (browser autoplay policy)
      var autoStart = function() {
        if (playing) return;
        music.setVolume(0.6);
        music.play();
        playing = true;
        btn.classList.add('active');
        document.removeEventListener('click', autoStart);
        document.removeEventListener('keydown', autoStart);
      };
      document.addEventListener('click', autoStart);
      document.addEventListener('keydown', autoStart);
    }
  }
})();
