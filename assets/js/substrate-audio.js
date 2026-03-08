/**
 * substrate-audio.js — Procedural sound engine for the Substrate arcade.
 *
 * Zero audio files. All sounds generated via Web Audio API.
 * Include this in any game: <script src="/substrate/assets/js/substrate-audio.js"></script>
 * Then call: SubstrateAudio.click(), SubstrateAudio.success(), etc.
 *
 * Respects user preference: sounds off by default, toggle with SubstrateAudio.toggle()
 * Persists preference in localStorage.
 */
const SubstrateAudio = (function() {
  'use strict';

  let ctx = null;
  let enabled = false;
  const STORAGE_KEY = 'substrate-audio-enabled';

  function getCtx() {
    if (!ctx) {
      try {
        ctx = new (window.AudioContext || window.webkitAudioContext)();
      } catch(e) {
        return null;
      }
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  function load() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      enabled = stored === 'true';
    } catch(e) {
      enabled = false;
    }
  }

  function save() {
    try { localStorage.setItem(STORAGE_KEY, enabled ? 'true' : 'false'); } catch(e) {}
  }

  // ── Core oscillator helper ──────────────────────────────────────────────

  function tone(freq, duration, type, volume, delay) {
    const c = getCtx();
    if (!c || !enabled) return;
    const t = c.currentTime + (delay || 0);
    const osc = c.createOscillator();
    const gain = c.createGain();
    osc.type = type || 'sine';
    osc.frequency.setValueAtTime(freq, t);
    gain.gain.setValueAtTime(volume || 0.15, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + duration);
    osc.connect(gain);
    gain.connect(c.destination);
    osc.start(t);
    osc.stop(t + duration);
  }

  function noise(duration, volume, delay) {
    const c = getCtx();
    if (!c || !enabled) return;
    const t = c.currentTime + (delay || 0);
    const bufferSize = c.sampleRate * duration;
    const buffer = c.createBuffer(1, bufferSize, c.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * (volume || 0.05);
    }
    const source = c.createBufferSource();
    source.buffer = buffer;
    const gain = c.createGain();
    gain.gain.setValueAtTime(volume || 0.05, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + duration);
    source.connect(gain);
    gain.connect(c.destination);
    source.start(t);
  }

  // ── Sound effects ───────────────────────────────────────────────────────

  const sounds = {
    // UI: light terminal click
    click: function() {
      tone(800, 0.06, 'square', 0.08);
    },

    // UI: hover / select
    hover: function() {
      tone(600, 0.04, 'sine', 0.05);
    },

    // Positive: success chime (ascending)
    success: function() {
      tone(523, 0.12, 'sine', 0.12);
      tone(659, 0.12, 'sine', 0.12, 0.1);
      tone(784, 0.2, 'sine', 0.15, 0.2);
    },

    // Negative: error buzz
    error: function() {
      tone(200, 0.15, 'sawtooth', 0.1);
      tone(150, 0.2, 'sawtooth', 0.08, 0.1);
    },

    // Warning: alert beep
    warning: function() {
      tone(440, 0.1, 'square', 0.1);
      tone(440, 0.1, 'square', 0.1, 0.15);
    },

    // Game: collect item / pickup
    pickup: function() {
      tone(880, 0.08, 'sine', 0.1);
      tone(1100, 0.08, 'sine', 0.1, 0.06);
      tone(1320, 0.15, 'sine', 0.12, 0.12);
    },

    // Game: move / step
    move: function() {
      noise(0.05, 0.03);
      tone(300, 0.04, 'sine', 0.05);
    },

    // Game: attack / hit
    hit: function() {
      noise(0.1, 0.08);
      tone(150, 0.12, 'sawtooth', 0.1);
    },

    // Game: defeat / death
    defeat: function() {
      tone(440, 0.2, 'sawtooth', 0.12);
      tone(350, 0.2, 'sawtooth', 0.1, 0.15);
      tone(260, 0.3, 'sawtooth', 0.08, 0.3);
      tone(180, 0.5, 'sawtooth', 0.06, 0.5);
    },

    // Game: victory fanfare
    victory: function() {
      tone(523, 0.15, 'sine', 0.12);
      tone(659, 0.15, 'sine', 0.12, 0.12);
      tone(784, 0.15, 'sine', 0.14, 0.24);
      tone(1047, 0.4, 'sine', 0.16, 0.36);
    },

    // Game: countdown tick
    tick: function() {
      tone(1000, 0.03, 'square', 0.06);
    },

    // Game: type / keystroke
    type: function() {
      tone(600 + Math.random() * 400, 0.03, 'square', 0.04);
    },

    // Ambient: terminal boot
    boot: function() {
      for (let i = 0; i < 6; i++) {
        tone(200 + i * 100, 0.08, 'sine', 0.04, i * 0.08);
      }
      noise(0.3, 0.02, 0.5);
    },

    // Game: spiral energy (V's signature)
    spiral: function() {
      for (let i = 0; i < 8; i++) {
        const freq = 300 + i * 80 + Math.sin(i) * 40;
        tone(freq, 0.12, 'sine', 0.06 + i * 0.01, i * 0.07);
      }
    },

    // Game: mycelium grow / network expand
    grow: function() {
      tone(220, 0.3, 'sine', 0.06);
      tone(330, 0.25, 'sine', 0.05, 0.1);
      tone(440, 0.2, 'sine', 0.04, 0.2);
      noise(0.15, 0.02, 0.3);
    },

    // Game: word correct (SIGTERM)
    correct: function() {
      tone(660, 0.08, 'sine', 0.1);
      tone(880, 0.12, 'sine', 0.12, 0.06);
    },

    // Game: word wrong (SIGTERM)
    wrong: function() {
      tone(200, 0.2, 'square', 0.08);
    },

    // Game: rap beat drop (V_CYPHER)
    beatdrop: function() {
      tone(80, 0.3, 'sine', 0.15);
      noise(0.08, 0.1, 0.05);
      tone(80, 0.2, 'sine', 0.12, 0.3);
      noise(0.06, 0.08, 0.35);
    },

    // Game: objection (OBJECTION!)
    objection: function() {
      tone(880, 0.05, 'sawtooth', 0.15);
      tone(1100, 0.3, 'sawtooth', 0.18, 0.05);
    },
  };

  // ── Public API ──────────────────────────────────────────────────────────

  load();

  const api = {
    toggle: function() {
      enabled = !enabled;
      save();
      if (enabled) {
        getCtx(); // init on first enable (needs user gesture)
        sounds.click();
      }
      return enabled;
    },

    isEnabled: function() { return enabled; },

    enable: function() { enabled = true; save(); getCtx(); },
    disable: function() { enabled = false; save(); },

    // Create a sound toggle button (call once per page)
    createToggle: function(container) {
      const btn = document.createElement('button');
      btn.className = 'substrate-audio-toggle';
      btn.setAttribute('aria-label', 'Toggle sound');
      btn.title = 'Toggle sound';
      function update() {
        btn.textContent = enabled ? '♪' : '♪̸';
        btn.style.opacity = enabled ? '1' : '0.4';
      }
      update();
      btn.addEventListener('click', function() {
        api.toggle();
        update();
      });
      // Minimal inline styling
      btn.style.cssText = 'position:fixed;bottom:16px;right:16px;z-index:999;' +
        'background:rgba(10,10,15,0.8);border:1px solid #1e1e2a;border-radius:6px;' +
        'color:#c8c8d0;font-size:1.2rem;width:36px;height:36px;cursor:pointer;' +
        'font-family:monospace;display:flex;align-items:center;justify-content:center;' +
        'transition:opacity 0.2s,border-color 0.2s;';
      (container || document.body).appendChild(btn);
      return btn;
    },
  };

  // Expose all sound functions on the API
  Object.keys(sounds).forEach(function(name) {
    api[name] = sounds[name];
  });

  return api;
})();
