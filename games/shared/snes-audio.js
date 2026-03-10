/**
 * snes-audio.js -- SPC700-style music engine for the Substrate arcade.
 *
 * 8-channel sample player with ADSR, echo, and pattern sequencer.
 * All instruments procedurally generated. Zero dependencies.
 *
 * Usage:
 *   <script src="../shared/snes-audio.js"></script>
 *   var music = new SNESAudio();
 *   music.loadSong('adventure');
 *   music.play();
 */
var SNESAudio = (function() {
'use strict';

var NF = []; // MIDI note -> frequency
for (var i = 0; i < 128; i++) NF[i] = 440 * Math.pow(2, (i - 69) / 12);
var NM = {C:0,D:2,E:4,F:5,G:7,A:9,B:11};
function n(s) {
  var m = s.match(/^([A-G])(#|b)?(\d)$/);
  if (!m) return 0;
  var b = NM[m[1]]; if (m[2]==='#') b++; else if (m[2]==='b') b--;
  return b + (parseInt(m[3]) + 1) * 12;
}
var R = -1, SR = 32000, SL = 512;

// ── Sample generation ────────────────────────────────────────────────
function genSamples() {
  var s = {};
  function mk(fn, len) {
    len = len || SL; var b = new Float32Array(len);
    for (var i = 0; i < len; i++) b[i] = fn(i / len);
    return b;
  }
  s.sq50 = mk(function(t) { return t < 0.5 ? 1 : -1; });
  s.sq25 = mk(function(t) { return t < 0.25 ? 1 : -1; });
  s.sq12 = mk(function(t) { return t < 0.125 ? 1 : -1; });
  s.saw = mk(function(t) { return 2 * t - 1; });
  s.tri = mk(function(t) {
    var st = Math.floor(t * 16) / 16;
    return st < 0.5 ? 4 * st - 1 : 3 - 4 * st;
  });
  s.sin = mk(function(t) { return Math.sin(2 * Math.PI * t); });
  s.noi = (function() { var b = new Float32Array(4096);
    for (var i = 0; i < 4096; i++) b[i] = Math.random() * 2 - 1; return b; })();
  s.pnoi = (function() { var b = new Float32Array(128);
    for (var i = 0; i < 128; i++) b[i] = Math.random() * 2 - 1; return b; })();
  s.str = mk(function(t) {
    var v = 0; for (var h = 1; h <= 8; h++) v += Math.sin(2*Math.PI*h*t)/(h*h); return v*0.7;
  });
  s.bas = mk(function(t) {
    var st = Math.floor(t*16)/16;
    return Math.tanh((st<0.5?4*st-1:3-4*st)*1.5);
  });
  s.snr = mk(function(t) { return (Math.random()*2-1)*0.6 + Math.sin(2*Math.PI*t*3)*(1-t)*0.4; }, 1024);
  s.kck = mk(function(t) { return Math.sin(2*Math.PI*(1+(1-t)*8)*t)*(1-t*0.5); }, 1024);
  s.hh = (function() { var b = new Float32Array(512), p = 0;
    for (var i = 0; i < 512; i++) { var r = Math.random()*2-1; b[i] = r-p; p = r; } return b; })();
  s.pno = mk(function(t) {
    return Math.sin(2*Math.PI*t)*0.5 + Math.sin(2*Math.PI*t*2.002)*0.3 +
           Math.sin(2*Math.PI*t*3.004)*0.15 + Math.sin(2*Math.PI*t*4.01)*0.05;
  });
  // FM synthesis — modulated sine for Genesis-style punch
  s.fm = mk(function(t) {
    var mod = Math.sin(2 * Math.PI * t * 3) * 2.5;
    return Math.sin(2 * Math.PI * t + mod) * 0.85;
  });
  // Organ — summed odd harmonics for classic B3 sound
  s.org = mk(function(t) {
    var v = 0;
    v += Math.sin(2*Math.PI*t) * 0.4;        // fundamental
    v += Math.sin(2*Math.PI*t*3) * 0.3;       // 3rd harmonic
    v += Math.sin(2*Math.PI*t*5) * 0.15;      // 5th harmonic
    v += Math.sin(2*Math.PI*t*7) * 0.08;      // 7th harmonic
    v += Math.sin(2*Math.PI*t*9) * 0.04;      // 9th harmonic
    v += Math.sin(2*Math.PI*t*2) * 0.25;      // sub-octave percussion
    return v * 0.7;
  });
  return s;
}

// ── Compact song definitions ─────────────────────────────────────────
// Instruments: [sampleKey, attack, decay, sustain, release, loop]
// Pattern step: [ch, midiNote, instKey, volume] or null for empty step
// Using helper I() for instrument defs, P() for patterns

function I(smp,a,d,s,r,lp) { return {s:smp,a:a,d:d,su:s,r:r,lp:lp!==false}; }

function songs() {
  var S = {};

  // ════════════════════════════════════════════════════════════════════
  // AIRLOCK — Tense ambient, 75 BPM
  // Progression: i-bVI-bVII-i (Em: Em-C-D-Em)
  // AABA' structure: A=brooding stepwise bass+whole-tone melody,
  // B=contrast with chromatic shift, A'=variation with added texture
  // Bar 16 ends on B(V) for seamless loop back to Em
  // ════════════════════════════════════════════════════════════════════
  S.airlock = { bpm:75, echo:[350,0.45,0.4,3000],
    inst: { p:I('str',0.8,0.3,0.6,1.2), b:I('bas',0.01,0.2,0.4,0.5), h:I('hh',0.005,0.1,0,0.05,false),
            t:I('sin',0.4,0.5,0.3,0.8), n:I('noi',0.5,1.0,0.2,1.5), f:I('fm',0.3,0.4,0.3,0.6) },
    pats: [
      // A section (bars 1-4): i-bVI hook — sparse, stepwise bass E-F#-G, whole-tone melody
      [32, [[0,n('E2'),'b',45],0,[1,n('B3'),'p',22],0, 0,0,[2,n('F#4'),'t',15],0,
            [0,n('F#2'),'b',40],0,0,0, 0,[1,n('G#4'),'t',12],0,0,
            [0,n('C3'),'b',42],0,[1,n('E4'),'p',20],0, 0,0,[5,n('D#4'),'f',12],0,
            [0,n('D3'),'b',40],0,0,[3,R,'h',8], 0,0,[2,n('F#4'),'t',14],0]],
      // A repeat (bars 5-8): same shape, minor variation — add noise texture
      [32, [[0,n('E2'),'b',45],0,[1,n('B3'),'p',22],0, [4,n('C2'),'n',6],0,[2,n('G#4'),'t',15],0,
            [0,n('F#2'),'b',40],0,0,[3,R,'h',8], 0,[1,n('F#4'),'t',12],0,0,
            [0,n('C3'),'b',42],0,[1,n('E4'),'p',20],0, [4,n('C2'),'n',5],0,[5,n('D#4'),'f',12],0,
            [0,n('D3'),'b',40],0,0,0, 0,[3,R,'h',10],[2,n('A#4'),'t',10],0]],
      // B section (bars 9-12): contrast — chromatic shift to bVII(D), denser texture
      [32, [[0,n('D2'),'b',48],0,[1,n('A4'),'p',25],0, 0,[2,n('C5'),'t',15],0,[3,R,'h',10],
            [0,n('C2'),'b',42],0,[5,n('E4'),'f',18],0, 0,0,[1,n('G4'),'p',20],0,
            [0,n('D2'),'b',45],0,[2,n('F#4'),'t',16],0, [4,n('C2'),'n',7],0,0,[3,R,'h',10],
            [0,n('E2'),'b',44],0,[1,n('B4'),'p',22],0, 0,0,[5,n('D#5'),'f',12],0]],
      // A' bridge (bars 13-16): thin out, end on B(V) for loop resolution
      [32, [[0,n('E2'),'b',42],0,[1,n('B3'),'p',20],0, 0,0,[2,n('F#4'),'t',12],0,
            [0,n('C3'),'b',38],0,0,0, 0,[1,n('E4'),'p',18],0,0,
            [0,n('D3'),'b',40],0,[5,n('A4'),'f',12],0, 0,0,0,[3,R,'h',8],
            [0,n('B1'),'b',44],0,0,0, 0,0,[2,n('F#4'),'t',10],0]]
    ], seq:[0,1,2,3,0,1,2,3] };

  // ════════════════════════════════════════════════════════════════════
  // BOOTLOADER — Digital startup, 140 BPM
  // Progression: Mixolydian I-bVII-I (E-D-E), heroic ascending arpeggios
  // AABA': A=driving beat+ascending melody, B=key center shift, end on B(V)
  // ════════════════════════════════════════════════════════════════════
  S.bootloader = { bpm:140, echo:[150,0.3,0.25,5000],
    inst: { l:I('sq50',0.01,0.1,0.7,0.15), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.15,0,0.05,false), h:I('hh',0.005,0.06,0,0.02,false), a:I('sq25',0.01,0.08,0.5,0.1),
            f:I('fm',0.01,0.08,0.6,0.1) },
    pats: [
      // A (bars 1-4): E Mixolydian hook — syncopated sq50 melody E-G#-A-B, ascending
      [16, [[2,R,'k',70],[4,R,'h',28],[0,n('E2'),'b',55],0,
            [1,n('E4'),'l',42],[4,R,'h',22],0,[1,n('G#4'),'l',38],
            [3,R,'s',50],[4,R,'h',28],[0,n('D2'),'b',50],0,
            [1,n('A4'),'l',40],[4,R,'h',22],[1,n('B4'),'l',44],0]],
      // A' (bars 5-8): hook variation — melody continues up, add FM texture
      [16, [[2,R,'k',70],[4,R,'h',28],[0,n('E2'),'b',55],[6,n('E4'),'f',25],
            [1,n('B4'),'l',42],[4,R,'h',22],0,[1,n('D5'),'l',40],
            [3,R,'s',50],[4,R,'h',28],[0,n('D2'),'b',50],0,
            [1,n('E5'),'l',45],[4,R,'h',22],[6,n('G#4'),'f',22],[1,n('D5'),'l',38]]],
      // B (bars 9-12): contrast — shift to A, arpeggiated texture, denser
      [16, [[2,R,'k',70],[5,n('A3'),'a',28],[0,n('A2'),'b',52],[5,n('C#4'),'a',28],
            [4,R,'h',20],[5,n('E4'),'a',28],0,[5,n('A4'),'a',25],
            [3,R,'s',50],[5,n('E4'),'a',28],[0,n('G2'),'b',48],[5,n('B3'),'a',28],
            [2,R,'k',65],[5,n('D4'),'a',28],[4,R,'h',20],[5,n('G4'),'a',25]]],
      // A/bridge (bars 13-16): thin, end on B(V) chord
      [16, [[2,R,'k',65],[4,R,'h',25],[0,n('E2'),'b',50],0,
            [1,n('E4'),'l',38],[4,R,'h',20],0,0,
            [3,R,'s',45],[4,R,'h',25],[0,n('B1'),'b',48],0,
            0,[4,R,'h',20],[1,n('F#4'),'l',35],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // BRIGADE — Military march, 130 BPM
  // Progression: bVI-bVII-I cadences (Ab-Bb-C), open 4ths and 5ths
  // Dotted rhythms, strong march feel, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.brigade = { bpm:130, echo:[180,0.25,0.2,4500],
    inst: { l:I('sq50',0.01,0.1,0.7,0.12), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false), r:I('saw',0.05,0.15,0.6,0.2),
            o:I('org',0.02,0.12,0.6,0.15) },
    pats: [
      // A (bars 1-4): C major hook with 4ths/5ths, dotted march rhythm
      [16, [[2,R,'k',72],[4,R,'h',28],[0,n('C3'),'b',52],0,
            [3,R,'s',55],[1,n('C5'),'r',42],0,[1,n('F5'),'r',38],
            [2,R,'k',68],[4,R,'h',25],[0,n('G2'),'b',48],[1,n('G5'),'r',44],
            [3,R,'s',52],[4,R,'h',22],[3,R,'s',32],0]],
      // A' (bars 5-8): hook with organ doubling and variation
      [16, [[2,R,'k',72],[4,R,'h',28],[0,n('C3'),'b',52],[6,n('C4'),'o',22],
            [3,R,'s',55],[1,n('C5'),'r',42],0,[1,n('E5'),'r',40],
            [2,R,'k',68],[4,R,'h',25],[0,n('G2'),'b',48],[1,n('G5'),'r',42],
            [3,R,'s',52],[1,n('A5'),'r',40],[6,n('G4'),'o',20],[1,n('G5'),'r',38]]],
      // B (bars 9-12): bVI-bVII-I cadence (Ab-Bb-C), contrast
      [16, [[2,R,'k',72],[1,n('Ab4'),'r',40],[0,n('Ab2'),'b',50],[4,R,'h',25],
            [3,R,'s',52],[1,n('C5'),'r',42],0,0,
            [2,R,'k',68],[1,n('Bb4'),'r',42],[0,n('Bb2'),'b',50],[4,R,'h',25],
            [3,R,'s',55],[1,n('D5'),'r',38],[1,n('C5'),'r',44],0]],
      // A/bridge (bars 13-16): thin out, end on G(V)
      [16, [[2,R,'k',65],[4,R,'h',22],[0,n('C3'),'b',48],0,
            [3,R,'s',48],[1,n('C5'),'r',38],0,0,
            [2,R,'k',60],[4,R,'h',22],[0,n('G2'),'b',48],0,
            0,[4,R,'h',18],[1,n('D5'),'r',32],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // CARD — Smooth chill, 110 BPM
  // Progression: IVmaj7-iii7-ii7-Imaj7 (Fmaj7-Em7-Dm7-Cmaj7 in C)
  // Piano-led arpeggios, jazz extensions, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.card = { bpm:110, echo:[250,0.35,0.35,4000],
    inst: { p:I('pno',0.01,0.3,0.3,0.4,false), b:I('bas',0.01,0.2,0.45,0.15), h:I('hh',0.005,0.05,0,0.02,false),
            s:I('snr',0.005,0.15,0,0.05,false), d:I('str',0.5,0.3,0.5,0.6), l:I('sin',0.05,0.2,0.5,0.3) },
    pats: [
      // A (bars 1-4): Fmaj7-Em7 — piano arpeggios, syncopated melody
      [16, [[0,n('F2'),'b',48],[1,n('A4'),'p',38],0,[2,R,'h',22],
            [5,n('E5'),'l',32],[2,R,'h',18],[1,n('C5'),'p',35],0,
            [0,n('E2'),'b',45],[3,R,'s',38],[1,n('B4'),'p',35],[2,R,'h',22],
            0,[1,n('G4'),'p',32],[2,R,'h',18],[5,n('D5'),'l',28]]],
      // A' (bars 5-8): Dm7-Cmaj7 — variation with string pad
      [16, [[0,n('D2'),'b',48],[1,n('F4'),'p',38],[4,n('D3'),'d',18],0,
            [5,n('A4'),'l',32],[2,R,'h',22],[1,n('D5'),'p',35],0,
            [0,n('C2'),'b',45],[3,R,'s',38],[1,n('E4'),'p',36],[2,R,'h',22],
            [4,n('C3'),'d',16],[1,n('G4'),'p',32],[2,R,'h',18],0]],
      // B (bars 9-12): contrast — Am7-Bbmaj7 (borrowed bVII), jazzier
      [16, [[0,n('A2'),'b',48],[1,n('C5'),'p',38],0,[2,R,'h',22],
            [5,n('E5'),'l',30],[1,n('A4'),'p',32],[2,R,'h',18],0,
            [0,n('Bb2'),'b',45],[3,R,'s',38],[1,n('D5'),'p',36],[2,R,'h',22],
            [4,n('Bb3'),'d',18],[1,n('F5'),'p',34],[2,R,'h',18],[5,n('A4'),'l',28]]],
      // A/bridge (bars 13-16): thin, end on G7(V)
      [16, [[0,n('F2'),'b',42],[1,n('A4'),'p',32],0,0,
            0,[2,R,'h',18],[1,n('C5'),'p',28],0,
            [0,n('G2'),'b',44],[3,R,'s',32],0,0,
            0,[1,n('B4'),'p',28],[2,R,'h',15],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // CASCADE — Escalating puzzle, 135 BPM
  // Progression: Tetris-style i-bVI-bVII-i (Am-F-G-Am), Russian minor
  // Syncopated melody on pentatonic scaffold, call-and-response, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.cascade = { bpm:135, echo:[120,0.2,0.2,5000],
    inst: { l:I('sq50',0.01,0.08,0.65,0.1), b:I('tri',0.01,0.12,0.5,0.1), k:I('kck',0.005,0.18,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), a:I('sq25',0.01,0.06,0.5,0.08) },
    pats: [
      // A (bars 1-4): Am hook — call phrase, syncopated A minor pentatonic
      [16, [[2,R,'k',70],[1,n('A4'),'l',44],[0,n('A2'),'b',50],[4,R,'h',24],
            0,[1,n('C5'),'l',40],[4,R,'h',18],[1,n('E5'),'l',42],
            [3,R,'s',50],[4,R,'h',24],[0,n('F2'),'b',46],[1,n('D5'),'l',40],
            [2,R,'k',62],[1,n('C5'),'l',42],[4,R,'h',18],0]],
      // A' (bars 5-8): response phrase — melody descends, add chromatic G#
      [16, [[2,R,'k',70],[1,n('E5'),'l',44],[0,n('G2'),'b',48],[4,R,'h',24],
            0,[1,n('D5'),'l',40],[4,R,'h',18],[1,n('C5'),'l',42],
            [3,R,'s',50],[4,R,'h',24],[0,n('A2'),'b',50],[1,n('B4'),'l',38],
            [2,R,'k',62],[1,n('A4'),'l',44],[4,R,'h',18],[1,n('G#4'),'l',35]]],
      // B (bars 9-12): bVI-bVII (F-G), arpeggiated contrast, denser
      [16, [[2,R,'k',70],[5,n('F3'),'a',30],[0,n('F2'),'b',48],[5,n('A3'),'a',28],
            [4,R,'h',18],[5,n('C4'),'a',28],0,[5,n('F4'),'a',25],
            [3,R,'s',50],[5,n('G3'),'a',28],[0,n('G2'),'b',48],[5,n('B3'),'a',28],
            [2,R,'k',62],[5,n('D4'),'a',28],[4,R,'h',18],[5,n('G4'),'a',25]]],
      // A/bridge (bars 13-16): thin, end on E(V of Am)
      [16, [[2,R,'k',65],[4,R,'h',22],[0,n('A2'),'b',46],0,
            [1,n('A4'),'l',38],[4,R,'h',18],0,0,
            [3,R,'s',45],[4,R,'h',22],[0,n('E2'),'b',48],0,
            0,[4,R,'h',18],[1,n('G#4'),'l',32],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // CHEMISTRY — Experimental, 115 BPM
  // Whole-tone and chromatic surprises, bubbly arpeggios
  // Progression: Cmaj7-D7-Emaj7-F#7 (whole-tone root motion!)
  // AABA' with bubbly sine arpeggios
  // ════════════════════════════════════════════════════════════════════
  S.chemistry = { bpm:115, echo:[280,0.35,0.35,3500],
    inst: { u:I('sin',0.02,0.15,0.3,0.2), b:I('tri',0.01,0.2,0.4,0.15), c:I('pnoi',0.005,0.04,0,0.02,false),
            p:I('str',0.6,0.4,0.5,0.5), l:I('sq25',0.01,0.06,0.4,0.1), h:I('hh',0.005,0.04,0,0.02,false) },
    pats: [
      // A (bars 1-4): C whole-tone hook — bubbly ascending sines
      [16, [[0,n('C3'),'b',44],[1,n('E5'),'u',30],0,[5,R,'h',18],
            [2,R,'c',28],[1,n('G5'),'u',28],0,[1,n('B5'),'u',25],
            [0,n('D3'),'b',40],[1,n('F#5'),'u',28],[5,R,'h',18],0,
            [2,R,'c',25],[4,n('A5'),'l',22],0,[1,n('D5'),'u',28]]],
      // A' (bars 5-8): variation — descending response, add pad
      [16, [[0,n('E3'),'b',44],[3,n('E3'),'p',18],[1,n('B5'),'u',30],0,
            [5,R,'h',18],[1,n('G#5'),'u',28],[2,R,'c',22],0,
            [0,n('F#3'),'b',40],[1,n('E5'),'u',28],0,[5,R,'h',18],
            [2,R,'c',25],[1,n('C#5'),'u',25],[4,n('D#5'),'l',20],0]],
      // B (bars 9-12): chromatic surprise — Eb tritone, denser textures
      [16, [[0,n('Eb3'),'b',46],[1,n('G5'),'u',32],[3,n('Eb3'),'p',20],[5,R,'h',18],
            [2,R,'c',28],[1,n('Bb5'),'u',28],0,[4,n('D5'),'l',25],
            [0,n('A2'),'b',42],[1,n('C#5'),'u',30],[5,R,'h',18],0,
            [2,R,'c',25],[1,n('E5'),'u',28],[4,n('G5'),'l',22],[5,R,'h',15]]],
      // A/bridge (bars 13-16): thin, end on G(V of C)
      [16, [[0,n('C3'),'b',40],[1,n('E5'),'u',25],0,0,
            [5,R,'h',15],[1,n('G5'),'u',22],0,0,
            [0,n('G2'),'b',42],0,[2,R,'c',18],0,
            0,[1,n('B4'),'u',22],0,0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // CYPHER — Spy thriller, 100 BPM
  // Progression: chromatic bass i-iv-bVI-bVII (Em-Am-C-D)
  // Semitone tension, syncopated lead, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.cypher = { bpm:100, echo:[300,0.4,0.35,3000],
    inst: { b:I('bas',0.01,0.2,0.4,0.15), l:I('sq25',0.02,0.15,0.5,0.2), p:I('str',0.5,0.4,0.4,0.8),
            k:I('kck',0.005,0.2,0,0.05,false), s:I('snr',0.005,0.15,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false),
            f:I('fm',0.02,0.1,0.45,0.2) },
    pats: [
      // A (bars 1-4): Em groove — chromatic bass E-F-F#-G, spy melody
      [16, [[3,R,'k',52],[5,R,'h',20],[0,n('E2'),'b',46],0,
            [1,n('E4'),'l',35],[5,R,'h',15],[1,n('F4'),'l',30],0,
            [4,R,'s',38],[5,R,'h',20],[0,n('F2'),'b',42],0,
            0,[1,n('G4'),'l',35],[5,R,'h',15],[1,n('F#4'),'l',28]]],
      // A' (bars 5-8): Am response — melody climbs with semitone spice
      [16, [[3,R,'k',52],[5,R,'h',20],[0,n('A2'),'b',46],[6,n('A3'),'f',18],
            [1,n('A4'),'l',35],[5,R,'h',15],[1,n('Bb4'),'l',30],0,
            [4,R,'s',38],[5,R,'h',20],[0,n('G2'),'b',44],0,
            [1,n('B4'),'l',38],[5,R,'h',15],[6,n('E4'),'f',15],[1,n('A4'),'l',30]]],
      // B (bars 9-12): bVI-bVII (C-D) — denser, pad enters
      [16, [[3,R,'k',52],[2,n('C3'),'p',22],[0,n('C3'),'b',46],[5,R,'h',18],
            [1,n('E5'),'l',35],0,[1,n('C5'),'l',32],0,
            [4,R,'s',38],[2,n('D3'),'p',22],[0,n('D3'),'b',44],[5,R,'h',18],
            [1,n('D5'),'l',35],[5,R,'h',15],[1,n('F#5'),'l',30],[6,n('D4'),'f',15]]],
      // A/bridge (bars 13-16): thin, end on B(V of Em)
      [16, [[3,R,'k',48],[5,R,'h',18],[0,n('E2'),'b',42],0,
            [1,n('E4'),'l',30],0,0,0,
            [4,R,'s',32],[5,R,'h',18],[0,n('B1'),'b',44],0,
            0,[1,n('D#4'),'l',28],[5,R,'h',12],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // MYCELIUM — Organic nature, 90 BPM, DKC-style ambient
  // Progression: Cm9-Abmaj7#11 extended chords, echo-heavy
  // Wide intervals, gentle stepwise motion, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.mycelium = { bpm:90, echo:[400,0.45,0.45,2500],
    inst: { p:I('str',0.8,0.5,0.5,1.0), f:I('sin',0.1,0.2,0.6,0.4), b:I('tri',0.05,0.3,0.35,0.2),
            c:I('pno',0.01,0.4,0.15,0.5,false), h:I('pnoi',0.005,0.08,0,0.03,false), d:I('sin',0.01,0.3,0,0.1,false),
            o:I('org',0.3,0.4,0.4,0.6) },
    pats: [
      // A (bars 1-4): Cm9 — wide intervals, gentle stepwise melody C-D-Eb-F
      [32, [[0,n('C3'),'b',34],0,[1,n('Eb4'),'f',28],0, 0,0,[3,n('G5'),'c',18],0,
            [0,n('G2'),'b',30],0,0,0, 0,[1,n('D4'),'f',25],0,[4,R,'h',8],
            [2,n('C3'),'p',18],0,[1,n('C5'),'f',28],0, 0,0,[5,n('Bb5'),'d',12],0,
            [0,n('Ab2'),'b',32],0,[1,n('Eb5'),'f',25],0, 0,0,0,[4,R,'h',10]]],
      // A' (bars 5-8): variation with organ texture, melody extends to F
      [32, [[0,n('C3'),'b',34],[6,n('C3'),'o',14],0,[1,n('Eb4'),'f',28], 0,0,[3,n('Bb5'),'c',16],0,
            [0,n('G2'),'b',30],0,[1,n('F4'),'f',26],0, 0,0,0,[4,R,'h',8],
            [2,n('Ab3'),'p',18],0,[1,n('D5'),'f',28],0, 0,[5,n('G5'),'d',12],0,0,
            [0,n('Bb2'),'b',32],0,[1,n('C5'),'f',25],0, [6,n('G3'),'o',12],0,0,[4,R,'h',10]]],
      // B (bars 9-12): Abmaj7#11 — shift key center, denser
      [32, [[0,n('Ab2'),'b',36],0,[1,n('C5'),'f',30],0, [3,n('Eb5'),'c',18],0,0,[4,R,'h',10],
            [0,n('Eb2'),'b',32],0,[1,n('G4'),'f',28],0, 0,0,[5,n('D6'),'d',10],0,
            [0,n('Bb2'),'b',34],[2,n('Bb3'),'p',18],[1,n('D5'),'f',28],0, 0,0,[3,n('F5'),'c',16],0,
            [0,n('F2'),'b',32],0,[1,n('Ab4'),'f',26],0, 0,0,0,[4,R,'h',8]]],
      // A/bridge (bars 13-16): thin, end on G(V of Cm)
      [32, [[0,n('C3'),'b',30],0,[1,n('Eb4'),'f',22],0, 0,0,0,0,
            [0,n('Ab2'),'b',28],0,0,0, 0,[1,n('C5'),'f',20],0,0,
            0,0,0,0, 0,0,0,0,
            [0,n('G2'),'b',32],0,[1,n('D4'),'f',18],0, 0,0,0,0]]
    ], seq:[0,1,2,3,0,1,2,3] };

  // ════════════════════════════════════════════════════════════════════
  // MYCO — Earthy ambient, 85 BPM, pastoral
  // Progression: I-V-vi-IV (C-G-Am-F), gentle stepwise melody
  // Harvest Moon warmth, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.myco = { bpm:85, echo:[380,0.4,0.4,2800],
    inst: { p:I('str',1.0,0.4,0.5,1.2), b:I('tri',0.05,0.3,0.3,0.2), e:I('pno',0.01,0.5,0.1,0.6,false),
            f:I('sin',0.15,0.25,0.5,0.5), c:I('pnoi',0.005,0.05,0,0.02,false) },
    pats: [
      // A (bars 1-4): C-G — gentle stepwise C-D-E-D-C melody
      [32, [[0,n('C3'),'b',30],0,[1,n('C5'),'f',24],0, 0,0,0,[2,n('E5'),'e',16],
            [0,n('G2'),'b',28],0,[1,n('D5'),'f',24],0, 0,0,[4,R,'c',8],0,
            [3,n('C3'),'p',16],0,[1,n('E5'),'f',24],0, 0,0,0,[2,n('G5'),'e',14],
            [0,n('G2'),'b',28],0,[1,n('D5'),'f',22],0, 0,0,0,0]],
      // A' (bars 5-8): Am-F — melody descends E-D-C-B, variation
      [32, [[0,n('A2'),'b',30],0,[1,n('E5'),'f',24],0, 0,0,0,[2,n('C5'),'e',16],
            [0,n('F2'),'b',28],0,[1,n('D5'),'f',24],0, 0,[4,R,'c',8],0,0,
            [3,n('A3'),'p',16],0,[1,n('C5'),'f',24],0, 0,0,[2,n('A4'),'e',14],0,
            [0,n('F2'),'b',28],0,[1,n('B4'),'f',22],0, 0,0,0,0]],
      // B (bars 9-12): vi-IV borrowed bVII (Am-Bb-F) — contrast
      [32, [[0,n('A2'),'b',32],0,[1,n('A4'),'f',26],0, [2,n('C5'),'e',18],0,0,[4,R,'c',8],
            [0,n('Bb2'),'b',30],0,[1,n('D5'),'f',26],0, 0,0,[2,n('F5'),'e',16],0,
            [0,n('F2'),'b',30],[3,n('F3'),'p',16],[1,n('C5'),'f',24],0, 0,0,0,[4,R,'c',8],
            [0,n('G2'),'b',30],0,[1,n('B4'),'f',22],0, 0,0,0,0]],
      // A/bridge (bars 13-16): thin, end on G(V)
      [32, [[0,n('C3'),'b',26],0,[1,n('C5'),'f',20],0, 0,0,0,0,
            [0,n('F2'),'b',24],0,0,0, 0,[1,n('A4'),'f',18],0,0,
            0,0,0,0, 0,0,0,0,
            [0,n('G2'),'b',28],0,[1,n('B4'),'f',18],0, 0,0,0,0]]
    ], seq:[0,1,2,3,0,1,2,3] };

  // ════════════════════════════════════════════════════════════════════
  // NOVEL — Cinematic/emotional, 72 BPM, FF6 opera style
  // Wide intervals, piano with strings, I-vi-IV-V in C
  // AABA' — singable melody within one octave
  // ════════════════════════════════════════════════════════════════════
  S.novel = { bpm:72, echo:[400,0.4,0.4,3000],
    inst: { s:I('str',0.6,0.4,0.6,1.0), p:I('pno',0.01,0.5,0.2,0.8,false), b:I('bas',0.05,0.3,0.35,0.3),
            f:I('sin',0.15,0.3,0.5,0.5), e:I('pno',0.01,0.8,0.05,1.0,false), o:I('org',0.4,0.3,0.5,0.6) },
    pats: [
      // A (bars 1-4): C-Am — sweeping piano melody C-E-G-A, wide strings
      [32, [[0,n('C3'),'b',34],0,[1,n('E5'),'p',36],0, [2,n('C4'),'s',24],0,[1,n('G5'),'p',32],0,
            0,0,[1,n('A5'),'p',34],0, [0,n('A2'),'b',30],0,[1,n('G5'),'p',30],0,
            [2,n('A3'),'s',22],0,[3,n('E5'),'f',24],0, 0,0,[1,n('F5'),'p',30],0,
            [0,n('A2'),'b',30],0,[1,n('E5'),'p',32],0, 0,0,0,0]],
      // A' (bars 5-8): F-G — melody varies, add organ texture
      [32, [[0,n('F3'),'b',34],[5,n('F3'),'o',14],0,[1,n('C6'),'p',32], [2,n('F4'),'s',26],0,[1,n('A5'),'p',30],0,
            0,0,[3,n('F5'),'f',24],0, [0,n('G2'),'b',32],0,[1,n('G5'),'p',32],0,
            [2,n('G3'),'s',22],0,[1,n('A5'),'p',30],0, 0,0,[3,n('B5'),'f',22],0,
            [0,n('G2'),'b',30],0,[1,n('G5'),'p',28],0, [5,n('D3'),'o',12],0,0,0]],
      // B (bars 9-12): bVI-bVII-I (Ab-Bb-C) — triumphant cadence
      [32, [[0,n('Ab2'),'b',36],0,[1,n('C5'),'p',34],0, [2,n('Ab3'),'s',28],0,[3,n('Eb5'),'f',28],0,
            0,0,[1,n('Ab5'),'p',30],0, [0,n('Bb2'),'b',34],0,[1,n('D5'),'p',34],0,
            [2,n('Bb3'),'s',26],0,[3,n('F5'),'f',28],0, [4,n('Bb5'),'e',15],0,0,0,
            [0,n('C3'),'b',36],0,[1,n('E5'),'p',36],0, [2,n('C4'),'s',28],0,[1,n('G5'),'p',32],0]],
      // A/bridge (bars 13-16): thin, end on G(V)
      [32, [[0,n('C3'),'b',30],0,[1,n('E5'),'p',28],0, 0,0,0,0,
            [0,n('F3'),'b',28],0,[3,n('A4'),'f',20],0, 0,0,0,0,
            0,0,0,0, 0,0,0,0,
            [0,n('G2'),'b',32],0,[1,n('D5'),'p',25],0, 0,0,[4,n('B5'),'e',12],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // OBJECTION — Courtroom intensity, 155 BPM
  // Phoenix Wright energy, ascending chromatic runs, i-bVII-bVI-V
  // AABA' with intense syncopation
  // ════════════════════════════════════════════════════════════════════
  S.objection = { bpm:155, echo:[130,0.2,0.2,5500],
    inst: { l:I('sq50',0.01,0.08,0.7,0.1), b:I('bas',0.01,0.12,0.5,0.08), k:I('kck',0.005,0.18,0,0.05,false),
            s:I('snr',0.005,0.1,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), r:I('saw',0.02,0.1,0.6,0.15),
            f:I('fm',0.01,0.06,0.65,0.1) },
    pats: [
      // A (bars 1-4): Cm hook — ascending chromatic C-D-Eb-E-F-G
      [16, [[2,R,'k',75],[4,R,'h',28],[1,n('C5'),'l',46],[0,n('C3'),'b',52],
            0,[1,n('D5'),'l',42],[4,R,'h',22],[1,n('Eb5'),'l',44],
            [3,R,'s',55],[4,R,'h',28],[0,n('Bb2'),'b',48],[1,n('F5'),'l',44],
            [2,R,'k',68],[1,n('G5'),'l',48],[4,R,'h',22],0]],
      // A' (bars 5-8): response — descend from peak, FM punch
      [16, [[2,R,'k',75],[4,R,'h',28],[1,n('G5'),'l',48],[0,n('Ab2'),'b',50],
            [6,n('C4'),'f',28],[1,n('F5'),'l',42],[4,R,'h',22],0,
            [3,R,'s',55],[4,R,'h',28],[0,n('Bb2'),'b',48],[1,n('Eb5'),'l',44],
            [2,R,'k',68],[1,n('D5'),'l',42],[4,R,'h',22],[1,n('C5'),'l',40]]],
      // B (bars 9-12): bVI-bVII (Ab-Bb) — saw lead countermelody, intense
      [16, [[2,R,'k',75],[5,n('Ab4'),'r',42],[0,n('Ab2'),'b',52],[4,R,'h',25],
            [1,n('C5'),'l',40],[5,n('C5'),'r',40],[4,R,'h',20],0,
            [3,R,'s',55],[5,n('Bb4'),'r',44],[0,n('Bb2'),'b',50],[4,R,'h',25],
            [2,R,'k',70],[5,n('D5'),'r',42],[1,n('F5'),'l',44],[5,n('Bb4'),'r',38]]],
      // A/bridge (bars 13-16): thin, end on G(V of Cm)
      [16, [[2,R,'k',68],[4,R,'h',22],[0,n('C3'),'b',48],0,
            [1,n('C5'),'l',40],[4,R,'h',18],0,0,
            [3,R,'s',48],[4,R,'h',22],[0,n('G2'),'b',50],0,
            0,[4,R,'h',18],[1,n('B4'),'l',36],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // TACTICS — Strategic/medieval, 95 BPM
  // Mixolydian I-bVII for heroic quests, 4ths/5ths, military snare
  // AABA' — D Mixolydian (D-C natural)
  // ════════════════════════════════════════════════════════════════════
  S.tactics = { bpm:95, echo:[320,0.35,0.3,3500],
    inst: { s:I('str',0.3,0.3,0.6,0.5), b:I('bas',0.02,0.2,0.4,0.15), f:I('sin',0.08,0.2,0.5,0.3),
            k:I('kck',0.005,0.2,0,0.05,false), n:I('snr',0.005,0.15,0,0.05,false), e:I('pno',0.01,0.6,0.1,0.5,false),
            o:I('org',0.1,0.2,0.5,0.3) },
    pats: [
      // A (bars 1-4): D Mixolydian hook — 4ths and 5ths, D-G-A-D melody
      [16, [[3,R,'k',62],[0,n('D3'),'b',46],[1,n('D4'),'s',32],0,
            [2,n('A4'),'f',30],0,[2,n('D5'),'f',32],0,
            [4,R,'n',48],[0,n('C3'),'b',42],[1,n('G4'),'s',30],0,
            [3,R,'k',55],0,[2,n('A4'),'f',28],0]],
      // A' (bars 5-8): variation — melody extends, add organ
      [16, [[3,R,'k',62],[0,n('D3'),'b',46],[1,n('D4'),'s',32],[6,n('D3'),'o',16],
            [2,n('D5'),'f',32],0,[2,n('E5'),'f',30],0,
            [4,R,'n',48],[0,n('C3'),'b',42],[1,n('G4'),'s',30],0,
            [3,R,'k',55],[2,n('C5'),'f',28],[6,n('C3'),'o',14],[5,n('D5'),'e',15]]],
      // B (bars 9-12): bVII-IV-I (C-G-D) — contrast, denser
      [16, [[3,R,'k',62],[0,n('C3'),'b',46],[1,n('C4'),'s',32],0,
            [2,n('E5'),'f',32],[6,n('C3'),'o',18],0,0,
            [4,R,'n',48],[0,n('G2'),'b',44],[1,n('G3'),'s',30],[2,n('B4'),'f',28],
            [3,R,'k',55],[0,n('D3'),'b',46],0,[5,n('D5'),'e',16]]],
      // A/bridge (bars 13-16): thin, end on A(V of D)
      [16, [[3,R,'k',55],[0,n('D3'),'b',42],[1,n('D4'),'s',28],0,
            0,0,[2,n('A4'),'f',24],0,
            [4,R,'n',40],[0,n('A2'),'b',44],0,0,
            0,0,[2,n('E4'),'f',22],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // ADVENTURE — Exploration, 120 BPM, Chrono Trigger warmth
  // I-bVII-I Mixolydian (G-F-G), singable melody
  // AABA' — pentatonic scaffold G-A-B-D-E with chromatic spice
  // ════════════════════════════════════════════════════════════════════
  S.adventure = { bpm:120, echo:[250,0.3,0.3,4000],
    inst: { l:I('sq50',0.02,0.12,0.6,0.15), b:I('tri',0.01,0.15,0.45,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false),
            p:I('str',0.4,0.3,0.5,0.5), a:I('sq25',0.01,0.08,0.5,0.1) },
    pats: [
      // A (bars 1-4): G major hook — call: G-A-B-D ascending, syncopated
      [16, [[2,R,'k',62],[1,n('G4'),'l',42],[0,n('G2'),'b',46],[4,R,'h',20],
            0,[1,n('A4'),'l',38],[4,R,'h',15],[1,n('B4'),'l',40],
            [3,R,'s',46],[4,R,'h',20],[0,n('F2'),'b',42],[1,n('D5'),'l',44],
            [2,R,'k',56],[1,n('B4'),'l',38],[4,R,'h',15],0]],
      // A' (bars 5-8): response — melody descends E-D-B-A, variation with pad
      [16, [[2,R,'k',62],[1,n('E5'),'l',42],[0,n('G2'),'b',46],[4,R,'h',20],
            [5,n('G3'),'p',18],[1,n('D5'),'l',40],[4,R,'h',15],0,
            [3,R,'s',46],[1,n('B4'),'l',40],[0,n('F2'),'b',42],[4,R,'h',20],
            [2,R,'k',56],[1,n('A4'),'l',42],[4,R,'h',15],[5,n('F3'),'p',16]]],
      // B (bars 9-12): C-F Mixolydian contrast — arpeggiated, thicker
      [16, [[2,R,'k',62],[6,n('C4'),'a',28],[0,n('C3'),'b',46],[6,n('E4'),'a',28],
            [4,R,'h',15],[6,n('G4'),'a',28],0,[6,n('C5'),'a',24],
            [3,R,'s',46],[6,n('G4'),'a',28],[0,n('F2'),'b',42],[6,n('A4'),'a',28],
            [2,R,'k',56],[6,n('F4'),'a',28],[4,R,'h',15],[6,n('C5'),'a',24]]],
      // A/bridge (bars 13-16): thin, end on D(V)
      [16, [[2,R,'k',56],[4,R,'h',18],[0,n('G2'),'b',42],0,
            [1,n('G4'),'l',36],[4,R,'h',14],0,0,
            [3,R,'s',40],[4,R,'h',18],[0,n('D2'),'b',44],0,
            0,[4,R,'h',14],[1,n('F#4'),'l',32],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // PUZZLE — Playful, 145 BPM, bouncy syncopation
  // Major pentatonic C-D-E-G-A, call-and-response, I-IV-V-I
  // AABA' — Puyo Puyo energy
  // ════════════════════════════════════════════════════════════════════
  S.puzzle = { bpm:145, echo:[140,0.2,0.2,5500],
    inst: { l:I('sq50',0.01,0.08,0.65,0.08), b:I('tri',0.01,0.1,0.5,0.08), k:I('kck',0.005,0.15,0,0.05,false),
            s:I('snr',0.005,0.1,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), a:I('sq25',0.01,0.06,0.5,0.08) },
    pats: [
      // A (bars 1-4): C major call — C-E-G-A pentatonic bounce
      [16, [[2,R,'k',72],[1,n('C5'),'l',42],[0,n('C3'),'b',50],[4,R,'h',24],
            0,[1,n('E5'),'l',40],[4,R,'h',18],[1,n('G5'),'l',42],
            [3,R,'s',52],[4,R,'h',24],[0,n('G2'),'b',46],[1,n('A5'),'l',40],
            [2,R,'k',62],[1,n('G5'),'l',42],[4,R,'h',18],0]],
      // A' (bars 5-8): response — descent A-G-E-D-C, variation
      [16, [[2,R,'k',72],[1,n('A5'),'l',42],[0,n('F2'),'b',48],[4,R,'h',24],
            0,[1,n('G5'),'l',40],[4,R,'h',18],[1,n('E5'),'l',40],
            [3,R,'s',52],[4,R,'h',24],[0,n('G2'),'b',46],[1,n('D5'),'l',42],
            [2,R,'k',62],[1,n('C5'),'l',44],[4,R,'h',18],[1,n('E5'),'l',38]]],
      // B (bars 9-12): IV-V (F-G) — arpeggiated contrast
      [16, [[2,R,'k',72],[5,n('F3'),'a',28],[0,n('F2'),'b',48],[5,n('A3'),'a',28],
            [4,R,'h',18],[5,n('C4'),'a',28],0,[5,n('F4'),'a',25],
            [3,R,'s',52],[5,n('G3'),'a',28],[0,n('G2'),'b',46],[5,n('B3'),'a',28],
            [2,R,'k',62],[5,n('D4'),'a',28],[4,R,'h',18],[5,n('G4'),'a',25]]],
      // A/bridge (bars 13-16): thin, end on G(V)
      [16, [[2,R,'k',65],[4,R,'h',20],[0,n('C3'),'b',44],0,
            [1,n('C5'),'l',36],[4,R,'h',16],0,0,
            [3,R,'s',45],[4,R,'h',20],[0,n('G2'),'b',46],0,
            0,[4,R,'h',16],[1,n('B4'),'l',34],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // IDLE — Ambient growth, 95 BPM, Harvest Moon warmth
  // Gentle arpeggiated piano, I-V-vi-IV (G-D-Em-C)
  // AABA' — pastoral, thin at boundaries
  // ════════════════════════════════════════════════════════════════════
  S.idle = { bpm:95, echo:[350,0.4,0.4,3000],
    inst: { g:I('pno',0.01,0.3,0.25,0.4,false), b:I('tri',0.02,0.2,0.35,0.15), p:I('str',0.6,0.4,0.5,0.8),
            f:I('sin',0.1,0.2,0.5,0.3), c:I('pnoi',0.005,0.06,0,0.02,false) },
    pats: [
      // A (bars 1-4): G-D — arpeggiated piano, gentle melody G-A-B
      [16, [[0,n('G2'),'b',34],[1,n('G4'),'g',30],0,0,
            [3,n('B4'),'f',24],[1,n('B4'),'g',28],[4,R,'c',10],0,
            [0,n('D3'),'b',30],[1,n('D5'),'g',28],0,0,
            0,[1,n('A4'),'g',28],[3,n('F#4'),'f',22],0]],
      // A' (bars 5-8): Em-C — melody descends B-A-G-E
      [16, [[0,n('E2'),'b',34],[1,n('B4'),'g',28],[2,n('E3'),'p',16],0,
            0,[1,n('A4'),'g',28],[4,R,'c',10],0,
            [0,n('C3'),'b',30],[1,n('G4'),'g',28],0,0,
            [2,n('C3'),'p',16],[1,n('E4'),'g',28],[3,n('E4'),'f',22],0]],
      // B (bars 9-12): bVII-IV (F-C) — borrowed chord warmth
      [16, [[0,n('F2'),'b',34],0,[3,n('A4'),'f',26],0,
            [1,n('C5'),'g',28],0,[4,R,'c',10],0,
            [0,n('C3'),'b',30],0,[3,n('E5'),'f',26],0,
            [1,n('G4'),'g',28],[2,n('C3'),'p',16],0,0]],
      // A/bridge (bars 13-16): thin, end on D(V)
      [16, [[0,n('G2'),'b',28],[1,n('G4'),'g',24],0,0,
            0,0,0,0,
            [0,n('D3'),'b',30],0,[1,n('F#4'),'g',22],0,
            0,0,0,0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // DECKBUILDER — Card battle, 125 BPM
  // Minor key tension with major chorus, i-bVI-bVII-i (Am-F-G-Am)
  // Strategic feel, AABA'
  // ════════════════════════════════════════════════════════════════════
  S.deckbuilder = { bpm:125, echo:[200,0.28,0.25,4500],
    inst: { l:I('sq50',0.01,0.1,0.65,0.12), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), t:I('str',0.2,0.25,0.5,0.3),
            f:I('fm',0.01,0.08,0.55,0.12) },
    pats: [
      // A (bars 1-4): Am hook — syncopated minor pentatonic A-C-D-E
      [16, [[2,R,'k',66],[1,n('A4'),'l',42],[0,n('A2'),'b',50],[4,R,'h',20],
            0,[1,n('C5'),'l',38],[4,R,'h',16],[1,n('D5'),'l',40],
            [3,R,'s',50],[4,R,'h',20],[0,n('F2'),'b',46],[1,n('E5'),'l',42],
            [2,R,'k',60],[1,n('D5'),'l',38],[4,R,'h',16],0]],
      // A' (bars 5-8): response — add FM punch, melody varies
      [16, [[2,R,'k',66],[1,n('E5'),'l',42],[0,n('G2'),'b',48],[4,R,'h',20],
            [6,n('A3'),'f',22],[1,n('D5'),'l',40],[4,R,'h',16],0,
            [3,R,'s',50],[4,R,'h',20],[0,n('A2'),'b',50],[1,n('C5'),'l',40],
            [2,R,'k',60],[1,n('A4'),'l',42],[4,R,'h',16],[6,n('E3'),'f',20]]],
      // B (bars 9-12): bVI-bVII (F-G) — major color, string texture
      [16, [[2,R,'k',66],[5,n('F3'),'t',28],[0,n('F2'),'b',48],[4,R,'h',18],
            [1,n('A4'),'l',38],[5,n('A3'),'t',26],[4,R,'h',14],0,
            [3,R,'s',50],[5,n('G3'),'t',28],[0,n('G2'),'b',46],[4,R,'h',18],
            [2,R,'k',60],[1,n('B4'),'l',40],[5,n('D4'),'t',24],[4,R,'h',14]]],
      // A/bridge (bars 13-16): thin, end on E(V of Am)
      [16, [[2,R,'k',58],[4,R,'h',16],[0,n('A2'),'b',44],0,
            [1,n('A4'),'l',34],[4,R,'h',14],0,0,
            [3,R,'s',42],[4,R,'h',16],[0,n('E2'),'b',46],0,
            0,[4,R,'h',14],[1,n('G#4'),'l',30],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // RUNNER — Fast action, 170 BPM, F-Zero energy
  // Saw lead, ascending runs, i-bVII-bVI-V (Am-G-F-E)
  // AABA' — driving chromatic bass
  // ════════════════════════════════════════════════════════════════════
  S.runner = { bpm:170, echo:[100,0.2,0.18,6000],
    inst: { l:I('saw',0.01,0.06,0.7,0.08), b:I('bas',0.01,0.1,0.5,0.06), k:I('kck',0.005,0.15,0,0.04,false),
            s:I('snr',0.005,0.1,0,0.04,false), h:I('hh',0.005,0.03,0,0.02,false), a:I('sq50',0.01,0.05,0.6,0.06),
            f:I('fm',0.01,0.05,0.6,0.06) },
    pats: [
      // A (bars 1-4): Am hook — ascending saw lead A-C-D-E, driving beat
      [16, [[2,R,'k',76],[4,R,'h',28],[0,n('A2'),'b',55],[1,n('A4'),'l',46],
            [4,R,'h',20],[1,n('C5'),'l',42],[4,R,'h',22],[1,n('D5'),'l',44],
            [3,R,'s',56],[4,R,'h',28],[0,n('G2'),'b',52],[1,n('E5'),'l',48],
            [2,R,'k',72],[4,R,'h',22],[1,n('D5'),'l',42],0]],
      // A' (bars 5-8): bVII-bVI — descend E-D-C-A, FM accents
      [16, [[2,R,'k',76],[4,R,'h',28],[0,n('G2'),'b',52],[1,n('E5'),'l',48],
            [6,n('G3'),'f',24],[1,n('D5'),'l',44],[4,R,'h',22],0,
            [3,R,'s',56],[4,R,'h',28],[0,n('F2'),'b',52],[1,n('C5'),'l',46],
            [2,R,'k',72],[1,n('A4'),'l',44],[4,R,'h',22],[6,n('E3'),'f',22]]],
      // B (bars 9-12): V-i resolution (E-Am) — arpeggiated energy burst
      [16, [[2,R,'k',76],[5,n('E3'),'a',30],[0,n('E2'),'b',54],[5,n('G#3'),'a',30],
            [4,R,'h',20],[5,n('B3'),'a',30],[4,R,'h',18],[5,n('E4'),'a',28],
            [3,R,'s',56],[5,n('A3'),'a',30],[0,n('A2'),'b',54],[5,n('C4'),'a',30],
            [2,R,'k',72],[5,n('E4'),'a',30],[4,R,'h',18],[5,n('A4'),'a',28]]],
      // A/bridge (bars 13-16): thin, end on E(V)
      [16, [[2,R,'k',70],[4,R,'h',22],[0,n('A2'),'b',50],0,
            [1,n('A4'),'l',40],[4,R,'h',18],0,0,
            [3,R,'s',48],[4,R,'h',22],[0,n('E2'),'b',52],0,
            0,[4,R,'h',18],[1,n('G#4'),'l',38],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // SIGNAL — Investigation, 105 BPM
  // Mysterious piano, semitone motion, i-iv-bVI-bVII (Am-Dm-F-G)
  // AABA' — sparse piano with semitone tension
  // ════════════════════════════════════════════════════════════════════
  S.signal = { bpm:105, echo:[300,0.35,0.35,3500],
    inst: { p:I('pno',0.01,0.35,0.2,0.4,false), b:I('bas',0.02,0.2,0.35,0.15), d:I('str',0.5,0.3,0.4,0.6),
            e:I('pno',0.01,0.5,0.08,0.5,false), h:I('hh',0.005,0.06,0,0.02,false), c:I('pnoi',0.005,0.05,0,0.02,false) },
    pats: [
      // A (bars 1-4): Am-Dm — piano call, semitone melody A-Bb-A-G#-A
      [16, [[0,n('A2'),'b',42],[1,n('A4'),'p',36],0,[4,R,'h',15],
            [1,n('Bb4'),'p',30],[5,R,'c',12],[1,n('A4'),'p',34],0,
            [0,n('D3'),'b',38],[1,n('G#4'),'p',32],0,[4,R,'h',15],
            0,[1,n('A4'),'p',34],[5,R,'c',10],0]],
      // A' (bars 5-8): bVI-bVII — response, add string pad
      [16, [[0,n('F2'),'b',42],[2,n('F3'),'d',18],[1,n('C5'),'p',36],0,
            [4,R,'h',15],[1,n('A4'),'p',30],0,0,
            [0,n('G2'),'b',40],[2,n('G3'),'d',18],[1,n('B4'),'p',34],0,
            0,[1,n('A4'),'p',30],[5,R,'c',12],[3,n('D5'),'e',14]]],
      // B (bars 9-12): contrast — chromatic bass descent A-Ab-G-F#
      [16, [[0,n('A2'),'b',44],[1,n('E5'),'p',36],0,[4,R,'h',16],
            [2,n('A3'),'d',20],[1,n('C5'),'p',32],0,0,
            [0,n('Ab2'),'b',40],[1,n('Eb5'),'p',34],[5,R,'c',12],0,
            [0,n('G2'),'b',42],[1,n('D5'),'p',36],[4,R,'h',14],[3,n('B5'),'e',14]]],
      // A/bridge (bars 13-16): thin, end on E(V of Am)
      [16, [[0,n('A2'),'b',36],[1,n('A4'),'p',28],0,0,
            0,0,0,0,
            [0,n('E2'),'b',38],0,[1,n('G#4'),'p',26],0,
            0,[3,n('B4'),'e',12],0,0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  // ════════════════════════════════════════════════════════════════════
  // SNATCHER — Cyberpunk noir, 110 BPM
  // Saw lead, minor 7ths, chromatic bass, noir detective
  // Progression: Em7-Dm7-Cmaj7-B7 (chromatic descent), AABA'
  // ════════════════════════════════════════════════════════════════════
  S.snatcher = { bpm:110, echo:[280,0.4,0.35,3500],
    inst: { l:I('saw',0.02,0.12,0.55,0.2), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false),
            p:I('str',0.4,0.3,0.45,0.5), a:I('sq25',0.01,0.08,0.5,0.1) },
    pats: [
      // A (bars 1-4): Em7 hook — chromatic bass E-Eb-D, saw melody E-G-A-B
      [16, [[2,R,'k',62],[4,R,'h',24],[0,n('E2'),'b',50],[1,n('E4'),'l',40],
            0,[1,n('G4'),'l',38],[4,R,'h',18],0,
            [3,R,'s',46],[4,R,'h',24],[0,n('Eb2'),'b',46],[1,n('A4'),'l',42],
            [2,R,'k',58],[1,n('B4'),'l',40],[4,R,'h',18],0]],
      // A' (bars 5-8): Dm7 — melody descends, add arpeggio texture
      [16, [[2,R,'k',62],[4,R,'h',24],[0,n('D2'),'b',50],[1,n('A4'),'l',42],
            [6,n('D3'),'a',24],[1,n('G4'),'l',38],[4,R,'h',18],0,
            [3,R,'s',46],[4,R,'h',24],[0,n('C2'),'b',48],[1,n('F4'),'l',40],
            [2,R,'k',58],[1,n('E4'),'l',42],[4,R,'h',18],[6,n('G3'),'a',22]]],
      // B (bars 9-12): Cmaj7-B7 — chromatic resolution, pad + lead call-response
      [16, [[2,R,'k',62],[5,n('C3'),'p',24],[0,n('C2'),'b',50],[4,R,'h',20],
            [1,n('E5'),'l',38],[4,R,'h',16],[1,n('G5'),'l',36],0,
            [3,R,'s',46],[5,n('B2'),'p',24],[0,n('B1'),'b',48],[4,R,'h',20],
            [2,R,'k',58],[1,n('D#5'),'l',40],[1,n('F#5'),'l',36],[4,R,'h',16]]],
      // A/bridge (bars 13-16): thin, end on B(V of Em)
      [16, [[2,R,'k',55],[4,R,'h',18],[0,n('E2'),'b',44],0,
            [1,n('E4'),'l',34],[4,R,'h',14],0,0,
            [3,R,'s',40],[4,R,'h',18],[0,n('B1'),'b',46],0,
            0,[4,R,'h',14],[1,n('D#4'),'l',30],0]]
    ], seq:[0,0,1,1,2,2,3,0] };

  return S;
}

// ── Engine ────────────────────────────────────────────────────────────

function Engine() {
  this._ctx = null;
  this._mg = null;   // master gain
  this._mf = null;   // master filter
  this._ei = null;   // echo input
  this._ed = null;   // echo delay
  this._ef = null;   // echo feedback
  this._efl = null;  // echo filter
  this._ew = null;   // echo wet
  this._dry = null;  // dry path
  this._smp = null;  // raw samples
  this._buf = {};    // AudioBuffers
  this._song = null;
  this._sn = null;   // song name
  this._on = false;  // playing
  this._mt = false;  // muted
  this._vol = 0.6;
  this._ch = [];
  this._sq = 0;      // sequence position
  this._st = 0;      // step position
  this._tmr = null;
  this._nxt = 0;     // next step time

  try {
    var v = localStorage.getItem('snes-audio-volume');
    if (v !== null) this._vol = parseFloat(v);
    if (localStorage.getItem('snes-audio-muted') === 'true') this._mt = true;
  } catch(e) {}

  this._smp = genSamples();
  for (var i = 0; i < 8; i++) this._ch[i] = {src:null,gn:null,pan:0,on:false};
}

Engine.prototype._init = function() {
  if (this._ctx) return;
  try { this._ctx = new (window.AudioContext || window.webkitAudioContext)({sampleRate:44100}); } catch(e) { return; }

  var c = this._ctx, k = Object.keys(this._smp);
  for (var i = 0; i < k.length; i++) {
    var raw = this._smp[k[i]], ab = c.createBuffer(1, raw.length, SR);
    var d = ab.getChannelData(0); for (var j = 0; j < raw.length; j++) d[j] = raw[j];
    this._buf[k[i]] = ab;
  }

  this._mg = c.createGain();
  this._mg.gain.value = this._mt ? 0 : this._vol;

  this._mf = c.createBiquadFilter();
  this._mf.type = 'lowpass'; this._mf.frequency.value = 14000; this._mf.Q.value = 0.7;

  this._dry = c.createGain(); this._dry.gain.value = 1.0;
  this._ei = c.createGain(); this._ei.gain.value = 0.35;
  this._ed = c.createDelay(1.0); this._ed.delayTime.value = 0.25;
  this._ef = c.createGain(); this._ef.gain.value = 0.3;
  this._efl = c.createBiquadFilter();
  this._efl.type = 'lowpass'; this._efl.frequency.value = 3500; this._efl.Q.value = 0.5;
  this._ew = c.createGain(); this._ew.gain.value = 0.3;

  this._ei.connect(this._ed);
  this._ed.connect(this._efl);
  this._efl.connect(this._ef);
  this._ef.connect(this._ed);
  this._efl.connect(this._ew);

  this._dry.connect(this._mf);
  this._ew.connect(this._mf);
  this._mf.connect(this._mg);
  this._mg.connect(c.destination);
};

Engine.prototype._resume = function() {
  if (this._ctx && this._ctx.state === 'suspended') this._ctx.resume();
};

Engine.prototype._suspend = function() {
  if (this._ctx && this._ctx.state === 'running' && !this._on) this._ctx.suspend();
};

Engine.prototype._echo = function(e) {
  if (!this._ctx || !e) return;
  this._ed.delayTime.value = Math.max(0.05, Math.min(0.5, (e[0]||250)/1000));
  this._ef.gain.value = Math.max(0, Math.min(0.9, e[1]||0.3));
  this._ew.gain.value = Math.max(0, Math.min(1, e[2]||0.3));
  this._efl.frequency.value = e[3]||3500;
};

Engine.prototype._note = function(ch, midi, inst, vol, t) {
  if (!this._ctx || ch < 0 || ch >= 8 || !inst) return;
  var id = this._song ? this._song.inst[inst] : null;
  // For stingers, check _stingerInst
  if (!id && this._stingerInst) id = this._stingerInst[inst];
  if (!id) return;
  var ab = this._buf[id.s];
  if (!ab) return;

  var c = this._ch[ch];
  if (c.src) { try { c.src.stop(t); } catch(e) {} }
  if (midi === R) { c.on = false; return; }

  var freq = NF[midi]||440, rate = freq / (SR / SL);
  var src = this._ctx.createBufferSource();
  src.buffer = ab; src.playbackRate.value = rate; src.loop = id.lp;

  var v = (vol/100) * 0.5;
  var env = this._ctx.createGain();
  env.gain.setValueAtTime(0.001, t);
  env.gain.linearRampToValueAtTime(v, t + id.a);
  env.gain.linearRampToValueAtTime(v * id.su, t + id.a + id.d);

  if (!id.lp) {
    var nl = id.a + id.d + 0.05;
    env.gain.linearRampToValueAtTime(0.001, t + nl + id.r);
    src.stop(t + nl + id.r + 0.01);
  }

  src.connect(env);
  var last = env;
  if (this._ctx.createStereoPanner) {
    var pan = this._ctx.createStereoPanner();
    pan.pan.value = c.pan || 0;
    env.connect(pan); last = pan;
  }
  last.connect(this._dry);
  last.connect(this._ei);
  src.start(t);

  c.src = src; c.gn = env; c.on = true;
};

Engine.prototype._step = function(t) {
  if (!this._song) return;
  var seq = this._song.seq;
  var pi = seq[this._sq % seq.length];
  var pat = this._song.pats[pi];
  if (!pat) return;

  var steps = pat[0], data = pat[1];
  var s = data[this._st];
  if (s && s !== 0) {
    this._note(s[0], s[1], s[2], s[3]||50, t);
  }

  this._st++;
  if (this._st >= steps) {
    this._st = 0; this._sq++;
    if (this._sq >= seq.length) this._sq = 0;
  }
};

Engine.prototype._sched = function() {
  if (!this._on || !this._ctx) return;
  var bpm = this._song ? this._song.bpm || 120 : 120;
  var dur = 60.0 / bpm / 4;
  while (this._nxt < this._ctx.currentTime + 0.1) {
    this._step(this._nxt);
    this._nxt += dur;
  }
};

// ── Stinger system ──────────────────────────────────────────────────
// Short musical cues: 'victory', 'collect', 'fail', 'discover'

Engine.prototype.stinger = function(type) {
  this._init(); this._resume();
  if (!this._ctx) return;

  var t = this._ctx.currentTime + 0.02;
  var notes, dur, inst;

  // Stinger instruments (independent of current song)
  this._stingerInst = {
    _sv: {s:'sq50',a:0.005,d:0.08,su:0.6,r:0.12,lp:false},
    _sf: {s:'fm',a:0.005,d:0.06,su:0.5,r:0.1,lp:false},
    _sp: {s:'pno',a:0.005,d:0.12,su:0.2,r:0.2,lp:false}
  };

  switch(type) {
    case 'victory':
      // Ascending major arpeggio, V→I resolution (G→C)
      // G-B-D-G then C-E-G-C (about 1 second)
      dur = 0.1;
      notes = [
        [0,n('G4'),'_sv',50], [0,n('B4'),'_sv',55], [0,n('D5'),'_sv',55],
        [0,n('G5'),'_sf',60], [0,n('C5'),'_sp',65], [0,n('E5'),'_sp',60],
        [0,n('G5'),'_sp',55], [0,n('C6'),'_sp',50]
      ];
      break;
    case 'collect':
      // 4 ascending notes, <1 second
      dur = 0.07;
      notes = [
        [0,n('C5'),'_sf',50], [0,n('E5'),'_sf',55],
        [0,n('G5'),'_sf',60], [0,n('C6'),'_sv',55]
      ];
      break;
    case 'fail':
      // Descending minor — sad trombone feel
      dur = 0.15;
      notes = [
        [0,n('E5'),'_sv',50], [0,n('Eb5'),'_sv',48],
        [0,n('C5'),'_sv',45], [0,n('A4'),'_sv',40],
        [0,n('Ab4'),'_sf',35]
      ];
      break;
    case 'discover':
      // Whole-tone run → bright major chord
      dur = 0.08;
      notes = [
        [0,n('C5'),'_sf',40], [0,n('D5'),'_sf',42], [0,n('E5'),'_sf',44],
        [0,n('F#5'),'_sf',46], [0,n('G#5'),'_sf',48],
        [0,n('C5'),'_sp',55], [1,n('E5'),'_sp',50], [1,n('G5'),'_sp',45]
      ];
      break;
    default:
      return;
  }

  var self = this;
  for (var i = 0; i < notes.length; i++) {
    var nn = notes[i];
    // Use channel 6-7 for stingers to avoid stepping on music
    var ch = (nn[0] % 2) + 6;
    var id = self._stingerInst[nn[2]];
    if (!id) continue;
    var ab = self._buf[id.s];
    if (!ab) continue;

    var midi = nn[1];
    var freq = NF[midi]||440, rate = freq / (SR / SL);
    var src = self._ctx.createBufferSource();
    src.buffer = ab; src.playbackRate.value = rate; src.loop = false;

    var v = (nn[3]/100) * 0.5;
    var env = self._ctx.createGain();
    var st = t + i * dur;
    env.gain.setValueAtTime(0.001, st);
    env.gain.linearRampToValueAtTime(v, st + id.a);
    env.gain.linearRampToValueAtTime(v * id.su, st + id.a + id.d);
    var nl = id.a + id.d + 0.05;
    env.gain.linearRampToValueAtTime(0.001, st + nl + id.r);
    src.stop(st + nl + id.r + 0.01);

    src.connect(env);
    env.connect(self._dry);
    env.connect(self._ei);
    src.start(st);
  }
};

// ── Public API ───────────────────────────────────────────────────────

Engine.prototype.loadSong = function(name) {
  var s = songs();
  if (s[name]) { this._song = s[name]; this._sn = name; return true; }
  return false;
};

Engine.prototype.play = function() {
  if (this._on) return;
  this._init(); this._resume();
  if (!this._ctx || !this._song) return;
  this._echo(this._song.echo);
  this._on = true; this._sq = 0; this._st = 0;
  this._nxt = this._ctx.currentTime + 0.05;
  var self = this;
  this._tmr = setInterval(function() { self._sched(); }, 25);
};

Engine.prototype.stop = function() {
  this._on = false;
  if (this._tmr) { clearInterval(this._tmr); this._tmr = null; }
  for (var i = 0; i < 8; i++) {
    var c = this._ch[i];
    if (c.src) { try { c.src.stop(); } catch(e) {} c.src = null; }
    c.on = false;
  }
  // Suspend AudioContext on mobile to save resources
  var self = this;
  setTimeout(function() { self._suspend(); }, 500);
};

Engine.prototype.pause = function() {
  if (!this._on) return;
  this._on = false;
  if (this._tmr) { clearInterval(this._tmr); this._tmr = null; }
  // Suspend AudioContext when paused (helps mobile battery)
  var self = this;
  setTimeout(function() { self._suspend(); }, 500);
};

Engine.prototype.resume = function() {
  if (this._on) return;
  this._resume();
  if (!this._ctx || !this._song) return;
  this._on = true; this._nxt = this._ctx.currentTime + 0.05;
  var self = this;
  this._tmr = setInterval(function() { self._sched(); }, 25);
};

Engine.prototype.setVolume = function(v) {
  this._vol = Math.max(0, Math.min(1, v));
  if (this._mg && !this._mt) this._mg.gain.value = this._vol;
  try { localStorage.setItem('snes-audio-volume', this._vol.toString()); } catch(e) {}
};

Engine.prototype.getVolume = function() { return this._vol; };

Engine.prototype.toggleMute = function() {
  this._mt = !this._mt;
  if (this._mg) this._mg.gain.value = this._mt ? 0 : this._vol;
  try { localStorage.setItem('snes-audio-muted', this._mt ? 'true' : 'false'); } catch(e) {}
  return this._mt;
};

Engine.prototype.isMuted = function() { return this._mt; };
Engine.prototype.isPlaying = function() { return this._on; };
Engine.prototype.getSongName = function() { return this._sn; };
Engine.prototype.listSongs = function() { return Object.keys(songs()); };

// ── Music toggle button ──────────────────────────────────────────────

Engine.prototype.createToggle = function(container) {
  var self = this;
  var btn = document.createElement('button');
  btn.className = 'snes-audio-toggle';
  btn.setAttribute('aria-label', 'Toggle music');
  btn.title = 'Toggle music';

  function draw() {
    var on = !self._mt && self._on;
    btn.innerHTML = '';
    var cv = document.createElement('canvas');
    cv.width = 16; cv.height = 16;
    cv.style.cssText = 'width:16px;height:16px;image-rendering:pixelated;';
    var cx = cv.getContext('2d');
    var cl = on ? '#33ff33' : '#555';
    cx.fillStyle = cl;
    cx.fillRect(2,5,3,6); cx.fillRect(5,3,2,10);
    if (on) {
      cx.fillRect(9,4,1,1); cx.fillRect(10,5,1,1); cx.fillRect(10,10,1,1);
      cx.fillRect(9,11,1,1); cx.fillRect(9,7,1,2);
      cx.fillRect(12,3,1,1); cx.fillRect(13,5,1,2); cx.fillRect(13,9,1,2); cx.fillRect(12,12,1,1);
    } else {
      cx.fillStyle = '#ff4444';
      cx.fillRect(9,5,1,1); cx.fillRect(10,6,1,1); cx.fillRect(11,7,1,1);
      cx.fillRect(12,8,1,1); cx.fillRect(13,9,1,1);
      cx.fillRect(13,5,1,1); cx.fillRect(12,6,1,1); cx.fillRect(10,8,1,1); cx.fillRect(9,9,1,1);
    }
    btn.appendChild(cv);
  }

  btn.style.cssText =
    'position:fixed;bottom:16px;right:56px;z-index:999;' +
    'background:rgba(10,10,15,0.85);border:2px solid #1e1e2a;' +
    'color:#c8c8d0;width:32px;height:32px;cursor:pointer;padding:0;' +
    'font-family:monospace;display:flex;align-items:center;justify-content:center;' +
    'border-radius:0;box-shadow:2px 2px 0 rgba(0,0,0,0.5);';

  draw();

  btn.addEventListener('click', function() {
    self._init(); self._resume();
    if (!self._on && self._song) { self.play(); }
    else if (self._on) { self.toggleMute(); }
    draw();
  });

  btn.addEventListener('dblclick', function(e) {
    e.preventDefault();
    if (self._on) self.stop(); else if (self._song) self.play();
    draw();
  });

  (container || document.body).appendChild(btn);
  return btn;
};

return Engine;
})();
