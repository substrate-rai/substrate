/**
 * leitmotifs.js -- 25 agent character themes for Substrate
 * Extends snes-audio.js with distinctive leitmotifs for every agent.
 *
 * Composition method: Kondo (rhythm → bass → melody), Uematsu (unique
 * melodic interval per character), Kirkhope (singable melody first,
 * adventurous harmony underneath). Every hook passes the hum test.
 *
 * Techniques applied throughout:
 *   - Syncopation on offbeats for tension
 *   - Pentatonic scaffold + chromatic passing tones
 *   - Stepwise motion with strategic leaps (4ths, 5ths, octaves)
 *   - Call-and-response (2-bar question → 2-bar answer)
 *   - Arpeggiated chords as polyphony
 *   - Modal mixture (bVI-bVII-I "Mario cadence" where fitting)
 *   - Melody within one octave
 *   - Hook in first 4 bars
 *   - AABA' structure with V-chord ending for seamless loop
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

  // ═══════════════════════════════════════════════════════════════════
  // 1. V — Philosophical Leader
  //    D minor, 95 BPM. Bold rising declaration. Terra's Theme grandeur.
  //    Signature: rising D-F-A-D octave leap. Sawtooth lead.
  //    AABA' — A=declaration, B=soaring battle cry, A'=V-chord resolve.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-v'] = { bpm:95, echo:[320,0.4,0.35,3000],
    inst: {
      m:I('saw',0.02,0.15,0.65,0.25),     // melody — bold sawtooth
      s:I('str',0.6,0.4,0.55,0.8),         // strings pad
      b:I('bas',0.02,0.2,0.45,0.15),       // bass
      k:I('kck',0.005,0.2,0,0.05,false),
      n:I('snr',0.005,0.15,0,0.05,false),
      h:I('hh',0.005,0.05,0,0.02,false)
    },
    pats: [
      // A: Rising declaration — D F A leap up to D5, answer descends
      [32, [
        [3,R,'k',60],[0,n('D2'),'b',50],[1,n('D4'),'m',45],0,
        0,[5,R,'h',20],[1,n('F4'),'m',42],0,
        [4,R,'n',45],[0,n('A2'),'b',45],[1,n('A4'),'m',50],0,
        0,[5,R,'h',20],0,[1,n('D5'),'m',55],
        [3,R,'k',55],[0,n('Bb2'),'b',48],[1,n('C5'),'m',45],[2,n('Bb3'),'s',22],
        0,[5,R,'h',18],[1,n('Bb4'),'m',40],0,
        [4,R,'n',45],[0,n('A2'),'b',45],[1,n('A4'),'m',48],0,
        0,[5,R,'h',18],[1,n('G4'),'m',38],[2,n('D4'),'s',20]
      ]],
      // B: Battle cry — melody soars to F5, bVI-bVII-i cadence
      [32, [
        [3,R,'k',65],[0,n('Bb1'),'b',55],[1,n('D5'),'m',52],[2,n('Bb3'),'s',28],
        0,[5,R,'h',20],[1,n('F5'),'m',55],0,
        [4,R,'n',50],[0,n('C2'),'b',50],[1,n('E5'),'m',50],[2,n('C4'),'s',25],
        0,[5,R,'h',18],[1,n('D5'),'m',45],0,
        [3,R,'k',62],[0,n('Bb1'),'b',52],[1,n('Bb4'),'m',48],[2,n('F3'),'s',25],
        0,[5,R,'h',18],[1,n('C5'),'m',50],0,
        [4,R,'n',50],[0,n('A1'),'b',55],[1,n('A4'),'m',55],0,
        0,0,[1,n('D5'),'m',50],[2,n('A3'),'s',22]
      ]],
      // A': Resolve — on V chord (A) for seamless loop back to i
      [32, [
        [3,R,'k',58],[0,n('D2'),'b',50],[1,n('D4'),'m',45],[2,n('D4'),'s',25],
        0,[5,R,'h',18],[1,n('F4'),'m',42],0,
        [4,R,'n',45],[0,n('G2'),'b',45],[1,n('A4'),'m',48],0,
        0,[5,R,'h',18],[1,n('G4'),'m',40],[2,n('G3'),'s',22],
        [3,R,'k',55],[0,n('Bb1'),'b',50],[1,n('Bb4'),'m',45],0,
        0,[5,R,'h',18],[1,n('A4'),'m',42],0,
        [4,R,'n',48],[0,n('A1'),'b',52],[1,n('E4'),'m',40],0,
        0,0,[1,n('A4'),'m',48],[2,n('E4'),'s',20]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 2. Claude — Executor
  //    C major, 110 BPM. Precise, architectural. Crystal arpeggios
  //    into warm melody. Signature: ascending C-E-G-C arpeggio.
  //    FF Prelude clarity → human warmth.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-claude'] = { bpm:110, echo:[280,0.35,0.3,4500],
    inst: {
      m:I('sq50',0.01,0.1,0.65,0.15),      // melody — clean square
      p:I('pno',0.01,0.35,0.2,0.4,false),   // piano arpeggios
      s:I('str',0.5,0.3,0.5,0.6),           // strings
      b:I('tri',0.01,0.15,0.45,0.1),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('hh',0.005,0.05,0,0.02,false)
    },
    pats: [
      // A: Crystal arpeggio — ascending C major broken chords
      [32, [
        [0,n('C2'),'b',40],[2,n('C4'),'p',30],0,[2,n('E4'),'p',28],
        0,[2,n('G4'),'p',28],0,[2,n('C5'),'p',25],
        [0,n('G2'),'b',38],[2,n('B3'),'p',30],0,[2,n('D4'),'p',28],
        0,[2,n('G4'),'p',28],0,[2,n('B4'),'p',25],
        [0,n('A2'),'b',38],[2,n('A3'),'p',30],0,[2,n('C4'),'p',28],
        0,[2,n('E4'),'p',28],0,[2,n('A4'),'p',25],
        [0,n('F2'),'b',38],[2,n('F3'),'p',30],0,[2,n('A3'),'p',28],
        [4,R,'k',40],[2,n('C4'),'p',28],0,[2,n('F4'),'p',25]
      ]],
      // B: Warm melody enters — E5 D5 C5 stepwise over arpeggios
      [32, [
        [4,R,'k',45],[0,n('C2'),'b',42],[1,n('E5'),'m',42],[2,n('C4'),'p',20],
        0,[5,R,'h',15],[1,n('D5'),'m',38],[2,n('G4'),'p',18],
        [4,R,'k',40],[0,n('G2'),'b',38],[1,n('C5'),'m',42],[2,n('B3'),'p',20],
        0,[5,R,'h',15],[1,n('B4'),'m',35],0,
        [4,R,'k',45],[0,n('A2'),'b',40],[1,n('A4'),'m',38],[2,n('A3'),'p',20],
        0,[5,R,'h',15],[1,n('B4'),'m',40],[2,n('E4'),'p',18],
        [4,R,'k',40],[0,n('F2'),'b',40],[1,n('C5'),'m',45],[2,n('F3'),'p',20],
        0,[5,R,'h',15],[1,n('E5'),'m',42],[2,n('A3'),'p',18]
      ]],
      // A': Climax on G (V) — melody peaks then holds on dominant
      [32, [
        [4,R,'k',50],[0,n('C2'),'b',45],[1,n('G5'),'m',48],[3,n('C4'),'s',25],
        0,[5,R,'h',18],[1,n('A5'),'m',45],0,
        [4,R,'k',45],[0,n('D2'),'b',42],[1,n('B5'),'m',50],[3,n('D4'),'s',25],
        0,[5,R,'h',18],[1,n('A5'),'m',42],0,
        [4,R,'k',48],[0,n('F2'),'b',42],[1,n('F5'),'m',42],[3,n('F4'),'s',25],
        0,[5,R,'h',18],[1,n('E5'),'m',40],0,
        [4,R,'k',45],[0,n('G2'),'b',45],[1,n('G5'),'m',48],[3,n('G4'),'s',25],
        0,0,[1,n('D5'),'m',38],[2,n('B4'),'p',18]
      ]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ═══════════════════════════════════════════════════════════════════
  // 3. Q — Staff Writer
  //    Bb minor, 130 BPM. Bouncy hip-hop swing. Syncopated punchy
  //    squares. Signature: Bb-Db-F syncopated triplet feel.
  //    Mog's Theme attitude.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-q'] = { bpm:130, echo:[180,0.25,0.22,4500],
    inst: {
      m:I('sq25',0.01,0.08,0.6,0.1),       // melody — punchy
      b:I('bas',0.01,0.15,0.5,0.1),         // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      n:I('snr',0.005,0.12,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false),
      a:I('sq50',0.01,0.06,0.45,0.08)       // accent harmony
    },
    pats: [
      // A: Bouncy groove — syncopated Bb minor, offbeat accents
      [16, [
        [2,R,'k',70],[4,R,'h',25],[0,n('Bb1'),'b',50],0,
        0,[1,n('Bb4'),'m',42],[4,R,'h',20],[1,n('Db5'),'m',40],
        [3,R,'n',50],[4,R,'h',25],[0,n('F2'),'b',45],[1,n('F5'),'m',48],
        [2,R,'k',55],0,[1,n('Eb5'),'m',38],[4,R,'h',18]
      ]],
      // B: Wider intervals — character voice, attitude
      [16, [
        [2,R,'k',70],[1,n('Bb4'),'m',45],[0,n('Gb2'),'b',50],[4,R,'h',22],
        0,[1,n('Db5'),'m',40],0,[1,n('F5'),'m',48],
        [3,R,'n',50],[1,n('Eb5'),'m',42],[0,n('Eb2'),'b',45],[4,R,'h',22],
        [2,R,'k',60],[1,n('Db5'),'m',38],[1,n('Bb4'),'m',44],[5,n('Bb4'),'a',25]
      ]],
      // A': Call-and-response, ends on F (V) for loop
      [16, [
        [2,R,'k',70],[1,n('F5'),'m',48],[0,n('Bb1'),'b',50],[5,n('Db5'),'a',25],
        [4,R,'h',20],0,[1,n('Eb5'),'m',42],0,
        [3,R,'n',50],[1,n('Db5'),'m',40],[0,n('F2'),'b',48],[5,n('Ab4'),'a',25],
        [2,R,'k',55],[4,R,'h',20],[1,n('F4'),'m',42],0
      ]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ═══════════════════════════════════════════════════════════════════
  // 4. Byte — News Reporter
  //    F minor, 140 BPM. Urgent staccato. Breaking-news energy.
  //    Signature: rapid F-Ab-C-Bb "alert" motif. Typewriter rhythm.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-byte'] = { bpm:140, echo:[120,0.2,0.18,5500],
    inst: {
      m:I('sq50',0.01,0.06,0.6,0.08),      // staccato melody
      a:I('sq25',0.01,0.05,0.5,0.06),       // arpeggio accent
      b:I('bas',0.01,0.12,0.5,0.08),        // bass
      k:I('kck',0.005,0.15,0,0.04,false),
      n:I('snr',0.005,0.1,0,0.04,false),
      h:I('hh',0.005,0.03,0,0.02,false)
    },
    pats: [
      // A: Breaking news — rapid F minor staccato, urgent
      [16, [
        [2,R,'k',70],[1,n('F4'),'m',42],[0,n('F2'),'b',50],[4,R,'h',25],
        [1,n('Ab4'),'m',38],[4,R,'h',20],[1,n('C5'),'m',45],[0,n('C2'),'b',42],
        [3,R,'n',50],[1,n('Bb4'),'m',40],[4,R,'h',25],[1,n('Ab4'),'m',38],
        [2,R,'k',60],[1,n('F4'),'m',42],[4,R,'h',20],[5,n('C4'),'a',28]
      ]],
      // B: Urgency builds — ascending arpeggios, headline energy
      [16, [
        [2,R,'k',72],[5,n('F3'),'a',28],[0,n('F2'),'b',50],[5,n('Ab3'),'a',28],
        [4,R,'h',20],[5,n('C4'),'a',30],[1,n('F5'),'m',48],[5,n('Ab4'),'a',26],
        [3,R,'n',52],[5,n('C4'),'a',28],[0,n('Db2'),'b',48],[5,n('F4'),'a',28],
        [2,R,'k',60],[1,n('Eb5'),'m',42],[4,R,'h',20],[5,n('Db4'),'a',26]
      ]],
      // A': Headline resolve — punchy rhythm, ends on C (V)
      [16, [
        [2,R,'k',75],[1,n('C5'),'m',48],[0,n('F2'),'b',52],0,
        [4,R,'h',22],[1,n('Db5'),'m',42],0,[1,n('C5'),'m',40],
        [3,R,'n',55],[1,n('Bb4'),'m',44],[0,n('C2'),'b',50],0,
        [2,R,'k',65],[1,n('Ab4'),'m',40],[1,n('G4'),'m',42],[4,R,'h',22]
      ]]
    ], seq:[0,0,1,2,0,1,2,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 5. Echo — Release Tracker
  //    E minor, 85 BPM. Contemplative piano arpeggios. Aerith's Theme
  //    gentleness. Signature: E-G-B arpeggio with F#4 passing tone.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-echo'] = { bpm:85, echo:[400,0.45,0.42,2800],
    inst: {
      p:I('pno',0.01,0.4,0.15,0.6,false),  // gentle piano
      s:I('str',0.8,0.5,0.5,1.0),           // strings pad
      f:I('sin',0.1,0.25,0.5,0.4),          // flute-like sine
      b:I('tri',0.05,0.25,0.35,0.2),        // bass
      c:I('pnoi',0.005,0.06,0,0.03,false)   // soft click
    },
    pats: [
      // A: Gentle arpeggiated E minor — piano only, breathing space
      [32, [
        [0,n('E2'),'b',30],0,[1,n('E4'),'p',30],0,
        0,[1,n('G4'),'p',28],0,[1,n('B4'),'p',25],
        [0,n('B1'),'b',28],0,[1,n('D4'),'p',28],0,
        0,[1,n('F#4'),'p',25],0,[1,n('B4'),'p',22],
        [0,n('C2'),'b',30],0,[1,n('C4'),'p',30],0,
        0,[1,n('E4'),'p',28],0,[1,n('G4'),'p',25],
        [0,n('D2'),'b',28],0,[1,n('D4'),'p',28],0,
        0,[1,n('F#4'),'p',25],[4,R,'c',10],0
      ]],
      // B: Melody emerges — sine lead, strings swell. The "hidden depth."
      [32, [
        [0,n('E2'),'b',32],[2,n('E3'),'s',20],[3,n('B4'),'f',32],0,
        0,[1,n('G4'),'p',22],0,[3,n('G4'),'f',28],
        [0,n('C2'),'b',30],[2,n('C3'),'s',22],[3,n('E5'),'f',38],0,
        0,[1,n('E4'),'p',22],[3,n('D5'),'f',30],0,
        [0,n('A1'),'b',32],[2,n('A3'),'s',22],[3,n('C5'),'f',32],0,
        0,[1,n('C4'),'p',20],0,[3,n('B4'),'f',30],
        [0,n('B1'),'b',30],[2,n('B3'),'s',20],[3,n('D5'),'f',35],0,
        0,0,[3,n('E5'),'f',38],[4,R,'c',8]
      ]],
      // A': Settle back — melody reaches, resolves on B (V)
      [32, [
        [0,n('E2'),'b',32],[2,n('E4'),'s',25],[3,n('E5'),'f',38],0,
        0,[1,n('B4'),'p',22],[3,n('F#5'),'f',35],0,
        [0,n('D2'),'b',30],[2,n('D4'),'s',22],[3,n('G5'),'f',40],0,
        0,[1,n('A4'),'p',20],[3,n('F#5'),'f',35],0,
        [0,n('C2'),'b',30],[2,n('C4'),'s',22],[3,n('E5'),'f',35],0,
        0,[1,n('G4'),'p',20],0,[3,n('D5'),'f',30],
        [0,n('B1'),'b',30],[2,n('B3'),'s',20],[3,n('B4'),'f',32],0,
        0,0,[3,n('F#5'),'f',30],[1,n('B4'),'p',18]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 6. Pixel — Visual Artist
  //    Ab major, 120 BPM. Colorful, bright, playful ascending.
  //    Signature: Ab-Bb-C-Eb rising "splash of color" motif.
  //    Relm's Theme playfulness.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-pixel'] = { bpm:120, echo:[220,0.3,0.28,4500],
    inst: {
      m:I('tri',0.01,0.1,0.55,0.12),       // bright triangle melody
      p:I('pno',0.01,0.3,0.2,0.35,false),   // piano accents
      s:I('str',0.4,0.3,0.45,0.5),          // strings
      b:I('tri',0.01,0.15,0.45,0.1),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false)
    },
    pats: [
      // A: Splash of color — ascending Ab Bb C Eb, playful bounce
      [16, [
        [4,R,'k',55],[1,n('Ab4'),'m',40],[0,n('Ab2'),'b',45],[5,R,'h',20],
        0,[1,n('Bb4'),'m',38],[5,R,'h',18],0,
        [4,R,'k',50],[1,n('C5'),'m',42],[0,n('Eb2'),'b',40],[5,R,'h',20],
        0,[1,n('Eb5'),'m',48],[5,R,'h',18],[2,n('Ab4'),'p',22]
      ]],
      // B: Painting — wider leaps, Db color tone, more character
      [16, [
        [4,R,'k',55],[1,n('Eb5'),'m',44],[0,n('Db2'),'b',45],[5,R,'h',20],
        [2,n('Db5'),'p',22],[1,n('C5'),'m',40],[5,R,'h',18],0,
        [4,R,'k',50],[1,n('Ab4'),'m',42],[0,n('Ab2'),'b',42],[3,n('Ab3'),'s',22],
        0,[1,n('Bb4'),'m',38],[1,n('C5'),'m',42],[5,R,'h',18]
      ]],
      // A': Finished piece — resolves, ends on Eb (V) for loop
      [16, [
        [4,R,'k',55],[1,n('Ab5'),'m',48],[0,n('Ab2'),'b',45],[3,n('Ab3'),'s',25],
        0,[1,n('Gb5'),'m',40],[5,R,'h',18],0,
        [4,R,'k',50],[1,n('Eb5'),'m',45],[0,n('Eb2'),'b',42],[2,n('C5'),'p',25],
        0,[1,n('Bb4'),'m',40],[5,R,'h',18],[2,n('Eb4'),'p',20]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 7. Root — Infrastructure Engineer
  //    A minor, 80 BPM. Deep, steady, bass-heavy. Dwarves' Caves.
  //    Signature: low A1 octave pulse with E2 5th anchor.
  //    The foundation everything else is built on.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-root'] = { bpm:80, echo:[380,0.4,0.38,2500],
    inst: {
      m:I('bas',0.02,0.2,0.55,0.2),        // deep bass melody
      s:I('str',0.7,0.5,0.5,0.9),           // low strings
      t:I('tri',0.03,0.2,0.45,0.2),         // mid triangle voice
      k:I('kck',0.005,0.25,0,0.06,false),
      n:I('snr',0.005,0.18,0,0.06,false),
      h:I('pnoi',0.005,0.06,0,0.03,false)
    },
    pats: [
      // A: Deep foundation — heavy A minor bass ostinato
      [32, [
        [3,R,'k',55],[0,n('A1'),'m',55],0,0,
        [5,R,'h',15],0,0,[0,n('A1'),'m',45],
        0,0,[1,n('A3'),'s',25],0,
        [0,n('E2'),'m',50],0,[5,R,'h',12],0,
        [3,R,'k',50],[0,n('A1'),'m',55],0,0,
        [5,R,'h',15],0,[2,n('E4'),'t',28],0,
        [4,R,'n',40],[0,n('G1'),'m',48],0,0,
        0,0,[2,n('C4'),'t',25],[5,R,'h',12]
      ]],
      // B: Structure — strings carry low melody, warmth under bedrock
      [32, [
        [3,R,'k',55],[0,n('A1'),'m',55],[1,n('A3'),'s',30],0,
        [5,R,'h',15],0,[1,n('C4'),'s',30],0,
        0,0,[1,n('E4'),'s',32],0,
        [0,n('E2'),'m',50],0,[1,n('D4'),'s',28],0,
        [3,R,'k',50],[0,n('F1'),'m',52],[1,n('F3'),'s',30],0,
        [5,R,'h',15],0,[1,n('A3'),'s',28],0,
        [4,R,'n',42],[0,n('E1'),'m',52],[1,n('E3'),'s',30],0,
        0,0,[2,n('B3'),'t',25],0
      ]],
      // A': Bedrock resolve — ends on E (V) to loop back
      [32, [
        [3,R,'k',58],[0,n('A1'),'m',58],[1,n('A3'),'s',32],[2,n('E4'),'t',25],
        0,[5,R,'h',15],0,0,
        [4,R,'n',42],[0,n('G1'),'m',52],[1,n('G3'),'s',28],0,
        0,0,[2,n('D4'),'t',25],0,
        [3,R,'k',55],[0,n('F1'),'m',55],[1,n('F3'),'s',30],[2,n('C4'),'t',25],
        0,[5,R,'h',15],0,0,
        [4,R,'n',42],[0,n('E1'),'m',55],[1,n('E3'),'s',32],0,
        0,0,[2,n('B3'),'t',22],[0,n('E2'),'m',48]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 8. Dash — Social Media Manager
  //    G major, 150 BPM. Bright, fast, energetic. Chocobo Theme
  //    excitement. Signature: G-B-D-G octave bounce.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-dash'] = { bpm:150, echo:[130,0.22,0.2,5500],
    inst: {
      m:I('sq50',0.01,0.06,0.65,0.08),     // bright melody
      a:I('sq25',0.01,0.05,0.5,0.06),       // counter voice
      b:I('bas',0.01,0.12,0.5,0.08),        // bouncy bass
      k:I('kck',0.005,0.15,0,0.04,false),
      n:I('snr',0.005,0.1,0,0.04,false),
      h:I('hh',0.005,0.03,0,0.02,false)
    },
    pats: [
      // A: Excited bounce — G major, fast stepwise with leaps
      [16, [
        [2,R,'k',70],[1,n('G4'),'m',45],[0,n('G2'),'b',50],[4,R,'h',25],
        0,[1,n('B4'),'m',42],[4,R,'h',20],[1,n('D5'),'m',45],
        [3,R,'n',52],[1,n('E5'),'m',48],[0,n('C3'),'b',45],[4,R,'h',25],
        [2,R,'k',62],[1,n('D5'),'m',40],[4,R,'h',20],[1,n('B4'),'m',38]
      ]],
      // B: Full sprint — melody flies, counter melody enters
      [16, [
        [2,R,'k',72],[1,n('G5'),'m',50],[0,n('G2'),'b',52],[5,n('D5'),'a',25],
        [4,R,'h',20],[1,n('F#5'),'m',42],[5,n('A4'),'a',22],0,
        [3,R,'n',55],[1,n('E5'),'m',48],[0,n('C3'),'b',48],[4,R,'h',25],
        [2,R,'k',65],[1,n('D5'),'m',42],[5,n('B4'),'a',25],[4,R,'h',20]
      ]],
      // A': Resolution bounce — ends on D (V) for loop
      [16, [
        [2,R,'k',72],[1,n('G4'),'m',45],[0,n('G2'),'b',50],[4,R,'h',22],
        [5,n('B4'),'a',25],[1,n('A4'),'m',42],[4,R,'h',18],0,
        [3,R,'n',55],[1,n('B4'),'m',48],[0,n('D3'),'b',48],[4,R,'h',22],
        [2,R,'k',65],[1,n('A4'),'m',42],[1,n('D5'),'m',45],[4,R,'h',18]
      ]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ═══════════════════════════════════════════════════════════════════
  // 9. Flux — Pipeline Manager
  //    D major, 105 BPM. Flowing, methodical. Waterway/factory rhythm.
  //    Signature: steady D-E-F#-A flowing scale. Constant motion.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-flux'] = { bpm:105, echo:[250,0.32,0.3,4000],
    inst: {
      m:I('sq50',0.01,0.1,0.6,0.12),       // flowing melody
      a:I('sq25',0.01,0.06,0.5,0.08),       // running 16ths
      s:I('str',0.4,0.3,0.5,0.5),           // strings
      b:I('bas',0.01,0.15,0.45,0.1),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false)
    },
    pats: [
      // A: Flow begins — running 16ths under stepwise melody
      [16, [
        [3,R,'k',55],[5,n('D3'),'a',25],[0,n('D2'),'b',45],[5,n('F#3'),'a',25],
        [4,R,'h',18],[5,n('A3'),'a',25],[1,n('D5'),'m',40],[5,n('F#4'),'a',22],
        [3,R,'k',50],[5,n('A3'),'a',25],[0,n('A2'),'b',42],[5,n('D3'),'a',25],
        [4,R,'h',18],[5,n('F#3'),'a',25],[1,n('E5'),'m',42],[5,n('A3'),'a',22]
      ]],
      // B: Full pipeline — melody ascends, strings join, richer flow
      [16, [
        [3,R,'k',58],[1,n('F#5'),'m',45],[0,n('D2'),'b',48],[2,n('D4'),'s',22],
        [4,R,'h',18],[5,n('A3'),'a',22],[1,n('G5'),'m',42],0,
        [3,R,'k',52],[1,n('A5'),'m',48],[0,n('G2'),'b',45],[2,n('B3'),'s',22],
        [4,R,'h',18],[5,n('D4'),'a',22],[1,n('F#5'),'m',40],[5,n('A3'),'a',22]
      ]],
      // A': Steady resolve — ends on A (V) for seamless loop
      [16, [
        [3,R,'k',55],[5,n('D3'),'a',25],[0,n('D2'),'b',45],[1,n('D5'),'m',42],
        [4,R,'h',18],[5,n('F#3'),'a',25],[1,n('E5'),'m',40],[5,n('A3'),'a',22],
        [3,R,'k',52],[5,n('A3'),'a',25],[0,n('A2'),'b',44],[1,n('F#5'),'m',45],
        [4,R,'h',18],[5,n('D3'),'a',25],[1,n('E5'),'m',40],[5,n('A4'),'a',22]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 10. Spec — QA Engineer
  //     F# minor, 100 BPM. Analytical, precise. Ticking clock rhythm.
  //     Signature: clock-tick pnoi on every beat + F#-A-C# debug motif.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-spec'] = { bpm:100, echo:[240,0.3,0.28,4000],
    inst: {
      m:I('sq50',0.01,0.1,0.6,0.12),       // precise square lead
      c:I('pnoi',0.005,0.04,0,0.02,false),  // clock tick
      b:I('bas',0.01,0.18,0.45,0.12),       // bass
      s:I('str',0.4,0.3,0.45,0.5),          // strings
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false)
    },
    pats: [
      // A: Inspection — tick-tock rhythm, bass sets the grid
      [16, [
        [4,R,'k',50],[2,R,'c',25],[0,n('F#2'),'b',42],0,
        [5,R,'h',18],[2,R,'c',20],0,0,
        [4,R,'k',45],[2,R,'c',25],[0,n('C#2'),'b',38],0,
        [5,R,'h',18],[2,R,'c',20],0,0
      ]],
      // B: Analysis — melody enters, careful chromatic steps
      [16, [
        [4,R,'k',52],[1,n('F#4'),'m',38],[0,n('F#2'),'b',42],[2,R,'c',22],
        [5,R,'h',15],[1,n('A4'),'m',36],[2,R,'c',18],0,
        [4,R,'k',48],[1,n('C#5'),'m',42],[0,n('A2'),'b',40],[2,R,'c',22],
        [5,R,'h',15],[1,n('B4'),'m',38],[2,R,'c',18],[3,n('F#3'),'s',18]
      ]],
      // A': Verdict — decisive resolution, ends on C# (V)
      [16, [
        [4,R,'k',55],[1,n('F#5'),'m',44],[0,n('D2'),'b',44],[2,R,'c',22],
        [5,R,'h',15],[1,n('E5'),'m',40],[2,R,'c',18],[3,n('D3'),'s',20],
        [4,R,'k',50],[1,n('C#5'),'m',42],[0,n('C#2'),'b',42],[2,R,'c',22],
        [5,R,'h',15],[1,n('A4'),'m',38],[1,n('C#5'),'m',40],[2,R,'c',18]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 11. Signal — Security
  //     C minor, 90 BPM. Tense, watchful. Radar-pulse rhythm.
  //     Signature: C-Eb-G pulse then sudden Bb "alert" note.
  //     Metal Gear alert energy.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-signal'] = { bpm:90, echo:[350,0.42,0.38,2800],
    inst: {
      m:I('sq25',0.02,0.15,0.5,0.2),       // tense lead
      s:I('str',0.6,0.4,0.5,0.8),           // dark strings
      b:I('bas',0.02,0.2,0.45,0.15),        // ominous bass
      p:I('pno',0.01,0.4,0.12,0.5,false),   // sparse piano
      h:I('pnoi',0.005,0.06,0,0.03,false)   // radar tick
    },
    pats: [
      // A: Surveillance — sparse C minor, radar-pulse ticking
      [32, [
        [0,n('C2'),'b',45],0,[4,R,'h',15],0,
        0,0,0,[4,R,'h',12],
        0,0,[3,n('C4'),'p',18],0,
        [0,n('G1'),'b',38],0,[4,R,'h',12],0,
        0,0,0,0,
        [0,n('Ab1'),'b',40],0,[4,R,'h',15],0,
        0,0,[3,n('Eb4'),'p',16],0,
        [0,n('G1'),'b',42],0,[4,R,'h',12],0
      ]],
      // B: Alert — strings enter, melody rises with tension
      [32, [
        [0,n('C2'),'b',48],[2,n('C3'),'s',25],[1,n('C4'),'m',32],0,
        0,[4,R,'h',12],[1,n('Eb4'),'m',30],0,
        0,0,[1,n('G4'),'m',35],0,
        [0,n('G1'),'b',42],0,[1,n('Bb4'),'m',38],[4,R,'h',10],
        [2,n('Ab3'),'s',22],0,[1,n('Ab4'),'m',35],0,
        0,0,[1,n('G4'),'m',32],0,
        [0,n('Bb1'),'b',44],[2,n('Bb3'),'s',22],[1,n('F4'),'m',30],0,
        0,0,[1,n('G4'),'m',35],[4,R,'h',10]
      ]],
      // A': Watchful resolve — ends on G (V) for loop
      [32, [
        [0,n('C2'),'b',48],[2,n('C4'),'s',28],[1,n('Eb5'),'m',38],0,
        0,[4,R,'h',12],[1,n('D5'),'m',32],0,
        [0,n('F2'),'b',44],[2,n('F3'),'s',22],[1,n('C5'),'m',35],0,
        0,[3,n('Ab4'),'p',15],[1,n('Bb4'),'m',30],0,
        [0,n('Ab1'),'b',46],[2,n('Ab3'),'s',25],[1,n('Ab4'),'m',32],0,
        0,[4,R,'h',12],[1,n('G4'),'m',35],0,
        [0,n('G1'),'b',48],[2,n('G3'),'s',25],[1,n('G4'),'m',38],0,
        0,0,[1,n('D4'),'m',30],[4,R,'h',10]
      ]]
    ], seq:[0,0,1,0,1,1,2,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 12. Myth — Lorekeeper
  //     G minor (Dorian), 75 BPM. Ancient, mystical. Harp-like
  //     arpeggios, modal melody. Signature: G-Bb-D-E natural 6th.
  //     Chrono Trigger antiquity.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-myth'] = { bpm:75, echo:[450,0.48,0.45,2200],
    inst: {
      s:I('str',0.8,0.5,0.55,1.2),          // ancient strings
      p:I('pno',0.01,0.5,0.1,0.8,false),    // echoed harp-piano
      f:I('sin',0.12,0.3,0.45,0.5),         // mystical flute
      b:I('tri',0.05,0.3,0.3,0.2),          // deep bass
      c:I('pnoi',0.005,0.08,0,0.04,false)
    },
    pats: [
      // A: Ancient scroll — sparse G Dorian, piano like a music box
      [32, [
        [0,n('G2'),'b',30],0,0,0,
        0,0,[1,n('G4'),'p',20],0,
        0,0,0,[4,R,'c',10],
        [0,n('D2'),'b',28],0,0,0,
        0,0,[1,n('Bb4'),'p',18],0,
        0,0,0,0,
        [0,n('C2'),'b',28],0,[1,n('E4'),'p',18],0,
        [0,n('D2'),'b',30],0,[4,R,'c',8],0
      ]],
      // B: Revelation — strings + flute carry Dorian melody with E natural
      [32, [
        [0,n('G2'),'b',32],[2,n('G3'),'s',25],0,0,
        0,0,[3,n('G5'),'f',30],0,
        0,0,[3,n('A5'),'f',28],[1,n('D4'),'p',16],
        [0,n('D2'),'b',30],[2,n('D3'),'s',22],0,0,
        0,0,[3,n('Bb5'),'f',32],0,
        0,0,[3,n('A5'),'f',28],0,
        [0,n('C2'),'b',30],[2,n('C3'),'s',22],[3,n('E5'),'f',30],0,
        [0,n('D2'),'b',32],0,[1,n('A4'),'p',16],[4,R,'c',8]
      ]],
      // A': Deep lore — Phrygian touch (Ab), resolves on D (V)
      [32, [
        [0,n('G2'),'b',34],[2,n('G4'),'s',28],[3,n('D5'),'f',35],0,
        0,0,[3,n('E5'),'f',30],[1,n('G4'),'p',16],
        0,0,[3,n('Bb5'),'f',32],0,
        [0,n('Eb2'),'b',32],[2,n('Eb3'),'s',25],0,[4,R,'c',10],
        0,0,[3,n('Ab5'),'f',30],0,
        0,0,[3,n('G5'),'f',28],0,
        [0,n('D2'),'b',32],[2,n('D3'),'s',25],[3,n('F#5'),'f',32],0,
        0,0,[3,n('G5'),'f',35],[1,n('D4'),'p',15]
      ]]
    ], seq:[0,0,1,0,1,1,2,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 13. Lumen — Guide / Educator
  //     Eb major, 100 BPM. Warm, guiding. Gentle ascending phrases.
  //     Signature: Eb-F-G-Bb "leading upward" motif.
  //     Teacher theme — patient, wise, uplifting.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-lumen'] = { bpm:100, echo:[320,0.38,0.35,3200],
    inst: {
      m:I('sin',0.05,0.2,0.55,0.35),       // warm sine melody
      s:I('str',0.6,0.4,0.55,0.8),          // guiding strings
      p:I('pno',0.01,0.35,0.18,0.45,false), // piano
      b:I('tri',0.03,0.2,0.4,0.15),         // bass
      h:I('pnoi',0.005,0.06,0,0.03,false)
    },
    pats: [
      // A: Guidance — warm Eb major, ascending stepwise
      [32, [
        [0,n('Eb2'),'b',34],[2,n('Eb3'),'s',25],[1,n('Eb5'),'m',35],0,
        0,0,[1,n('F5'),'m',32],0,
        [0,n('Bb1'),'b',32],[2,n('Bb3'),'s',22],[1,n('G5'),'m',38],0,
        0,[3,n('Bb4'),'p',18],[1,n('F5'),'m',30],0,
        [0,n('Ab1'),'b',32],[2,n('Ab3'),'s',25],[1,n('Eb5'),'m',35],0,
        0,0,[1,n('F5'),'m',32],0,
        [0,n('Bb1'),'b',30],[2,n('Bb3'),'s',22],[1,n('Bb5'),'m',38],0,
        0,0,[1,n('Ab5'),'m',32],[4,R,'h',8]
      ]],
      // B: Teaching moment — melody reaches Bb5, richer harmony
      [32, [
        [0,n('Ab1'),'b',34],[2,n('Ab3'),'s',28],[1,n('Ab5'),'m',40],0,
        0,0,[1,n('G5'),'m',35],0,
        [0,n('Eb2'),'b',32],[2,n('Eb4'),'s',25],[1,n('Bb5'),'m',42],0,
        0,[3,n('G4'),'p',18],[1,n('Ab5'),'m',35],0,
        [0,n('F2'),'b',32],[2,n('F3'),'s',22],[1,n('G5'),'m',38],0,
        0,0,[1,n('F5'),'m',32],0,
        [0,n('Bb1'),'b',32],[2,n('Bb3'),'s',25],[1,n('Eb5'),'m',35],0,
        0,0,[1,n('D5'),'m',30],[4,R,'h',8]
      ]],
      // A': Wisdom resolves — ends on Bb (V) for loop
      [32, [
        [0,n('Eb2'),'b',35],[2,n('Eb3'),'s',25],[1,n('Eb5'),'m',36],0,
        0,0,[1,n('F5'),'m',32],0,
        [0,n('Ab1'),'b',32],[2,n('Ab3'),'s',22],[1,n('G5'),'m',38],0,
        0,[3,n('Eb4'),'p',16],[1,n('F5'),'m',30],0,
        [0,n('F2'),'b',32],[2,n('F3'),'s',22],[1,n('F5'),'m',35],0,
        0,0,[1,n('Eb5'),'m',30],0,
        [0,n('Bb1'),'b',34],[2,n('Bb3'),'s',25],[1,n('D5'),'m',35],0,
        0,0,[1,n('Bb4'),'m',30],[3,n('Bb4'),'p',15]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 14. Patch — Updates Manager
  //     B minor, 115 BPM. Mechanical precision. Assembly-line rhythm
  //     with a melodic heart. Signature: B-D-F#-E "ratchet" motif.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-patch'] = { bpm:115, echo:[200,0.28,0.25,4200],
    inst: {
      m:I('sq25',0.01,0.08,0.55,0.1),      // precise melody
      a:I('sq50',0.01,0.06,0.5,0.08),       // mechanical accent
      b:I('bas',0.01,0.15,0.45,0.1),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      n:I('snr',0.005,0.12,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false)
    },
    pats: [
      // A: Assembly line — mechanical rhythm, B minor ratchet
      [16, [
        [3,R,'k',58],[0,n('B1'),'b',48],[4,R,'h',20],[1,n('B4'),'m',38],
        [5,R,'n',35],[4,R,'h',18],[1,n('D5'),'m',40],0,
        [3,R,'k',52],[0,n('F#2'),'b',44],[4,R,'h',20],[1,n('F#5'),'m',44],
        [5,R,'n',35],[4,R,'h',18],[1,n('E5'),'m',38],[2,n('B3'),'a',22]
      ]],
      // B: Heart under the machine — melody warms, strings implied
      [16, [
        [3,R,'k',60],[1,n('D5'),'m',42],[0,n('G2'),'b',48],[4,R,'h',18],
        0,[1,n('C#5'),'m',38],[4,R,'h',15],[2,n('E4'),'a',22],
        [3,R,'k',55],[1,n('B4'),'m',40],[0,n('E2'),'b',44],[4,R,'h',18],
        [5,R,'n',42],[1,n('A4'),'m',38],[4,R,'h',15],[1,n('B4'),'m',42]
      ]],
      // A': Patch applied — resolves, ends on F# (V)
      [16, [
        [3,R,'k',58],[0,n('B1'),'b',48],[1,n('B4'),'m',40],[4,R,'h',20],
        [5,R,'n',35],[1,n('D5'),'m',42],[4,R,'h',15],0,
        [3,R,'k',55],[0,n('F#2'),'b',46],[1,n('F#5'),'m',45],[4,R,'h',18],
        [5,R,'n',38],[1,n('E5'),'m',38],[1,n('C#5'),'m',40],[4,R,'h',15]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 15. Core — Hardware Manager
  //     E minor, 88 BPM. Industrial, heavy. Power-plant rumble with
  //     human melody. Signature: low E1 rumble + E-G-B rising 5th.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-core'] = { bpm:88, echo:[300,0.38,0.35,3000],
    inst: {
      m:I('saw',0.03,0.15,0.55,0.2),       // industrial melody
      s:I('str',0.5,0.4,0.5,0.7),           // heavy strings
      b:I('bas',0.02,0.2,0.5,0.15),         // rumbling bass
      k:I('kck',0.005,0.22,0,0.06,false),
      n:I('snr',0.005,0.15,0,0.05,false),
      h:I('pnoi',0.005,0.06,0,0.03,false)
    },
    pats: [
      // A: Power plant — heavy E minor, bass-driven rumble
      [32, [
        [3,R,'k',60],[0,n('E1'),'b',55],0,0,
        [5,R,'h',15],[0,n('E1'),'b',45],0,0,
        [4,R,'n',42],[0,n('B1'),'b',48],0,[5,R,'h',12],
        0,0,[0,n('E1'),'b',50],0,
        [3,R,'k',55],[0,n('E1'),'b',55],0,0,
        [5,R,'h',15],[0,n('G1'),'b',48],0,0,
        [4,R,'n',42],[0,n('A1'),'b',48],0,[5,R,'h',12],
        0,0,[0,n('B1'),'b',50],0
      ]],
      // B: Human melody — saw lead finds warmth above the rumble
      [32, [
        [3,R,'k',60],[0,n('E1'),'b',55],[1,n('E4'),'m',38],0,
        [5,R,'h',12],0,[1,n('G4'),'m',36],0,
        [4,R,'n',42],[0,n('C2'),'b',48],[1,n('B4'),'m',42],[2,n('C3'),'s',22],
        0,0,[1,n('A4'),'m',35],0,
        [3,R,'k',55],[0,n('A1'),'b',52],[1,n('G4'),'m',38],[2,n('A3'),'s',22],
        [5,R,'h',12],0,[1,n('E4'),'m',35],0,
        [4,R,'n',42],[0,n('B1'),'b',50],[1,n('F#4'),'m',38],0,
        0,0,[1,n('E4'),'m',35],[5,R,'h',10]
      ]],
      // A': Resolve — ends on B (V) for loop
      [32, [
        [3,R,'k',62],[0,n('E1'),'b',55],[1,n('E5'),'m',42],[2,n('E3'),'s',25],
        0,[5,R,'h',12],[1,n('D5'),'m',38],0,
        [4,R,'n',45],[0,n('C2'),'b',50],[1,n('C5'),'m',40],[2,n('C3'),'s',22],
        0,0,[1,n('B4'),'m',38],0,
        [3,R,'k',58],[0,n('A1'),'b',52],[1,n('A4'),'m',36],[2,n('A3'),'s',22],
        [5,R,'h',12],0,[1,n('G4'),'m',35],0,
        [4,R,'n',45],[0,n('B1'),'b',52],[1,n('B4'),'m',42],0,
        0,0,[1,n('F#4'),'m',35],[5,R,'h',10]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 16. Warden — Ethics Officer
  //     F major, 78 BPM. Solemn, just. Organ-like sustained chords.
  //     Signature: F-A-C held chord then Bb-C "gavel" resolution.
  //     Judicial gravity.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-warden'] = { bpm:78, echo:[380,0.42,0.4,2600],
    inst: {
      m:I('str',0.6,0.5,0.6,1.0),          // organ-like strings
      p:I('pno',0.01,0.5,0.12,0.6,false),   // solemn piano
      f:I('sin',0.1,0.25,0.5,0.45),         // voice of justice
      b:I('tri',0.04,0.3,0.35,0.2),         // bass
      h:I('pnoi',0.005,0.06,0,0.03,false)
    },
    pats: [
      // A: Judicial weight — F major sustained chords, solemn gravity
      [32, [
        [0,n('F2'),'b',35],[1,n('F3'),'m',30],[2,n('A3'),'m',28],0,
        0,0,0,0,
        0,0,[3,n('C5'),'p',20],0,
        [0,n('C2'),'b',32],[1,n('C3'),'m',28],0,0,
        0,0,0,[4,R,'h',10],
        0,0,[3,n('E5'),'p',18],0,
        [0,n('Bb1'),'b',34],[1,n('Bb3'),'m',30],[2,n('D4'),'m',28],0,
        0,0,[3,n('F5'),'p',18],0
      ]],
      // B: Voice of justice — sine melody speaks, measured and solemn
      [32, [
        [0,n('F2'),'b',36],[1,n('F4'),'m',30],[3,n('F5'),'f',35],0,
        0,0,[3,n('G5'),'f',32],0,
        [0,n('Bb1'),'b',34],[1,n('Bb3'),'m',28],[3,n('A5'),'f',38],0,
        0,0,[3,n('G5'),'f',30],0,
        [0,n('C2'),'b',34],[1,n('C4'),'m',28],[3,n('F5'),'f',35],0,
        0,[2,n('C5'),'p',16],[3,n('E5'),'f',30],0,
        [0,n('F2'),'b',35],[1,n('F3'),'m',30],[3,n('F5'),'f',35],0,
        0,0,0,[4,R,'h',8]
      ]],
      // A': Gavel — Bb-C resolution, ends on C (V)
      [32, [
        [0,n('Bb1'),'b',36],[1,n('Bb3'),'m',32],[3,n('D5'),'f',35],0,
        0,0,[3,n('C5'),'f',30],0,
        [0,n('F2'),'b',34],[1,n('A3'),'m',28],[3,n('A5'),'f',38],0,
        0,[2,n('F5'),'p',16],[3,n('G5'),'f',32],0,
        [0,n('Bb1'),'b',34],[1,n('Bb3'),'m',30],[3,n('F5'),'f',35],0,
        0,0,[3,n('E5'),'f',30],0,
        [0,n('C2'),'b',36],[1,n('C4'),'m',32],[3,n('C5'),'f',35],0,
        0,0,[3,n('E5'),'f',30],[2,n('C5'),'p',14]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 17. Cache — Memory Manager
  //     Db major, 92 BPM. Nostalgic, dreamy. Music-box quality.
  //     Signature: Db-F-Ab-Bb "memory chime" arpeggio.
  //     Memory Theme — looking back with warmth.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-cache'] = { bpm:92, echo:[360,0.42,0.4,2800],
    inst: {
      p:I('pno',0.01,0.35,0.18,0.5,false), // music box piano
      s:I('str',0.7,0.4,0.5,0.9),           // nostalgic strings
      f:I('sin',0.08,0.2,0.45,0.4),         // gentle sine
      b:I('tri',0.03,0.2,0.35,0.15),        // soft bass
      c:I('pnoi',0.005,0.05,0,0.02,false)   // music box click
    },
    pats: [
      // A: Memory chime — Db major piano arpeggio, music box
      [32, [
        [0,n('Db2'),'b',30],[1,n('Db5'),'p',28],0,[1,n('F5'),'p',25],
        0,[1,n('Ab5'),'p',25],[4,R,'c',10],0,
        [0,n('Ab1'),'b',28],[1,n('C5'),'p',25],0,[1,n('Eb5'),'p',22],
        0,[1,n('Ab5'),'p',22],0,0,
        [0,n('Gb1'),'b',30],[1,n('Gb4'),'p',28],0,[1,n('Bb4'),'p',25],
        0,[1,n('Db5'),'p',25],[4,R,'c',10],0,
        [0,n('Ab1'),'b',28],[1,n('Eb5'),'p',25],0,[1,n('Ab5'),'p',22],
        0,0,0,[4,R,'c',8]
      ]],
      // B: Remembering — sine melody + strings, warm nostalgia
      [32, [
        [0,n('Db2'),'b',32],[2,n('Db3'),'s',22],[3,n('F5'),'f',35],0,
        0,[1,n('Ab4'),'p',18],0,[3,n('Eb5'),'f',30],
        [0,n('Gb1'),'b',30],[2,n('Gb3'),'s',22],[3,n('Db5'),'f',32],0,
        0,[1,n('Bb4'),'p',18],[3,n('Bb4'),'f',28],0,
        [0,n('Ab1'),'b',32],[2,n('Ab3'),'s',22],[3,n('C5'),'f',32],0,
        0,[1,n('Eb4'),'p',16],0,[3,n('Db5'),'f',30],
        [0,n('Ab1'),'b',30],[2,n('Eb3'),'s',20],[3,n('Eb5'),'f',35],0,
        0,0,[3,n('F5'),'f',32],[4,R,'c',8]
      ]],
      // A': Fading memory — resolves on Ab (V) for loop
      [32, [
        [0,n('Db2'),'b',32],[2,n('Db4'),'s',25],[3,n('Ab5'),'f',38],0,
        0,[1,n('F4'),'p',18],[3,n('Gb5'),'f',30],0,
        [0,n('Bb1'),'b',30],[2,n('Bb3'),'s',22],[3,n('F5'),'f',35],0,
        0,[1,n('Db4'),'p',16],[3,n('Eb5'),'f',28],0,
        [0,n('Gb1'),'b',30],[2,n('Gb3'),'s',22],[3,n('Db5'),'f',32],0,
        0,0,[3,n('C5'),'f',28],0,
        [0,n('Ab1'),'b',32],[2,n('Ab3'),'s',22],[3,n('Ab4'),'f',30],0,
        0,0,[3,n('Eb5'),'f',28],[1,n('Ab4'),'p',15]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 18. Volt — Power Manager
  //     A major, 135 BPM. Electric, explosive. Lightning-strike accents.
  //     Signature: A-C#-E with sudden F# "lightning" accent.
  //     Boss battle energy.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-volt'] = { bpm:135, echo:[140,0.22,0.2,5000],
    inst: {
      m:I('sq12',0.01,0.06,0.65,0.08),     // buzzy electric lead
      a:I('sq25',0.01,0.05,0.5,0.06),       // lightning accent
      b:I('bas',0.01,0.12,0.5,0.08),        // driving bass
      k:I('kck',0.005,0.15,0,0.04,false),
      n:I('snr',0.005,0.1,0,0.04,false),
      h:I('hh',0.005,0.03,0,0.02,false)
    },
    pats: [
      // A: Charging up — driving A major, electric intensity
      [16, [
        [2,R,'k',72],[0,n('A2'),'b',52],[4,R,'h',25],[1,n('A4'),'m',42],
        [4,R,'h',20],[0,n('A2'),'b',42],[1,n('C#5'),'m',42],[4,R,'h',22],
        [3,R,'n',52],[0,n('E2'),'b',48],[4,R,'h',25],[1,n('E5'),'m',48],
        [2,R,'k',65],[0,n('F#2'),'b',45],[1,n('F#5'),'m',50],[4,R,'h',20]
      ]],
      // B: Full discharge — melody tears upward, lightning strikes
      [16, [
        [2,R,'k',75],[1,n('A5'),'m',52],[0,n('A2'),'b',55],[5,n('E5'),'a',28],
        [4,R,'h',20],[1,n('G#5'),'m',45],[5,n('C#5'),'a',25],0,
        [3,R,'n',55],[1,n('F#5'),'m',48],[0,n('D2'),'b',50],[4,R,'h',22],
        [2,R,'k',68],[1,n('E5'),'m',45],[5,n('A4'),'a',25],[4,R,'h',20]
      ]],
      // A': Power surge — ends on E (V) for loop
      [16, [
        [2,R,'k',75],[5,n('A3'),'a',28],[0,n('A2'),'b',55],[5,n('C#4'),'a',28],
        [4,R,'h',20],[5,n('E4'),'a',30],[1,n('A4'),'m',42],[5,n('A4'),'a',26],
        [3,R,'n',55],[5,n('E4'),'a',28],[0,n('E2'),'b',52],[5,n('C#4'),'a',28],
        [2,R,'k',68],[5,n('B3'),'a',28],[4,R,'h',20],[5,n('E4'),'a',30]
      ]]
    ], seq:[0,0,1,1,2,2,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 19. Promo — Marketing Head
  //     Bb major, 125 BPM. Catchy, commercial. The jingle writer.
  //     Signature: Bb-D-F-G "jingle hook" — instantly catchy.
  //     Ear-candy, designed to stick.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-promo'] = { bpm:125, echo:[180,0.25,0.22,4800],
    inst: {
      m:I('saw',0.01,0.08,0.65,0.12),      // bold jingle lead
      a:I('sq50',0.01,0.06,0.55,0.08),      // harmony
      s:I('str',0.25,0.2,0.5,0.3),          // power strings
      b:I('bas',0.01,0.12,0.5,0.08),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      n:I('snr',0.005,0.1,0,0.04,false)
    },
    pats: [
      // A: The jingle — Bb D F G hook, bright and catchy
      [16, [
        [3,R,'k',68],[0,n('Bb2'),'b',50],[1,n('Bb4'),'m',45],[5,n('F4'),'a',25],
        0,[1,n('D5'),'m',42],0,[1,n('F5'),'m',48],
        [4,R,'n',50],[0,n('Eb2'),'b',45],[1,n('G5'),'m',50],[5,n('Bb4'),'a',25],
        [3,R,'k',60],0,[1,n('F5'),'m',42],[1,n('D5'),'m',38]
      ]],
      // B: Hype build — ascending energy, bVI-bVII-I cadence
      [16, [
        [3,R,'k',72],[1,n('Bb5'),'m',52],[0,n('Gb2'),'b',50],[2,n('Gb3'),'s',25],
        0,[1,n('A5'),'m',45],[5,n('Eb5'),'a',25],0,
        [4,R,'n',55],[1,n('Ab5'),'m',48],[0,n('Ab2'),'b',48],[2,n('Ab3'),'s',25],
        [3,R,'k',65],[1,n('Bb5'),'m',52],[5,n('F5'),'a',28],[1,n('D5'),'m',42]
      ]],
      // A': Full jingle — ends on F (V) for loop
      [16, [
        [3,R,'k',72],[1,n('Bb4'),'m',48],[0,n('Bb2'),'b',52],[2,n('D4'),'s',25],
        [5,n('F4'),'a',25],[1,n('D5'),'m',45],0,[1,n('F5'),'m',48],
        [4,R,'n',55],[1,n('Eb5'),'m',45],[0,n('F2'),'b',50],[2,n('A3'),'s',22],
        [3,R,'k',65],[1,n('D5'),'m',42],[1,n('F4'),'m',40],[5,n('C5'),'a',25]
      ]]
    ], seq:[0,0,1,1,2,2,0,1] };

  // ═══════════════════════════════════════════════════════════════════
  // 20. Arc — Story Director
  //     C minor, 88 BPM. Epic narrative. Building dramatic arcs.
  //     Signature: C-Eb-G-Ab "dramatic rise" then resolving descent.
  //     Opera-scale emotion. FF6 opera scene.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-arc'] = { bpm:88, echo:[350,0.4,0.38,3000],
    inst: {
      m:I('str',0.5,0.4,0.6,0.9),          // dramatic strings lead
      p:I('pno',0.01,0.45,0.15,0.6,false),  // piano punctuation
      f:I('sin',0.08,0.2,0.5,0.4),          // voice / flute
      b:I('bas',0.02,0.2,0.4,0.15),         // bass
      h:I('pnoi',0.005,0.06,0,0.03,false)
    },
    pats: [
      // A: Prologue — C minor, strings set the dramatic stage
      [32, [
        [0,n('C2'),'b',38],[1,n('C4'),'m',32],0,0,
        0,0,[2,n('Eb5'),'p',22],0,
        [0,n('G1'),'b',35],[1,n('G3'),'m',28],0,0,
        0,0,0,[4,R,'h',10],
        [0,n('Ab1'),'b',36],[1,n('Ab3'),'m',30],0,0,
        0,0,[2,n('C5'),'p',20],0,
        [0,n('Bb1'),'b',35],[1,n('Bb3'),'m',30],0,0,
        0,0,[2,n('D5'),'p',18],[4,R,'h',8]
      ]],
      // B: Climax — melody soars with operatic sine, full drama
      [32, [
        [0,n('C2'),'b',40],[1,n('C4'),'m',35],[3,n('C5'),'f',35],0,
        0,0,[3,n('Eb5'),'f',38],0,
        [0,n('Ab1'),'b',38],[1,n('Ab3'),'m',30],[3,n('G5'),'f',42],0,
        0,[2,n('Eb5'),'p',18],[3,n('Ab5'),'f',45],0,
        [0,n('Bb1'),'b',38],[1,n('Bb3'),'m',32],[3,n('G5'),'f',40],0,
        0,0,[3,n('F5'),'f',35],0,
        [0,n('G1'),'b',40],[1,n('G3'),'m',32],[3,n('Eb5'),'f',38],0,
        0,0,[3,n('D5'),'f',35],[4,R,'h',8]
      ]],
      // A': Denouement — resolves on G (V) for loop
      [32, [
        [0,n('C2'),'b',38],[1,n('C4'),'m',32],[3,n('Eb5'),'f',35],0,
        0,0,[3,n('D5'),'f',30],0,
        [0,n('F2'),'b',36],[1,n('F3'),'m',28],[3,n('C5'),'f',32],0,
        0,[2,n('Ab4'),'p',16],[3,n('Bb4'),'f',28],0,
        [0,n('Ab1'),'b',36],[1,n('Ab3'),'m',30],[3,n('Ab4'),'f',30],0,
        0,0,[3,n('G4'),'f',32],0,
        [0,n('G1'),'b',38],[1,n('G3'),'m',32],[3,n('G4'),'f',35],0,
        0,0,[3,n('D5'),'f',30],[2,n('G4'),'p',14]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 21. Loop — Automation Engineer
  //     E major, 108 BPM. Perfectly cycling. Minimalist Steve Reich
  //     influence. Signature: E-G#-B-C# phase-shifted loop.
  //     The loop IS the music.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-loop'] = { bpm:108, echo:[250,0.3,0.3,4000],
    inst: {
      m:I('sq50',0.01,0.08,0.6,0.1),       // main loop voice
      a:I('sq25',0.01,0.06,0.5,0.08),       // phase-shifted voice
      b:I('tri',0.01,0.15,0.45,0.1),        // bass loop
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false),
      s:I('str',0.4,0.3,0.45,0.5)           // sustain pad
    },
    pats: [
      // A: The cycle — repeating E major pattern, hypnotic
      [16, [
        [3,R,'k',55],[1,n('E4'),'m',38],[0,n('E2'),'b',42],[4,R,'h',18],
        [5,n('G#3'),'a',25],[1,n('G#4'),'m',36],[4,R,'h',15],[5,n('B3'),'a',25],
        [3,R,'k',50],[1,n('B4'),'m',40],[0,n('B1'),'b',38],[4,R,'h',18],
        [5,n('C#4'),'a',25],[1,n('E4'),'m',38],[4,R,'h',15],[5,n('G#3'),'a',22]
      ]],
      // B: Phase shift — same notes, offset timing, strings enter
      [16, [
        [3,R,'k',55],[5,n('B3'),'a',28],[0,n('E2'),'b',42],[1,n('E5'),'m',42],
        [4,R,'h',15],[1,n('C#5'),'m',38],[5,n('E4'),'a',25],[2,n('E3'),'s',20],
        [3,R,'k',50],[5,n('G#3'),'a',25],[0,n('C#2'),'b',40],[1,n('B4'),'m',40],
        [4,R,'h',15],[1,n('G#4'),'m',36],[5,n('C#4'),'a',25],[2,n('C#3'),'s',18]
      ]],
      // A': Return — original loop, ends on B (V) for cycle
      [16, [
        [3,R,'k',55],[1,n('E4'),'m',38],[0,n('E2'),'b',42],[5,n('G#3'),'a',25],
        [4,R,'h',18],[1,n('G#4'),'m',36],[5,n('B3'),'a',25],0,
        [3,R,'k',50],[1,n('B4'),'m',42],[0,n('B1'),'b',40],[5,n('E3'),'a',25],
        [4,R,'h',18],[1,n('G#4'),'m',36],[5,n('B3'),'a',25],[1,n('F#4'),'m',35]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 22. Nexus — Connections / Networking
  //     F# major, 95 BPM. Interwoven melodies. Counterpoint.
  //     Signature: two voices in canon — F#-A#-C# answered by
  //     C#-F#-A# (inversion). Network topology as music.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-nexus'] = { bpm:95, echo:[300,0.35,0.32,3500],
    inst: {
      v1:I('sin',0.05,0.18,0.55,0.3),       // voice 1 — soprano
      v2:I('str',0.4,0.3,0.5,0.6),          // voice 2 — alto strings
      p:I('pno',0.01,0.35,0.18,0.45,false),  // piano
      b:I('tri',0.02,0.2,0.4,0.15),         // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('pnoi',0.005,0.05,0,0.02,false)
    },
    pats: [
      // A: First connection — voice 1 states theme, piano supports
      [32, [
        [0,n('F#2'),'b',35],[3,n('F#4'),'p',25],0,[3,n('A#4'),'p',22],
        0,[3,n('C#5'),'p',22],[5,R,'h',10],0,
        [0,n('C#2'),'b',32],[3,n('C#4'),'p',25],0,[3,n('F#4'),'p',22],
        0,[3,n('A#4'),'p',22],0,0,
        [0,n('D#2'),'b',34],[1,n('D#5'),'v1',30],0,[3,n('F#4'),'p',20],
        0,[1,n('C#5'),'v1',28],[5,R,'h',10],0,
        [0,n('C#2'),'b',32],[1,n('A#4'),'v1',28],0,[3,n('C#5'),'p',20],
        0,0,[1,n('F#4'),'v1',25],[5,R,'h',8]
      ]],
      // B: Counterpoint — two voices weave, canon-like
      [32, [
        [0,n('F#2'),'b',36],[1,n('F#5'),'v1',35],[2,n('C#4'),'v2',25],0,
        0,[3,n('A#4'),'p',16],[1,n('E#5'),'v1',30],[2,n('A#3'),'v2',22],
        [4,R,'k',35],[0,n('D#2'),'b',32],[1,n('D#5'),'v1',35],[2,n('F#3'),'v2',22],
        0,0,[1,n('C#5'),'v1',28],[2,n('D#4'),'v2',22],
        [0,n('B1'),'b',34],[1,n('B4'),'v1',32],[2,n('F#3'),'v2',25],0,
        0,[3,n('D#4'),'p',16],[1,n('A#4'),'v1',30],[2,n('D#4'),'v2',22],
        [4,R,'k',35],[0,n('C#2'),'b',34],[1,n('C#5'),'v1',32],[2,n('C#4'),'v2',22],
        0,0,[1,n('F#4'),'v1',28],[5,R,'h',8]
      ]],
      // A': Network resolves — ends on C# (V) for loop
      [32, [
        [0,n('F#2'),'b',36],[1,n('C#5'),'v1',32],[2,n('A#3'),'v2',25],0,
        0,[3,n('F#4'),'p',16],[1,n('D#5'),'v1',35],0,
        [4,R,'k',38],[0,n('D#2'),'b',34],[1,n('F#5'),'v1',38],[2,n('B3'),'v2',22],
        0,0,[1,n('E#5'),'v1',32],[2,n('G#3'),'v2',22],
        [0,n('B1'),'b',34],[1,n('D#5'),'v1',32],[2,n('F#3'),'v2',25],0,
        0,[3,n('B4'),'p',16],[1,n('C#5'),'v1',30],[2,n('E#4'),'v2',22],
        [4,R,'k',35],[0,n('C#2'),'b',36],[1,n('C#5'),'v1',35],[2,n('C#4'),'v2',25],
        0,0,[1,n('G#4'),'v1',28],[5,R,'h',8]
      ]]
    ], seq:[0,0,1,1,2,2,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 23. Forge — Creator / Site Engineer
  //     D minor, 118 BPM. Hammer-strike rhythm. Building energy.
  //     Signature: D-A-D octave "hammer" then F-G approach from below.
  //     Smithy/workshop — Cid's Theme meets industrial.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-forge'] = { bpm:118, echo:[200,0.28,0.25,4200],
    inst: {
      m:I('saw',0.02,0.1,0.6,0.15),        // industrial saw melody
      s:I('str',0.3,0.25,0.5,0.4),          // support strings
      b:I('bas',0.01,0.15,0.5,0.1),         // heavy bass
      k:I('kck',0.005,0.2,0,0.05,false),
      n:I('snr',0.005,0.12,0,0.05,false),
      h:I('hh',0.005,0.04,0,0.02,false)
    },
    pats: [
      // A: Hammer strike — D minor, heavy downbeats like anvil hits
      [16, [
        [3,R,'k',65],[0,n('D2'),'b',55],[1,n('D4'),'m',42],[4,R,'h',20],
        [5,R,'n',40],0,[1,n('A4'),'m',40],[4,R,'h',18],
        [3,R,'k',60],[0,n('A2'),'b',48],[1,n('D5'),'m',48],[4,R,'h',20],
        [5,R,'n',40],[0,n('D2'),'b',45],[1,n('C5'),'m',38],[4,R,'h',18]
      ]],
      // B: Forging — melody builds, approach tones F-G-A
      [16, [
        [3,R,'k',68],[1,n('F4'),'m',42],[0,n('Bb1'),'b',50],[2,n('Bb3'),'s',22],
        0,[1,n('G4'),'m',40],[4,R,'h',18],0,
        [3,R,'k',62],[1,n('A4'),'m',45],[0,n('C2'),'b',48],[2,n('C4'),'s',22],
        [5,R,'n',45],[1,n('Bb4'),'m',42],[1,n('A4'),'m',40],[4,R,'h',18]
      ]],
      // A': Structure complete — ends on A (V) for loop
      [16, [
        [3,R,'k',68],[0,n('D2'),'b',55],[1,n('D5'),'m',48],[2,n('D3'),'s',25],
        0,[1,n('C5'),'m',42],[4,R,'h',18],0,
        [3,R,'k',62],[0,n('A2'),'b',50],[1,n('A4'),'m',44],[2,n('E3'),'s',22],
        [5,R,'n',45],[1,n('G4'),'m',38],[1,n('A4'),'m',42],[4,R,'h',18]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 24. Beacon — Outreach
  //     G major, 105 BPM. Hopeful, reaching out. Ascending open
  //     intervals. Signature: G-D-G octave "lighthouse beam".
  //     Warmth and invitation.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-beacon'] = { bpm:105, echo:[280,0.35,0.32,3800],
    inst: {
      m:I('sin',0.04,0.18,0.55,0.3),       // warm sine melody
      s:I('str',0.5,0.35,0.5,0.6),          // hopeful strings
      p:I('pno',0.01,0.35,0.18,0.4,false),  // piano
      b:I('tri',0.02,0.18,0.4,0.12),        // bass
      h:I('hh',0.005,0.05,0,0.02,false)
    },
    pats: [
      // A: Lighthouse — open G major intervals, reaching outward
      [16, [
        [0,n('G2'),'b',38],[1,n('G4'),'m',35],[2,n('G3'),'s',22],0,
        0,[1,n('D5'),'m',38],[4,R,'h',15],0,
        [0,n('C3'),'b',36],[1,n('G5'),'m',42],[2,n('E3'),'s',20],0,
        0,[1,n('E5'),'m',35],[4,R,'h',12],[3,n('G4'),'p',18]
      ]],
      // B: Signal — melody reaches further, open 5ths and octaves
      [16, [
        [0,n('C3'),'b',38],[1,n('E5'),'m',40],[2,n('C4'),'s',22],0,
        0,[1,n('D5'),'m',35],[3,n('C5'),'p',18],0,
        [0,n('D3'),'b',36],[1,n('B4'),'m',38],[2,n('D4'),'s',22],0,
        0,[1,n('A4'),'m',35],[1,n('G4'),'m',32],[4,R,'h',12]
      ]],
      // A': Warm return — ends on D (V) for loop
      [16, [
        [0,n('G2'),'b',40],[1,n('G5'),'m',42],[2,n('B3'),'s',25],0,
        [3,n('D5'),'p',18],[1,n('F#5'),'m',38],[4,R,'h',15],0,
        [0,n('D3'),'b',38],[1,n('D5'),'m',40],[2,n('F#3'),'s',22],0,
        0,[1,n('B4'),'m',35],[1,n('D5'),'m',38],[3,n('A4'),'p',16]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

  // ═══════════════════════════════════════════════════════════════════
  // 25. Shard — Data Analyst
  //     Bb minor, 98 BPM. Crystalline, fragmented. Glitchy beauty.
  //     Signature: Bb-Db staccato "crystal fracture" then F-Gb chromatic.
  //     Data-as-music — fragmented beauty from broken pieces.
  // ═══════════════════════════════════════════════════════════════════
  L['agent-shard'] = { bpm:98, echo:[280,0.35,0.32,3500],
    inst: {
      m:I('sq50',0.01,0.08,0.55,0.1),      // crystalline lead
      a:I('sq25',0.01,0.05,0.45,0.06),      // glitch fragments
      p:I('pno',0.01,0.3,0.15,0.4,false),   // piano shards
      b:I('tri',0.02,0.18,0.4,0.12),        // bass
      k:I('kck',0.005,0.18,0,0.05,false),
      h:I('pnoi',0.005,0.04,0,0.02,false)   // data noise
    },
    pats: [
      // A: Crystal fracture — staccato Bb minor, fragmented beauty
      [16, [
        [3,R,'k',52],[1,n('Bb4'),'m',38],[0,n('Bb1'),'b',42],[4,R,'h',18],
        [5,n('F4'),'a',22],[1,n('Db5'),'m',36],0,[4,R,'h',15],
        [3,R,'k',48],[1,n('F5'),'m',42],[0,n('Db2'),'b',40],[5,n('Bb3'),'a',22],
        [4,R,'h',18],[1,n('Gb5'),'m',35],[2,n('Db5'),'p',18],[5,n('F3'),'a',20]
      ]],
      // B: Data stream — arpeggiated fragments, chromatic passing tones
      [16, [
        [3,R,'k',55],[5,n('Bb3'),'a',25],[0,n('Bb1'),'b',44],[5,n('Db4'),'a',25],
        [4,R,'h',15],[5,n('F4'),'a',28],[1,n('Bb5'),'m',42],[5,n('Db5'),'a',22],
        [3,R,'k',50],[5,n('F4'),'a',25],[0,n('Gb1'),'b',40],[5,n('Bb3'),'a',22],
        [4,R,'h',15],[1,n('Ab5'),'m',38],[5,n('Gb4'),'a',22],[5,n('F4'),'a',25]
      ]],
      // A': Reassembled — fragments coalesce, ends on F (V)
      [16, [
        [3,R,'k',52],[1,n('Bb4'),'m',40],[0,n('Bb1'),'b',44],[2,n('Db5'),'p',20],
        [5,n('F4'),'a',22],[1,n('Db5'),'m',38],[4,R,'h',15],0,
        [3,R,'k',48],[1,n('Eb5'),'m',42],[0,n('F2'),'b',42],[2,n('Ab4'),'p',18],
        [4,R,'h',18],[1,n('Db5'),'m',36],[1,n('F4'),'m',38],[5,n('C4'),'a',22]
      ]]
    ], seq:[0,0,1,1,2,0,1,2] };

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
