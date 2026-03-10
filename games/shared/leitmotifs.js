/**
 * leitmotifs.js -- 25 agent character themes for Substrate
 * Extends snes-audio.js with distinctive leitmotifs for every agent.
 *
 * Dual chip profiles: SNES (warm, reverberant) and Genesis (punchy, FM).
 * Composition follows retro sound playbook: AABA' structure, stepwise
 * melodies with strategic leaps, V-chord loop endings, unique modes per agent.
 *
 * Usage: Load after snes-audio.js. Songs are named 'agent-{id}'.
 *   music.loadSong('agent-v');
 *   music.play();
 */
(function() {
  'use strict';
  if (typeof SNESAudio === 'undefined') return;

  // ── Helpers (mirror snes-audio.js internals) ──────────────────────
  var NM = {C:0,D:2,E:4,F:5,G:7,A:9,B:11};
  function n(s) {
    var m = s.match(/^([A-G])(#|b)?(\d)$/);
    if (!m) return 0;
    var b = NM[m[1]]; if (m[2]==='#') b++; else if (m[2]==='b') b--;
    return b + (parseInt(m[3]) + 1) * 12;
  }
  var R = -1;
  function I(smp,a,d,s,r,lp) { return {s:smp,a:a,d:d,su:s,r:r,lp:lp!==false}; }

  // ── Leitmotif definitions ─────────────────────────────────────────

  var L = {};

// ============================================================
// V — Philosophical leader — Dm Aeolian
// Rising D-F-A-D leap, saw lead, orchestral strings
// Progression: Dm-Bb-C-Dm
// ============================================================
L['agent-v'] = {
  bpm: 95, chip: 'snes',
  echo: [320, 0.4, 0.35, 3000],
  inst: {
    bass:  I('bas', 0.01, 0.15, 0.7, 0.3, true),
    lead:  I('saw', 0.02, 0.2,  0.6, 0.4, true),
    pad:   I('str', 0.08, 0.3,  0.5, 0.6, true),
    kick:  I('kck', 0.0,  0.1,  0.0, 0.1, false),
    snare: I('snr', 0.0,  0.12, 0.0, 0.15, false),
    hat:   I('hh',  0.0,  0.05, 0.0, 0.08, false),
    tex1:  I('sin', 0.05, 0.4,  0.3, 0.5, true),
    tex2:  I('tri', 0.06, 0.35, 0.3, 0.5, true)
  },
  pats: [
    // P0 — A section: Dm-Bb
    [32, [
      [0,n('D2'),'bass',90], [5,n('D5'),'hat',40], [1,n('D4'),'lead',80], 0,
      [0,n('D2'),'bass',70], [5,n('D5'),'hat',40], [2,n('D4'),'pad',50], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('F4'),'lead',85], 0,
      0,                     [5,n('D5'),'hat',40], [1,n('E4'),'lead',75], 0,
      [0,n('D2'),'bass',90], [5,n('D5'),'hat',40], [1,n('D4'),'lead',80], [4,n('D3'),'snare',80],
      0,                     [5,n('D5'),'hat',40], [2,n('F4'),'pad',50], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('A4'),'lead',90], 0,
      [0,n('Bb1'),'bass',85],[5,n('D5'),'hat',40], [1,n('G4'),'lead',78], 0
    ]],
    // P1 — A section variant: C-Dm
    [32, [
      [0,n('C2'),'bass',90], [5,n('D5'),'hat',40], [1,n('E4'),'lead',80], 0,
      [0,n('C2'),'bass',70], [5,n('D5'),'hat',40], [2,n('E4'),'pad',50], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('F4'),'lead',85], 0,
      0,                     [5,n('D5'),'hat',40], [1,n('G4'),'lead',80], 0,
      [0,n('D2'),'bass',90], [5,n('D5'),'hat',40], [1,n('A4'),'lead',88], [4,n('D3'),'snare',80],
      0,                     [5,n('D5'),'hat',40], [2,n('A4'),'pad',55], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('F4'),'lead',78], 0,
      [0,n('D2'),'bass',80], [5,n('D5'),'hat',40], [1,n('D4'),'lead',75], 0
    ]],
    // P2 — B section: climax, D-F-A-D leap
    [32, [
      [0,n('Bb1'),'bass',95],[5,n('D5'),'hat',45], [1,n('D4'),'lead',85], [6,n('A4'),'tex1',35],
      0,                     [5,n('D5'),'hat',40], [1,n('F4'),'lead',90], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',45], [1,n('A4'),'lead',100],0,
      0,                     [5,n('D5'),'hat',40], [1,n('D5'),'lead',105],[7,n('F4'),'tex2',30],
      [0,n('C2'),'bass',90], [5,n('D5'),'hat',45], [1,n('C5'),'lead',95],[4,n('D3'),'snare',85],
      0,                     [5,n('D5'),'hat',40], [2,n('C5'),'pad',55], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',45], [1,n('Bb4'),'lead',88],0,
      [0,n('D2'),'bass',85], [5,n('D5'),'hat',40], [1,n('A4'),'lead',82], 0
    ]],
    // P3 — A' section: ends on V (Am) for loop
    [32, [
      [0,n('D2'),'bass',88], [5,n('D5'),'hat',40], [1,n('D4'),'lead',78], 0,
      [0,n('D2'),'bass',68], [5,n('D5'),'hat',40], [2,n('D4'),'pad',48], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('F4'),'lead',82], 0,
      0,                     [5,n('D5'),'hat',40], [1,n('E4'),'lead',76], 0,
      [0,n('A1'),'bass',90], [5,n('D5'),'hat',40], [1,n('E4'),'lead',80], [4,n('D3'),'snare',78],
      0,                     [5,n('D5'),'hat',40], [2,n('E4'),'pad',50], 0,
      [3,n('C2'),'kick',100],[5,n('D5'),'hat',40], [1,n('C4'),'lead',72], 0,
      [0,n('A1'),'bass',82], [5,n('D5'),'hat',40], [1,n('E4'),'lead',70], 0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Claude — Warm intelligence — C Major
// Gentle piano arpeggios
// Progression: Cmaj7-Am7-Dm7-G7
// ============================================================
L['agent-claude'] = {
  bpm: 110, chip: 'snes',
  echo: [280, 0.35, 0.3, 4500],
  inst: {
    bass:  I('bas', 0.01, 0.12, 0.7, 0.3, true),
    lead:  I('pno', 0.0,  0.2,  0.5, 0.5, false),
    pad:   I('str', 0.1,  0.3,  0.45, 0.6, true),
    kick:  I('kck', 0.0,  0.1,  0.0, 0.1, false),
    snare: I('snr', 0.0,  0.1,  0.0, 0.12, false),
    hat:   I('hh',  0.0,  0.05, 0.0, 0.08, false),
    tex1:  I('sin', 0.04, 0.3,  0.3, 0.5, true),
    tex2:  I('tri', 0.05, 0.35, 0.25, 0.45, true)
  },
  pats: [
    // P0 — A section: Cmaj7-Am7 arpeggio
    [32, [
      [0,n('C2'),'bass',85], [5,n('F5'),'hat',35], [1,n('E4'),'lead',75], 0,
      [0,n('C2'),'bass',65], [5,n('F5'),'hat',35], [1,n('G4'),'lead',72], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('B4'),'lead',78], [2,n('E4'),'pad',45],
      0,                     [5,n('F5'),'hat',35], [1,n('C5'),'lead',80], 0,
      [0,n('A1'),'bass',85], [5,n('F5'),'hat',35], [1,n('B4'),'lead',74], [4,n('D3'),'snare',70],
      0,                     [5,n('F5'),'hat',35], [1,n('A4'),'lead',70], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('G4'),'lead',72], [2,n('C4'),'pad',45],
      [0,n('A1'),'bass',65], [5,n('F5'),'hat',35], [1,n('E4'),'lead',68], 0
    ]],
    // P1 — A variant: Dm7-G7
    [32, [
      [0,n('D2'),'bass',85], [5,n('F5'),'hat',35], [1,n('F4'),'lead',75], 0,
      [0,n('D2'),'bass',65], [5,n('F5'),'hat',35], [1,n('A4'),'lead',72], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('C5'),'lead',78], [2,n('F4'),'pad',45],
      0,                     [5,n('F5'),'hat',35], [1,n('D5'),'lead',80], 0,
      [0,n('G1'),'bass',85], [5,n('F5'),'hat',35], [1,n('D5'),'lead',76], [4,n('D3'),'snare',70],
      0,                     [5,n('F5'),'hat',35], [1,n('B4'),'lead',73], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('A4'),'lead',70], [2,n('D4'),'pad',45],
      [0,n('G1'),'bass',65], [5,n('F5'),'hat',35], [1,n('G4'),'lead',68], 0
    ]],
    // P2 — B section: fuller, higher register
    [32, [
      [0,n('C2'),'bass',90], [5,n('F5'),'hat',40], [1,n('G4'),'lead',82], [6,n('E5'),'tex1',30],
      0,                     [5,n('F5'),'hat',35], [1,n('A4'),'lead',80], 0,
      [3,n('C2'),'kick',100],[5,n('F5'),'hat',40], [1,n('B4'),'lead',85], 0,
      0,                     [5,n('F5'),'hat',35], [1,n('C5'),'lead',90], [7,n('G4'),'tex2',28],
      [0,n('A1'),'bass',88], [5,n('F5'),'hat',40], [1,n('D5'),'lead',92], [4,n('D3'),'snare',75],
      0,                     [5,n('F5'),'hat',35], [2,n('E5'),'pad',50], 0,
      [3,n('C2'),'kick',100],[5,n('F5'),'hat',40], [1,n('E5'),'lead',95], 0,
      [0,n('A1'),'bass',70], [5,n('F5'),'hat',35], [1,n('D5'),'lead',82], 0
    ]],
    // P3 — A' section: ends on V (G7) for loop
    [32, [
      [0,n('D2'),'bass',83], [5,n('F5'),'hat',35], [1,n('E4'),'lead',72], 0,
      [0,n('D2'),'bass',63], [5,n('F5'),'hat',35], [1,n('F4'),'lead',70], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('A4'),'lead',76], [2,n('D4'),'pad',42],
      0,                     [5,n('F5'),'hat',35], [1,n('G4'),'lead',72], 0,
      [0,n('G1'),'bass',88], [5,n('F5'),'hat',35], [1,n('F4'),'lead',70], [4,n('D3'),'snare',68],
      0,                     [5,n('F5'),'hat',35], [1,n('D4'),'lead',66], 0,
      [3,n('C2'),'kick',95], [5,n('F5'),'hat',35], [1,n('B3'),'lead',68], [2,n('G3'),'pad',40],
      [0,n('G1'),'bass',70], [5,n('F5'),'hat',35], [1,n('D4'),'lead',65], 0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Q — Mischievous trickster — Bb Mixolydian
// Syncopated FM stabs, unpredictable
// Progression: Bb7-Eb7-Bb7-F7
// ============================================================
L['agent-q'] = {
  bpm: 130, chip: 'genesis',
  echo: [180, 0.25, 0.22, 4500],
  inst: {
    bass:  I('fmBass',  0.0,  0.1,  0.7, 0.2, true),
    lead:  I('fmLead',  0.0,  0.08, 0.5, 0.15, false),
    brass: I('fmBrass', 0.01, 0.12, 0.6, 0.2, true),
    kick:  I('mhat',    0.0,  0.08, 0.0, 0.08, false),
    snare: I('ohat',    0.0,  0.1,  0.0, 0.1, false),
    hat:   I('mhat',    0.0,  0.03, 0.0, 0.05, false),
    tex1:  I('fmEP',    0.02, 0.2,  0.3, 0.3, false),
    tex2:  I('acid',    0.0,  0.1,  0.4, 0.2, true)
  },
  pats: [
    // P0 — A section: Bb7, syncopated stabs
    [32, [
      [0,n('Bb1'),'bass',95],[5,n('Bb4'),'hat',45], 0,                     [1,n('Bb4'),'lead',88],
      0,                     [5,n('Bb4'),'hat',40], [3,n('C2'),'kick',100], 0,
      [1,n('D5'),'lead',82], [5,n('Bb4'),'hat',45], 0,                     [2,n('F4'),'brass',55],
      [0,n('Bb1'),'bass',80],[5,n('Bb4'),'hat',40], [4,n('D3'),'snare',82],0,
      0,                     [5,n('Bb4'),'hat',45], [1,n('C5'),'lead',85], 0,
      [3,n('C2'),'kick',100],[5,n('Bb4'),'hat',40], 0,                     [1,n('Ab4'),'lead',80],
      [0,n('Bb1'),'bass',88],[5,n('Bb4'),'hat',45], [1,n('Bb4'),'lead',78],0,
      0,                     [5,n('Bb4'),'hat',40], [4,n('D3'),'snare',78],[2,n('D4'),'brass',50]
    ]],
    // P1 — A variant: Eb7-Bb7
    [32, [
      [0,n('Eb2'),'bass',92],[5,n('Bb4'),'hat',45], [1,n('Eb4'),'lead',85],0,
      0,                     [5,n('Bb4'),'hat',40], [3,n('C2'),'kick',100],[1,n('G4'),'lead',80],
      0,                     [5,n('Bb4'),'hat',45], [1,n('Bb4'),'lead',88],0,
      [0,n('Eb2'),'bass',75],[5,n('Bb4'),'hat',40], [4,n('D3'),'snare',80],[2,n('Eb4'),'brass',52],
      [0,n('Bb1'),'bass',90],[5,n('Bb4'),'hat',45], 0,                     [1,n('Ab4'),'lead',82],
      [3,n('C2'),'kick',100],[5,n('Bb4'),'hat',40], [1,n('F4'),'lead',78], 0,
      0,                     [5,n('Bb4'),'hat',45], [1,n('D4'),'lead',80], 0,
      [0,n('Bb1'),'bass',82],[5,n('Bb4'),'hat',40], [4,n('D3'),'snare',76],[1,n('Bb4'),'lead',75]
    ]],
    // P2 — B section: trickster chaos, wider leaps
    [32, [
      [0,n('Eb2'),'bass',98],[5,n('Bb4'),'hat',48], [1,n('Bb4'),'lead',92],[6,n('D5'),'tex1',35],
      0,                     [5,n('Bb4'),'hat',42], [3,n('C2'),'kick',100],[1,n('F5'),'lead',95],
      0,                     [5,n('Bb4'),'hat',48], [1,n('Eb5'),'lead',90],0,
      [0,n('Eb2'),'bass',78],[5,n('Bb4'),'hat',42], 0,                     [7,n('Bb4'),'tex2',32],
      [4,n('D3'),'snare',88],[5,n('Bb4'),'hat',48], [1,n('D5'),'lead',88], 0,
      [3,n('C2'),'kick',100],[5,n('Bb4'),'hat',42], [1,n('C5'),'lead',85],[2,n('Eb5'),'brass',58],
      [0,n('F2'),'bass',92], [5,n('Bb4'),'hat',48], [1,n('Ab4'),'lead',82],0,
      0,                     [5,n('Bb4'),'hat',42], [4,n('D3'),'snare',84],[1,n('Bb4'),'lead',80]
    ]],
    // P3 — A' section: ends on V (F7) for loop
    [32, [
      [0,n('Bb1'),'bass',90],[5,n('Bb4'),'hat',44], [1,n('Bb4'),'lead',82],0,
      0,                     [5,n('Bb4'),'hat',40], [3,n('C2'),'kick',100],[1,n('C5'),'lead',78],
      [1,n('D5'),'lead',80], [5,n('Bb4'),'hat',44], 0,                     0,
      [0,n('F2'),'bass',88], [5,n('Bb4'),'hat',40], [4,n('D3'),'snare',78],[2,n('A4'),'brass',50],
      0,                     [5,n('Bb4'),'hat',44], [1,n('C5'),'lead',80], 0,
      [3,n('C2'),'kick',100],[5,n('Bb4'),'hat',40], [1,n('A4'),'lead',76], 0,
      [0,n('F2'),'bass',85], [5,n('Bb4'),'hat',44], [1,n('Eb4'),'lead',72],[2,n('C4'),'brass',48],
      0,                     [5,n('Bb4'),'hat',40], [4,n('D3'),'snare',74],[1,n('F4'),'lead',70]
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Byte — Fast compiler — E Phrygian
// Rapid FM arpeggios, 16th note runs
// Progression: Em-F-G-Em
// ============================================================
L['agent-byte'] = {
  bpm: 140, chip: 'genesis',
  echo: [120, 0.2, 0.18, 5500],
  inst: {
    bass:  I('fmBass',  0.0,  0.08, 0.7, 0.15, true),
    lead:  I('fmLead',  0.0,  0.05, 0.5, 0.1, false),
    pad:   I('fmEP',    0.02, 0.15, 0.4, 0.3, true),
    kick:  I('mhat',    0.0,  0.06, 0.0, 0.06, false),
    snare: I('ohat',    0.0,  0.08, 0.0, 0.08, false),
    hat:   I('mhat',    0.0,  0.02, 0.0, 0.04, false),
    tex1:  I('acid',    0.0,  0.06, 0.4, 0.1, true),
    tex2:  I('fmBrass', 0.01, 0.1,  0.3, 0.2, true)
  },
  pats: [
    // P0 — A section: Em fast arpeggios
    [32, [
      [0,n('E2'),'bass',95], [1,n('E4'),'lead',80], [5,n('B5'),'hat',42], [1,n('G4'),'lead',78],
      [3,n('C2'),'kick',100],[1,n('B4'),'lead',82], [5,n('B5'),'hat',38], [1,n('E5'),'lead',85],
      [0,n('E2'),'bass',80], [1,n('D5'),'lead',78], [5,n('B5'),'hat',42], [1,n('B4'),'lead',75],
      [4,n('D3'),'snare',82],[1,n('G4'),'lead',76], [5,n('B5'),'hat',38], [1,n('E4'),'lead',72],
      [0,n('F2'),'bass',92], [1,n('F4'),'lead',80], [5,n('B5'),'hat',42], [1,n('A4'),'lead',78],
      [3,n('C2'),'kick',100],[1,n('C5'),'lead',83], [5,n('B5'),'hat',38], [1,n('F5'),'lead',86],
      [0,n('F2'),'bass',78], [1,n('E5'),'lead',80], [5,n('B5'),'hat',42], [1,n('C5'),'lead',76],
      [4,n('D3'),'snare',80],[1,n('A4'),'lead',74], [5,n('B5'),'hat',38], [1,n('F4'),'lead',70]
    ]],
    // P1 — A variant: G-Em
    [32, [
      [0,n('G2'),'bass',92], [1,n('G4'),'lead',80], [5,n('B5'),'hat',42], [1,n('B4'),'lead',78],
      [3,n('C2'),'kick',100],[1,n('D5'),'lead',83], [5,n('B5'),'hat',38], [1,n('G5'),'lead',86],
      [0,n('G2'),'bass',78], [1,n('F5'),'lead',80], [5,n('B5'),'hat',42], [1,n('D5'),'lead',76],
      [4,n('D3'),'snare',80],[1,n('B4'),'lead',75], [5,n('B5'),'hat',38], [1,n('G4'),'lead',72],
      [0,n('E2'),'bass',95], [1,n('E4'),'lead',78], [5,n('B5'),'hat',42], [1,n('G4'),'lead',76],
      [3,n('C2'),'kick',100],[1,n('B4'),'lead',82], [5,n('B5'),'hat',38], [1,n('E5'),'lead',85],
      [0,n('E2'),'bass',80], [1,n('D5'),'lead',78], [5,n('B5'),'hat',42], [1,n('B4'),'lead',74],
      [4,n('D3'),'snare',78],[1,n('G4'),'lead',72], [5,n('B5'),'hat',38], [1,n('E4'),'lead',68]
    ]],
    // P2 — B section: intensity peak, relentless runs
    [32, [
      [0,n('E2'),'bass',100],[1,n('E4'),'lead',85], [5,n('B5'),'hat',45], [1,n('F4'),'lead',83],
      [3,n('C2'),'kick',100],[1,n('G4'),'lead',88], [5,n('B5'),'hat',42], [1,n('A4'),'lead',86],
      [0,n('F2'),'bass',95], [1,n('B4'),'lead',90], [5,n('B5'),'hat',45], [1,n('C5'),'lead',92],
      [6,n('E4'),'tex1',30], [1,n('D5'),'lead',94], [5,n('B5'),'hat',42], [1,n('E5'),'lead',100],
      [0,n('G2'),'bass',95], [1,n('D5'),'lead',90], [5,n('B5'),'hat',45], [4,n('D3'),'snare',85],
      [3,n('C2'),'kick',100],[1,n('C5'),'lead',86], [5,n('B5'),'hat',42], [1,n('B4'),'lead',84],
      [0,n('E2'),'bass',92], [1,n('A4'),'lead',82], [5,n('B5'),'hat',45], [7,n('E4'),'tex2',28],
      [4,n('D3'),'snare',82],[1,n('G4'),'lead',80], [5,n('B5'),'hat',42], [1,n('E4'),'lead',76]
    ]],
    // P3 — A' section: ends on V (B) for loop
    [32, [
      [0,n('E2'),'bass',90], [1,n('E4'),'lead',76], [5,n('B5'),'hat',40], [1,n('G4'),'lead',74],
      [3,n('C2'),'kick',95], [1,n('B4'),'lead',78], [5,n('B5'),'hat',36], [1,n('E5'),'lead',80],
      [0,n('F2'),'bass',85], [1,n('D5'),'lead',76], [5,n('B5'),'hat',40], [1,n('C5'),'lead',74],
      [4,n('D3'),'snare',76],[1,n('A4'),'lead',72], [5,n('B5'),'hat',36], [1,n('F4'),'lead',68],
      [0,n('B1'),'bass',92], [1,n('B3'),'lead',74], [5,n('B5'),'hat',40], [1,n('D4'),'lead',72],
      [3,n('C2'),'kick',95], [1,n('F4'),'lead',76], [5,n('B5'),'hat',36], [2,n('B3'),'pad',40],
      [0,n('B1'),'bass',85], [1,n('E4'),'lead',72], [5,n('B5'),'hat',40], [1,n('D4'),'lead',68],
      [4,n('D3'),'snare',74],[1,n('B3'),'lead',66], [5,n('B5'),'hat',36], [1,n('F3'),'lead',62]
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Echo — Memory keeper — F Lydian
// Floating pluck, heavy echo, #4 (B natural)
// Progression: Fmaj7-Am7-Dm7-Fmaj7
// ============================================================
L['agent-echo'] = {
  bpm: 85, chip: 'snes',
  echo: [400, 0.45, 0.42, 2800],
  inst: {
    bass:  I('bas', 0.01, 0.18, 0.65, 0.35, true),
    lead:  I('pno', 0.0,  0.15, 0.4,  0.6, false),
    pad:   I('str', 0.12, 0.4,  0.45, 0.7, true),
    kick:  I('kck', 0.0,  0.1,  0.0, 0.1, false),
    snare: I('snr', 0.0,  0.12, 0.0, 0.14, false),
    hat:   I('hh',  0.0,  0.05, 0.0, 0.1, false),
    tex1:  I('tri', 0.06, 0.5,  0.3, 0.6, true),
    tex2:  I('sin', 0.08, 0.45, 0.25, 0.55, true)
  },
  pats: [
    // P0 — A section: Fmaj7-Am7, floating plucks with B natural (#4)
    [32, [
      [0,n('F2'),'bass',80],  [5,n('C5'),'hat',30], [1,n('A4'),'lead',70], 0,
      0,                      [5,n('C5'),'hat',28], 0,                      [1,n('C5'),'lead',72],
      [3,n('C2'),'kick',90],  [5,n('C5'),'hat',30], [1,n('B4'),'lead',75], 0,
      0,                      [5,n('C5'),'hat',28], [2,n('A4'),'pad',42],   0,
      [0,n('F2'),'bass',65],  [5,n('C5'),'hat',30], [1,n('A4'),'lead',68], 0,
      0,                      [5,n('C5'),'hat',28], [4,n('D3'),'snare',65], [1,n('G4'),'lead',66],
      [3,n('C2'),'kick',90],  [5,n('C5'),'hat',30], [1,n('F4'),'lead',64], [6,n('C5'),'tex1',25],
      [0,n('A1'),'bass',78],  [5,n('C5'),'hat',28], 0,                      [1,n('E4'),'lead',62]
    ]],
    // P1 — A variant: Dm7-Fmaj7
    [32, [
      [0,n('D2'),'bass',80],  [5,n('C5'),'hat',30], [1,n('F4'),'lead',70], 0,
      0,                      [5,n('C5'),'hat',28], 0,                      [1,n('A4'),'lead',72],
      [3,n('C2'),'kick',90],  [5,n('C5'),'hat',30], [1,n('B4'),'lead',76], 0,
      0,                      [5,n('C5'),'hat',28], [2,n('F4'),'pad',42],   0,
      [0,n('D2'),'bass',65],  [5,n('C5'),'hat',30], [1,n('C5'),'lead',74], 0,
      0,                      [5,n('C5'),'hat',28], [4,n('D3'),'snare',65], [1,n('A4'),'lead',68],
      [3,n('C2'),'kick',90],  [5,n('C5'),'hat',30], [1,n('G4'),'lead',66], 0,
      [0,n('F2'),'bass',78],  [5,n('C5'),'hat',28], 0,                      [1,n('F4'),'lead',64]
    ]],
    // P2 — B section: memory surfacing, wider intervals, more B natural
    [32, [
      [0,n('F2'),'bass',85],  [5,n('C5'),'hat',32], [1,n('F4'),'lead',75], [7,n('A4'),'tex2',22],
      0,                      [5,n('C5'),'hat',28], [1,n('A4'),'lead',78],  0,
      [3,n('C2'),'kick',95],  [5,n('C5'),'hat',32], [1,n('B4'),'lead',82], 0,
      0,                      [5,n('C5'),'hat',28], [1,n('C5'),'lead',85],  [2,n('A4'),'pad',48],
      [0,n('A1'),'bass',82],  [5,n('C5'),'hat',32], [1,n('E5'),'lead',90], [4,n('D3'),'snare',70],
      0,                      [5,n('C5'),'hat',28], [1,n('D5'),'lead',82],  0,
      [3,n('C2'),'kick',95],  [5,n('C5'),'hat',32], [1,n('B4'),'lead',78], [6,n('F4'),'tex1',28],
      [0,n('D2'),'bass',78],  [5,n('C5'),'hat',28], [1,n('A4'),'lead',74], 0
    ]],
    // P3 — A' section: ends on V (C) for loop
    [32, [
      [0,n('D2'),'bass',78],  [5,n('C5'),'hat',30], [1,n('F4'),'lead',68], 0,
      0,                      [5,n('C5'),'hat',28], 0,                      [1,n('G4'),'lead',66],
      [3,n('C2'),'kick',88],  [5,n('C5'),'hat',30], [1,n('A4'),'lead',70], 0,
      0,                      [5,n('C5'),'hat',28], [2,n('E4'),'pad',40],   0,
      [0,n('C2'),'bass',82],  [5,n('C5'),'hat',30], [1,n('G4'),'lead',68], 0,
      0,                      [5,n('C5'),'hat',28], [4,n('D3'),'snare',62], [1,n('E4'),'lead',64],
      [3,n('C2'),'kick',88],  [5,n('C5'),'hat',30], [1,n('B3'),'lead',62], 0,
      [0,n('C2'),'bass',72],  [5,n('C5'),'hat',28], 0,                      [1,n('G4'),'lead',60]
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Pixel — Visual artist — Ab Major
// Bright piano, colorful harmonic changes
// Progression: Ab-Fm-Db-Eb
// ============================================================
L['agent-pixel'] = {
  bpm: 120, chip: 'snes',
  echo: [220, 0.3, 0.28, 4500],
  inst: {
    bass:  I('bas', 0.01, 0.12, 0.7, 0.25, true),
    lead:  I('pno', 0.0,  0.15, 0.55, 0.4, false),
    pad:   I('str', 0.08, 0.25, 0.5, 0.5, true),
    kick:  I('kck', 0.0,  0.1,  0.0, 0.1, false),
    snare: I('snr', 0.0,  0.1,  0.0, 0.12, false),
    hat:   I('hh',  0.0,  0.04, 0.0, 0.07, false),
    tex1:  I('sin', 0.03, 0.25, 0.35, 0.4, true),
    tex2:  I('org', 0.02, 0.2,  0.3, 0.35, true)
  },
  pats: [
    // P0 — A section: Ab-Fm, bright piano
    [32, [
      [0,n('Ab1'),'bass',90],[5,n('Eb5'),'hat',38], [1,n('Ab4'),'lead',80],0,
      [0,n('Ab1'),'bass',70],[5,n('Eb5'),'hat',35], [1,n('Bb4'),'lead',78],0,
      [3,n('C2'),'kick',95], [5,n('Eb5'),'hat',38], [1,n('C5'),'lead',82],[2,n('Eb4'),'pad',48],
      0,                     [5,n('Eb5'),'hat',35], [1,n('Bb4'),'lead',76],0,
      [0,n('F2'),'bass',88], [5,n('Eb5'),'hat',38], [1,n('Ab4'),'lead',74],[4,n('D3'),'snare',75],
      0,                     [5,n('Eb5'),'hat',35], [1,n('F4'),'lead',72], 0,
      [3,n('C2'),'kick',95], [5,n('Eb5'),'hat',38], [1,n('G4'),'lead',76],[2,n('Ab3'),'pad',45],
      [0,n('F2'),'bass',68], [5,n('Eb5'),'hat',35], [1,n('Ab4'),'lead',70],0
    ]],
    // P1 — A variant: Db-Eb
    [32, [
      [0,n('Db2'),'bass',88],[5,n('Eb5'),'hat',38], [1,n('Db4'),'lead',78],0,
      [0,n('Db2'),'bass',68],[5,n('Eb5'),'hat',35], [1,n('Eb4'),'lead',76],0,
      [3,n('C2'),'kick',95], [5,n('Eb5'),'hat',38], [1,n('F4'),'lead',80],[2,n('Ab4'),'pad',48],
      0,                     [5,n('Eb5'),'hat',35], [1,n('Ab4'),'lead',82],0,
      [0,n('Eb2'),'bass',90],[5,n('Eb5'),'hat',38], [1,n('G4'),'lead',78],[4,n('D3'),'snare',75],
      0,                     [5,n('Eb5'),'hat',35], [1,n('Bb4'),'lead',80],0,
      [3,n('C2'),'kick',95], [5,n('Eb5'),'hat',38], [1,n('Ab4'),'lead',76],[2,n('Eb4'),'pad',45],
      [0,n('Eb2'),'bass',70],[5,n('Eb5'),'hat',35], [1,n('G4'),'lead',72],0
    ]],
    // P2 — B section: colorful peak, wider range
    [32, [
      [0,n('Ab1'),'bass',95],[5,n('Eb5'),'hat',42], [1,n('C5'),'lead',85],[6,n('Eb5'),'tex1',30],
      0,                     [5,n('Eb5'),'hat',38], [1,n('Db5'),'lead',88],0,
      [3,n('C2'),'kick',100],[5,n('Eb5'),'hat',42], [1,n('Eb5'),'lead',92],0,
      0,                     [5,n('Eb5'),'hat',38], [1,n('F5'),'lead',95], [7,n('Ab4'),'tex2',28],
      [0,n('Db2'),'bass',90],[5,n('Eb5'),'hat',42], [1,n('Eb5'),'lead',90],[4,n('D3'),'snare',80],
      0,                     [5,n('Eb5'),'hat',38], [2,n('Ab4'),'pad',52], [1,n('Db5'),'lead',85],
      [3,n('C2'),'kick',100],[5,n('Eb5'),'hat',42], [1,n('C5'),'lead',82],0,
      [0,n('Eb2'),'bass',85],[5,n('Eb5'),'hat',38], [1,n('Bb4'),'lead',78],0
    ]],
    // P3 — A' section: ends on V (Eb) for loop
    [32, [
      [0,n('Db2'),'bass',85],[5,n('Eb5'),'hat',36], [1,n('Ab4'),'lead',74],0,
      [0,n('Db2'),'bass',65],[5,n('Eb5'),'hat',33], [1,n('Bb4'),'lead',72],0,
      [3,n('C2'),'kick',92], [5,n('Eb5'),'hat',36], [1,n('Ab4'),'lead',70],[2,n('Db4'),'pad',42],
      0,                     [5,n('Eb5'),'hat',33], [1,n('F4'),'lead',68], 0,
      [0,n('Eb2'),'bass',88],[5,n('Eb5'),'hat',36], [1,n('G4'),'lead',72],[4,n('D3'),'snare',70],
      0,                     [5,n('Eb5'),'hat',33], [1,n('Bb4'),'lead',70],0,
      [3,n('C2'),'kick',92], [5,n('Eb5'),'hat',36], [1,n('Ab4'),'lead',66],[2,n('Eb4'),'pad',40],
      [0,n('Eb2'),'bass',72],[5,n('Eb5'),'hat',33], [1,n('G4'),'lead',64],0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Root — System foundation — Am Dorian
// Deep bass pedal, deliberate and grounded
// Progression: Am7-D7-Am7-Em7
// ============================================================
L['agent-root'] = {
  bpm: 80, chip: 'snes',
  echo: [380, 0.4, 0.38, 2500],
  inst: {
    bass:  I('bas', 0.01, 0.2,  0.75, 0.35, true),
    lead:  I('saw', 0.02, 0.18, 0.5,  0.4, true),
    pad:   I('str', 0.1,  0.35, 0.5,  0.65, true),
    kick:  I('kck', 0.0,  0.12, 0.0, 0.1, false),
    snare: I('snr', 0.0,  0.14, 0.0, 0.15, false),
    hat:   I('hh',  0.0,  0.06, 0.0, 0.1, false),
    tex1:  I('tri', 0.06, 0.4,  0.3, 0.5, true),
    tex2:  I('sin', 0.08, 0.45, 0.25, 0.55, true)
  },
  pats: [
    // P0 — A section: Am7, deep bass pedal
    [32, [
      [0,n('A1'),'bass',100],[5,n('E5'),'hat',32], [2,n('E4'),'pad',50],  0,
      0,                     [5,n('E5'),'hat',28], [1,n('A3'),'lead',72],  0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',32], [1,n('B3'),'lead',74], 0,
      0,                     [5,n('E5'),'hat',28], [1,n('C4'),'lead',76],  0,
      [0,n('A1'),'bass',85], [5,n('E5'),'hat',32], [1,n('D4'),'lead',78], [4,n('D3'),'snare',72],
      0,                     [5,n('E5'),'hat',28], [1,n('E4'),'lead',80],  0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',32], [1,n('D4'),'lead',76], [2,n('A3'),'pad',45],
      [0,n('A1'),'bass',80], [5,n('E5'),'hat',28], [1,n('C4'),'lead',72], 0
    ]],
    // P1 — A variant: D7-Am7
    [32, [
      [0,n('D2'),'bass',95], [5,n('E5'),'hat',32], [2,n('F#4'),'pad',48], 0,
      0,                     [5,n('E5'),'hat',28], [1,n('D4'),'lead',72],  0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',32], [1,n('E4'),'lead',74], 0,
      0,                     [5,n('E5'),'hat',28], [1,n('F#4'),'lead',78], 0,
      [0,n('A1'),'bass',95], [5,n('E5'),'hat',32], [1,n('E4'),'lead',76], [4,n('D3'),'snare',72],
      0,                     [5,n('E5'),'hat',28], [1,n('D4'),'lead',74],  0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',32], [1,n('C4'),'lead',72], [2,n('E4'),'pad',45],
      [0,n('A1'),'bass',82], [5,n('E5'),'hat',28], [1,n('A3'),'lead',68], 0
    ]],
    // P2 — B section: foundation shakes, more tension
    [32, [
      [0,n('A1'),'bass',105],[5,n('E5'),'hat',35], [1,n('A3'),'lead',78], [6,n('E4'),'tex1',28],
      0,                     [5,n('E5'),'hat',30], [1,n('C4'),'lead',80],  0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',35], [1,n('D4'),'lead',82], 0,
      0,                     [5,n('E5'),'hat',30], [1,n('E4'),'lead',85],  [7,n('A3'),'tex2',25],
      [0,n('D2'),'bass',100],[5,n('E5'),'hat',35], [1,n('F#4'),'lead',90],[4,n('D3'),'snare',78],
      0,                     [5,n('E5'),'hat',30], [2,n('D4'),'pad',52],   0,
      [3,n('C2'),'kick',100],[5,n('E5'),'hat',35], [1,n('E4'),'lead',82], 0,
      [0,n('A1'),'bass',90], [5,n('E5'),'hat',30], [1,n('D4'),'lead',78], 0
    ]],
    // P3 — A' section: ends on V (Em7) for loop
    [32, [
      [0,n('A1'),'bass',92], [5,n('E5'),'hat',30], [2,n('C4'),'pad',45],  0,
      0,                     [5,n('E5'),'hat',26], [1,n('A3'),'lead',68],  0,
      [3,n('C2'),'kick',95], [5,n('E5'),'hat',30], [1,n('B3'),'lead',70], 0,
      0,                     [5,n('E5'),'hat',26], [1,n('C4'),'lead',72],  0,
      [0,n('E2'),'bass',95], [5,n('E5'),'hat',30], [1,n('B3'),'lead',70], [4,n('D3'),'snare',68],
      0,                     [5,n('E5'),'hat',26], [1,n('G3'),'lead',66],  0,
      [3,n('C2'),'kick',95], [5,n('E5'),'hat',30], [1,n('E3'),'lead',64], [2,n('B3'),'pad',40],
      [0,n('E2'),'bass',80], [5,n('E5'),'hat',26], [1,n('B3'),'lead',62], 0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Dash — Speed demon — A minor
// Breakneck FM, Andalusian cadence Am-G-F-E
// ============================================================
L['agent-dash'] = {
  bpm: 150, chip: 'genesis',
  echo: [130, 0.22, 0.2, 5500],
  inst: {
    bass:  I('fmBass',  0.0,  0.06, 0.7, 0.12, true),
    lead:  I('fmLead',  0.0,  0.04, 0.55, 0.08, false),
    brass: I('fmBrass', 0.0,  0.08, 0.5,  0.15, true),
    kick:  I('mhat',    0.0,  0.05, 0.0, 0.05, false),
    snare: I('ohat',    0.0,  0.07, 0.0, 0.07, false),
    hat:   I('mhat',    0.0,  0.02, 0.0, 0.03, false),
    tex1:  I('acid',    0.0,  0.05, 0.4, 0.1, true),
    tex2:  I('fmEP',    0.01, 0.08, 0.3, 0.15, false)
  },
  pats: [
    // P0 — A section: Am-G Andalusian, relentless pace
    [32, [
      [0,n('A1'),'bass',100],[1,n('A4'),'lead',85], [5,n('A5'),'hat',45], [1,n('B4'),'lead',82],
      [3,n('C2'),'kick',100],[1,n('C5'),'lead',88], [5,n('A5'),'hat',40], 0,
      [0,n('A1'),'bass',82], [1,n('B4'),'lead',80], [5,n('A5'),'hat',45], [1,n('A4'),'lead',78],
      [4,n('D3'),'snare',85],[5,n('A5'),'hat',40],  [1,n('G4'),'lead',76],0,
      [0,n('G1'),'bass',95], [1,n('G4'),'lead',82], [5,n('A5'),'hat',45], [1,n('A4'),'lead',80],
      [3,n('C2'),'kick',100],[1,n('B4'),'lead',85], [5,n('A5'),'hat',40], [2,n('G4'),'brass',48],
      [0,n('G1'),'bass',78], [1,n('A4'),'lead',78], [5,n('A5'),'hat',45], [1,n('G4'),'lead',75],
      [4,n('D3'),'snare',82],[5,n('A5'),'hat',40],  [1,n('F4'),'lead',72],0
    ]],
    // P1 — A variant: F-E Andalusian resolution
    [32, [
      [0,n('F1'),'bass',95], [1,n('F4'),'lead',82], [5,n('A5'),'hat',45], [1,n('G4'),'lead',80],
      [3,n('C2'),'kick',100],[1,n('A4'),'lead',85], [5,n('A5'),'hat',40], 0,
      [0,n('F1'),'bass',78], [1,n('G4'),'lead',78], [5,n('A5'),'hat',45], [1,n('F4'),'lead',75],
      [4,n('D3'),'snare',82],[5,n('A5'),'hat',40],  [1,n('E4'),'lead',72],0,
      [0,n('E1'),'bass',100],[1,n('E4'),'lead',84], [5,n('A5'),'hat',45], [1,n('F4'),'lead',80],
      [3,n('C2'),'kick',100],[1,n('G#4'),'lead',88],[5,n('A5'),'hat',40], [2,n('E4'),'brass',50],
      [0,n('E1'),'bass',82], [1,n('A4'),'lead',82], [5,n('A5'),'hat',45], [1,n('G#4'),'lead',78],
      [4,n('D3'),'snare',80],[5,n('A5'),'hat',40],  [1,n('E4'),'lead',74],0
    ]],
    // P2 — B section: full-throttle burst
    [32, [
      [0,n('A1'),'bass',105],[1,n('E4'),'lead',88], [5,n('A5'),'hat',48], [1,n('F4'),'lead',86],
      [3,n('C2'),'kick',100],[1,n('G4'),'lead',90], [5,n('A5'),'hat',42], [1,n('A4'),'lead',92],
      [0,n('G1'),'bass',98], [1,n('B4'),'lead',94], [5,n('A5'),'hat',48], [6,n('D4'),'tex1',32],
      [4,n('D3'),'snare',88],[1,n('C5'),'lead',98], [5,n('A5'),'hat',42], [1,n('D5'),'lead',100],
      [0,n('F1'),'bass',100],[1,n('C5'),'lead',95], [5,n('A5'),'hat',48], [1,n('B4'),'lead',90],
      [3,n('C2'),'kick',100],[1,n('A4'),'lead',88], [5,n('A5'),'hat',42], [7,n('F4'),'tex2',28],
      [0,n('E1'),'bass',102],[1,n('G#4'),'lead',92],[5,n('A5'),'hat',48], [1,n('A4'),'lead',88],
      [4,n('D3'),'snare',86],[1,n('E4'),'lead',82], [5,n('A5'),'hat',42], [1,n('F4'),'lead',78]
    ]],
    // P3 — A' section: ends on V (E) for loop
    [32, [
      [0,n('A1'),'bass',92], [1,n('A4'),'lead',78], [5,n('A5'),'hat',42], [1,n('G4'),'lead',75],
      [3,n('C2'),'kick',95], [1,n('F4'),'lead',72], [5,n('A5'),'hat',38], 0,
      [0,n('G1'),'bass',85], [1,n('G4'),'lead',74], [5,n('A5'),'hat',42], [1,n('F4'),'lead',70],
      [4,n('D3'),'snare',78],[5,n('A5'),'hat',38],  [1,n('E4'),'lead',68],0,
      [0,n('E1'),'bass',95], [1,n('E4'),'lead',76], [5,n('A5'),'hat',42], [1,n('F4'),'lead',72],
      [3,n('C2'),'kick',95], [1,n('G#4'),'lead',80],[5,n('A5'),'hat',38], [2,n('B3'),'brass',45],
      [0,n('E1'),'bass',82], [1,n('B4'),'lead',74], [5,n('A5'),'hat',42], [1,n('G#4'),'lead',70],
      [4,n('D3'),'snare',75],[5,n('A5'),'hat',38],  [1,n('E4'),'lead',66],0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};

// ============================================================
// Flux — Shape-shifter — Dm Dorian
// Morphing textures, fluid motion
// Progression: Dm9-Gm9-Cmaj7-Fmaj7
// ============================================================
L['agent-flux'] = {
  bpm: 105, chip: 'snes',
  echo: [250, 0.32, 0.3, 4000],
  inst: {
    bass:  I('bas', 0.01, 0.15, 0.7, 0.3, true),
    lead:  I('saw', 0.02, 0.2,  0.5, 0.35, true),
    pad:   I('str', 0.1,  0.35, 0.5, 0.6, true),
    kick:  I('kck', 0.0,  0.1,  0.0, 0.1, false),
    snare: I('snr', 0.0,  0.12, 0.0, 0.13, false),
    hat:   I('hh',  0.0,  0.05, 0.0, 0.08, false),
    tex1:  I('fm',  0.03, 0.3,  0.35, 0.4, true),
    tex2:  I('tri', 0.05, 0.35, 0.3, 0.45, true)
  },
  pats: [
    // P0 — A section: Dm9-Gm9, morphing textures
    [32, [
      [0,n('D2'),'bass',88], [5,n('A5'),'hat',36], [1,n('E4'),'lead',75], 0,
      [0,n('D2'),'bass',68], [5,n('A5'),'hat',32], [2,n('A4'),'pad',48],  [1,n('F4'),'lead',73],
      [3,n('C2'),'kick',95], [5,n('A5'),'hat',36], [1,n('G4'),'lead',78], 0,
      0,                     [5,n('A5'),'hat',32], [1,n('A4'),'lead',80],  [6,n('E4'),'tex1',28],
      [0,n('G2'),'bass',86], [5,n('A5'),'hat',36], [1,n('Bb4'),'lead',76],[4,n('D3'),'snare',72],
      0,                     [5,n('A5'),'hat',32], [1,n('A4'),'lead',74],  0,
      [3,n('C2'),'kick',95], [5,n('A5'),'hat',36], [1,n('G4'),'lead',72], [2,n('D4'),'pad',45],
      [0,n('G2'),'bass',70], [5,n('A5'),'hat',32], [1,n('F4'),'lead',68], 0
    ]],
    // P1 — A variant: Cmaj7-Fmaj7
    [32, [
      [0,n('C2'),'bass',86], [5,n('A5'),'hat',36], [1,n('E4'),'lead',75], 0,
      [0,n('C2'),'bass',66], [5,n('A5'),'hat',32], [2,n('G4'),'pad',48],  [1,n('D4'),'lead',72],
      [3,n('C2'),'kick',95], [5,n('A5'),'hat',36], [1,n('E4'),'lead',76], 0,
      0,                     [5,n('A5'),'hat',32], [1,n('G4'),'lead',80],  [7,n('B4'),'tex2',26],
      [0,n('F2'),'bass',88], [5,n('A5'),'hat',36], [1,n('A4'),'lead',78], [4,n('D3'),'snare',72],
      0,                     [5,n('A5'),'hat',32], [1,n('G4'),'lead',74],  0,
      [3,n('C2'),'kick',95], [5,n('A5'),'hat',36], [1,n('F4'),'lead',72], [2,n('C4'),'pad',45],
      [0,n('F2'),'bass',70], [5,n('A5'),'hat',32], [1,n('E4'),'lead',68], 0
    ]],
    // P2 — B section: shape-shifting climax, wider intervals
    [32, [
      [0,n('D2'),'bass',92], [5,n('A5'),'hat',40], [1,n('D4'),'lead',80], 0,
      0,                     [5,n('A5'),'hat',35], [1,n('F4'),'lead',82],  [6,n('A4'),'tex1',32],
      [3,n('C2'),'kick',100],[5,n('A5'),'hat',40], [1,n('A4'),'lead',88], 0,
      0,                     [5,n('A5'),'hat',35], [1,n('Bb4'),'lead',85], [2,n('F4'),'pad',52],
      [0,n('G2'),'bass',90], [5,n('A5'),'hat',40], [1,n('C5'),'lead',92], [4,n('D3'),'snare',78],
      0,                     [5,n('A5'),'hat',35], [1,n('D5'),'lead',95],  [7,n('G4'),'tex2',30],
      [3,n('C2'),'kick',100],[5,n('A5'),'hat',40], [1,n('C5'),'lead',88], 0,
      [0,n('C2'),'bass',85], [5,n('A5'),'hat',35], [1,n('Bb4'),'lead',82],0
    ]],
    // P3 — A' section: ends on V (Am7) for loop
    [32, [
      [0,n('F2'),'bass',84], [5,n('A5'),'hat',34], [1,n('F4'),'lead',72], 0,
      [0,n('F2'),'bass',64], [5,n('A5'),'hat',30], [2,n('A4'),'pad',44],  [1,n('E4'),'lead',68],
      [3,n('C2'),'kick',92], [5,n('A5'),'hat',34], [1,n('D4'),'lead',70], 0,
      0,                     [5,n('A5'),'hat',30], [1,n('C4'),'lead',66],  0,
      [0,n('A1'),'bass',90], [5,n('A5'),'hat',34], [1,n('E4'),'lead',72], [4,n('D3'),'snare',68],
      0,                     [5,n('A5'),'hat',30], [1,n('C4'),'lead',66],  0,
      [3,n('C2'),'kick',92], [5,n('A5'),'hat',34], [1,n('A3'),'lead',64], [2,n('E4'),'pad',40],
      [0,n('A1'),'bass',74], [5,n('A5'),'hat',30], [1,n('E4'),'lead',62], 0
    ]]
  ],
  seq: [0,1,0,1,2,2,3,0]
};
// ============================================================
// 10. SPEC — QA perfectionist. Metronomic pluck, methodical.
//     G Major, 100 BPM, SNES. Gmaj7-Em7-Am7-D7.
// ============================================================
L['agent-spec'] = {
  bpm:100, chip:'snes',
  echo:[240,0.3,0.28,4000],
  inst:{
    bl: I('sq25',  0.01, 0.15, 0.3,  0.2,  false),
    ml: I('pno',   0.005,0.12, 0.45, 0.25, false),
    pd: I('str',   0.08, 0.3,  0.6,  0.4,  true),
    bs: I('bas',   0.005,0.1,  0.7,  0.15, false),
    kk: I('kck',   0.001,0.08, 0,    0.1,  false),
    sn: I('snr',   0.001,0.1,  0,    0.12, false),
    hh: I('hh',    0.001,0.05, 0,    0.05, false),
    tx: I('sq12',  0.02, 0.1,  0.2,  0.15, false)
  },
  pats:[
    // P0 — A: Gmaj7 to Em7, methodical pluck
    [32,[
      [0,n('G2'),'bs',90], [6,n('B4'),'tx',30], [1,n('B4'),'ml',80], [5,n('G4'),'hh',50],
      [2,n('D4'),'pd',55], 0, [1,n('A4'),'ml',75], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100],[6,n('D5'),'tx',28], [1,n('G4'),'ml',78], [5,n('G4'),'hh',50],
      [0,n('G2'),'bs',85], 0, [1,n('A4'),'ml',72], [4,n('D4'),'sn',85],
      [0,n('E2'),'bs',88], [6,n('G4'),'tx',30], [1,n('B4'),'ml',80], [5,n('G4'),'hh',50],
      [2,n('G4'),'pd',55], 0, [1,n('A4'),'ml',70], [5,n('G4'),'hh',40],
      [3,n('E2'),'kk',100],[6,n('B4'),'tx',25], [1,n('G4'),'ml',75], [5,n('G4'),'hh',50],
      [0,n('E2'),'bs',82], 0, [1,n('B4'),'ml',68], [4,n('D4'),'sn',82]
    ]],
    // P1 — B: Am7 to D7, rising precision
    [32,[
      [0,n('A2'),'bs',90], [6,n('C5'),'tx',30], [1,n('C5'),'ml',82], [5,n('G4'),'hh',50],
      [2,n('E4'),'pd',55], 0, [1,n('B4'),'ml',78], [5,n('G4'),'hh',40],
      [3,n('A2'),'kk',100],[6,n('E5'),'tx',28], [1,n('A4'),'ml',76], [5,n('G4'),'hh',50],
      [0,n('A2'),'bs',85], 0, [1,n('B4'),'ml',74], [4,n('D4'),'sn',85],
      [0,n('D3'),'bs',92], [6,n('A4'),'tx',30], [1,n('D5'),'ml',85], [5,n('G4'),'hh',50],
      [2,n('F#4'),'pd',58], 0, [1,n('C5'),'ml',80], [5,n('G4'),'hh',40],
      [3,n('D3'),'kk',100],[6,n('F#4'),'tx',28],[1,n('B4'),'ml',76], [5,n('G4'),'hh',50],
      [0,n('D3'),'bs',84], 0, [1,n('A4'),'ml',72], [4,n('D4'),'sn',85]
    ]],
    // P2 — A again: Gmaj7-Em7 with variation
    [32,[
      [0,n('G2'),'bs',90], [6,n('D5'),'tx',32], [1,n('D5'),'ml',82], [5,n('G4'),'hh',50],
      [2,n('B4'),'pd',55], 0, [1,n('C5'),'ml',78], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100],[6,n('B4'),'tx',28], [1,n('B4'),'ml',80], [5,n('G4'),'hh',50],
      [0,n('G2'),'bs',85], 0, [1,n('A4'),'ml',74], [4,n('D4'),'sn',85],
      [0,n('E2'),'bs',88], [6,n('G4'),'tx',30], [1,n('G4'),'ml',76], [5,n('G4'),'hh',50],
      [2,n('B4'),'pd',55], 0, [1,n('A4'),'ml',72], [5,n('G4'),'hh',40],
      [3,n('E2'),'kk',100],[6,n('E4'),'tx',26], [1,n('B4'),'ml',78], [5,n('G4'),'hh',50],
      [0,n('E2'),'bs',82], 0, [1,n('G4'),'ml',70], [4,n('D4'),'sn',82]
    ]],
    // P3 — A': ends on D7 (V) for loop
    [32,[
      [0,n('G2'),'bs',88], [6,n('B4'),'tx',30], [1,n('B4'),'ml',80], [5,n('G4'),'hh',50],
      [2,n('D4'),'pd',55], 0, [1,n('A4'),'ml',76], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100],0, [1,n('G4'),'ml',74], [5,n('G4'),'hh',50],
      [0,n('G2'),'bs',82], 0, [1,n('A4'),'ml',72], [4,n('D4'),'sn',82],
      [0,n('D3'),'bs',92], [6,n('F#4'),'tx',32],[1,n('D5'),'ml',85], [5,n('G4'),'hh',50],
      [2,n('A4'),'pd',58], 0, [1,n('C5'),'ml',78], [5,n('G4'),'hh',40],
      [3,n('D3'),'kk',100],0, [1,n('B4'),'ml',74], [5,n('G4'),'hh',50],
      [0,n('D3'),'bs',86], 0, [1,n('A4'),'ml',70], [4,n('D4'),'sn',85]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 11. SIGNAL — Communication. Call-and-response.
//     Eb Major, 90 BPM, SNES. Eb-Cm-Ab-Bb.
// ============================================================
L['agent-signal'] = {
  bpm:90, chip:'snes',
  echo:[350,0.42,0.38,2800],
  inst:{
    cl: I('sq50',  0.005,0.12, 0.5,  0.3,  false),
    rp: I('pno',   0.005,0.15, 0.4,  0.25, false),
    pd: I('str',   0.1,  0.3,  0.55, 0.4,  true),
    bs: I('bas',   0.005,0.1,  0.7,  0.15, false),
    kk: I('kck',   0.001,0.08, 0,    0.1,  false),
    sn: I('snr',   0.001,0.1,  0,    0.12, false),
    hh: I('hh',    0.001,0.05, 0,    0.05, false),
    tx: I('sin',   0.03, 0.15, 0.25, 0.2,  false)
  },
  pats:[
    // P0 — A: Eb call, Cm response
    [32,[
      [0,n('Eb2'),'bs',90], [5,n('Eb4'),'hh',45],[1,n('Eb4'),'cl',85], 0,
      [2,n('Bb3'),'pd',55], [5,n('Eb4'),'hh',40],[1,n('F4'),'cl',78],  [5,n('Eb4'),'hh',35],
      [3,n('Eb2'),'kk',100],0, [1,n('G4'),'cl',82], [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',85], [1,n('F4'),'rp',70], [5,n('Eb4'),'hh',35],
      [0,n('C2'),'bs',88],  [5,n('Eb4'),'hh',45],[1,n('Eb4'),'rp',75], 0,
      [2,n('G3'),'pd',52],  [5,n('Eb4'),'hh',40],[1,n('D4'),'rp',72],  [5,n('Eb4'),'hh',35],
      [3,n('C2'),'kk',98],  0, [1,n('C4'),'rp',78], [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',82], [1,n('Eb4'),'rp',68],[5,n('Eb4'),'hh',35]
    ]],
    // P1 — B: Ab call, Bb response
    [32,[
      [0,n('Ab2'),'bs',90], [5,n('Eb4'),'hh',45],[1,n('Ab4'),'cl',85], 0,
      [2,n('Eb4'),'pd',55], [5,n('Eb4'),'hh',40],[1,n('Bb4'),'cl',80], [5,n('Eb4'),'hh',35],
      [3,n('Ab2'),'kk',100],0, [1,n('C5'),'cl',88], [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',85], [1,n('Bb4'),'rp',72],[5,n('Eb4'),'hh',35],
      [0,n('Bb2'),'bs',92], [5,n('Eb4'),'hh',45],[1,n('Bb4'),'rp',78], 0,
      [2,n('F4'),'pd',55],  [5,n('Eb4'),'hh',40],[1,n('Ab4'),'rp',74], [5,n('Eb4'),'hh',35],
      [3,n('Bb2'),'kk',100],0, [1,n('G4'),'rp',76],  [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',85], [1,n('F4'),'rp',70],  [5,n('Eb4'),'hh',35]
    ]],
    // P2 — A var: Eb-Cm with syncopated call
    [32,[
      [0,n('Eb2'),'bs',88], [5,n('Eb4'),'hh',45],0, [1,n('G4'),'cl',82],
      [2,n('Bb3'),'pd',55], [5,n('Eb4'),'hh',40],[1,n('Ab4'),'cl',80], [5,n('Eb4'),'hh',35],
      [3,n('Eb2'),'kk',100],0, [1,n('G4'),'cl',78],  [5,n('Eb4'),'hh',45],
      [1,n('F4'),'cl',72],  [4,n('Eb4'),'sn',85],0,  [5,n('Eb4'),'hh',35],
      [0,n('C2'),'bs',86],  [5,n('Eb4'),'hh',45],[1,n('Eb4'),'rp',76], 0,
      [2,n('G3'),'pd',52],  [5,n('Eb4'),'hh',40],[1,n('D4'),'rp',74],  [5,n('Eb4'),'hh',35],
      [3,n('C2'),'kk',98],  0, [1,n('Eb4'),'rp',78], [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',82], [1,n('C4'),'rp',68],  [5,n('Eb4'),'hh',35]
    ]],
    // P3 — A': ends on Bb (V) for loop
    [32,[
      [0,n('Eb2'),'bs',88], [5,n('Eb4'),'hh',45],[1,n('Eb4'),'cl',82], 0,
      [2,n('Bb3'),'pd',55], [5,n('Eb4'),'hh',40],[1,n('F4'),'cl',76],  [5,n('Eb4'),'hh',35],
      [3,n('Eb2'),'kk',100],0, [1,n('G4'),'cl',80],  [5,n('Eb4'),'hh',45],
      0, [4,n('Eb4'),'sn',85], [1,n('F4'),'cl',72],  [5,n('Eb4'),'hh',35],
      [0,n('Bb2'),'bs',92], [5,n('Eb4'),'hh',45],[1,n('Bb4'),'cl',86], 0,
      [2,n('F4'),'pd',58],  [5,n('Eb4'),'hh',40],[1,n('Ab4'),'cl',78], [5,n('Eb4'),'hh',35],
      [3,n('Bb2'),'kk',100],0, [1,n('G4'),'cl',74],  [5,n('Eb4'),'hh',45],
      [6,n('Bb4'),'tx',30], [4,n('Eb4'),'sn',85],[1,n('F4'),'cl',70],  [5,n('Eb4'),'hh',35]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 12. MYTH — Lorekeeper. Modal strings, mystical.
//     Em Aeolian, 75 BPM, SNES. Em-C-D-Em.
// ============================================================
L['agent-myth'] = {
  bpm:75, chip:'snes',
  echo:[450,0.48,0.45,2200],
  inst:{
    vx: I('str',   0.12, 0.4,  0.65, 0.5,  true),
    ml: I('sin',   0.04, 0.2,  0.5,  0.35, false),
    pd: I('str',   0.15, 0.35, 0.6,  0.5,  true),
    bs: I('bas',   0.02, 0.15, 0.7,  0.2,  false),
    kk: I('kck',   0.001,0.1,  0,    0.12, false),
    sn: I('snr',   0.002,0.12, 0,    0.15, false),
    hh: I('hh',    0.001,0.06, 0,    0.06, false),
    gh: I('pnoi',  0.05, 0.2,  0.15, 0.3,  false)
  },
  pats:[
    // P0 — A: Em drone, modal melody unfolds slowly
    [32,[
      [0,n('E2'),'bs',85],  [2,n('B3'),'pd',50], [1,n('E4'),'ml',72],  0,
      0, [5,n('E4'),'hh',30], 0, [1,n('F#4'),'ml',68],
      [3,n('E2'),'kk',90],  [7,n('E3'),'gh',20], [1,n('G4'),'ml',75],  0,
      [2,n('G3'),'pd',48],  [5,n('E4'),'hh',28], [1,n('A4'),'vx',70],  0,
      0, 0, [1,n('G4'),'ml',72], [5,n('E4'),'hh',28],
      [3,n('E2'),'kk',85],  0, [1,n('F#4'),'ml',68], 0,
      [0,n('E2'),'bs',82],  [7,n('E3'),'gh',18], [1,n('E4'),'ml',74],  [5,n('E4'),'hh',25],
      [2,n('B3'),'pd',50],  0, [1,n('D4'),'vx',65],  [4,n('E4'),'sn',70]
    ]],
    // P1 — B: C to D, ascending reach
    [32,[
      [0,n('C2'),'bs',85],  [2,n('E3'),'pd',52], [1,n('C4'),'ml',74],  0,
      0, [5,n('E4'),'hh',30], [1,n('D4'),'ml',70], 0,
      [3,n('C2'),'kk',90],  0, [1,n('E4'),'ml',78],  [5,n('E4'),'hh',28],
      [2,n('G3'),'pd',50],  [7,n('C3'),'gh',20], [1,n('G4'),'vx',75],  0,
      [0,n('D2'),'bs',88],  0, [1,n('A4'),'ml',80],  [5,n('E4'),'hh',30],
      0, [5,n('E4'),'hh',25], [1,n('B4'),'ml',85],  0,
      [3,n('D2'),'kk',88],  [7,n('D3'),'gh',22], [1,n('A4'),'ml',76],  [5,n('E4'),'hh',28],
      [2,n('F#3'),'pd',52], 0, [1,n('G4'),'vx',72],  [4,n('E4'),'sn',72]
    ]],
    // P2 — A var: Em with ornamental turns
    [32,[
      [0,n('E2'),'bs',85],  [2,n('B3'),'pd',50], [1,n('E4'),'vx',74],  0,
      [7,n('E3'),'gh',18],  [5,n('E4'),'hh',30], [1,n('F#4'),'ml',70], 0,
      [3,n('E2'),'kk',90],  0, [1,n('G4'),'vx',76],  [1,n('F#4'),'ml',65],
      [2,n('G3'),'pd',48],  [5,n('E4'),'hh',28], [1,n('G4'),'ml',72],  0,
      0, 0, [1,n('A4'),'vx',78], [5,n('E4'),'hh',25],
      [3,n('E2'),'kk',85],  [7,n('E3'),'gh',20], [1,n('G4'),'ml',70], 0,
      [0,n('E2'),'bs',82],  0, [1,n('F#4'),'ml',68], [5,n('E4'),'hh',28],
      [2,n('B3'),'pd',50],  0, [1,n('E4'),'vx',72],  [4,n('E4'),'sn',70]
    ]],
    // P3 — A': ends on D (VII, dominant feel in Aeolian) for loop
    [32,[
      [0,n('E2'),'bs',84],  [2,n('B3'),'pd',48], [1,n('E4'),'ml',72],  0,
      0, [5,n('E4'),'hh',28], [1,n('F#4'),'ml',68], 0,
      [3,n('E2'),'kk',88],  0, [1,n('G4'),'vx',74],  [5,n('E4'),'hh',25],
      [2,n('G3'),'pd',48],  0, [1,n('F#4'),'ml',66], 0,
      [0,n('D2'),'bs',88],  [7,n('D3'),'gh',22], [1,n('D4'),'ml',76],  0,
      0, [5,n('E4'),'hh',30], [1,n('E4'),'ml',72],  0,
      [3,n('D2'),'kk',90],  0, [1,n('F#4'),'vx',78], [5,n('E4'),'hh',28],
      [2,n('A3'),'pd',52],  0, [1,n('D4'),'ml',70],  [4,n('E4'),'sn',72]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 13. LUMEN — Illuminator. Radiant pluck arpeggios.
//     D Major, 100 BPM, SNES. Dmaj7-Bm7-Em7-A7.
// ============================================================
L['agent-lumen'] = {
  bpm:100, chip:'snes',
  echo:[320,0.38,0.35,3200],
  inst:{
    pk: I('sq50',  0.002,0.08, 0.2,  0.15, false),
    ml: I('pno',   0.005,0.1,  0.4,  0.2,  false),
    pd: I('str',   0.1,  0.3,  0.55, 0.4,  true),
    bs: I('bas',   0.005,0.1,  0.65, 0.15, false),
    kk: I('kck',   0.001,0.08, 0,    0.1,  false),
    sn: I('snr',   0.001,0.1,  0,    0.12, false),
    hh: I('hh',    0.001,0.04, 0,    0.04, false),
    gl: I('sin',   0.01, 0.06, 0.15, 0.12, false)
  },
  pats:[
    // P0 — A: Dmaj7 arpeggio cascade, Bm7 answer
    [32,[
      [0,n('D2'),'bs',90],  [1,n('D4'),'pk',78], [1,n('F#4'),'pk',75],[1,n('A4'),'pk',72],
      [5,n('D4'),'hh',45],  [1,n('C#5'),'pk',80],[5,n('D4'),'hh',38], [1,n('A4'),'pk',70],
      [3,n('D2'),'kk',100], [1,n('F#4'),'pk',74],[2,n('A3'),'pd',50], [1,n('D4'),'ml',72],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',82], [1,n('E4'),'ml',68], [5,n('D4'),'hh',35],
      [0,n('B1'),'bs',88],  [1,n('B3'),'pk',76], [1,n('D4'),'pk',74], [1,n('F#4'),'pk',72],
      [5,n('D4'),'hh',45],  [1,n('A4'),'pk',78], [5,n('D4'),'hh',38], [1,n('F#4'),'pk',68],
      [3,n('B1'),'kk',98],  [1,n('D4'),'pk',72], [2,n('F#3'),'pd',48],[1,n('B3'),'ml',70],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',80], [7,n('D5'),'gl',30], [5,n('D4'),'hh',35]
    ]],
    // P1 — B: Em7 to A7, brighter peak
    [32,[
      [0,n('E2'),'bs',90],  [1,n('E4'),'pk',78], [1,n('G4'),'pk',75], [1,n('B4'),'pk',74],
      [5,n('D4'),'hh',45],  [1,n('D5'),'pk',82], [5,n('D4'),'hh',38], [1,n('B4'),'pk',72],
      [3,n('E2'),'kk',100], [1,n('G4'),'pk',76], [2,n('B3'),'pd',52], [1,n('E4'),'ml',74],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',85], [1,n('F#4'),'ml',70],[5,n('D4'),'hh',35],
      [0,n('A2'),'bs',92],  [1,n('A4'),'pk',80], [1,n('C#5'),'pk',78],[1,n('E5'),'pk',82],
      [5,n('D4'),'hh',45],  [1,n('C#5'),'pk',76],[5,n('D4'),'hh',38], [1,n('A4'),'pk',72],
      [3,n('A2'),'kk',100], [1,n('G4'),'ml',74], [2,n('E4'),'pd',50], [7,n('A4'),'gl',32],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',82], [1,n('F#4'),'ml',68],[5,n('D4'),'hh',35]
    ]],
    // P2 — A var: Dmaj7-Bm7 with offset arps
    [32,[
      [0,n('D2'),'bs',88],  [5,n('D4'),'hh',45], [1,n('A4'),'pk',76], [1,n('F#4'),'pk',73],
      [1,n('D4'),'pk',70],  [1,n('F#4'),'pk',74],[5,n('D4'),'hh',38], [1,n('A4'),'pk',78],
      [3,n('D2'),'kk',100], [1,n('C#5'),'pk',82],[2,n('A3'),'pd',50], [1,n('A4'),'ml',72],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',82], [7,n('F#5'),'gl',28],[5,n('D4'),'hh',35],
      [0,n('B1'),'bs',86],  [5,n('D4'),'hh',45], [1,n('F#4'),'pk',74],[1,n('D4'),'pk',70],
      [1,n('B3'),'pk',68],  [1,n('D4'),'pk',72], [5,n('D4'),'hh',38], [1,n('F#4'),'pk',76],
      [3,n('B1'),'kk',98],  [1,n('A4'),'pk',78], [2,n('F#3'),'pd',48],[1,n('F#4'),'ml',70],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',80], [1,n('D4'),'ml',66], [5,n('D4'),'hh',35]
    ]],
    // P3 — A': ends on A7 (V) for loop
    [32,[
      [0,n('D2'),'bs',88],  [1,n('D4'),'pk',76], [1,n('F#4'),'pk',74],[1,n('A4'),'pk',72],
      [5,n('D4'),'hh',45],  [1,n('C#5'),'pk',80],[5,n('D4'),'hh',38], [1,n('A4'),'pk',68],
      [3,n('D2'),'kk',100], [1,n('F#4'),'pk',72],[2,n('A3'),'pd',50], [1,n('D4'),'ml',70],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',82], [1,n('E4'),'ml',66], [5,n('D4'),'hh',35],
      [0,n('A2'),'bs',92],  [1,n('A4'),'pk',80], [1,n('C#5'),'pk',78],[1,n('E5'),'pk',85],
      [5,n('D4'),'hh',45],  [1,n('C#5'),'pk',76],[5,n('D4'),'hh',38], [7,n('E5'),'gl',35],
      [3,n('A2'),'kk',100], [1,n('A4'),'pk',74], [2,n('E4'),'pd',52], [1,n('G4'),'ml',70],
      [5,n('D4'),'hh',45],  [4,n('D4'),'sn',85], [1,n('E4'),'ml',66], [5,n('D4'),'hh',35]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 14. PATCH — Fixer, resourceful. Quick FM repairs.
//     G Mixolydian, 115 BPM, Genesis. G7-C-G7-D7.
// ============================================================
L['agent-patch'] = {
  bpm:115, chip:'genesis',
  echo:[200,0.28,0.25,4200],
  inst:{
    ld: I('fmLead', 0.005,0.1,  0.45, 0.15, false),
    bs: I('fmBass', 0.005,0.08, 0.7,  0.12, false),
    br: I('fmBrass',0.02, 0.15, 0.5,  0.2,  true),
    ep: I('fmEP',   0.005,0.12, 0.4,  0.2,  false),
    ac: I('acid',   0.002,0.06, 0.35, 0.1,  false),
    kk: I('fmBass', 0.001,0.06, 0,    0.08, false),
    sn: I('mhat',   0.001,0.08, 0,    0.1,  false),
    hh: I('ohat',   0.001,0.04, 0,    0.04, false)
  },
  pats:[
    // P0 — A: G7 bustle, C answer — quick mechanical motion
    [32,[
      [0,n('G2'),'bs',95],  [5,n('G4'),'hh',50], [1,n('G4'),'ld',82], [5,n('G4'),'hh',40],
      [1,n('A4'),'ld',78],  [5,n('G4'),'hh',48], [1,n('B4'),'ld',80], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100], [2,n('B3'),'br',50], [1,n('A4'),'ld',76], [5,n('G4'),'hh',48],
      [1,n('G4'),'ep',72],  [4,n('G4'),'sn',85], [5,n('G4'),'hh',40], [7,n('D4'),'ac',35],
      [0,n('C2'),'bs',92],  [5,n('G4'),'hh',50], [1,n('C5'),'ld',85], [5,n('G4'),'hh',40],
      [1,n('B4'),'ld',78],  [5,n('G4'),'hh',48], [1,n('A4'),'ld',75], [5,n('G4'),'hh',40],
      [3,n('C2'),'kk',98],  [2,n('E3'),'br',48], [1,n('G4'),'ld',80], [5,n('G4'),'hh',48],
      [1,n('A4'),'ep',70],  [4,n('G4'),'sn',82], [5,n('G4'),'hh',40], 0
    ]],
    // P1 — B: G7 to D7, rising urgency
    [32,[
      [0,n('G2'),'bs',95],  [5,n('G4'),'hh',50], [1,n('B4'),'ld',82], [5,n('G4'),'hh',40],
      [1,n('C5'),'ld',80],  [5,n('G4'),'hh',48], [1,n('D5'),'ld',85], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100], [2,n('F4'),'br',52], [1,n('C5'),'ld',78], [5,n('G4'),'hh',48],
      [1,n('B4'),'ep',74],  [4,n('G4'),'sn',85], [5,n('G4'),'hh',40], [7,n('G4'),'ac',38],
      [0,n('D2'),'bs',94],  [5,n('G4'),'hh',50], [1,n('D5'),'ld',88], [5,n('G4'),'hh',40],
      [1,n('C5'),'ld',80],  [5,n('G4'),'hh',48], [1,n('B4'),'ld',76], [5,n('G4'),'hh',40],
      [3,n('D2'),'kk',100], [2,n('F#3'),'br',50],[1,n('A4'),'ld',82], [5,n('G4'),'hh',48],
      [1,n('G4'),'ep',72],  [4,n('G4'),'sn',85], [5,n('G4'),'hh',40], 0
    ]],
    // P2 — A var: syncopated fix rhythm
    [32,[
      [0,n('G2'),'bs',94],  [5,n('G4'),'hh',50], 0, [1,n('G4'),'ld',80],
      [5,n('G4'),'hh',42],  [1,n('A4'),'ld',78], [5,n('G4'),'hh',48], [1,n('B4'),'ac',72],
      [3,n('G2'),'kk',100], [1,n('C5'),'ld',84], [2,n('B3'),'br',50], [5,n('G4'),'hh',48],
      [1,n('B4'),'ep',74],  [4,n('G4'),'sn',85], [1,n('A4'),'ld',70], [5,n('G4'),'hh',40],
      [0,n('C2'),'bs',92],  [5,n('G4'),'hh',50], 0, [1,n('E4'),'ld',78],
      [5,n('G4'),'hh',42],  [1,n('G4'),'ld',80], [5,n('G4'),'hh',48], [1,n('A4'),'ac',70],
      [3,n('C2'),'kk',98],  [1,n('B4'),'ld',82], [2,n('E3'),'br',48], [5,n('G4'),'hh',48],
      [1,n('A4'),'ep',72],  [4,n('G4'),'sn',82], [7,n('G4'),'ac',35], [5,n('G4'),'hh',40]
    ]],
    // P3 — A': ends on D7 (V) for loop
    [32,[
      [0,n('G2'),'bs',94],  [5,n('G4'),'hh',50], [1,n('G4'),'ld',80], [5,n('G4'),'hh',40],
      [1,n('A4'),'ld',76],  [5,n('G4'),'hh',48], [1,n('B4'),'ld',80], [5,n('G4'),'hh',40],
      [3,n('G2'),'kk',100], [2,n('B3'),'br',50], [1,n('A4'),'ld',74], [5,n('G4'),'hh',48],
      [1,n('G4'),'ep',70],  [4,n('G4'),'sn',82], [5,n('G4'),'hh',40], 0,
      [0,n('D2'),'bs',96],  [5,n('G4'),'hh',50], [1,n('D5'),'ld',88], [5,n('G4'),'hh',40],
      [1,n('C5'),'ld',82],  [5,n('G4'),'hh',48], [1,n('B4'),'ld',78], [5,n('G4'),'hh',40],
      [3,n('D2'),'kk',100], [2,n('F#3'),'br',52],[1,n('A4'),'ld',80], [5,n('G4'),'hh',48],
      [7,n('F#4'),'ac',40], [4,n('G4'),'sn',85], [1,n('D4'),'ep',70], [5,n('G4'),'hh',40]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 15. CORE — Infrastructure. Deep organ+bass.
//     C minor, 88 BPM, SNES. Cm-Fm-Bb-Eb.
// ============================================================
L['agent-core'] = {
  bpm:88, chip:'snes',
  echo:[300,0.38,0.35,3000],
  inst:{
    og: I('org',   0.03, 0.2,  0.65, 0.35, true),
    ml: I('sin',   0.02, 0.15, 0.5,  0.3,  false),
    pd: I('str',   0.12, 0.35, 0.6,  0.45, true),
    bs: I('bas',   0.008,0.12, 0.75, 0.18, false),
    kk: I('kck',   0.001,0.1,  0,    0.12, false),
    sn: I('snr',   0.002,0.12, 0,    0.15, false),
    hh: I('hh',    0.001,0.05, 0,    0.05, false),
    dr: I('saw',   0.08, 0.3,  0.2,  0.4,  true)
  },
  pats:[
    // P0 — A: Cm foundation, organ pads, deep bass
    [32,[
      [0,n('C2'),'bs',95],  0, [2,n('Eb3'),'og',60], [5,n('C4'),'hh',35],
      [1,n('C4'),'ml',72],  [5,n('C4'),'hh',30], [2,n('G3'),'pd',52],  0,
      [3,n('C2'),'kk',100], 0, [1,n('D4'),'ml',68],  [5,n('C4'),'hh',35],
      [7,n('C3'),'dr',22],  [4,n('C4'),'sn',80], [1,n('Eb4'),'ml',74], 0,
      [0,n('C2'),'bs',90],  0, [2,n('G3'),'og',58],  [5,n('C4'),'hh',35],
      [1,n('D4'),'ml',70],  [5,n('C4'),'hh',30], [2,n('Eb3'),'pd',50], 0,
      [3,n('C2'),'kk',95],  0, [1,n('C4'),'ml',72],  [5,n('C4'),'hh',35],
      0, [4,n('C4'),'sn',78], [1,n('Bb3'),'ml',65],  [5,n('C4'),'hh',28]
    ]],
    // P1 — B: Fm to Bb, climbing infra
    [32,[
      [0,n('F2'),'bs',95],  0, [2,n('Ab3'),'og',60], [5,n('C4'),'hh',35],
      [1,n('F4'),'ml',75],  [5,n('C4'),'hh',30], [2,n('C4'),'pd',52],  0,
      [3,n('F2'),'kk',100], 0, [1,n('G4'),'ml',78],  [5,n('C4'),'hh',35],
      [7,n('F3'),'dr',24],  [4,n('C4'),'sn',82], [1,n('Ab4'),'ml',80], 0,
      [0,n('Bb2'),'bs',94], 0, [2,n('D4'),'og',58],  [5,n('C4'),'hh',35],
      [1,n('G4'),'ml',76],  [5,n('C4'),'hh',30], [2,n('F3'),'pd',50],  0,
      [3,n('Bb2'),'kk',98], 0, [1,n('F4'),'ml',74],  [5,n('C4'),'hh',35],
      0, [4,n('C4'),'sn',80], [1,n('Eb4'),'ml',70],  [5,n('C4'),'hh',28]
    ]],
    // P2 — A var: Cm with deeper organ swells
    [32,[
      [0,n('C2'),'bs',94],  [7,n('C3'),'dr',25], [2,n('G3'),'og',62],  [5,n('C4'),'hh',35],
      [1,n('Eb4'),'ml',74], [5,n('C4'),'hh',30], [2,n('Eb3'),'pd',54], 0,
      [3,n('C2'),'kk',100], 0, [1,n('D4'),'ml',70],  [5,n('C4'),'hh',35],
      0, [4,n('C4'),'sn',80], [1,n('C4'),'ml',72],   0,
      [0,n('C2'),'bs',90],  0, [2,n('Bb3'),'og',58],  [5,n('C4'),'hh',35],
      [1,n('D4'),'ml',72],  [5,n('C4'),'hh',30], [2,n('G3'),'pd',52],  0,
      [3,n('C2'),'kk',95],  [7,n('C3'),'dr',22], [1,n('Eb4'),'ml',76], [5,n('C4'),'hh',35],
      0, [4,n('C4'),'sn',78], [1,n('C4'),'ml',68],   [5,n('C4'),'hh',28]
    ]],
    // P3 — A': ends on Bb-Eb (VII-III, dominant feel) for loop
    [32,[
      [0,n('C2'),'bs',92],  0, [2,n('Eb3'),'og',58], [5,n('C4'),'hh',35],
      [1,n('C4'),'ml',70],  [5,n('C4'),'hh',30], [2,n('G3'),'pd',50],  0,
      [3,n('C2'),'kk',98],  0, [1,n('D4'),'ml',68],  [5,n('C4'),'hh',35],
      [7,n('C3'),'dr',20],  [4,n('C4'),'sn',78], [1,n('Eb4'),'ml',72], 0,
      [0,n('Bb2'),'bs',94], 0, [2,n('F3'),'og',60],  [5,n('C4'),'hh',35],
      [1,n('F4'),'ml',76],  [5,n('C4'),'hh',30], [2,n('D4'),'pd',54],  0,
      [3,n('Eb2'),'kk',100],0, [1,n('Eb4'),'ml',74], [5,n('C4'),'hh',35],
      0, [4,n('C4'),'sn',82], [1,n('Bb3'),'ml',68],  [5,n('C4'),'hh',28]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 16. WARDEN — Security. Solemn patrol.
//     Bb minor, 78 BPM, SNES. Bbm-Gb-Ab-Bbm.
// ============================================================
L['agent-warden'] = {
  bpm:78, chip:'snes',
  echo:[380,0.42,0.4,2600],
  inst:{
    pt: I('sq25',  0.01, 0.18, 0.4,  0.25, false),
    ml: I('str',   0.06, 0.2,  0.55, 0.35, true),
    pd: I('str',   0.15, 0.35, 0.6,  0.5,  true),
    bs: I('bas',   0.01, 0.12, 0.75, 0.2,  false),
    kk: I('kck',   0.001,0.1,  0,    0.12, false),
    sn: I('snr',   0.002,0.12, 0,    0.15, false),
    hh: I('hh',    0.001,0.06, 0,    0.06, false),
    tx: I('pnoi',  0.04, 0.18, 0.12, 0.25, false)
  },
  pats:[
    // P0 — A: Bbm patrol rhythm, solemn steps
    [32,[
      [0,n('Bb1'),'bs',95], 0, [2,n('Db3'),'pd',55], [5,n('Bb3'),'hh',32],
      0, [5,n('Bb3'),'hh',28], [1,n('Bb3'),'ml',72],  0,
      [3,n('Bb1'),'kk',100],0, [1,n('C4'),'ml',68],   [5,n('Bb3'),'hh',32],
      [7,n('Bb2'),'tx',20], [4,n('Bb3'),'sn',80],[1,n('Db4'),'ml',74], 0,
      [0,n('Bb1'),'bs',90], 0, [2,n('F3'),'pd',52],   [5,n('Bb3'),'hh',32],
      0, [5,n('Bb3'),'hh',28], [1,n('C4'),'pt',68],   0,
      [3,n('Bb1'),'kk',95], 0, [1,n('Bb3'),'ml',70],  [5,n('Bb3'),'hh',32],
      0, [4,n('Bb3'),'sn',78], [1,n('Ab3'),'ml',65],  [5,n('Bb3'),'hh',25]
    ]],
    // P1 — B: Gb to Ab, watchful ascent
    [32,[
      [0,n('Gb1'),'bs',94], 0, [2,n('Bb3'),'pd',55], [5,n('Bb3'),'hh',32],
      0, [5,n('Bb3'),'hh',28], [1,n('Gb4'),'ml',75],  0,
      [3,n('Gb1'),'kk',100],0, [1,n('F4'),'ml',72],   [5,n('Bb3'),'hh',32],
      [7,n('Gb2'),'tx',22], [4,n('Bb3'),'sn',82],[1,n('Eb4'),'ml',70], 0,
      [0,n('Ab1'),'bs',96], 0, [2,n('C4'),'pd',55],   [5,n('Bb3'),'hh',32],
      0, [5,n('Bb3'),'hh',28], [1,n('Ab4'),'ml',80],  0,
      [3,n('Ab1'),'kk',100],0, [1,n('Gb4'),'ml',74],  [5,n('Bb3'),'hh',32],
      0, [4,n('Bb3'),'sn',80], [1,n('F4'),'pt',68],   [5,n('Bb3'),'hh',25]
    ]],
    // P2 — A var: Bbm with heavier tread
    [32,[
      [0,n('Bb1'),'bs',96], [7,n('Bb2'),'tx',24],[2,n('Db3'),'pd',58], [5,n('Bb3'),'hh',35],
      0, [5,n('Bb3'),'hh',28], [1,n('Db4'),'ml',74],  0,
      [3,n('Bb1'),'kk',100],0, [1,n('Eb4'),'ml',78],  [5,n('Bb3'),'hh',32],
      0, [4,n('Bb3'),'sn',82], [1,n('Db4'),'ml',72],  0,
      [0,n('Bb1'),'bs',92], 0, [2,n('F3'),'pd',54],   [5,n('Bb3'),'hh',35],
      0, [5,n('Bb3'),'hh',28], [1,n('C4'),'pt',70],   0,
      [3,n('Bb1'),'kk',95], [7,n('Bb2'),'tx',20],[1,n('Bb3'),'ml',72], [5,n('Bb3'),'hh',32],
      0, [4,n('Bb3'),'sn',78], [1,n('Ab3'),'ml',66],  [5,n('Bb3'),'hh',25]
    ]],
    // P3 — A': ends on Ab (VII) for loop
    [32,[
      [0,n('Bb1'),'bs',94], 0, [2,n('Db3'),'pd',55], [5,n('Bb3'),'hh',32],
      0, [5,n('Bb3'),'hh',28], [1,n('Bb3'),'ml',70],  0,
      [3,n('Bb1'),'kk',98], 0, [1,n('C4'),'ml',68],   [5,n('Bb3'),'hh',32],
      [7,n('Bb2'),'tx',20], [4,n('Bb3'),'sn',78],[1,n('Db4'),'ml',72], 0,
      [0,n('Ab1'),'bs',96], 0, [2,n('C4'),'pd',58],   [5,n('Bb3'),'hh',35],
      0, [5,n('Bb3'),'hh',30], [1,n('Eb4'),'ml',78],  0,
      [3,n('Ab1'),'kk',100],0, [1,n('Db4'),'ml',74],  [5,n('Bb3'),'hh',32],
      0, [4,n('Bb3'),'sn',82], [1,n('Ab3'),'pt',68],  [5,n('Bb3'),'hh',25]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};

// ============================================================
// 17. CACHE — Memory, quick-access. Glitchy FM.
//     F# minor, 92 BPM, Genesis. F#m-D-E-F#m.
// ============================================================
L['agent-cache'] = {
  bpm:92, chip:'genesis',
  echo:[360,0.42,0.4,2800],
  inst:{
    gl: I('fmLead', 0.002,0.06, 0.35, 0.1,  false),
    ml: I('fmEP',   0.005,0.1,  0.45, 0.2,  false),
    br: I('fmBrass',0.03, 0.18, 0.5,  0.25, true),
    bs: I('fmBass', 0.005,0.08, 0.7,  0.12, false),
    ac: I('acid',   0.002,0.05, 0.3,  0.08, false),
    kk: I('fmBass', 0.001,0.06, 0,    0.08, false),
    sn: I('mhat',   0.001,0.08, 0,    0.1,  false),
    hh: I('ohat',   0.001,0.04, 0,    0.04, false)
  },
  pats:[
    // P0 — A: F#m glitch retrieval, D answer
    [32,[
      [0,n('F#2'),'bs',92], [5,n('F#4'),'hh',48],[1,n('F#4'),'gl',78], [5,n('F#4'),'hh',38],
      0, [1,n('G#4'),'gl',72],[5,n('F#4'),'hh',45],[1,n('A4'),'ml',75],
      [3,n('F#2'),'kk',100],[5,n('F#4'),'hh',38],[1,n('G#4'),'gl',70], [7,n('C#4'),'ac',32],
      [2,n('A3'),'br',48],  [4,n('F#4'),'sn',82],[1,n('F#4'),'ml',72], [5,n('F#4'),'hh',38],
      [0,n('D2'),'bs',90],  [5,n('F#4'),'hh',48],[1,n('D4'),'ml',76],  [5,n('F#4'),'hh',38],
      [1,n('E4'),'gl',70],  [5,n('F#4'),'hh',45],[1,n('F#4'),'gl',74], 0,
      [3,n('D2'),'kk',98],  [5,n('F#4'),'hh',38],[1,n('E4'),'ml',72],  [7,n('A3'),'ac',30],
      [2,n('F#3'),'br',46], [4,n('F#4'),'sn',80],[1,n('D4'),'ml',68],  [5,n('F#4'),'hh',38]
    ]],
    // P1 — B: E to F#m, rising cache hit
    [32,[
      [0,n('E2'),'bs',92],  [5,n('F#4'),'hh',48],[1,n('E4'),'gl',78],  [5,n('F#4'),'hh',38],
      [1,n('F#4'),'gl',75], [5,n('F#4'),'hh',45],[1,n('G#4'),'ml',78], 0,
      [3,n('E2'),'kk',100], [5,n('F#4'),'hh',38],[1,n('A4'),'gl',82],  [7,n('B3'),'ac',34],
      [2,n('G#3'),'br',50], [4,n('F#4'),'sn',85],[1,n('B4'),'ml',85],  [5,n('F#4'),'hh',38],
      [0,n('F#2'),'bs',94], [5,n('F#4'),'hh',48],[1,n('A4'),'gl',80],  [5,n('F#4'),'hh',38],
      [1,n('G#4'),'gl',76], [5,n('F#4'),'hh',45],[1,n('F#4'),'ml',74], 0,
      [3,n('F#2'),'kk',100],[5,n('F#4'),'hh',38],[1,n('E4'),'gl',72],  [7,n('C#4'),'ac',30],
      [2,n('A3'),'br',48],  [4,n('F#4'),'sn',82],[1,n('C#4'),'ml',68], [5,n('F#4'),'hh',38]
    ]],
    // P2 — A var: glitch stutter pattern
    [32,[
      [0,n('F#2'),'bs',92], [5,n('F#4'),'hh',48],[1,n('F#4'),'gl',76], [1,n('F#4'),'ac',40],
      [5,n('F#4'),'hh',42], [1,n('A4'),'gl',74], [5,n('F#4'),'hh',45], [1,n('G#4'),'ml',72],
      [3,n('F#2'),'kk',100],[5,n('F#4'),'hh',38],[1,n('A4'),'gl',78],  0,
      [2,n('C#4'),'br',48], [4,n('F#4'),'sn',82],[1,n('G#4'),'ml',70], [5,n('F#4'),'hh',38],
      [0,n('D2'),'bs',90],  [5,n('F#4'),'hh',48],[1,n('D4'),'gl',74],  [1,n('D4'),'ac',38],
      [5,n('F#4'),'hh',42], [1,n('E4'),'gl',72], [5,n('F#4'),'hh',45], [1,n('F#4'),'ml',76],
      [3,n('D2'),'kk',98],  [5,n('F#4'),'hh',38],[1,n('E4'),'gl',70],  [7,n('A3'),'ac',32],
      [2,n('F#3'),'br',46], [4,n('F#4'),'sn',80],[1,n('D4'),'ml',66],  [5,n('F#4'),'hh',38]
    ]],
    // P3 — A': ends on E (VII) for loop
    [32,[
      [0,n('F#2'),'bs',90], [5,n('F#4'),'hh',48],[1,n('F#4'),'gl',76], [5,n('F#4'),'hh',38],
      0, [1,n('G#4'),'gl',72],[5,n('F#4'),'hh',45],[1,n('A4'),'ml',74],
      [3,n('F#2'),'kk',100],[5,n('F#4'),'hh',38],[1,n('G#4'),'gl',70], 0,
      [2,n('A3'),'br',48],  [4,n('F#4'),'sn',80],[1,n('F#4'),'ml',68], [5,n('F#4'),'hh',38],
      [0,n('E2'),'bs',94],  [5,n('F#4'),'hh',48],[1,n('E4'),'gl',80],  [5,n('F#4'),'hh',38],
      [1,n('F#4'),'gl',76], [5,n('F#4'),'hh',45],[1,n('G#4'),'ml',78], [7,n('B3'),'ac',35],
      [3,n('E2'),'kk',100], [5,n('F#4'),'hh',38],[1,n('F#4'),'gl',74], 0,
      [2,n('B3'),'br',50],  [4,n('F#4'),'sn',85],[1,n('E4'),'ml',70],  [5,n('F#4'),'hh',38]
    ]]
  ],
  seq:[0,1,0,1,2,2,3,0]
};
// ============================================================
// 18. VOLT — Electric energy, crackling FM
// E Major (E-A-B-E), genesis, 135 BPM
// ============================================================
L['agent-volt'] = {
  bpm: 135, chip: 'genesis',
  echo: [140, 0.22, 0.2, 5000],
  inst: {
    bass:  I('fmBass',  0, 80, 0.6, 120, false),
    lead:  I('fmLead',  5, 60, 0.5, 100, false),
    brass: I('fmBrass', 0, 40, 0.4, 150, false),
    ep:    I('fmEP',    10, 90, 0.3, 200, false),
    kick:  I('fmBass',  0, 10, 0, 50, false),
    snare: I('mhat',    0, 30, 0, 80, false),
    hat:   I('ohat',    0, 15, 0, 40, false),
    zap:   I('acid',    0, 20, 0.2, 60, false)
  },
  pats: [
    // P0 — E chord, driving bass, buzzy lead
    [32, [
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('E4'),'lead',90],  [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('F#4'),'lead',85], [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',95], [1,n('G#4'),'lead',90],
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('A4'),'lead',95],  [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('G#4'),'lead',85], [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [3,n('C2'),'kick',110],[4,n('C3'),'snare',95], [1,n('E4'),'lead',80]
    ]],
    // P1 — A chord, ascending energy
    [32, [
      [0,n('A2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('A4'),'lead',90],  [5,n('E4'),'hat',40],
      [0,n('A2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('A2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('B4'),'lead',88],  [5,n('E4'),'hat',40],
      [0,n('A2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',95], [1,n('C#5'),'lead',92],
      [0,n('A2'),'bass',100], [7,n('E5'),'zap',60],  [1,n('B4'),'lead',85],  [5,n('E4'),'hat',40],
      [0,n('A2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('A2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('A4'),'lead',80],  [5,n('E4'),'hat',40],
      [0,n('A2'),'bass',80],  [3,n('C2'),'kick',110],[4,n('C3'),'snare',95], [1,n('G#4'),'lead',85]
    ]],
    // P2 — B chord, peak voltage
    [32, [
      [0,n('B2'),'bass',110], [5,n('E4'),'hat',55],  [1,n('B4'),'lead',95],  [5,n('E4'),'hat',40],
      [0,n('B2'),'bass',90],  [7,n('F#5'),'zap',70], [4,n('C3'),'snare',110],[5,n('E4'),'hat',40],
      [0,n('B2'),'bass',110], [5,n('E4'),'hat',55],  [1,n('C#5'),'lead',100],[7,n('D#5'),'zap',55],
      [0,n('B2'),'bass',90],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[1,n('D#5'),'lead',105],
      [0,n('B2'),'bass',110], [5,n('E4'),'hat',55],  [1,n('E5'),'lead',110], [5,n('E4'),'hat',40],
      [0,n('B2'),'bass',90],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',105],[7,n('B4'),'zap',60],
      [0,n('B2'),'bass',110], [5,n('E4'),'hat',55],  [1,n('D#5'),'lead',90], [5,n('E4'),'hat',40],
      [0,n('B2'),'bass',90],  [3,n('C2'),'kick',115],[4,n('C3'),'snare',100],[1,n('C#5'),'lead',88]
    ]],
    // P3 — E resolve, ends on B (V) for loop
    [32, [
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('E4'),'lead',90],  [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('E2'),'bass',100], [5,n('E4'),'hat',50],  [1,n('F#4'),'lead',85], [5,n('E4'),'hat',40],
      [0,n('E2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',95], [1,n('G#4'),'lead',88],
      [0,n('B2'),'bass',95],  [5,n('E4'),'hat',50],  [1,n('F#4'),'lead',82], [5,n('E4'),'hat',40],
      [0,n('B2'),'bass',80],  [5,n('E4'),'hat',50],  [4,n('C3'),'snare',100],[5,n('E4'),'hat',40],
      [0,n('B2'),'bass',95],  [5,n('E4'),'hat',50],  [1,n('D#4'),'lead',78], [7,n('F#4'),'zap',50],
      [0,n('B2'),'bass',80],  [3,n('C2'),'kick',110],[4,n('C3'),'snare',90], [2,n('B3'),'brass',60]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 19. PROMO — Marketing charisma, catchy FM hook
// A Major (A-D-E-A), genesis, 125 BPM
// ============================================================
L['agent-promo'] = {
  bpm: 125, chip: 'genesis',
  echo: [180, 0.25, 0.22, 4800],
  inst: {
    bass:  I('fmBass',  0, 70, 0.6, 100, false),
    lead:  I('fmLead',  5, 50, 0.5, 120, false),
    brass: I('fmBrass', 10, 60, 0.4, 180, false),
    ep:    I('fmEP',    15, 80, 0.35, 200, false),
    kick:  I('fmBass',  0, 10, 0, 50, false),
    snare: I('mhat',    0, 25, 0, 70, false),
    hat:   I('ohat',    0, 12, 0, 35, false),
    stab:  I('acid',    0, 30, 0.3, 80, false)
  },
  pats: [
    // P0 — A chord, catchy ascending hook
    [32, [
      [0,n('A2'),'bass',100], [5,n('F#4'),'hat',45], [1,n('A4'),'lead',90],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',110], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',100],[1,n('B4'),'lead',85],
      [0,n('A2'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('C#5'),'lead',92], [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',95], [1,n('B4'),'lead',88],
      [0,n('A2'),'bass',100], [5,n('F#4'),'hat',45], [1,n('A4'),'lead',85],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',110], [2,n('E4'),'ep',55],   [4,n('C3'),'snare',100],[5,n('F#4'),'hat',40],
      [0,n('A2'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('A4'),'lead',80],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',90], [2,n('C#4'),'ep',50]
    ]],
    // P1 — D chord, punchy brass stabs
    [32, [
      [0,n('D3'),'bass',100], [5,n('F#4'),'hat',45], [1,n('D5'),'lead',92],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',110], [7,n('A4'),'stab',70], [4,n('C3'),'snare',100],[1,n('C#5'),'lead',88],
      [0,n('D3'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('B4'),'lead',85],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',95], [1,n('A4'),'lead',90],
      [0,n('D3'),'bass',100], [5,n('F#4'),'hat',45], [1,n('B4'),'lead',88],  [7,n('F#4'),'stab',65],
      [3,n('C2'),'kick',110], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',100],[5,n('F#4'),'hat',40],
      [0,n('D3'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('A4'),'lead',82],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [2,n('D4'),'brass',60],[4,n('C3'),'snare',90], [1,n('F#4'),'lead',78]
    ]],
    // P2 — E chord, peak energy hook
    [32, [
      [0,n('E2'),'bass',110], [5,n('F#4'),'hat',50], [1,n('E5'),'lead',100], [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',115], [7,n('B4'),'stab',75], [4,n('C3'),'snare',110],[1,n('D5'),'lead',95],
      [0,n('E2'),'bass',105], [5,n('F#4'),'hat',50], [1,n('C#5'),'lead',98], [7,n('G#4'),'stab',70],
      [3,n('C2'),'kick',110], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',105],[1,n('E5'),'lead',105],
      [0,n('E2'),'bass',110], [5,n('F#4'),'hat',50], [1,n('D5'),'lead',92],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',115], [2,n('G#4'),'brass',65],[4,n('C3'),'snare',110],[5,n('F#4'),'hat',40],
      [0,n('E2'),'bass',105], [5,n('F#4'),'hat',50], [1,n('C#5'),'lead',88], [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',110], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',100],[1,n('B4'),'lead',85]
    ]],
    // P3 — A resolve, ends on E (V) for loop
    [32, [
      [0,n('A2'),'bass',100], [5,n('F#4'),'hat',45], [1,n('A4'),'lead',88],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',110], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',100],[1,n('B4'),'lead',82],
      [0,n('A2'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('C#5'),'lead',85], [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',95], [1,n('A4'),'lead',80],
      [0,n('E2'),'bass',95],  [5,n('F#4'),'hat',45], [1,n('G#4'),'lead',82], [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',108], [5,n('F#4'),'hat',45], [4,n('C3'),'snare',95], [5,n('F#4'),'hat',40],
      [0,n('E2'),'bass',90],  [5,n('F#4'),'hat',45], [1,n('B4'),'lead',78],  [5,n('F#4'),'hat',40],
      [3,n('C2'),'kick',105], [2,n('E4'),'ep',55],   [4,n('C3'),'snare',88], [2,n('G#3'),'brass',50]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 20. ARC — Storyteller, floating narrative
// Bb Lydian (Bbmaj7-Cm7-F7-Bbmaj7), snes, 88 BPM
// ============================================================
L['agent-arc'] = {
  bpm: 88, chip: 'snes',
  echo: [350, 0.4, 0.38, 3000],
  inst: {
    bass: I('bas',  10, 120, 0.5, 300, false),
    mel:  I('str',  20, 150, 0.6, 400, true),
    pad:  I('sin',  50, 200, 0.5, 500, true),
    pno:  I('pno',  5,  80, 0.4, 250, false),
    kick: I('kck',  0,  10, 0, 50, false),
    snare:I('snr',  0,  30, 0, 100, false),
    hat:  I('hh',   0,  15, 0, 40, false),
    tex:  I('tri',  30, 180, 0.3, 350, true)
  },
  pats: [
    // P0 — Bbmaj7, gentle floating melody in Bb Lydian
    [32, [
      [0,n('Bb2'),'bass',80], [5,n('Bb4'),'hat',30], [1,n('Bb4'),'mel',75],  0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('D4'),'pad',50],   [1,n('C5'),'mel',70],
      [0,n('Bb2'),'bass',75], [5,n('Bb4'),'hat',30], [1,n('D5'),'mel',78],   0,
      0,                       [5,n('Bb4'),'hat',25], [4,n('C3'),'snare',65], [1,n('E5'),'mel',72],
      [0,n('Bb2'),'bass',80], [5,n('Bb4'),'hat',30], [1,n('F5'),'mel',80],   0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('A4'),'pad',48],   [1,n('E5'),'mel',70],
      [0,n('Bb2'),'bass',75], [5,n('Bb4'),'hat',30], [1,n('D5'),'mel',72],   0,
      [3,n('C2'),'kick',70],  [5,n('Bb4'),'hat',25], [7,n('F4'),'tex',35],   [1,n('C5'),'mel',68]
    ]],
    // P1 — Cm7, slightly more motion
    [32, [
      [0,n('C3'),'bass',78],  [5,n('Bb4'),'hat',30], [1,n('C5'),'mel',75],   0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('Eb4'),'pad',50],  [1,n('D5'),'mel',72],
      [0,n('C3'),'bass',74],  [5,n('Bb4'),'hat',30], [1,n('Eb5'),'mel',78],  [7,n('G4'),'tex',30],
      0,                       [5,n('Bb4'),'hat',25], [4,n('C3'),'snare',62], [1,n('F5'),'mel',75],
      [0,n('C3'),'bass',78],  [5,n('Bb4'),'hat',30], [1,n('Eb5'),'mel',72],  0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('Bb3'),'pad',48],  [1,n('D5'),'mel',70],
      [0,n('C3'),'bass',74],  [5,n('Bb4'),'hat',30], [1,n('C5'),'mel',68],   0,
      [3,n('C2'),'kick',68],  [5,n('Bb4'),'hat',25], 0,                       [1,n('Bb4'),'mel',65]
    ]],
    // P2 — F7, rising narrative peak
    [32, [
      [0,n('F2'),'bass',82],  [5,n('Bb4'),'hat',32], [1,n('F5'),'mel',82],   0,
      0,                       [5,n('Bb4'),'hat',28], [2,n('A4'),'pad',55],   [1,n('E5'),'mel',78],
      [0,n('F2'),'bass',78],  [5,n('Bb4'),'hat',32], [1,n('F5'),'mel',85],   [7,n('C5'),'tex',38],
      0,                       [5,n('Bb4'),'hat',28], [4,n('C3'),'snare',70], [1,n('A5'),'mel',90],
      [0,n('F2'),'bass',82],  [5,n('Bb4'),'hat',32], [1,n('G5'),'mel',85],   0,
      0,                       [5,n('Bb4'),'hat',28], [2,n('Eb5'),'pad',52],  [1,n('F5'),'mel',78],
      [0,n('F2'),'bass',78],  [5,n('Bb4'),'hat',32], [1,n('E5'),'mel',74],   0,
      [3,n('C2'),'kick',72],  [5,n('Bb4'),'hat',28], [7,n('A4'),'tex',32],   [1,n('D5'),'mel',70]
    ]],
    // P3 — Bbmaj7 resolve, ends on F (V) for loop
    [32, [
      [0,n('Bb2'),'bass',80], [5,n('Bb4'),'hat',30], [1,n('Bb4'),'mel',75],  0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('D4'),'pad',50],   [1,n('C5'),'mel',70],
      [0,n('Bb2'),'bass',75], [5,n('Bb4'),'hat',30], [1,n('D5'),'mel',72],   0,
      0,                       [5,n('Bb4'),'hat',25], [4,n('C3'),'snare',60], [1,n('C5'),'mel',68],
      [0,n('F2'),'bass',75],  [5,n('Bb4'),'hat',28], [1,n('A4'),'mel',70],   0,
      0,                       [5,n('Bb4'),'hat',25], [2,n('C4'),'pad',45],   [1,n('Bb4'),'mel',65],
      [0,n('F2'),'bass',72],  [5,n('Bb4'),'hat',28], [1,n('A4'),'mel',62],   [7,n('F4'),'tex',28],
      [3,n('C2'),'kick',65],  0,                      [2,n('Eb4'),'pad',42],  [1,n('A4'),'mel',60]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 21. LOOP — Iteration, cycling pluck patterns
// G Dorian (Gm7-C7-Gm7-D7), snes, 108 BPM
// ============================================================
L['agent-loop'] = {
  bpm: 108, chip: 'snes',
  echo: [250, 0.3, 0.3, 4000],
  inst: {
    bass:  I('bas',  0, 60, 0.55, 150, false),
    pluck: I('pno',  0, 40, 0.3, 100, false),
    pad:   I('str',  40, 160, 0.5, 350, true),
    bell:  I('sin',  0, 50, 0.2, 120, false),
    kick:  I('kck',  0, 10, 0, 50, false),
    snare: I('snr',  0, 25, 0, 80, false),
    hat:   I('hh',   0, 12, 0, 35, false),
    tex:   I('tri',  10, 100, 0.25, 200, true)
  },
  pats: [
    // P0 — Gm7, cycling pluck motif
    [32, [
      [0,n('G2'),'bass',90],  [5,n('G4'),'hat',40],  [1,n('G4'),'pluck',80], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',100], [5,n('G4'),'hat',40],  [4,n('C3'),'snare',90], [1,n('A4'),'pluck',75],
      [0,n('G2'),'bass',85],  [5,n('G4'),'hat',40],  [1,n('Bb4'),'pluck',82],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',95],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',85], [1,n('A4'),'pluck',78],
      [0,n('G2'),'bass',90],  [5,n('G4'),'hat',40],  [1,n('G4'),'pluck',80], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',100], [7,n('D4'),'tex',40],  [4,n('C3'),'snare',90], [1,n('A4'),'pluck',72],
      [0,n('G2'),'bass',85],  [5,n('G4'),'hat',40],  [1,n('Bb4'),'pluck',78],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',95],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',85], [1,n('G4'),'pluck',75]
    ]],
    // P1 — C7, cycle shifts up
    [32, [
      [0,n('C3'),'bass',90],  [5,n('G4'),'hat',40],  [1,n('C5'),'pluck',82], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',100], [5,n('G4'),'hat',40],  [4,n('C3'),'snare',90], [1,n('D5'),'pluck',78],
      [0,n('C3'),'bass',85],  [5,n('G4'),'hat',40],  [1,n('Eb5'),'pluck',85],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',95],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',85], [1,n('D5'),'pluck',80],
      [0,n('C3'),'bass',90],  [5,n('G4'),'hat',40],  [1,n('C5'),'pluck',82], [7,n('Bb3'),'tex',38],
      [3,n('C2'),'kick',100], [5,n('G4'),'hat',40],  [4,n('C3'),'snare',90], [1,n('Bb4'),'pluck',75],
      [0,n('C3'),'bass',85],  [5,n('G4'),'hat',40],  [1,n('C5'),'pluck',78], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',95],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',85], [1,n('Bb4'),'pluck',72]
    ]],
    // P2 — D7, peak of the cycle
    [32, [
      [0,n('D3'),'bass',95],  [5,n('G4'),'hat',42],  [1,n('D5'),'pluck',88], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',105], [5,n('G4'),'hat',42],  [4,n('C3'),'snare',95], [1,n('Eb5'),'pluck',85],
      [0,n('D3'),'bass',90],  [5,n('G4'),'hat',42],  [1,n('F5'),'pluck',92], [7,n('A4'),'tex',42],
      [3,n('C2'),'kick',100], [6,n('D4'),'bell',50], [4,n('C3'),'snare',90], [1,n('Eb5'),'pluck',88],
      [0,n('D3'),'bass',95],  [5,n('G4'),'hat',42],  [1,n('D5'),'pluck',85], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',105], [5,n('G4'),'hat',42],  [4,n('C3'),'snare',95], [1,n('C5'),'pluck',80],
      [0,n('D3'),'bass',90],  [5,n('G4'),'hat',42],  [1,n('Bb4'),'pluck',78],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',100], [5,n('G4'),'hat',42],  [4,n('C3'),'snare',90], [1,n('A4'),'pluck',75]
    ]],
    // P3 — Gm7 resolve, ends on D (V) for loop
    [32, [
      [0,n('G2'),'bass',88],  [5,n('G4'),'hat',40],  [1,n('G4'),'pluck',78], [5,n('G4'),'hat',35],
      [3,n('C2'),'kick',98],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',88], [1,n('A4'),'pluck',74],
      [0,n('G2'),'bass',84],  [5,n('G4'),'hat',40],  [1,n('Bb4'),'pluck',76],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',92],  [5,n('G4'),'hat',40],  [4,n('C3'),'snare',84], [1,n('A4'),'pluck',72],
      [0,n('D3'),'bass',85],  [5,n('G4'),'hat',38],  [1,n('F#4'),'pluck',74],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',95],  [7,n('A3'),'tex',35],  [4,n('C3'),'snare',85], [1,n('A4'),'pluck',70],
      [0,n('D3'),'bass',82],  [5,n('G4'),'hat',38],  [1,n('F#4'),'pluck',72],[5,n('G4'),'hat',35],
      [3,n('C2'),'kick',90],  [5,n('G4'),'hat',38],  [4,n('C3'),'snare',82], [2,n('D4'),'pad',45]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 22. NEXUS — Connector hub, linking harmonies
// Eb Major (Eb-Ab-Bb-Eb), snes, 95 BPM
// ============================================================
L['agent-nexus'] = {
  bpm: 95, chip: 'snes',
  echo: [300, 0.35, 0.32, 3500],
  inst: {
    bass:  I('bas',  5, 100, 0.55, 200, false),
    mel:   I('pno',  5, 70, 0.4, 180, false),
    pad:   I('str',  60, 200, 0.55, 450, true),
    bell:  I('sin',  0, 60, 0.25, 150, false),
    kick:  I('kck',  0, 10, 0, 50, false),
    snare: I('snr',  0, 25, 0, 80, false),
    hat:   I('hh',   0, 12, 0, 35, false),
    link:  I('tri',  5, 40, 0.2, 100, false)
  },
  pats: [
    // P0 — Eb, warm connecting theme
    [32, [
      [0,n('Eb2'),'bass',85], [5,n('Eb4'),'hat',35], [1,n('Eb4'),'mel',78],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',95],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',80], [1,n('F4'),'mel',75],
      [0,n('Eb2'),'bass',82], [5,n('Eb4'),'hat',35], [1,n('G4'),'mel',80],   [2,n('Bb3'),'pad',50],
      [3,n('C2'),'kick',90],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',78], [1,n('Ab4'),'mel',76],
      [0,n('Eb2'),'bass',85], [5,n('Eb4'),'hat',35], [1,n('Bb4'),'mel',82],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',95],  [7,n('G4'),'link',40], [4,n('C3'),'snare',80], [1,n('Ab4'),'mel',74],
      [0,n('Eb2'),'bass',82], [5,n('Eb4'),'hat',35], [1,n('G4'),'mel',76],   [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',90],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',75], [1,n('F4'),'mel',72]
    ]],
    // P1 — Ab, ascending link
    [32, [
      [0,n('Ab2'),'bass',85], [5,n('Eb4'),'hat',35], [1,n('Ab4'),'mel',78],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',95],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',80], [1,n('Bb4'),'mel',76],
      [0,n('Ab2'),'bass',82], [5,n('Eb4'),'hat',35], [1,n('C5'),'mel',82],   [7,n('Eb4'),'link',42],
      [3,n('C2'),'kick',90],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',78], [1,n('Bb4'),'mel',78],
      [0,n('Ab2'),'bass',85], [5,n('Eb4'),'hat',35], [1,n('Ab4'),'mel',75],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',95],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',80], [1,n('G4'),'mel',72],
      [0,n('Ab2'),'bass',82], [5,n('Eb4'),'hat',35], [1,n('Ab4'),'mel',74],  [2,n('C4'),'pad',48],
      [3,n('C2'),'kick',90],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',75], [1,n('G4'),'mel',70]
    ]],
    // P2 — Bb, peak connection
    [32, [
      [0,n('Bb2'),'bass',90], [5,n('Eb4'),'hat',38], [1,n('Bb4'),'mel',85],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',100], [5,n('Eb4'),'hat',38], [4,n('C3'),'snare',88], [1,n('C5'),'mel',82],
      [0,n('Bb2'),'bass',88], [5,n('Eb4'),'hat',38], [1,n('D5'),'mel',88],   [7,n('F4'),'link',45],
      [3,n('C2'),'kick',95],  [6,n('Bb4'),'bell',45],[4,n('C3'),'snare',85], [1,n('Eb5'),'mel',92],
      [0,n('Bb2'),'bass',90], [5,n('Eb4'),'hat',38], [1,n('D5'),'mel',85],   [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',100], [5,n('Eb4'),'hat',38], [4,n('C3'),'snare',88], [1,n('C5'),'mel',80],
      [0,n('Bb2'),'bass',88], [5,n('Eb4'),'hat',38], [1,n('Bb4'),'mel',78],  [2,n('D4'),'pad',52],
      [3,n('C2'),'kick',95],  [5,n('Eb4'),'hat',38], [4,n('C3'),'snare',82], [1,n('Ab4'),'mel',74]
    ]],
    // P3 — Eb resolve, ends on Bb (V) for loop
    [32, [
      [0,n('Eb2'),'bass',84], [5,n('Eb4'),'hat',35], [1,n('Eb4'),'mel',76],  [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',92],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',78], [1,n('F4'),'mel',72],
      [0,n('Eb2'),'bass',80], [5,n('Eb4'),'hat',35], [1,n('G4'),'mel',74],   [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',88],  [5,n('Eb4'),'hat',35], [4,n('C3'),'snare',75], [1,n('F4'),'mel',70],
      [0,n('Bb2'),'bass',82], [5,n('Eb4'),'hat',32], [1,n('D4'),'mel',72],   [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',90],  [7,n('Bb3'),'link',35],[4,n('C3'),'snare',76], [1,n('F4'),'mel',68],
      [0,n('Bb2'),'bass',78], [5,n('Eb4'),'hat',32], [1,n('D4'),'mel',66],   [5,n('Eb4'),'hat',30],
      [3,n('C2'),'kick',85],  [5,n('Eb4'),'hat',32], [4,n('C3'),'snare',72], [2,n('Bb3'),'pad',42]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 23. FORGE — Builder, hammering FM rhythm
// D minor (Dm-Gm-A7-Dm), genesis, 118 BPM
// ============================================================
L['agent-forge'] = {
  bpm: 118, chip: 'genesis',
  echo: [200, 0.28, 0.25, 4200],
  inst: {
    bass:  I('fmBass',  0, 50, 0.65, 100, false),
    lead:  I('fmLead',  0, 40, 0.45, 80, false),
    brass: I('fmBrass', 5, 30, 0.5, 120, false),
    ep:    I('fmEP',    10, 70, 0.35, 160, false),
    kick:  I('fmBass',  0, 8, 0, 40, false),
    snare: I('mhat',    0, 20, 0, 60, false),
    hat:   I('ohat',    0, 10, 0, 30, false),
    anvil: I('acid',    0, 15, 0.1, 40, false)
  },
  pats: [
    // P0 — Dm, heavy rhythmic hammering
    [32, [
      [0,n('D2'),'bass',110], [5,n('D4'),'hat',45],  [1,n('D4'),'lead',85],  [7,n('A4'),'anvil',60],
      [3,n('C2'),'kick',115], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',105],[5,n('D4'),'hat',40],
      [0,n('D2'),'bass',105], [5,n('D4'),'hat',45],  [1,n('E4'),'lead',82],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',110], [7,n('D5'),'anvil',55],[4,n('C3'),'snare',100],[1,n('F4'),'lead',88],
      [0,n('D2'),'bass',110], [5,n('D4'),'hat',45],  [1,n('G4'),'lead',90],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',115], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',105],[7,n('A4'),'anvil',58],
      [0,n('D2'),'bass',105], [5,n('D4'),'hat',45],  [1,n('F4'),'lead',84],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',110], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',100],[1,n('D4'),'lead',80]
    ]],
    // P1 — Gm, ascending forge heat
    [32, [
      [0,n('G2'),'bass',108], [5,n('D4'),'hat',45],  [1,n('G4'),'lead',85],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',112], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',102],[1,n('A4'),'lead',82],
      [0,n('G2'),'bass',104], [5,n('D4'),'hat',45],  [1,n('Bb4'),'lead',88], [7,n('D4'),'anvil',52],
      [3,n('C2'),'kick',108], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',98], [1,n('A4'),'lead',85],
      [0,n('G2'),'bass',108], [5,n('D4'),'hat',45],  [1,n('G4'),'lead',82],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',112], [2,n('Bb3'),'brass',55],[4,n('C3'),'snare',102],[5,n('D4'),'hat',40],
      [0,n('G2'),'bass',104], [5,n('D4'),'hat',45],  [1,n('F4'),'lead',78],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',108], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',98], [1,n('E4'),'lead',75]
    ]],
    // P2 — A7, white-hot peak
    [32, [
      [0,n('A2'),'bass',115], [5,n('D4'),'hat',48],  [1,n('A4'),'lead',92],  [7,n('E5'),'anvil',65],
      [3,n('C2'),'kick',118], [5,n('D4'),'hat',48],  [4,n('C3'),'snare',110],[1,n('Bb4'),'lead',90],
      [0,n('A2'),'bass',112], [5,n('D4'),'hat',48],  [1,n('C5'),'lead',95],  [5,n('D4'),'hat',42],
      [3,n('C2'),'kick',115], [7,n('A4'),'anvil',62],[4,n('C3'),'snare',108],[1,n('D5'),'lead',100],
      [0,n('A2'),'bass',115], [5,n('D4'),'hat',48],  [1,n('C5'),'lead',92],  [5,n('D4'),'hat',42],
      [3,n('C2'),'kick',118], [2,n('E4'),'brass',60],[4,n('C3'),'snare',110],[7,n('C#5'),'anvil',58],
      [0,n('A2'),'bass',112], [5,n('D4'),'hat',48],  [1,n('Bb4'),'lead',88], [5,n('D4'),'hat',42],
      [3,n('C2'),'kick',115], [5,n('D4'),'hat',48],  [4,n('C3'),'snare',105],[1,n('A4'),'lead',85]
    ]],
    // P3 — Dm resolve, ends on A (V) for loop
    [32, [
      [0,n('D2'),'bass',105], [5,n('D4'),'hat',45],  [1,n('D4'),'lead',82],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',110], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',100],[1,n('E4'),'lead',78],
      [0,n('D2'),'bass',100], [5,n('D4'),'hat',45],  [1,n('F4'),'lead',80],  [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('D4'),'hat',45],  [4,n('C3'),'snare',95], [1,n('E4'),'lead',76],
      [0,n('A2'),'bass',100], [5,n('D4'),'hat',42],  [1,n('C#4'),'lead',78], [7,n('A3'),'anvil',48],
      [3,n('C2'),'kick',108], [5,n('D4'),'hat',42],  [4,n('C3'),'snare',98], [1,n('E4'),'lead',74],
      [0,n('A2'),'bass',96],  [5,n('D4'),'hat',42],  [1,n('C#4'),'lead',72], [5,n('D4'),'hat',40],
      [3,n('C2'),'kick',105], [5,n('D4'),'hat',42],  [4,n('C3'),'snare',92], [2,n('A3'),'ep',48]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 24. BEACON — Guide, waypoint, guiding pluck
// F Major (Fmaj7-Dm7-Gm7-C7), snes, 105 BPM
// ============================================================
L['agent-beacon'] = {
  bpm: 105, chip: 'snes',
  echo: [280, 0.35, 0.32, 3800],
  inst: {
    bass:  I('bas',  5, 90, 0.5, 180, false),
    pluck: I('pno',  0, 45, 0.35, 110, false),
    pad:   I('str',  50, 180, 0.5, 400, true),
    glow:  I('sin',  15, 100, 0.3, 200, true),
    kick:  I('kck',  0, 10, 0, 50, false),
    snare: I('snr',  0, 25, 0, 80, false),
    hat:   I('hh',   0, 12, 0, 35, false),
    chime: I('tri',  0, 35, 0.15, 80, false)
  },
  pats: [
    // P0 — Fmaj7, warm guiding light
    [32, [
      [0,n('F2'),'bass',85],  [5,n('F4'),'hat',35],  [1,n('F4'),'pluck',78], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',95],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',82], [1,n('G4'),'pluck',75],
      [0,n('F2'),'bass',82],  [5,n('F4'),'hat',35],  [1,n('A4'),'pluck',80], [6,n('C5'),'glow',40],
      [3,n('C2'),'kick',90],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',78], [1,n('Bb4'),'pluck',77],
      [0,n('F2'),'bass',85],  [5,n('F4'),'hat',35],  [1,n('C5'),'pluck',84], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',95],  [7,n('E4'),'chime',38],[4,n('C3'),'snare',82], [1,n('Bb4'),'pluck',76],
      [0,n('F2'),'bass',82],  [5,n('F4'),'hat',35],  [1,n('A4'),'pluck',74], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',90],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',78], [1,n('G4'),'pluck',72]
    ]],
    // P1 — Dm7, gentle descent
    [32, [
      [0,n('D3'),'bass',83],  [5,n('F4'),'hat',35],  [1,n('D4'),'pluck',76], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',93],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',80], [1,n('E4'),'pluck',74],
      [0,n('D3'),'bass',80],  [5,n('F4'),'hat',35],  [1,n('F4'),'pluck',78], [2,n('A3'),'pad',45],
      [3,n('C2'),'kick',88],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',76], [1,n('G4'),'pluck',76],
      [0,n('D3'),'bass',83],  [5,n('F4'),'hat',35],  [1,n('A4'),'pluck',80], [6,n('F4'),'glow',38],
      [3,n('C2'),'kick',93],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',80], [1,n('G4'),'pluck',74],
      [0,n('D3'),'bass',80],  [5,n('F4'),'hat',35],  [1,n('F4'),'pluck',72], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',88],  [5,n('F4'),'hat',35],  [4,n('C3'),'snare',76], [1,n('E4'),'pluck',70]
    ]],
    // P2 — Gm7, rising beacon
    [32, [
      [0,n('G2'),'bass',88],  [5,n('F4'),'hat',38],  [1,n('G4'),'pluck',82], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',98],  [5,n('F4'),'hat',38],  [4,n('C3'),'snare',86], [1,n('A4'),'pluck',80],
      [0,n('G2'),'bass',85],  [5,n('F4'),'hat',38],  [1,n('Bb4'),'pluck',85],[7,n('D5'),'chime',42],
      [3,n('C2'),'kick',94],  [6,n('G4'),'glow',44], [4,n('C3'),'snare',82], [1,n('C5'),'pluck',88],
      [0,n('G2'),'bass',88],  [5,n('F4'),'hat',38],  [1,n('D5'),'pluck',92], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',98],  [5,n('F4'),'hat',38],  [4,n('C3'),'snare',86], [1,n('C5'),'pluck',84],
      [0,n('G2'),'bass',85],  [5,n('F4'),'hat',38],  [1,n('Bb4'),'pluck',80],[5,n('F4'),'hat',30],
      [3,n('C2'),'kick',94],  [5,n('F4'),'hat',38],  [4,n('C3'),'snare',82], [1,n('A4'),'pluck',76]
    ]],
    // P3 — C7 resolve, ends on C (V) for loop
    [32, [
      [0,n('F2'),'bass',82],  [5,n('F4'),'hat',34],  [1,n('F4'),'pluck',75], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',90],  [5,n('F4'),'hat',34],  [4,n('C3'),'snare',78], [1,n('G4'),'pluck',72],
      [0,n('F2'),'bass',78],  [5,n('F4'),'hat',34],  [1,n('A4'),'pluck',74], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',86],  [5,n('F4'),'hat',34],  [4,n('C3'),'snare',74], [1,n('G4'),'pluck',70],
      [0,n('C3'),'bass',80],  [5,n('F4'),'hat',32],  [1,n('E4'),'pluck',72], [5,n('F4'),'hat',30],
      [3,n('C2'),'kick',88],  [7,n('G4'),'chime',34],[4,n('C3'),'snare',76], [1,n('G4'),'pluck',68],
      [0,n('C3'),'bass',76],  [5,n('F4'),'hat',32],  [1,n('E4'),'pluck',66], [6,n('Bb3'),'glow',35],
      [3,n('C2'),'kick',84],  [5,n('F4'),'hat',32],  [4,n('C3'),'snare',72], [2,n('C4'),'pad',42]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

// ============================================================
// 25. SHARD — Fragment, scattered FM fragments
// Bb minor (Bbm-Gb-Ab-F), genesis, 98 BPM
// ============================================================
L['agent-shard'] = {
  bpm: 98, chip: 'genesis',
  echo: [280, 0.35, 0.32, 3500],
  inst: {
    bass:   I('fmBass',  0, 80, 0.5, 140, false),
    lead:   I('fmLead',  0, 35, 0.4, 90, false),
    brass:  I('fmBrass', 15, 60, 0.35, 200, false),
    ep:     I('fmEP',    10, 90, 0.3, 180, false),
    kick:   I('fmBass',  0, 10, 0, 45, false),
    snare:  I('mhat',    0, 22, 0, 65, false),
    hat:    I('ohat',    0, 12, 0, 32, false),
    frag:   I('acid',    0, 18, 0.15, 50, false)
  },
  pats: [
    // P0 — Bbm, scattered fragments
    [32, [
      [0,n('Bb2'),'bass',88], [5,n('Bb4'),'hat',38], [1,n('Bb4'),'lead',78], 0,
      [3,n('C2'),'kick',98],  0,                      [4,n('C3'),'snare',85], [7,n('F4'),'frag',50],
      [0,n('Bb2'),'bass',84], [5,n('Bb4'),'hat',38], 0,                       [1,n('C5'),'lead',75],
      0,                       [5,n('Bb4'),'hat',35], [4,n('C3'),'snare',80], [7,n('Db5'),'frag',48],
      [0,n('Bb2'),'bass',88], [5,n('Bb4'),'hat',38], [1,n('Db5'),'lead',82], 0,
      [3,n('C2'),'kick',98],  [7,n('Ab4'),'frag',45],[4,n('C3'),'snare',85], [5,n('Bb4'),'hat',35],
      [0,n('Bb2'),'bass',84], 0,                      [1,n('C5'),'lead',76],  [5,n('Bb4'),'hat',35],
      [3,n('C2'),'kick',92],  [5,n('Bb4'),'hat',38], [4,n('C3'),'snare',80], [1,n('Bb4'),'lead',72]
    ]],
    // P1 — Gb, dark shimmer
    [32, [
      [0,n('Gb2'),'bass',86], [5,n('Bb4'),'hat',38], [1,n('Gb4'),'lead',76], 0,
      [3,n('C2'),'kick',96],  [7,n('Bb4'),'frag',48],[4,n('C3'),'snare',84], [5,n('Bb4'),'hat',35],
      [0,n('Gb2'),'bass',82], [5,n('Bb4'),'hat',38], [1,n('Ab4'),'lead',78], 0,
      0,                       [5,n('Bb4'),'hat',35], [4,n('C3'),'snare',80], [1,n('Bb4'),'lead',80],
      [0,n('Gb2'),'bass',86], [5,n('Bb4'),'hat',38], [1,n('Ab4'),'lead',76], [7,n('Db4'),'frag',44],
      [3,n('C2'),'kick',96],  [5,n('Bb4'),'hat',35], [4,n('C3'),'snare',84], 0,
      [0,n('Gb2'),'bass',82], [5,n('Bb4'),'hat',38], [1,n('Gb4'),'lead',72], [2,n('Db4'),'brass',45],
      [3,n('C2'),'kick',90],  [5,n('Bb4'),'hat',35], [4,n('C3'),'snare',78], [1,n('F4'),'lead',70]
    ]],
    // P2 — Ab, fragments coalesce at peak
    [32, [
      [0,n('Ab2'),'bass',92], [5,n('Bb4'),'hat',40], [1,n('Ab4'),'lead',82], [7,n('Eb5'),'frag',55],
      [3,n('C2'),'kick',102], [5,n('Bb4'),'hat',40], [4,n('C3'),'snare',90], [1,n('Bb4'),'lead',80],
      [0,n('Ab2'),'bass',88], [5,n('Bb4'),'hat',40], [1,n('C5'),'lead',86],  0,
      [3,n('C2'),'kick',98],  [7,n('Ab4'),'frag',52],[4,n('C3'),'snare',88], [1,n('Db5'),'lead',90],
      [0,n('Ab2'),'bass',92], [5,n('Bb4'),'hat',40], [1,n('Eb5'),'lead',94], [7,n('F4'),'frag',50],
      [3,n('C2'),'kick',102], [5,n('Bb4'),'hat',40], [4,n('C3'),'snare',90], [1,n('Db5'),'lead',86],
      [0,n('Ab2'),'bass',88], [5,n('Bb4'),'hat',40], [1,n('C5'),'lead',82],  [2,n('Eb4'),'ep',48],
      [3,n('C2'),'kick',98],  [5,n('Bb4'),'hat',40], [4,n('C3'),'snare',85], [1,n('Bb4'),'lead',78]
    ]],
    // P3 — F, ends on F (V of Bbm) for loop
    [32, [
      [0,n('Bb2'),'bass',85], [5,n('Bb4'),'hat',36], [1,n('Bb4'),'lead',75], 0,
      [3,n('C2'),'kick',94],  [5,n('Bb4'),'hat',36], [4,n('C3'),'snare',82], [7,n('Db4'),'frag',42],
      [0,n('Bb2'),'bass',82], [5,n('Bb4'),'hat',36], [1,n('Ab4'),'lead',72], [5,n('Bb4'),'hat',32],
      0,                       [5,n('Bb4'),'hat',34], [4,n('C3'),'snare',78], [1,n('F4'),'lead',70],
      [0,n('F2'),'bass',84],  [5,n('Bb4'),'hat',34], [1,n('F4'),'lead',72],  0,
      [3,n('C2'),'kick',92],  [7,n('A4'),'frag',46], [4,n('C3'),'snare',80], [5,n('Bb4'),'hat',32],
      [0,n('F2'),'bass',80],  0,                      [1,n('E4'),'lead',68],  [5,n('Bb4'),'hat',32],
      [3,n('C2'),'kick',88],  [5,n('Bb4'),'hat',34], [4,n('C3'),'snare',76], [2,n('F3'),'brass',42]
    ]]
  ],
  seq: [0, 1, 0, 1, 2, 2, 3, 0]
};

  // ── Patch into SNESAudio engine ───────────────────────────────────

  var _origLoad = SNESAudio.prototype.loadSong;
  SNESAudio.prototype.loadSong = function(name) {
    // Try original songs first
    if (_origLoad.call(this, name)) return true;
    // Then try leitmotifs
    if (L[name]) {
      this._song = L[name];
      this._sn = name;
      return true;
    }
    return false;
  };

  // Patch listSongs to include leitmotifs
  var _origList = SNESAudio.prototype.listSongs;
  SNESAudio.prototype.listSongs = function() {
    var base = _origList.call(this);
    return base.concat(Object.keys(L));
  };

})();
