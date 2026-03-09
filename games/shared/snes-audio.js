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
  return s;
}

// ── Compact song definitions ─────────────────────────────────────────
// Instruments: [sampleKey, attack, decay, sustain, release, loop]
// Pattern step: [ch, midiNote, instKey, volume] or null for empty step
// Using helper I() for instrument defs, P() for patterns

function I(smp,a,d,s,r,lp) { return {s:smp,a:a,d:d,su:s,r:r,lp:lp!==false}; }

function songs() {
  var S = {};

  // ── AIRLOCK -- Tense ambient (Metroid / Alien 3) ─────────────────
  S.airlock = { bpm:75, echo:[350,0.45,0.4,3000],
    inst: { p:I('str',0.8,0.3,0.6,1.2), b:I('bas',0.01,0.2,0.4,0.5), h:I('hh',0.005,0.1,0,0.05,false),
            t:I('sin',0.4,0.5,0.3,0.8), n:I('noi',0.5,1.0,0.2,1.5) },
    pats: [
      [32, [[0,n('E2'),'b',50],0,0,0, 0,0,0,0, [1,n('B3'),'p',25],0,0,0, [0,n('E2'),'b',35],0,0,0,
            0,0,0,0, [2,n('E4'),'t',15],0,0,0, [0,n('B1'),'b',45],0,0,0, 0,0,[3,R,'h',10],0]],
      [32, [[0,n('E2'),'b',50],0,0,0, [4,n('C2'),'n',8],0,0,0, [1,n('C4'),'p',25],0,0,0, [0,n('F2'),'b',40],0,0,0,
            [3,R,'h',15],0,0,0, [2,n('G4'),'t',15],0,0,0, [0,n('E2'),'b',45],0,0,0, [3,R,'h',12],0,0,0]]
    ], seq:[0,0,1,1,0,1] };

  // ── BOOTLOADER -- Digital startup (Mega Man X) ───────────────────
  S.bootloader = { bpm:140, echo:[150,0.3,0.25,5000],
    inst: { l:I('sq50',0.01,0.1,0.7,0.15), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.15,0,0.05,false), h:I('hh',0.005,0.06,0,0.02,false), a:I('sq25',0.01,0.08,0.5,0.1) },
    pats: [
      [16, [[0,n('E2'),'b',60],[4,R,'h',30],[1,n('E4'),'l',40],0,
            [2,R,'k',70],[4,R,'h',25],0,0, [0,n('E2'),'b',50],[4,R,'h',30],[3,R,'s',50],0,
            [2,R,'k',65],[4,R,'h',25],[1,n('G4'),'l',40],0]],
      [16, [[2,R,'k',70],[4,R,'h',30],[1,n('E5'),'l',45],[0,n('E2'),'b',50],
            0,[4,R,'h',25],[1,n('D5'),'l',40],0, [2,R,'k',65],[4,R,'h',30],[3,R,'s',50],[1,n('B4'),'l',40],
            [0,n('D2'),'b',50],[4,R,'h',25],[1,n('A4'),'l',35],0]],
      [16, [[2,R,'k',70],[5,n('E4'),'a',30],[0,n('E2'),'b',50],[5,n('G4'),'a',30],
            0,[5,n('B4'),'a',30],[4,R,'h',20],[5,n('E5'),'a',25],
            [3,R,'s',50],[5,n('B4'),'a',30],[0,n('D2'),'b',50],[5,n('G4'),'a',30],
            [2,R,'k',65],[5,n('D4'),'a',30],[4,R,'h',20],[5,n('F#4'),'a',30]]]
    ], seq:[0,0,1,1,2,2,1,2] };

  // ── BRIGADE -- Military march (Advance Wars) ────────────────────
  S.brigade = { bpm:130, echo:[180,0.25,0.2,4500],
    inst: { l:I('sq50',0.01,0.1,0.7,0.12), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false), r:I('saw',0.05,0.15,0.6,0.2) },
    pats: [
      [16, [[2,R,'k',70],[4,R,'h',30],[0,n('C3'),'b',50],0, [3,R,'s',55],[4,R,'h',25],0,0,
            [2,R,'k',70],[4,R,'h',30],[0,n('G2'),'b',50],0, [3,R,'s',55],[4,R,'h',25],[3,R,'s',35],0]],
      [16, [[2,R,'k',70],[1,n('C5'),'r',40],[0,n('C3'),'b',50],0, [3,R,'s',55],[1,n('E5'),'r',40],0,0,
            [2,R,'k',65],[1,n('G5'),'r',45],[0,n('G2'),'b',50],0, [3,R,'s',55],[1,n('E5'),'r',35],[4,R,'h',20],0]],
      [16, [[2,R,'k',70],[1,n('G5'),'r',45],[0,n('C3'),'b',50],[5,n('C5'),'l',30],
            [3,R,'s',55],0,[1,n('A5'),'r',40],0, [2,R,'k',70],[1,n('G5'),'r',45],[0,n('F2'),'b',50],0,
            [3,R,'s',55],[1,n('E5'),'r',40],[4,R,'h',25],[5,n('E5'),'l',30]]]
    ], seq:[0,0,1,1,2,2,1,2] };

  // ── CARD -- Smooth chill (FF6 casino) ────────────────────────────
  S.card = { bpm:110, echo:[250,0.35,0.35,4000],
    inst: { p:I('pno',0.01,0.3,0.3,0.4,false), b:I('bas',0.01,0.2,0.45,0.15), h:I('hh',0.005,0.05,0,0.02,false),
            s:I('snr',0.005,0.15,0,0.05,false), d:I('str',0.5,0.3,0.5,0.6), l:I('sin',0.05,0.2,0.5,0.3) },
    pats: [
      [16, [[0,n('A2'),'b',50],[2,R,'h',30],[1,n('C5'),'p',40],0, 0,[2,R,'h',20],[1,n('E5'),'p',35],0,
            [3,R,'s',40],[2,R,'h',30],[1,n('A4'),'p',40],0, [0,n('E2'),'b',45],[2,R,'h',20],[1,n('G4'),'p',35],0]],
      [16, [[0,n('D3'),'b',50],[4,n('D4'),'d',20],[5,n('F5'),'l',35],0, 0,[2,R,'h',25],[5,n('E5'),'l',30],0,
            [3,R,'s',40],0,[5,n('D5'),'l',35],0, [0,n('A2'),'b',45],[2,R,'h',25],[5,n('C5'),'l',30],0]]
    ], seq:[0,0,1,1,0,1] };

  // ── CASCADE -- Escalating tension (Tetris) ───────────────────────
  S.cascade = { bpm:135, echo:[120,0.2,0.2,5000],
    inst: { l:I('sq50',0.01,0.08,0.65,0.1), b:I('tri',0.01,0.12,0.5,0.1), k:I('kck',0.005,0.18,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), a:I('sq25',0.01,0.06,0.5,0.08) },
    pats: [
      [16, [[2,R,'k',70],[1,n('A4'),'l',45],[0,n('A2'),'b',50],[4,R,'h',25],
            0,[1,n('E4'),'l',40],[4,R,'h',20],0, [3,R,'s',50],[1,n('F4'),'l',40],[0,n('F2'),'b',45],[4,R,'h',25],
            [2,R,'k',60],[1,n('E4'),'l',40],[4,R,'h',20],0]],
      [16, [[2,R,'k',70],[1,n('D4'),'l',45],[0,n('D2'),'b',50],[4,R,'h',25],
            0,[1,n('C4'),'l',40],[4,R,'h',20],0, [3,R,'s',50],[1,n('B3'),'l',40],[0,n('E2'),'b',45],[4,R,'h',25],
            [2,R,'k',60],[1,n('A3'),'l',45],[4,R,'h',20],0]],
      [16, [[2,R,'k',70],[5,n('A3'),'a',30],[0,n('A2'),'b',50],[5,n('C4'),'a',30],
            [4,R,'h',20],[5,n('E4'),'a',30],0,[5,n('A4'),'a',25],
            [3,R,'s',50],[5,n('E4'),'a',30],[0,n('E2'),'b',45],[5,n('C4'),'a',30],
            [2,R,'k',60],[5,n('B3'),'a',30],[4,R,'h',20],[5,n('E4'),'a',30]]]
    ], seq:[0,1,0,1,2,2,0,2] };

  // ── CHEMISTRY -- Experimental/bubbly (SimCity lab) ───────────────
  S.chemistry = { bpm:115, echo:[280,0.35,0.35,3500],
    inst: { u:I('sin',0.02,0.15,0.3,0.2), b:I('tri',0.01,0.2,0.4,0.15), c:I('pnoi',0.005,0.04,0,0.02,false),
            p:I('str',0.6,0.4,0.5,0.5), l:I('sq25',0.01,0.06,0.4,0.1), h:I('hh',0.005,0.04,0,0.02,false) },
    pats: [
      [16, [[0,n('C3'),'b',45],[1,n('G5'),'u',30],0,[5,R,'h',20], 0,[1,n('E5'),'u',25],[2,R,'c',30],0,
            [0,n('G2'),'b',40],[1,n('C6'),'u',20],0,[5,R,'h',20], 0,[4,n('E5'),'l',25],[2,R,'c',25],0]],
      [16, [[0,n('F3'),'b',45],[3,n('F3'),'p',20],[1,n('A5'),'u',30],0,
            [5,R,'h',20],[1,n('F5'),'u',25],0,[2,R,'c',25],
            [0,n('C3'),'b',40],0,[1,n('C5'),'u',30],[5,R,'h',20], 0,[4,n('G5'),'l',20],0,[2,R,'c',20]]]
    ], seq:[0,0,1,1,0,1] };

  // ── CYPHER -- Spy thriller (Metal Gear) ──────────────────────────
  S.cypher = { bpm:100, echo:[300,0.4,0.35,3000],
    inst: { b:I('bas',0.01,0.2,0.4,0.15), l:I('sq25',0.02,0.15,0.5,0.2), p:I('str',0.5,0.4,0.4,0.8),
            k:I('kck',0.005,0.2,0,0.05,false), s:I('snr',0.005,0.15,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false) },
    pats: [
      [16, [[3,R,'k',50],[5,R,'h',20],[0,n('E2'),'b',45],0, 0,[5,R,'h',15],0,0,
            0,[5,R,'h',20],[0,n('G2'),'b',40],0, [4,R,'s',35],[5,R,'h',15],0,0]],
      [16, [[3,R,'k',50],[1,n('E4'),'l',35],[0,n('E2'),'b',45],0,
            0,[1,n('F4'),'l',30],[5,R,'h',15],0,
            [2,n('B3'),'p',20],[1,n('G4'),'l',35],[0,n('B1'),'b',40],0,
            [4,R,'s',35],[1,n('F4'),'l',30],[5,R,'h',20],[1,n('E4'),'l',25]]]
    ], seq:[0,0,1,0,1,1] };

  // ── MYCELIUM -- Organic nature (Secret of Mana) ──────────────────
  S.mycelium = { bpm:90, echo:[400,0.45,0.45,2500],
    inst: { p:I('str',0.8,0.5,0.5,1.0), f:I('sin',0.1,0.2,0.6,0.4), b:I('tri',0.05,0.3,0.35,0.2),
            c:I('pno',0.01,0.4,0.15,0.5,false), h:I('pnoi',0.005,0.08,0,0.03,false), d:I('sin',0.01,0.3,0,0.1,false) },
    pats: [
      [32, [[0,n('D3'),'b',35],0,[1,n('A4'),'f',30],0, 0,0,0,[3,n('F#5'),'c',20],
            0,0,[1,n('F#4'),'f',25],0, [0,n('A2'),'b',30],0,0,0,
            [2,n('D3'),'p',20],0,[1,n('D5'),'f',30],0, 0,0,[5,n('A5'),'d',15],0,
            0,0,[1,n('E4'),'f',25],0, [0,n('G2'),'b',30],0,0,[4,R,'h',10]]],
      [32, [[0,n('G2'),'b',35],0,[1,n('B4'),'f',30],0, 0,0,[3,n('D5'),'c',20],0,
            0,0,[1,n('G4'),'f',25],0, [0,n('D2'),'b',30],0,0,[5,n('D6'),'d',12],
            [2,n('G3'),'p',20],0,[1,n('B4'),'f',30],0, 0,0,0,[4,R,'h',10],
            0,0,[1,n('A4'),'f',25],0, [0,n('E2'),'b',30],0,0,0]]
    ], seq:[0,1,0,1] };

  // ── MYCO -- Earthy ambient (Earthbound peaceful) ─────────────────
  S.myco = { bpm:85, echo:[380,0.4,0.4,2800],
    inst: { p:I('str',1.0,0.4,0.5,1.2), b:I('tri',0.05,0.3,0.3,0.2), e:I('pno',0.01,0.5,0.1,0.6,false),
            f:I('sin',0.15,0.25,0.5,0.5), c:I('pnoi',0.005,0.05,0,0.02,false) },
    pats: [
      [32, [[0,n('C3'),'b',30],0,0,0, [1,n('E4'),'f',25],0,0,[2,n('G5'),'e',18],
            0,0,0,0, [0,n('G2'),'b',28],0,[4,R,'c',10],0,
            [3,n('C3'),'p',18],0,[1,n('G4'),'f',25],0, 0,0,0,[2,n('C5'),'e',15],
            0,0,0,0, [0,n('F2'),'b',30],0,0,0]],
      [32, [[0,n('A2'),'b',30],0,0,0, [1,n('C5'),'f',25],0,0,0,
            0,0,[2,n('E5'),'e',18],0, [0,n('E2'),'b',28],0,0,[4,R,'c',10],
            [3,n('A3'),'p',18],0,0,0, [1,n('A4'),'f',25],0,0,[2,n('D5'),'e',15],
            0,0,0,0, [0,n('D2'),'b',30],0,0,0]]
    ], seq:[0,0,1,1,0,1] };

  // ── NOVEL -- Emotional/cinematic (FF6 opera) ─────────────────────
  S.novel = { bpm:72, echo:[400,0.4,0.4,3000],
    inst: { s:I('str',0.6,0.4,0.6,1.0), p:I('pno',0.01,0.5,0.2,0.8,false), b:I('bas',0.05,0.3,0.35,0.3),
            f:I('sin',0.15,0.3,0.5,0.5), e:I('pno',0.01,0.8,0.05,1.0,false) },
    pats: [
      [32, [[0,n('C3'),'b',35],0,[1,n('E5'),'p',35],0, [2,n('C4'),'s',25],0,[1,n('G5'),'p',30],0,
            0,0,[1,n('A5'),'p',30],0, [0,n('G2'),'b',30],0,[1,n('G5'),'p',30],0,
            0,0,[3,n('E5'),'f',25],0, [2,n('G3'),'s',25],0,0,0,
            [0,n('A2'),'b',30],0,[1,n('C5'),'p',30],0, 0,0,[4,n('E6'),'e',15],0]],
      [32, [[0,n('F3'),'b',35],0,[3,n('C6'),'f',30],0, [2,n('F4'),'s',30],0,[3,n('A5'),'f',28],0,
            0,0,0,0, [0,n('C3'),'b',35],0,[1,n('G5'),'p',35],0,
            [2,n('E4'),'s',30],0,[3,n('E5'),'f',30],0, 0,0,0,[4,n('C6'),'e',15],
            [0,n('G2'),'b',35],0,[1,n('D5'),'p',30],0, 0,0,0,0]]
    ], seq:[0,0,1,0,1,1] };

  // ── OBJECTION -- Intense courtroom (Phoenix Wright) ──────────────
  S.objection = { bpm:155, echo:[130,0.2,0.2,5500],
    inst: { l:I('sq50',0.01,0.08,0.7,0.1), b:I('bas',0.01,0.12,0.5,0.08), k:I('kck',0.005,0.18,0,0.05,false),
            s:I('snr',0.005,0.1,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), r:I('saw',0.02,0.1,0.6,0.15) },
    pats: [
      [16, [[2,R,'k',75],[4,R,'h',30],[1,n('C5'),'l',45],[0,n('C3'),'b',50],
            0,[4,R,'h',25],[1,n('D5'),'l',40],0,
            [3,R,'s',55],[4,R,'h',30],[1,n('E5'),'l',45],0,
            [2,R,'k',65],[4,R,'h',25],[1,n('G5'),'l',50],0]],
      [16, [[2,R,'k',75],[5,n('C5'),'r',40],[0,n('C3'),'b',50],[4,R,'h',25],
            0,[5,n('E5'),'r',45],[4,R,'h',20],0,
            [3,R,'s',55],[5,n('G5'),'r',50],[0,n('G2'),'b',50],[4,R,'h',25],
            [2,R,'k',70],[1,n('C6'),'l',40],[4,R,'h',20],[3,R,'s',35]]],
      [16, [[2,R,'k',75],[1,n('G5'),'l',50],[0,n('F2'),'b',50],[4,R,'h',30],
            [5,n('A4'),'r',35],[4,R,'h',20],[1,n('A5'),'l',45],0,
            [3,R,'s',55],[1,n('G5'),'l',45],[0,n('C3'),'b',50],[4,R,'h',25],
            [2,R,'k',70],[1,n('E5'),'l',45],[3,R,'s',40],[1,n('D5'),'l',40]]]
    ], seq:[0,0,1,1,2,2,1,2] };

  // ── TACTICS -- Strategic/medieval (FF Tactics) ───────────────────
  S.tactics = { bpm:95, echo:[320,0.35,0.3,3500],
    inst: { s:I('str',0.3,0.3,0.6,0.5), b:I('bas',0.02,0.2,0.4,0.15), f:I('sin',0.08,0.2,0.5,0.3),
            k:I('kck',0.005,0.2,0,0.05,false), n:I('snr',0.005,0.15,0,0.05,false), e:I('pno',0.01,0.6,0.1,0.5,false) },
    pats: [
      [16, [[3,R,'k',60],[0,n('D3'),'b',45],[1,n('D4'),'s',30],0, 0,0,[2,n('A4'),'f',30],0,
            [4,R,'n',45],[0,n('A2'),'b',40],0,0, [3,R,'k',50],0,[2,n('F4'),'f',30],0]],
      [16, [[3,R,'k',65],[1,n('D4'),'s',35],[0,n('D3'),'b',50],0, 0,[2,n('D5'),'f',35],0,0,
            [4,R,'n',50],[1,n('F4'),'s',30],[0,n('F2'),'b',45],0,
            [3,R,'k',55],[2,n('E5'),'f',30],[5,n('A5'),'e',15],0]],
      [16, [[3,R,'k',60],[0,n('G2'),'b',45],[1,n('G3'),'s',30],0, [2,n('B4'),'f',30],0,0,0,
            [4,R,'n',45],[0,n('C3'),'b',45],[2,n('C5'),'f',30],0, [3,R,'k',50],0,[5,n('D5'),'e',18],0]]
    ], seq:[0,0,1,2,1,1,2,0] };

  // ── ADVENTURE -- Exploration (Chrono Trigger) ────────────────────
  S.adventure = { bpm:120, echo:[250,0.3,0.3,4000],
    inst: { l:I('sq50',0.02,0.12,0.6,0.15), b:I('tri',0.01,0.15,0.45,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false),
            p:I('str',0.4,0.3,0.5,0.5), a:I('sq25',0.01,0.08,0.5,0.1) },
    pats: [
      [16, [[2,R,'k',60],[1,n('G4'),'l',40],[0,n('G2'),'b',45],[4,R,'h',20],
            0,[1,n('A4'),'l',35],[4,R,'h',15],0,
            [3,R,'s',45],[1,n('B4'),'l',40],[0,n('D3'),'b',40],[4,R,'h',20],
            [2,R,'k',55],[1,n('D5'),'l',45],[4,R,'h',15],0]],
      [16, [[2,R,'k',60],[1,n('E5'),'l',40],[0,n('C3'),'b',45],[4,R,'h',20],
            [5,n('C4'),'p',20],[1,n('D5'),'l',35],[4,R,'h',15],0,
            [3,R,'s',45],[1,n('B4'),'l',40],[0,n('G2'),'b',40],[4,R,'h',20],
            [2,R,'k',55],[1,n('A4'),'l',40],[4,R,'h',15],0]],
      [16, [[2,R,'k',60],[6,n('G3'),'a',30],[0,n('E2'),'b',45],[6,n('B3'),'a',28],
            [4,R,'h',15],[6,n('E4'),'a',28],0,[6,n('G4'),'a',25],
            [3,R,'s',45],[6,n('E4'),'a',28],[0,n('D2'),'b',40],[6,n('B3'),'a',28],
            [2,R,'k',55],[6,n('D4'),'a',30],[4,R,'h',15],[6,n('F#4'),'a',28]]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ── PUZZLE -- Playful (Puyo Puyo / Tetris Attack) ────────────────
  S.puzzle = { bpm:145, echo:[140,0.2,0.2,5500],
    inst: { l:I('sq50',0.01,0.08,0.65,0.08), b:I('tri',0.01,0.1,0.5,0.08), k:I('kck',0.005,0.15,0,0.05,false),
            s:I('snr',0.005,0.1,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), a:I('sq25',0.01,0.06,0.5,0.08) },
    pats: [
      [16, [[2,R,'k',70],[1,n('C5'),'l',40],[0,n('C3'),'b',50],[4,R,'h',25],
            0,[1,n('E5'),'l',38],[4,R,'h',20],0,
            [3,R,'s',50],[1,n('G5'),'l',42],[0,n('G2'),'b',45],[4,R,'h',25],
            [2,R,'k',60],[1,n('E5'),'l',38],[4,R,'h',20],0]],
      [16, [[2,R,'k',70],[1,n('F5'),'l',42],[0,n('F2'),'b',50],[4,R,'h',25],
            0,[1,n('E5'),'l',38],[4,R,'h',20],0,
            [3,R,'s',50],[1,n('D5'),'l',40],[0,n('G2'),'b',45],[4,R,'h',25],
            [2,R,'k',60],[1,n('C5'),'l',42],[4,R,'h',20],0]],
      [16, [[2,R,'k',70],[5,n('C4'),'a',30],[0,n('C3'),'b',50],[5,n('E4'),'a',28],
            [4,R,'h',20],[5,n('G4'),'a',28],0,[5,n('C5'),'a',25],
            [3,R,'s',50],[5,n('G4'),'a',28],[0,n('G2'),'b',45],[5,n('E4'),'a',28],
            [2,R,'k',60],[5,n('F4'),'a',28],[4,R,'h',20],[5,n('A4'),'a',28]]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ── IDLE -- Ambient growth (Harvest Moon) ────────────────────────
  S.idle = { bpm:95, echo:[350,0.4,0.4,3000],
    inst: { g:I('pno',0.01,0.3,0.25,0.4,false), b:I('tri',0.02,0.2,0.35,0.15), p:I('str',0.6,0.4,0.5,0.8),
            f:I('sin',0.1,0.2,0.5,0.3), c:I('pnoi',0.005,0.06,0,0.02,false) },
    pats: [
      [16, [[0,n('G2'),'b',35],[1,n('G4'),'g',30],0,0, 0,[1,n('B4'),'g',28],[4,R,'c',12],0,
            [0,n('D3'),'b',30],[1,n('D4'),'g',30],0,0, [2,n('G3'),'p',20],[1,n('A4'),'g',28],0,0]],
      [16, [[0,n('C3'),'b',35],0,[3,n('E5'),'f',30],0, 0,[1,n('C4'),'g',25],[4,R,'c',12],0,
            [0,n('G2'),'b',30],0,[3,n('D5'),'f',28],0, [2,n('C3'),'p',20],[1,n('E4'),'g',25],0,0]]
    ], seq:[0,0,1,1,0,1] };

  // ── DECKBUILDER -- Card battle (Yu-Gi-Oh SNES) ──────────────────
  S.deckbuilder = { bpm:125, echo:[200,0.28,0.25,4500],
    inst: { l:I('sq50',0.01,0.1,0.65,0.12), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.04,0,0.02,false), t:I('str',0.2,0.25,0.5,0.3) },
    pats: [
      [16, [[2,R,'k',65],[1,n('E4'),'l',40],[0,n('E2'),'b',50],[4,R,'h',20],
            0,[1,n('G4'),'l',38],[4,R,'h',18],0,
            [3,R,'s',50],[1,n('A4'),'l',40],[0,n('A2'),'b',45],[4,R,'h',20],
            [2,R,'k',60],[1,n('B4'),'l',42],[4,R,'h',18],0]],
      [16, [[2,R,'k',65],[5,n('A3'),'t',30],[0,n('A2'),'b',50],0,
            0,[1,n('C5'),'l',40],[4,R,'h',20],0,
            [3,R,'s',50],[5,n('E4'),'t',30],[0,n('E2'),'b',45],0,
            [2,R,'k',60],[1,n('B4'),'l',38],[4,R,'h',20],0]]
    ], seq:[0,0,1,1,0,1] };

  // ── RUNNER -- Fast-paced action (F-Zero) ─────────────────────────
  S.runner = { bpm:170, echo:[100,0.2,0.18,6000],
    inst: { l:I('saw',0.01,0.06,0.7,0.08), b:I('bas',0.01,0.1,0.5,0.06), k:I('kck',0.005,0.15,0,0.04,false),
            s:I('snr',0.005,0.1,0,0.04,false), h:I('hh',0.005,0.03,0,0.02,false), a:I('sq50',0.01,0.05,0.6,0.06) },
    pats: [
      [16, [[2,R,'k',75],[4,R,'h',30],[0,n('A2'),'b',55],[1,n('A4'),'l',45],
            [4,R,'h',20],[1,n('C5'),'l',40],[4,R,'h',25],0,
            [3,R,'s',55],[4,R,'h',30],[0,n('G2'),'b',50],[1,n('E5'),'l',45],
            [2,R,'k',70],[4,R,'h',25],[1,n('D5'),'l',40],[4,R,'h',20]]],
      [16, [[2,R,'k',75],[1,n('E5'),'l',50],[0,n('C3'),'b',55],[4,R,'h',25],
            0,[1,n('D5'),'l',45],[4,R,'h',20],[5,n('C4'),'a',30],
            [3,R,'s',55],[1,n('C5'),'l',45],[0,n('F2'),'b',50],[4,R,'h',25],
            [2,R,'k',70],[5,n('E4'),'a',30],[4,R,'h',20],[5,n('G4'),'a',28]]],
      [16, [[2,R,'k',75],[5,n('A3'),'a',30],[0,n('A2'),'b',55],[5,n('C4'),'a',30],
            [4,R,'h',20],[5,n('E4'),'a',30],[4,R,'h',20],[5,n('A4'),'a',28],
            [3,R,'s',55],[5,n('E4'),'a',30],[0,n('E2'),'b',50],[5,n('C4'),'a',30],
            [2,R,'k',70],[5,n('G3'),'a',30],[4,R,'h',20],[5,n('B3'),'a',30]]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ── SIGNAL -- Mysterious deduction (investigation) ───────────────
  S.signal = { bpm:105, echo:[300,0.35,0.35,3500],
    inst: { p:I('pno',0.01,0.35,0.2,0.4,false), b:I('bas',0.02,0.2,0.35,0.15), d:I('str',0.5,0.3,0.4,0.6),
            e:I('pno',0.01,0.5,0.08,0.5,false), h:I('hh',0.005,0.06,0,0.02,false), c:I('pnoi',0.005,0.05,0,0.02,false) },
    pats: [
      [16, [[0,n('A2'),'b',40],[1,n('A4'),'p',35],0,[4,R,'h',15],
            0,[1,n('C5'),'p',30],0,0,
            [0,n('E2'),'b',35],[1,n('E4'),'p',30],0,[5,R,'c',12],
            0,[3,n('E5'),'e',15],0,0]],
      [16, [[0,n('D3'),'b',40],[2,n('D3'),'d',20],[1,n('F5'),'p',35],0,
            0,[1,n('E5'),'p',30],[4,R,'h',15],0,
            [0,n('A2'),'b',35],0,[1,n('D5'),'p',30],0,
            0,[1,n('C5'),'p',30],[5,R,'c',12],[3,n('A5'),'e',15]]]
    ], seq:[0,0,1,0,1,1] };

  // ── SNATCHER -- Cyberpunk noir (Snatcher PCE) ────────────────────
  S.snatcher = { bpm:110, echo:[280,0.4,0.35,3500],
    inst: { l:I('saw',0.02,0.12,0.55,0.2), b:I('bas',0.01,0.15,0.5,0.1), k:I('kck',0.005,0.2,0,0.05,false),
            s:I('snr',0.005,0.12,0,0.05,false), h:I('hh',0.005,0.05,0,0.02,false),
            p:I('str',0.4,0.3,0.45,0.5), a:I('sq25',0.01,0.08,0.5,0.1) },
    pats: [
      [16, [[2,R,'k',60],[4,R,'h',25],[0,n('E2'),'b',50],0, 0,[4,R,'h',20],[0,n('G2'),'b',40],0,
            [3,R,'s',45],[4,R,'h',25],[0,n('A2'),'b',45],0, [2,R,'k',55],[4,R,'h',20],[0,n('G2'),'b',40],0]],
      [16, [[2,R,'k',60],[1,n('E4'),'l',40],[0,n('E2'),'b',50],[4,R,'h',20],
            0,[1,n('G4'),'l',38],0,[6,n('B3'),'a',25],
            [3,R,'s',45],[1,n('A4'),'l',40],[0,n('A2'),'b',45],[4,R,'h',20],
            [2,R,'k',55],[1,n('G4'),'l',38],[6,n('E4'),'a',25],0]],
      [16, [[2,R,'k',60],[5,n('E3'),'p',25],[0,n('E2'),'b',50],[6,n('E3'),'a',25],
            [4,R,'h',20],[6,n('G3'),'a',25],0,[6,n('B3'),'a',22],
            [3,R,'s',45],[6,n('E4'),'a',25],[0,n('B1'),'b',45],[6,n('B3'),'a',22],
            [2,R,'k',55],[6,n('G3'),'a',25],[4,R,'h',20],[6,n('E3'),'a',22]]]
    ], seq:[0,0,1,1,2,2,1,2] };

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
  this._mf.type = 'lowpass'; this._mf.frequency.value = 12000; this._mf.Q.value = 0.7;

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

Engine.prototype._echo = function(e) {
  if (!this._ctx || !e) return;
  this._ed.delayTime.value = Math.max(0.05, Math.min(0.5, (e[0]||250)/1000));
  this._ef.gain.value = Math.max(0, Math.min(0.9, e[1]||0.3));
  this._ew.gain.value = Math.max(0, Math.min(1, e[2]||0.3));
  this._efl.frequency.value = e[3]||3500;
};

Engine.prototype._note = function(ch, midi, inst, vol, t) {
  if (!this._ctx || ch < 0 || ch >= 8 || !inst) return;
  var id = this._song.inst[inst];
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
};

Engine.prototype.pause = function() {
  if (!this._on) return;
  this._on = false;
  if (this._tmr) { clearInterval(this._tmr); this._tmr = null; }
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
