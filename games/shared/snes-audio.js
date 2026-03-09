/**
 * snes-audio.js -- SPC700-style music engine for the Substrate arcade.
 *
 * Replicates the SNES sound chip approach:
 *   - 8 channels of sample playback with pitch-shifting
 *   - ADSR envelopes per channel
 *   - Echo buffer with delay, feedback, and lowpass filter
 *   - All instruments procedurally generated (no external files)
 *   - Master lowpass at ~12kHz to simulate the SPC700 DAC
 *
 * Usage:
 *   <script src="../shared/snes-audio.js"></script>
 *   var music = new SNESAudio();
 *   music.loadSong('adventure');
 *   music.play();
 *
 * Size target: <30KB minified. Zero dependencies.
 */
var SNESAudio = (function() {
  'use strict';

  // ── MIDI note to frequency ──────────────────────────────────────────────
  var NOTE_FREQ = [];
  for (var i = 0; i < 128; i++) {
    NOTE_FREQ[i] = 440 * Math.pow(2, (i - 69) / 12);
  }

  // Note name helpers
  var NOTE_MAP = {C:0,D:2,E:4,F:5,G:7,A:9,B:11};
  function n(name) {
    // e.g. 'C4' => 60, 'F#3' => 54, 'Bb5' => 82
    var m = name.match(/^([A-G])(#|b)?(\d)$/);
    if (!m) return 0;
    var base = NOTE_MAP[m[1]];
    if (m[2] === '#') base++;
    else if (m[2] === 'b') base--;
    return base + (parseInt(m[3]) + 1) * 12;
  }

  // Shorthand: rest
  var R = -1;

  // ── Sample generation ──────────────────────────────────────────────────
  // Generate short looped waveform buffers (like BRR samples).
  // Each is 512 samples at 32000Hz -- authentic SNES sample size.

  var SAMPLE_RATE = 32000;
  var SAMPLE_LEN = 512;

  function generateSamples() {
    var samples = {};

    // Square waves with variable duty cycle
    samples.square50 = makeSample(function(t) {
      return t < 0.5 ? 1 : -1;
    });
    samples.square25 = makeSample(function(t) {
      return t < 0.25 ? 1 : -1;
    });
    samples.square12 = makeSample(function(t) {
      return t < 0.125 ? 1 : -1;
    });

    // Sawtooth
    samples.saw = makeSample(function(t) {
      return 2 * t - 1;
    });

    // Triangle (NES-style, slightly stepped -- 16 steps)
    samples.triangle = makeSample(function(t) {
      var step = Math.floor(t * 16) / 16;
      return step < 0.5 ? 4 * step - 1 : 3 - 4 * step;
    });

    // Sine
    samples.sine = makeSample(function(t) {
      return Math.sin(2 * Math.PI * t);
    });

    // Noise (white)
    samples.noise = makeNoiseSample(4096);

    // Periodic noise (shorter loop for metallic sound)
    samples.periodicNoise = makeNoiseSample(128);

    // Strings: filtered sawtooth (softer harmonics)
    samples.strings = makeSample(function(t) {
      var v = 0;
      for (var h = 1; h <= 8; h++) {
        v += Math.sin(2 * Math.PI * h * t) / (h * h);
      }
      return v * 0.7;
    });

    // Bass: triangle with slight overdrive
    samples.bass = makeSample(function(t) {
      var step = Math.floor(t * 16) / 16;
      var v = step < 0.5 ? 4 * step - 1 : 3 - 4 * step;
      return Math.tanh(v * 1.5);
    });

    // Snare: noise burst + sine body (single cycle, meant to be short)
    samples.snare = makeSample(function(t) {
      var nz = Math.random() * 2 - 1;
      var body = Math.sin(2 * Math.PI * t * 3) * (1 - t);
      return nz * 0.6 + body * 0.4;
    }, 1024);

    // Kick: sine with pitch sweep down (encoded in one cycle)
    samples.kick = makeSample(function(t) {
      var freq = 1 + (1 - t) * 8;
      return Math.sin(2 * Math.PI * freq * t) * (1 - t * 0.5);
    }, 1024);

    // Hi-hat: highpassed noise burst
    samples.hihat = (function() {
      var len = 512;
      var buf = new Float32Array(len);
      var prev = 0;
      for (var i = 0; i < len; i++) {
        var raw = Math.random() * 2 - 1;
        buf[i] = raw - prev;
        prev = raw;
      }
      return buf;
    })();

    // Piano: detuned sines (3 partials slightly detuned)
    samples.piano = makeSample(function(t) {
      return (
        Math.sin(2 * Math.PI * t * 1.0) * 0.5 +
        Math.sin(2 * Math.PI * t * 2.002) * 0.3 +
        Math.sin(2 * Math.PI * t * 3.004) * 0.15 +
        Math.sin(2 * Math.PI * t * 4.01) * 0.05
      );
    });

    return samples;
  }

  function makeSample(fn, len) {
    len = len || SAMPLE_LEN;
    var buf = new Float32Array(len);
    for (var i = 0; i < len; i++) {
      buf[i] = fn(i / len);
    }
    return buf;
  }

  function makeNoiseSample(len) {
    var buf = new Float32Array(len);
    for (var i = 0; i < len; i++) {
      buf[i] = Math.random() * 2 - 1;
    }
    return buf;
  }

  // ── Song presets ────────────────────────────────────────────────────────
  // Each song: { bpm, echo, patterns, sequence, instruments }
  // Pattern step: [channel, note (MIDI or R for rest), instrument, volume, fx]
  //   fx: { legato, vibrato, echo }

  function getSongs() {
    var songs = {};

    // ── AIRLOCK -- Tense ambient (Metroid / Alien 3 style) ──────────────
    songs.airlock = {
      bpm: 75,
      echo: {delay: 350, feedback: 0.45, wet: 0.4, cutoff: 3000},
      instruments: {
        pad: {sample: 'strings', adsr: [0.8, 0.3, 0.6, 1.2], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.2, 0.4, 0.5], loop: true},
        perc: {sample: 'hihat', adsr: [0.005, 0.1, 0, 0.05], loop: false},
        tone: {sample: 'sine', adsr: [0.4, 0.5, 0.3, 0.8], loop: true},
        noise: {sample: 'noise', adsr: [0.5, 1.0, 0.2, 1.5], loop: true}
      },
      patterns: [
        // P0: eerie pad sustained + low bass pulses
        {steps: 32, data: [
          [0, n('E2'), 'bass', 0.5], null, null, null,
          null, null, null, null,
          [1, n('B3'), 'pad', 0.25], null, null, null,
          [0, n('E2'), 'bass', 0.35], null, null, null,
          null, null, null, null,
          [2, n('E4'), 'tone', 0.15], null, null, null,
          [0, n('B1'), 'bass', 0.45], null, null, null,
          null, null, [3, R, 'perc', 0.1], null
        ]},
        // P1: tension build
        {steps: 32, data: [
          [0, n('E2'), 'bass', 0.5], null, null, null,
          [4, n('C2'), 'noise', 0.08], null, null, null,
          [1, n('C4'), 'pad', 0.25], null, null, null,
          [0, n('F2'), 'bass', 0.4], null, null, null,
          [3, R, 'perc', 0.15], null, null, null,
          [2, n('G4'), 'tone', 0.15], null, null, null,
          [0, n('E2'), 'bass', 0.45], null, null, null,
          [3, R, 'perc', 0.12], null, null, null
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── BOOTLOADER -- Digital startup (Mega Man X intro style) ──────────
    songs.bootloader = {
      bpm: 140,
      echo: {delay: 150, feedback: 0.3, wet: 0.25, cutoff: 5000},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.1, 0.7, 0.15], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.15, 0.5, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.15, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.06, 0, 0.02], loop: false},
        arp: {sample: 'square25', adsr: [0.01, 0.08, 0.5, 0.1], loop: true}
      },
      patterns: [
        // P0: driving intro
        {steps: 16, data: [
          [0, n('E2'), 'bass', 0.6], [4, R, 'hat', 0.3], [1, n('E4'), 'lead', 0.4], null,
          [2, R, 'kick', 0.7], [4, R, 'hat', 0.25], null, null,
          [0, n('E2'), 'bass', 0.5], [4, R, 'hat', 0.3], [3, R, 'snare', 0.5], null,
          [2, R, 'kick', 0.65], [4, R, 'hat', 0.25], [1, n('G4'), 'lead', 0.4], null
        ]},
        // P1: melody
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [4, R, 'hat', 0.3], [1, n('E5'), 'lead', 0.45], [0, n('E2'), 'bass', 0.5],
          null, [4, R, 'hat', 0.25], [1, n('D5'), 'lead', 0.4], null,
          [2, R, 'kick', 0.65], [4, R, 'hat', 0.3], [3, R, 'snare', 0.5], [1, n('B4'), 'lead', 0.4],
          [0, n('D2'), 'bass', 0.5], [4, R, 'hat', 0.25], [1, n('A4'), 'lead', 0.35], null
        ]},
        // P2: arp section
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [5, n('E4'), 'arp', 0.3], [0, n('E2'), 'bass', 0.5], [5, n('G4'), 'arp', 0.3],
          null, [5, n('B4'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('E5'), 'arp', 0.25],
          [3, R, 'snare', 0.5], [5, n('B4'), 'arp', 0.3], [0, n('D2'), 'bass', 0.5], [5, n('G4'), 'arp', 0.3],
          [2, R, 'kick', 0.65], [5, n('D4'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('F#4'), 'arp', 0.3]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 1, 2]
    };

    // ── BRIGADE -- Military march (Advance Wars style) ──────────────────
    songs.brigade = {
      bpm: 130,
      echo: {delay: 180, feedback: 0.25, wet: 0.2, cutoff: 4500},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.1, 0.7, 0.12], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.15, 0.5, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.12, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.05, 0, 0.02], loop: false},
        brass: {sample: 'saw', adsr: [0.05, 0.15, 0.6, 0.2], loop: true}
      },
      patterns: [
        // P0: march rhythm
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [4, R, 'hat', 0.3], [0, n('C3'), 'bass', 0.5], null,
          [3, R, 'snare', 0.55], [4, R, 'hat', 0.25], null, null,
          [2, R, 'kick', 0.7], [4, R, 'hat', 0.3], [0, n('G2'), 'bass', 0.5], null,
          [3, R, 'snare', 0.55], [4, R, 'hat', 0.25], [3, R, 'snare', 0.35], null
        ]},
        // P1: brass melody
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('C5'), 'brass', 0.4], [0, n('C3'), 'bass', 0.5], null,
          [3, R, 'snare', 0.55], [1, n('E5'), 'brass', 0.4], null, null,
          [2, R, 'kick', 0.65], [1, n('G5'), 'brass', 0.45], [0, n('G2'), 'bass', 0.5], null,
          [3, R, 'snare', 0.55], [1, n('E5'), 'brass', 0.35], [4, R, 'hat', 0.2], null
        ]},
        // P2: triumphant
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('G5'), 'brass', 0.45], [0, n('C3'), 'bass', 0.5], [5, n('C5'), 'lead', 0.3],
          [3, R, 'snare', 0.55], null, [1, n('A5'), 'brass', 0.4], null,
          [2, R, 'kick', 0.7], [1, n('G5'), 'brass', 0.45], [0, n('F2'), 'bass', 0.5], null,
          [3, R, 'snare', 0.55], [1, n('E5'), 'brass', 0.4], [4, R, 'hat', 0.25], [5, n('E5'), 'lead', 0.3]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 1, 2]
    };

    // ── CARD -- Smooth chill (FF6 casino style) ─────────────────────────
    songs.card = {
      bpm: 110,
      echo: {delay: 250, feedback: 0.35, wet: 0.35, cutoff: 4000},
      instruments: {
        piano: {sample: 'piano', adsr: [0.01, 0.3, 0.3, 0.4], loop: false},
        bass: {sample: 'bass', adsr: [0.01, 0.2, 0.45, 0.15], loop: true},
        hat: {sample: 'hihat', adsr: [0.005, 0.05, 0, 0.02], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.15, 0, 0.05], loop: false},
        pad: {sample: 'strings', adsr: [0.5, 0.3, 0.5, 0.6], loop: true},
        lead: {sample: 'sine', adsr: [0.05, 0.2, 0.5, 0.3], loop: true}
      },
      patterns: [
        // P0: jazzy groove
        {steps: 16, data: [
          [0, n('A2'), 'bass', 0.5], [2, R, 'hat', 0.3], [1, n('C5'), 'piano', 0.4], null,
          null, [2, R, 'hat', 0.2], [1, n('E5'), 'piano', 0.35], null,
          [3, R, 'snare', 0.4], [2, R, 'hat', 0.3], [1, n('A4'), 'piano', 0.4], null,
          [0, n('E2'), 'bass', 0.45], [2, R, 'hat', 0.2], [1, n('G4'), 'piano', 0.35], null
        ]},
        // P1: melody over pad
        {steps: 16, data: [
          [0, n('D3'), 'bass', 0.5], [4, n('D4'), 'pad', 0.2], [5, n('F5'), 'lead', 0.35], null,
          null, [2, R, 'hat', 0.25], [5, n('E5'), 'lead', 0.3], null,
          [3, R, 'snare', 0.4], null, [5, n('D5'), 'lead', 0.35], null,
          [0, n('A2'), 'bass', 0.45], [2, R, 'hat', 0.25], [5, n('C5'), 'lead', 0.3], null
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── CASCADE -- Escalating tension (Tetris building up) ──────────────
    songs.cascade = {
      bpm: 135,
      echo: {delay: 120, feedback: 0.2, wet: 0.2, cutoff: 5000},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.08, 0.65, 0.1], loop: true},
        bass: {sample: 'triangle', adsr: [0.01, 0.12, 0.5, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.18, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.12, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.04, 0, 0.02], loop: false},
        arp: {sample: 'square25', adsr: [0.01, 0.06, 0.5, 0.08], loop: true}
      },
      patterns: [
        // P0: Russian-inspired melody in A minor
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('A4'), 'lead', 0.45], [0, n('A2'), 'bass', 0.5], [4, R, 'hat', 0.25],
          null, [1, n('E4'), 'lead', 0.4], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.5], [1, n('F4'), 'lead', 0.4], [0, n('F2'), 'bass', 0.45], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.6], [1, n('E4'), 'lead', 0.4], [4, R, 'hat', 0.2], null
        ]},
        // P1: second phrase
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('D4'), 'lead', 0.45], [0, n('D2'), 'bass', 0.5], [4, R, 'hat', 0.25],
          null, [1, n('C4'), 'lead', 0.4], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.5], [1, n('B3'), 'lead', 0.4], [0, n('E2'), 'bass', 0.45], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.6], [1, n('A3'), 'lead', 0.45], [4, R, 'hat', 0.2], null
        ]},
        // P2: arp escalation
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [5, n('A3'), 'arp', 0.3], [0, n('A2'), 'bass', 0.5], [5, n('C4'), 'arp', 0.3],
          [4, R, 'hat', 0.2], [5, n('E4'), 'arp', 0.3], null, [5, n('A4'), 'arp', 0.25],
          [3, R, 'snare', 0.5], [5, n('E4'), 'arp', 0.3], [0, n('E2'), 'bass', 0.45], [5, n('C4'), 'arp', 0.3],
          [2, R, 'kick', 0.6], [5, n('B3'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('E4'), 'arp', 0.3]
        ]}
      ],
      sequence: [0, 1, 0, 1, 2, 2, 0, 2]
    };

    // ── CHEMISTRY -- Experimental/bubbly (SimCity SNES lab) ─────────────
    songs.chemistry = {
      bpm: 115,
      echo: {delay: 280, feedback: 0.35, wet: 0.35, cutoff: 3500},
      instruments: {
        bubble: {sample: 'sine', adsr: [0.02, 0.15, 0.3, 0.2], loop: true},
        bass: {sample: 'triangle', adsr: [0.01, 0.2, 0.4, 0.15], loop: true},
        click: {sample: 'periodicNoise', adsr: [0.005, 0.04, 0, 0.02], loop: false},
        pad: {sample: 'strings', adsr: [0.6, 0.4, 0.5, 0.5], loop: true},
        blip: {sample: 'square25', adsr: [0.01, 0.06, 0.4, 0.1], loop: true},
        hat: {sample: 'hihat', adsr: [0.005, 0.04, 0, 0.02], loop: false}
      },
      patterns: [
        {steps: 16, data: [
          [0, n('C3'), 'bass', 0.45], [1, n('G5'), 'bubble', 0.3], null, [5, R, 'hat', 0.2],
          null, [1, n('E5'), 'bubble', 0.25], [2, R, 'click', 0.3], null,
          [0, n('G2'), 'bass', 0.4], [1, n('C6'), 'bubble', 0.2], null, [5, R, 'hat', 0.2],
          null, [4, n('E5'), 'blip', 0.25], [2, R, 'click', 0.25], null
        ]},
        {steps: 16, data: [
          [0, n('F3'), 'bass', 0.45], [3, n('F3'), 'pad', 0.2], [1, n('A5'), 'bubble', 0.3], null,
          [5, R, 'hat', 0.2], [1, n('F5'), 'bubble', 0.25], null, [2, R, 'click', 0.25],
          [0, n('C3'), 'bass', 0.4], null, [1, n('C5'), 'bubble', 0.3], [5, R, 'hat', 0.2],
          null, [4, n('G5'), 'blip', 0.2], null, [2, R, 'click', 0.2]
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── CYPHER -- Spy thriller (Metal Gear SNES style) ──────────────────
    songs.cypher = {
      bpm: 100,
      echo: {delay: 300, feedback: 0.4, wet: 0.35, cutoff: 3000},
      instruments: {
        bass: {sample: 'bass', adsr: [0.01, 0.2, 0.4, 0.15], loop: true},
        lead: {sample: 'square25', adsr: [0.02, 0.15, 0.5, 0.2], loop: true},
        pad: {sample: 'strings', adsr: [0.5, 0.4, 0.4, 0.8], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.15, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.05, 0, 0.02], loop: false}
      },
      patterns: [
        // P0: sneaky bass + sparse drums
        {steps: 16, data: [
          [3, R, 'kick', 0.5], [5, R, 'hat', 0.2], [0, n('E2'), 'bass', 0.45], null,
          null, [5, R, 'hat', 0.15], null, null,
          null, [5, R, 'hat', 0.2], [0, n('G2'), 'bass', 0.4], null,
          [4, R, 'snare', 0.35], [5, R, 'hat', 0.15], null, null
        ]},
        // P1: melody + tension
        {steps: 16, data: [
          [3, R, 'kick', 0.5], [1, n('E4'), 'lead', 0.35], [0, n('E2'), 'bass', 0.45], null,
          null, [1, n('F4'), 'lead', 0.3], [5, R, 'hat', 0.15], null,
          [2, n('B3'), 'pad', 0.2], [1, n('G4'), 'lead', 0.35], [0, n('B1'), 'bass', 0.4], null,
          [4, R, 'snare', 0.35], [1, n('F4'), 'lead', 0.3], [5, R, 'hat', 0.2], [1, n('E4'), 'lead', 0.25]
        ]}
      ],
      sequence: [0, 0, 1, 0, 1, 1]
    };

    // ── MYCELIUM -- Organic nature (Secret of Mana forest) ─────────────
    songs.mycelium = {
      bpm: 90,
      echo: {delay: 400, feedback: 0.45, wet: 0.45, cutoff: 2500},
      instruments: {
        pad: {sample: 'strings', adsr: [0.8, 0.5, 0.5, 1.0], loop: true},
        flute: {sample: 'sine', adsr: [0.1, 0.2, 0.6, 0.4], loop: true},
        bass: {sample: 'triangle', adsr: [0.05, 0.3, 0.35, 0.2], loop: true},
        chime: {sample: 'piano', adsr: [0.01, 0.4, 0.15, 0.5], loop: false},
        hat: {sample: 'periodicNoise', adsr: [0.005, 0.08, 0, 0.03], loop: false},
        drop: {sample: 'sine', adsr: [0.01, 0.3, 0, 0.1], loop: false}
      },
      patterns: [
        // P0: peaceful forest
        {steps: 32, data: [
          [0, n('D3'), 'bass', 0.35], null, [1, n('A4'), 'flute', 0.3], null,
          null, null, null, [3, n('F#5'), 'chime', 0.2],
          null, null, [1, n('F#4'), 'flute', 0.25], null,
          [0, n('A2'), 'bass', 0.3], null, null, null,
          [2, n('D3'), 'pad', 0.2], null, [1, n('D5'), 'flute', 0.3], null,
          null, null, [5, n('A5'), 'drop', 0.15], null,
          null, null, [1, n('E4'), 'flute', 0.25], null,
          [0, n('G2'), 'bass', 0.3], null, null, [4, R, 'hat', 0.1]
        ]},
        // P1: deeper woods
        {steps: 32, data: [
          [0, n('G2'), 'bass', 0.35], null, [1, n('B4'), 'flute', 0.3], null,
          null, null, [3, n('D5'), 'chime', 0.2], null,
          null, null, [1, n('G4'), 'flute', 0.25], null,
          [0, n('D2'), 'bass', 0.3], null, null, [5, n('D6'), 'drop', 0.12],
          [2, n('G3'), 'pad', 0.2], null, [1, n('B4'), 'flute', 0.3], null,
          null, null, null, [4, R, 'hat', 0.1],
          null, null, [1, n('A4'), 'flute', 0.25], null,
          [0, n('E2'), 'bass', 0.3], null, null, null
        ]}
      ],
      sequence: [0, 1, 0, 1]
    };

    // ── MYCO -- Earthy ambient (Earthbound peaceful) ────────────────────
    songs.myco = {
      bpm: 85,
      echo: {delay: 380, feedback: 0.4, wet: 0.4, cutoff: 2800},
      instruments: {
        pad: {sample: 'strings', adsr: [1.0, 0.4, 0.5, 1.2], loop: true},
        bass: {sample: 'triangle', adsr: [0.05, 0.3, 0.3, 0.2], loop: true},
        bell: {sample: 'piano', adsr: [0.01, 0.5, 0.1, 0.6], loop: false},
        flute: {sample: 'sine', adsr: [0.15, 0.25, 0.5, 0.5], loop: true},
        click: {sample: 'periodicNoise', adsr: [0.005, 0.05, 0, 0.02], loop: false}
      },
      patterns: [
        {steps: 32, data: [
          [0, n('C3'), 'bass', 0.3], null, null, null,
          [1, n('E4'), 'flute', 0.25], null, null, [2, n('G5'), 'bell', 0.18],
          null, null, null, null,
          [0, n('G2'), 'bass', 0.28], null, [4, R, 'click', 0.1], null,
          [3, n('C3'), 'pad', 0.18], null, [1, n('G4'), 'flute', 0.25], null,
          null, null, null, [2, n('C5'), 'bell', 0.15],
          null, null, null, null,
          [0, n('F2'), 'bass', 0.3], null, null, null
        ]},
        {steps: 32, data: [
          [0, n('Am2'), 'bass', 0.3], null, null, null,
          [1, n('C5'), 'flute', 0.25], null, null, null,
          null, null, [2, n('E5'), 'bell', 0.18], null,
          [0, n('E2'), 'bass', 0.28], null, null, [4, R, 'click', 0.1],
          [3, n('A3'), 'pad', 0.18], null, null, null,
          [1, n('A4'), 'flute', 0.25], null, null, [2, n('D5'), 'bell', 0.15],
          null, null, null, null,
          [0, n('D2'), 'bass', 0.3], null, null, null
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── NOVEL -- Emotional/cinematic (FF6 opera style) ──────────────────
    songs.novel = {
      bpm: 72,
      echo: {delay: 400, feedback: 0.4, wet: 0.4, cutoff: 3000},
      instruments: {
        strings: {sample: 'strings', adsr: [0.6, 0.4, 0.6, 1.0], loop: true},
        piano: {sample: 'piano', adsr: [0.01, 0.5, 0.2, 0.8], loop: false},
        bass: {sample: 'bass', adsr: [0.05, 0.3, 0.35, 0.3], loop: true},
        flute: {sample: 'sine', adsr: [0.15, 0.3, 0.5, 0.5], loop: true},
        bell: {sample: 'piano', adsr: [0.01, 0.8, 0.05, 1.0], loop: false}
      },
      patterns: [
        // P0: sweeping strings + piano
        {steps: 32, data: [
          [0, n('C3'), 'bass', 0.35], null, [1, n('E5'), 'piano', 0.35], null,
          [2, n('C4'), 'strings', 0.25], null, [1, n('G5'), 'piano', 0.3], null,
          null, null, [1, n('A5'), 'piano', 0.3], null,
          [0, n('G2'), 'bass', 0.3], null, [1, n('G5'), 'piano', 0.3], null,
          null, null, [3, n('E5'), 'flute', 0.25], null,
          [2, n('G3'), 'strings', 0.25], null, null, null,
          [0, n('A2'), 'bass', 0.3], null, [1, n('C5'), 'piano', 0.3], null,
          null, null, [4, n('E6'), 'bell', 0.15], null
        ]},
        // P1: climactic
        {steps: 32, data: [
          [0, n('F3'), 'bass', 0.35], null, [3, n('C6'), 'flute', 0.3], null,
          [2, n('F4'), 'strings', 0.3], null, [3, n('A5'), 'flute', 0.28], null,
          null, null, null, null,
          [0, n('C3'), 'bass', 0.35], null, [1, n('G5'), 'piano', 0.35], null,
          [2, n('E4'), 'strings', 0.3], null, [3, n('E5'), 'flute', 0.3], null,
          null, null, null, [4, n('C6'), 'bell', 0.15],
          [0, n('G2'), 'bass', 0.35], null, [1, n('D5'), 'piano', 0.3], null,
          null, null, null, null
        ]}
      ],
      sequence: [0, 0, 1, 0, 1, 1]
    };

    // ── OBJECTION -- Intense courtroom (Phoenix Wright style) ───────────
    songs.objection = {
      bpm: 155,
      echo: {delay: 130, feedback: 0.2, wet: 0.2, cutoff: 5500},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.08, 0.7, 0.1], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.12, 0.5, 0.08], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.18, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.1, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.04, 0, 0.02], loop: false},
        brass: {sample: 'saw', adsr: [0.02, 0.1, 0.6, 0.15], loop: true}
      },
      patterns: [
        // P0: intense cross-examination
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [4, R, 'hat', 0.3], [1, n('C5'), 'lead', 0.45], [0, n('C3'), 'bass', 0.5],
          null, [4, R, 'hat', 0.25], [1, n('D5'), 'lead', 0.4], null,
          [3, R, 'snare', 0.55], [4, R, 'hat', 0.3], [1, n('E5'), 'lead', 0.45], null,
          [2, R, 'kick', 0.65], [4, R, 'hat', 0.25], [1, n('G5'), 'lead', 0.5], null
        ]},
        // P1: objection theme
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [5, n('C5'), 'brass', 0.4], [0, n('C3'), 'bass', 0.5], [4, R, 'hat', 0.25],
          null, [5, n('E5'), 'brass', 0.45], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.55], [5, n('G5'), 'brass', 0.5], [0, n('G2'), 'bass', 0.5], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.7], [1, n('C6'), 'lead', 0.4], [4, R, 'hat', 0.2], [3, R, 'snare', 0.35]
        ]},
        // P2: pressing pursuit
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [1, n('G5'), 'lead', 0.5], [0, n('F2'), 'bass', 0.5], [4, R, 'hat', 0.3],
          [5, n('A4'), 'brass', 0.35], [4, R, 'hat', 0.2], [1, n('A5'), 'lead', 0.45], null,
          [3, R, 'snare', 0.55], [1, n('G5'), 'lead', 0.45], [0, n('C3'), 'bass', 0.5], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.7], [1, n('E5'), 'lead', 0.45], [3, R, 'snare', 0.4], [1, n('D5'), 'lead', 0.4]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 1, 2]
    };

    // ── TACTICS -- Strategic/medieval (FF Tactics / Ogre Battle) ────────
    songs.tactics = {
      bpm: 95,
      echo: {delay: 320, feedback: 0.35, wet: 0.3, cutoff: 3500},
      instruments: {
        strings: {sample: 'strings', adsr: [0.3, 0.3, 0.6, 0.5], loop: true},
        bass: {sample: 'bass', adsr: [0.02, 0.2, 0.4, 0.15], loop: true},
        flute: {sample: 'sine', adsr: [0.08, 0.2, 0.5, 0.3], loop: true},
        drum: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.15, 0, 0.05], loop: false},
        bell: {sample: 'piano', adsr: [0.01, 0.6, 0.1, 0.5], loop: false}
      },
      patterns: [
        // P0: medieval march
        {steps: 16, data: [
          [3, R, 'drum', 0.6], [0, n('D3'), 'bass', 0.45], [1, n('D4'), 'strings', 0.3], null,
          null, null, [2, n('A4'), 'flute', 0.3], null,
          [4, R, 'snare', 0.45], [0, n('A2'), 'bass', 0.4], null, null,
          [3, R, 'drum', 0.5], null, [2, n('F4'), 'flute', 0.3], null
        ]},
        // P1: battle theme
        {steps: 16, data: [
          [3, R, 'drum', 0.65], [1, n('D4'), 'strings', 0.35], [0, n('D3'), 'bass', 0.5], null,
          null, [2, n('D5'), 'flute', 0.35], null, null,
          [4, R, 'snare', 0.5], [1, n('F4'), 'strings', 0.3], [0, n('F2'), 'bass', 0.45], null,
          [3, R, 'drum', 0.55], [2, n('E5'), 'flute', 0.3], [5, n('A5'), 'bell', 0.15], null
        ]},
        // P2: strategic tension
        {steps: 16, data: [
          [3, R, 'drum', 0.6], [0, n('G2'), 'bass', 0.45], [1, n('G3'), 'strings', 0.3], null,
          [2, n('B4'), 'flute', 0.3], null, null, null,
          [4, R, 'snare', 0.45], [0, n('C3'), 'bass', 0.45], [2, n('C5'), 'flute', 0.3], null,
          [3, R, 'drum', 0.5], null, [5, n('D5'), 'bell', 0.18], null
        ]}
      ],
      sequence: [0, 0, 1, 2, 1, 1, 2, 0]
    };

    // ── ADVENTURE -- Exploration (Chrono Trigger overworld) ─────────────
    songs.adventure = {
      bpm: 120,
      echo: {delay: 250, feedback: 0.3, wet: 0.3, cutoff: 4000},
      instruments: {
        lead: {sample: 'square50', adsr: [0.02, 0.12, 0.6, 0.15], loop: true},
        bass: {sample: 'triangle', adsr: [0.01, 0.15, 0.45, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.12, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.05, 0, 0.02], loop: false},
        pad: {sample: 'strings', adsr: [0.4, 0.3, 0.5, 0.5], loop: true},
        arp: {sample: 'square25', adsr: [0.01, 0.08, 0.5, 0.1], loop: true}
      },
      patterns: [
        // P0: hopeful overworld theme in G
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [1, n('G4'), 'lead', 0.4], [0, n('G2'), 'bass', 0.45], [4, R, 'hat', 0.2],
          null, [1, n('A4'), 'lead', 0.35], [4, R, 'hat', 0.15], null,
          [3, R, 'snare', 0.45], [1, n('B4'), 'lead', 0.4], [0, n('D3'), 'bass', 0.4], [4, R, 'hat', 0.2],
          [2, R, 'kick', 0.55], [1, n('D5'), 'lead', 0.45], [4, R, 'hat', 0.15], null
        ]},
        // P1: second phrase
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [1, n('E5'), 'lead', 0.4], [0, n('C3'), 'bass', 0.45], [4, R, 'hat', 0.2],
          [5, n('C4'), 'pad', 0.2], [1, n('D5'), 'lead', 0.35], [4, R, 'hat', 0.15], null,
          [3, R, 'snare', 0.45], [1, n('B4'), 'lead', 0.4], [0, n('G2'), 'bass', 0.4], [4, R, 'hat', 0.2],
          [2, R, 'kick', 0.55], [1, n('A4'), 'lead', 0.4], [4, R, 'hat', 0.15], null
        ]},
        // P2: arp bridge
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [6, n('G3'), 'arp', 0.3], [0, n('E2'), 'bass', 0.45], [6, n('B3'), 'arp', 0.28],
          [4, R, 'hat', 0.15], [6, n('E4'), 'arp', 0.28], null, [6, n('G4'), 'arp', 0.25],
          [3, R, 'snare', 0.45], [6, n('E4'), 'arp', 0.28], [0, n('D2'), 'bass', 0.4], [6, n('B3'), 'arp', 0.28],
          [2, R, 'kick', 0.55], [6, n('D4'), 'arp', 0.3], [4, R, 'hat', 0.15], [6, n('F#4'), 'arp', 0.28]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 0, 1]
    };

    // ── PUZZLE -- Playful puzzle (Puyo Puyo / Tetris Attack) ────────────
    songs.puzzle = {
      bpm: 145,
      echo: {delay: 140, feedback: 0.2, wet: 0.2, cutoff: 5500},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.08, 0.65, 0.08], loop: true},
        bass: {sample: 'triangle', adsr: [0.01, 0.1, 0.5, 0.08], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.15, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.1, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.04, 0, 0.02], loop: false},
        arp: {sample: 'square25', adsr: [0.01, 0.06, 0.5, 0.08], loop: true}
      },
      patterns: [
        // P0: bouncy main theme
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('C5'), 'lead', 0.4], [0, n('C3'), 'bass', 0.5], [4, R, 'hat', 0.25],
          null, [1, n('E5'), 'lead', 0.38], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.5], [1, n('G5'), 'lead', 0.42], [0, n('G2'), 'bass', 0.45], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.6], [1, n('E5'), 'lead', 0.38], [4, R, 'hat', 0.2], null
        ]},
        // P1: B section
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [1, n('F5'), 'lead', 0.42], [0, n('F2'), 'bass', 0.5], [4, R, 'hat', 0.25],
          null, [1, n('E5'), 'lead', 0.38], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.5], [1, n('D5'), 'lead', 0.4], [0, n('G2'), 'bass', 0.45], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.6], [1, n('C5'), 'lead', 0.42], [4, R, 'hat', 0.2], null
        ]},
        // P2: fast arps
        {steps: 16, data: [
          [2, R, 'kick', 0.7], [5, n('C4'), 'arp', 0.3], [0, n('C3'), 'bass', 0.5], [5, n('E4'), 'arp', 0.28],
          [4, R, 'hat', 0.2], [5, n('G4'), 'arp', 0.28], null, [5, n('C5'), 'arp', 0.25],
          [3, R, 'snare', 0.5], [5, n('G4'), 'arp', 0.28], [0, n('G2'), 'bass', 0.45], [5, n('E4'), 'arp', 0.28],
          [2, R, 'kick', 0.6], [5, n('F4'), 'arp', 0.28], [4, R, 'hat', 0.2], [5, n('A4'), 'arp', 0.28]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 0, 1, 2]
    };

    // ── IDLE -- Ambient growth (Harvest Moon style) ─────────────────────
    songs.idle = {
      bpm: 95,
      echo: {delay: 350, feedback: 0.4, wet: 0.4, cutoff: 3000},
      instruments: {
        guitar: {sample: 'piano', adsr: [0.01, 0.3, 0.25, 0.4], loop: false},
        bass: {sample: 'triangle', adsr: [0.02, 0.2, 0.35, 0.15], loop: true},
        pad: {sample: 'strings', adsr: [0.6, 0.4, 0.5, 0.8], loop: true},
        flute: {sample: 'sine', adsr: [0.1, 0.2, 0.5, 0.3], loop: true},
        click: {sample: 'periodicNoise', adsr: [0.005, 0.06, 0, 0.02], loop: false}
      },
      patterns: [
        // P0: peaceful farm
        {steps: 16, data: [
          [0, n('G2'), 'bass', 0.35], [1, n('G4'), 'guitar', 0.3], null, null,
          null, [1, n('B4'), 'guitar', 0.28], [4, R, 'click', 0.12], null,
          [0, n('D3'), 'bass', 0.3], [1, n('D4'), 'guitar', 0.3], null, null,
          [2, n('G3'), 'pad', 0.2], [1, n('A4'), 'guitar', 0.28], null, null
        ]},
        // P1: meadow melody
        {steps: 16, data: [
          [0, n('C3'), 'bass', 0.35], null, [3, n('E5'), 'flute', 0.3], null,
          null, [1, n('C4'), 'guitar', 0.25], [4, R, 'click', 0.12], null,
          [0, n('G2'), 'bass', 0.3], null, [3, n('D5'), 'flute', 0.28], null,
          [2, n('C3'), 'pad', 0.2], [1, n('E4'), 'guitar', 0.25], null, null
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── DECKBUILDER -- Card battle (Yu-Gi-Oh SNES style) ────────────────
    songs.deckbuilder = {
      bpm: 125,
      echo: {delay: 200, feedback: 0.28, wet: 0.25, cutoff: 4500},
      instruments: {
        lead: {sample: 'square50', adsr: [0.01, 0.1, 0.65, 0.12], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.15, 0.5, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.12, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.04, 0, 0.02], loop: false},
        strings: {sample: 'strings', adsr: [0.2, 0.25, 0.5, 0.3], loop: true}
      },
      patterns: [
        // P0: duel theme
        {steps: 16, data: [
          [2, R, 'kick', 0.65], [1, n('E4'), 'lead', 0.4], [0, n('E2'), 'bass', 0.5], [4, R, 'hat', 0.2],
          null, [1, n('G4'), 'lead', 0.38], [4, R, 'hat', 0.18], null,
          [3, R, 'snare', 0.5], [1, n('A4'), 'lead', 0.4], [0, n('A2'), 'bass', 0.45], [4, R, 'hat', 0.2],
          [2, R, 'kick', 0.6], [1, n('B4'), 'lead', 0.42], [4, R, 'hat', 0.18], null
        ]},
        // P1: dramatic strings
        {steps: 16, data: [
          [2, R, 'kick', 0.65], [5, n('A3'), 'strings', 0.3], [0, n('A2'), 'bass', 0.5], null,
          null, [1, n('C5'), 'lead', 0.4], [4, R, 'hat', 0.2], null,
          [3, R, 'snare', 0.5], [5, n('E4'), 'strings', 0.3], [0, n('E2'), 'bass', 0.45], null,
          [2, R, 'kick', 0.6], [1, n('B4'), 'lead', 0.38], [4, R, 'hat', 0.2], null
        ]}
      ],
      sequence: [0, 0, 1, 1, 0, 1]
    };

    // ── RUNNER -- Fast-paced action (F-Zero style) ──────────────────────
    songs.runner = {
      bpm: 170,
      echo: {delay: 100, feedback: 0.2, wet: 0.18, cutoff: 6000},
      instruments: {
        lead: {sample: 'saw', adsr: [0.01, 0.06, 0.7, 0.08], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.1, 0.5, 0.06], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.15, 0, 0.04], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.1, 0, 0.04], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.03, 0, 0.02], loop: false},
        arp: {sample: 'square50', adsr: [0.01, 0.05, 0.6, 0.06], loop: true}
      },
      patterns: [
        // P0: high-speed chase
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [4, R, 'hat', 0.3], [0, n('A2'), 'bass', 0.55], [1, n('A4'), 'lead', 0.45],
          [4, R, 'hat', 0.2], [1, n('C5'), 'lead', 0.4], [4, R, 'hat', 0.25], null,
          [3, R, 'snare', 0.55], [4, R, 'hat', 0.3], [0, n('G2'), 'bass', 0.5], [1, n('E5'), 'lead', 0.45],
          [2, R, 'kick', 0.7], [4, R, 'hat', 0.25], [1, n('D5'), 'lead', 0.4], [4, R, 'hat', 0.2]
        ]},
        // P1: melodic section
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [1, n('E5'), 'lead', 0.5], [0, n('C3'), 'bass', 0.55], [4, R, 'hat', 0.25],
          null, [1, n('D5'), 'lead', 0.45], [4, R, 'hat', 0.2], [5, n('C4'), 'arp', 0.3],
          [3, R, 'snare', 0.55], [1, n('C5'), 'lead', 0.45], [0, n('F2'), 'bass', 0.5], [4, R, 'hat', 0.25],
          [2, R, 'kick', 0.7], [5, n('E4'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('G4'), 'arp', 0.28]
        ]},
        // P2: breakdown with arps
        {steps: 16, data: [
          [2, R, 'kick', 0.75], [5, n('A3'), 'arp', 0.3], [0, n('A2'), 'bass', 0.55], [5, n('C4'), 'arp', 0.3],
          [4, R, 'hat', 0.2], [5, n('E4'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('A4'), 'arp', 0.28],
          [3, R, 'snare', 0.55], [5, n('E4'), 'arp', 0.3], [0, n('E2'), 'bass', 0.5], [5, n('C4'), 'arp', 0.3],
          [2, R, 'kick', 0.7], [5, n('G3'), 'arp', 0.3], [4, R, 'hat', 0.2], [5, n('B3'), 'arp', 0.3]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 0, 1]
    };

    // ── SIGNAL -- Mysterious deduction (Phoenix Wright investigation) ───
    songs.signal = {
      bpm: 105,
      echo: {delay: 300, feedback: 0.35, wet: 0.35, cutoff: 3500},
      instruments: {
        piano: {sample: 'piano', adsr: [0.01, 0.35, 0.2, 0.4], loop: false},
        bass: {sample: 'bass', adsr: [0.02, 0.2, 0.35, 0.15], loop: true},
        pad: {sample: 'strings', adsr: [0.5, 0.3, 0.4, 0.6], loop: true},
        bell: {sample: 'piano', adsr: [0.01, 0.5, 0.08, 0.5], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.06, 0, 0.02], loop: false},
        click: {sample: 'periodicNoise', adsr: [0.005, 0.05, 0, 0.02], loop: false}
      },
      patterns: [
        // P0: investigation mood
        {steps: 16, data: [
          [0, n('A2'), 'bass', 0.4], [1, n('A4'), 'piano', 0.35], null, [4, R, 'hat', 0.15],
          null, [1, n('C5'), 'piano', 0.3], null, null,
          [0, n('E2'), 'bass', 0.35], [1, n('E4'), 'piano', 0.3], null, [5, R, 'click', 0.12],
          null, [3, n('E5'), 'bell', 0.15], null, null
        ]},
        // P1: discovery
        {steps: 16, data: [
          [0, n('D3'), 'bass', 0.4], [2, n('D3'), 'pad', 0.2], [1, n('F5'), 'piano', 0.35], null,
          null, [1, n('E5'), 'piano', 0.3], [4, R, 'hat', 0.15], null,
          [0, n('A2'), 'bass', 0.35], null, [1, n('D5'), 'piano', 0.3], null,
          null, [1, n('C5'), 'piano', 0.3], [5, R, 'click', 0.12], [3, n('A5'), 'bell', 0.15]
        ]}
      ],
      sequence: [0, 0, 1, 0, 1, 1]
    };

    // ── SNATCHER -- Cyberpunk noir (Snatcher PCE style) ─────────────────
    songs.snatcher = {
      bpm: 110,
      echo: {delay: 280, feedback: 0.4, wet: 0.35, cutoff: 3500},
      instruments: {
        lead: {sample: 'saw', adsr: [0.02, 0.12, 0.55, 0.2], loop: true},
        bass: {sample: 'bass', adsr: [0.01, 0.15, 0.5, 0.1], loop: true},
        kick: {sample: 'kick', adsr: [0.005, 0.2, 0, 0.05], loop: false},
        snare: {sample: 'snare', adsr: [0.005, 0.12, 0, 0.05], loop: false},
        hat: {sample: 'hihat', adsr: [0.005, 0.05, 0, 0.02], loop: false},
        pad: {sample: 'strings', adsr: [0.4, 0.3, 0.45, 0.5], loop: true},
        arp: {sample: 'square25', adsr: [0.01, 0.08, 0.5, 0.1], loop: true}
      },
      patterns: [
        // P0: noir bass groove
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [4, R, 'hat', 0.25], [0, n('E2'), 'bass', 0.5], null,
          null, [4, R, 'hat', 0.2], [0, n('G2'), 'bass', 0.4], null,
          [3, R, 'snare', 0.45], [4, R, 'hat', 0.25], [0, n('A2'), 'bass', 0.45], null,
          [2, R, 'kick', 0.55], [4, R, 'hat', 0.2], [0, n('G2'), 'bass', 0.4], null
        ]},
        // P1: synth lead melody
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [1, n('E4'), 'lead', 0.4], [0, n('E2'), 'bass', 0.5], [4, R, 'hat', 0.2],
          null, [1, n('G4'), 'lead', 0.38], null, [6, n('B3'), 'arp', 0.25],
          [3, R, 'snare', 0.45], [1, n('A4'), 'lead', 0.4], [0, n('A2'), 'bass', 0.45], [4, R, 'hat', 0.2],
          [2, R, 'kick', 0.55], [1, n('G4'), 'lead', 0.38], [6, n('E4'), 'arp', 0.25], null
        ]},
        // P2: dark pad + arps
        {steps: 16, data: [
          [2, R, 'kick', 0.6], [5, n('E3'), 'pad', 0.25], [0, n('E2'), 'bass', 0.5], [6, n('E3'), 'arp', 0.25],
          [4, R, 'hat', 0.2], [6, n('G3'), 'arp', 0.25], null, [6, n('B3'), 'arp', 0.22],
          [3, R, 'snare', 0.45], [6, n('E4'), 'arp', 0.25], [0, n('B1'), 'bass', 0.45], [6, n('B3'), 'arp', 0.22],
          [2, R, 'kick', 0.55], [6, n('G3'), 'arp', 0.25], [4, R, 'hat', 0.2], [6, n('E3'), 'arp', 0.22]
        ]}
      ],
      sequence: [0, 0, 1, 1, 2, 2, 1, 2]
    };

    return songs;
  }

  // ── Engine constructor ──────────────────────────────────────────────────

  function SNESAudioEngine() {
    this._ctx = null;
    this._masterGain = null;
    this._masterFilter = null;
    this._echoInput = null;
    this._echoDelay = null;
    this._echoFeedback = null;
    this._echoFilter = null;
    this._echoWet = null;
    this._echoDry = null;
    this._samples = null;
    this._audioBuffers = {};
    this._song = null;
    this._songName = null;
    this._playing = false;
    this._muted = false;
    this._volume = 0.6;
    this._channels = new Array(8);
    this._seqPos = 0;
    this._stepPos = 0;
    this._timer = null;
    this._nextStepTime = 0;
    this._lookAhead = 0.1;    // seconds to look ahead for scheduling
    this._scheduleInterval = 25; // ms between scheduler calls
    this._toggleBtn = null;

    // Load preferences
    try {
      var stored = localStorage.getItem('snes-audio-volume');
      if (stored !== null) this._volume = parseFloat(stored);
      var mutedStored = localStorage.getItem('snes-audio-muted');
      if (mutedStored === 'true') this._muted = true;
    } catch(e) {}

    // Generate samples
    this._samples = generateSamples();

    // Initialize channels
    for (var i = 0; i < 8; i++) {
      this._channels[i] = {
        source: null,
        gain: null,
        pan: 0,
        active: false
      };
    }
  }

  SNESAudioEngine.prototype._initAudio = function() {
    if (this._ctx) return;
    try {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)({sampleRate: 44100});
    } catch(e) {
      return;
    }

    // Convert raw samples to AudioBuffers
    var self = this;
    var sampleNames = Object.keys(this._samples);
    for (var i = 0; i < sampleNames.length; i++) {
      var name = sampleNames[i];
      var raw = this._samples[name];
      var buf = this._ctx.createBuffer(1, raw.length, SAMPLE_RATE);
      var data = buf.getChannelData(0);
      for (var j = 0; j < raw.length; j++) {
        data[j] = raw[j];
      }
      this._audioBuffers[name] = buf;
    }

    // Master chain: channels -> echoSend + dry -> masterFilter -> masterGain -> destination
    this._masterGain = this._ctx.createGain();
    this._masterGain.gain.value = this._muted ? 0 : this._volume;

    // SPC700 DAC lowpass (~12kHz)
    this._masterFilter = this._ctx.createBiquadFilter();
    this._masterFilter.type = 'lowpass';
    this._masterFilter.frequency.value = 12000;
    this._masterFilter.Q.value = 0.7;

    // Dry path
    this._echoDry = this._ctx.createGain();
    this._echoDry.gain.value = 1.0;

    // Echo system
    this._echoInput = this._ctx.createGain();
    this._echoInput.gain.value = 0.35;

    this._echoDelay = this._ctx.createDelay(1.0);
    this._echoDelay.delayTime.value = 0.25;

    this._echoFeedback = this._ctx.createGain();
    this._echoFeedback.gain.value = 0.3;

    this._echoFilter = this._ctx.createBiquadFilter();
    this._echoFilter.type = 'lowpass';
    this._echoFilter.frequency.value = 3500;
    this._echoFilter.Q.value = 0.5;

    this._echoWet = this._ctx.createGain();
    this._echoWet.gain.value = 0.3;

    // Wire echo: input -> delay -> filter -> feedback -> delay (loop)
    //                                    \-> wet -> masterFilter
    this._echoInput.connect(this._echoDelay);
    this._echoDelay.connect(this._echoFilter);
    this._echoFilter.connect(this._echoFeedback);
    this._echoFeedback.connect(this._echoDelay);
    this._echoFilter.connect(this._echoWet);

    // Mix: dry + wet -> masterFilter -> masterGain -> destination
    this._echoDry.connect(this._masterFilter);
    this._echoWet.connect(this._masterFilter);
    this._masterFilter.connect(this._masterGain);
    this._masterGain.connect(this._ctx.destination);
  };

  SNESAudioEngine.prototype._resumeCtx = function() {
    if (this._ctx && this._ctx.state === 'suspended') {
      this._ctx.resume();
    }
  };

  // ── Configure echo from song settings ────────────────────────────────

  SNESAudioEngine.prototype._configureEcho = function(echoSettings) {
    if (!this._ctx || !echoSettings) return;
    var e = echoSettings;
    this._echoDelay.delayTime.value = Math.max(0.05, Math.min(0.5, (e.delay || 250) / 1000));
    this._echoFeedback.gain.value = Math.max(0, Math.min(0.9, e.feedback || 0.3));
    this._echoWet.gain.value = Math.max(0, Math.min(1, e.wet || 0.3));
    this._echoFilter.frequency.value = e.cutoff || 3500;
  };

  // ── Play a note on a channel ──────────────────────────────────────────

  SNESAudioEngine.prototype._playNote = function(channel, midiNote, instrument, volume, time) {
    if (!this._ctx || channel < 0 || channel >= 8) return;
    if (!instrument) return;

    var inst = this._song.instruments[instrument];
    if (!inst) return;

    var buf = this._audioBuffers[inst.sample];
    if (!buf) return;

    // Stop any existing note on this channel
    var ch = this._channels[channel];
    if (ch.source) {
      try { ch.source.stop(time); } catch(e) {}
    }

    // For rest notes, just cut the channel
    if (midiNote === R) {
      ch.active = false;
      return;
    }

    var freq = NOTE_FREQ[midiNote] || 440;
    // playbackRate for pitch-shifting: base sample is at ~C4 (261.6Hz)
    // We play 1 cycle of waveform in SAMPLE_LEN samples at SAMPLE_RATE
    // So base frequency = SAMPLE_RATE / SAMPLE_LEN
    var baseFreq = SAMPLE_RATE / SAMPLE_LEN;
    var rate = freq / baseFreq;

    // Create source
    var source = this._ctx.createBufferSource();
    source.buffer = buf;
    source.playbackRate.value = rate;
    source.loop = inst.loop !== false;

    // ADSR envelope
    var adsr = inst.adsr || [0.01, 0.1, 0.5, 0.1];
    var attack = adsr[0];
    var decay = adsr[1];
    var sustain = adsr[2];
    var release = adsr[3];
    var vol = (volume || 0.5) * 0.5; // Scale down for mixing headroom

    var env = this._ctx.createGain();
    env.gain.setValueAtTime(0.001, time);
    env.gain.linearRampToValueAtTime(vol, time + attack);
    env.gain.linearRampToValueAtTime(vol * sustain, time + attack + decay);

    // For non-looping samples, apply release after a fixed duration
    if (!inst.loop) {
      var noteLen = attack + decay + 0.05;
      env.gain.linearRampToValueAtTime(0.001, time + noteLen + release);
      source.stop(time + noteLen + release + 0.01);
    }

    // Pan
    var panner = null;
    if (this._ctx.createStereoPanner) {
      panner = this._ctx.createStereoPanner();
      panner.pan.value = ch.pan || 0;
    }

    // Connect: source -> env -> panner? -> dry + echoInput
    source.connect(env);
    var last = env;
    if (panner) {
      env.connect(panner);
      last = panner;
    }
    last.connect(this._echoDry);
    last.connect(this._echoInput);

    source.start(time);

    ch.source = source;
    ch.gain = env;
    ch.active = true;

    // Store release info for later
    ch._adsr = adsr;
    ch._vol = vol;
    ch._startTime = time;
  };

  // ── Sequencer ─────────────────────────────────────────────────────────

  SNESAudioEngine.prototype._scheduleStep = function(time) {
    if (!this._song) return;

    var seq = this._song.sequence;
    var patIdx = seq[this._seqPos % seq.length];
    var pattern = this._song.patterns[patIdx];
    if (!pattern) return;

    var step = pattern.data[this._stepPos];
    if (step) {
      // step = [channel, note, instrument, volume, fx]
      this._playNote(step[0], step[1], step[2], step[3] || 0.5, time);
    }

    // Advance step
    this._stepPos++;
    if (this._stepPos >= pattern.steps) {
      this._stepPos = 0;
      this._seqPos++;
      if (this._seqPos >= seq.length) {
        this._seqPos = 0; // loop song
      }
    }
  };

  SNESAudioEngine.prototype._scheduler = function() {
    if (!this._playing || !this._ctx) return;

    var bpm = this._song ? this._song.bpm || 120 : 120;
    var stepDuration = 60.0 / bpm / 4; // 16th note steps

    while (this._nextStepTime < this._ctx.currentTime + this._lookAhead) {
      this._scheduleStep(this._nextStepTime);
      this._nextStepTime += stepDuration;
    }
  };

  // ── Public API ────────────────────────────────────────────────────────

  SNESAudioEngine.prototype.loadSong = function(name) {
    var songs = getSongs();
    if (songs[name]) {
      this._song = songs[name];
      this._songName = name;
      return true;
    }
    return false;
  };

  SNESAudioEngine.prototype.play = function() {
    if (this._playing) return;
    this._initAudio();
    this._resumeCtx();
    if (!this._ctx || !this._song) return;

    this._configureEcho(this._song.echo);
    this._playing = true;
    this._seqPos = 0;
    this._stepPos = 0;
    this._nextStepTime = this._ctx.currentTime + 0.05;

    var self = this;
    this._timer = setInterval(function() { self._scheduler(); }, this._scheduleInterval);
  };

  SNESAudioEngine.prototype.stop = function() {
    this._playing = false;
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
    // Stop all channels
    for (var i = 0; i < 8; i++) {
      var ch = this._channels[i];
      if (ch.source) {
        try { ch.source.stop(); } catch(e) {}
        ch.source = null;
      }
      ch.active = false;
    }
  };

  SNESAudioEngine.prototype.pause = function() {
    if (!this._playing) return;
    this._playing = false;
    if (this._timer) {
      clearInterval(this._timer);
      this._timer = null;
    }
  };

  SNESAudioEngine.prototype.resume = function() {
    if (this._playing) return;
    this._resumeCtx();
    if (!this._ctx || !this._song) return;

    this._playing = true;
    this._nextStepTime = this._ctx.currentTime + 0.05;

    var self = this;
    this._timer = setInterval(function() { self._scheduler(); }, this._scheduleInterval);
  };

  SNESAudioEngine.prototype.setVolume = function(v) {
    this._volume = Math.max(0, Math.min(1, v));
    if (this._masterGain && !this._muted) {
      this._masterGain.gain.value = this._volume;
    }
    try { localStorage.setItem('snes-audio-volume', this._volume.toString()); } catch(e) {}
  };

  SNESAudioEngine.prototype.getVolume = function() {
    return this._volume;
  };

  SNESAudioEngine.prototype.toggleMute = function() {
    this._muted = !this._muted;
    if (this._masterGain) {
      this._masterGain.gain.value = this._muted ? 0 : this._volume;
    }
    try { localStorage.setItem('snes-audio-muted', this._muted ? 'true' : 'false'); } catch(e) {}
    return this._muted;
  };

  SNESAudioEngine.prototype.isMuted = function() {
    return this._muted;
  };

  SNESAudioEngine.prototype.isPlaying = function() {
    return this._playing;
  };

  SNESAudioEngine.prototype.getSongName = function() {
    return this._songName;
  };

  // List available songs
  SNESAudioEngine.prototype.listSongs = function() {
    return Object.keys(getSongs());
  };

  // ── Music toggle button ───────────────────────────────────────────────
  // Creates a pixel-art styled speaker icon toggle button.

  SNESAudioEngine.prototype.createToggle = function(container) {
    var self = this;
    var btn = document.createElement('button');
    btn.className = 'snes-audio-toggle';
    btn.setAttribute('aria-label', 'Toggle music');
    btn.title = 'Toggle music';

    function updateBtn() {
      // 8x8 pixel speaker icon via box-shadow
      var on = !self._muted && self._playing;
      btn.innerHTML = '';
      var canvas = document.createElement('canvas');
      canvas.width = 16;
      canvas.height = 16;
      canvas.style.cssText = 'width:16px;height:16px;image-rendering:pixelated;';
      var cx = canvas.getContext('2d');
      var c = on ? '#33ff33' : '#555';
      cx.fillStyle = c;
      // Speaker body
      cx.fillRect(2, 5, 3, 6);
      cx.fillRect(5, 3, 2, 10);
      if (on) {
        // Sound waves
        cx.fillRect(9, 4, 1, 1);
        cx.fillRect(10, 5, 1, 1);
        cx.fillRect(10, 10, 1, 1);
        cx.fillRect(9, 11, 1, 1);
        cx.fillRect(9, 7, 1, 2);
        cx.fillRect(12, 3, 1, 1);
        cx.fillRect(13, 5, 1, 2);
        cx.fillRect(13, 9, 1, 2);
        cx.fillRect(12, 12, 1, 1);
      } else {
        // X mark for muted
        cx.fillStyle = '#ff4444';
        cx.fillRect(9, 5, 1, 1);
        cx.fillRect(10, 6, 1, 1);
        cx.fillRect(11, 7, 1, 1);
        cx.fillRect(12, 8, 1, 1);
        cx.fillRect(13, 9, 1, 1);
        cx.fillRect(13, 5, 1, 1);
        cx.fillRect(12, 6, 1, 1);
        cx.fillRect(10, 8, 1, 1);
        cx.fillRect(9, 9, 1, 1);
      }
      btn.appendChild(canvas);
    }

    btn.style.cssText =
      'position:fixed;bottom:16px;right:56px;z-index:999;' +
      'background:rgba(10,10,15,0.85);border:2px solid #1e1e2a;' +
      'color:#c8c8d0;width:32px;height:32px;cursor:pointer;padding:0;' +
      'font-family:monospace;display:flex;align-items:center;justify-content:center;' +
      'border-radius:0;box-shadow:2px 2px 0 rgba(0,0,0,0.5);';

    updateBtn();

    btn.addEventListener('click', function() {
      self._initAudio();
      self._resumeCtx();
      if (!self._playing && self._song) {
        self.play();
      } else if (self._playing) {
        self.toggleMute();
      }
      updateBtn();
    });

    // Double-click to stop/restart
    btn.addEventListener('dblclick', function(e) {
      e.preventDefault();
      if (self._playing) {
        self.stop();
      } else if (self._song) {
        self.play();
      }
      updateBtn();
    });

    this._toggleBtn = btn;
    (container || document.body).appendChild(btn);
    return btn;
  };

  return SNESAudioEngine;
})();
