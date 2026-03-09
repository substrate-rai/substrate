/**
 * NovelEngine — A Ren'Py-inspired visual novel engine in pure JavaScript.
 * Built for Substrate's games. Static HTML, no dependencies, under 20KB.
 *
 * Usage:
 *   var vn = new NovelEngine(document.getElementById('game-container'));
 *   vn.defineCharacter('claude', { name: 'Claude', color: '#00ffaa' });
 *   vn.loadScript(script);
 *   vn.start();
 */

(function(root) {
'use strict';

// ============================================================
// BUILT-IN BACKGROUNDS (CSS/canvas drawn)
// ============================================================
var BACKGROUNDS = {
  'server-room': function(ctx, w, h, t) {
    ctx.fillStyle = '#0a0d14';
    ctx.fillRect(0, 0, w, h);
    // Rack lines
    ctx.strokeStyle = 'rgba(0,224,154,0.04)';
    ctx.lineWidth = 1;
    for (var x = 0; x < w; x += 40) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    // Blinking LEDs
    for (var i = 0; i < 30; i++) {
      var lx = ((i * 137) % w);
      var ly = ((i * 97) % h);
      var on = Math.sin(t * 2 + i * 1.7) > 0.3;
      if (on) {
        ctx.fillStyle = i % 3 === 0 ? 'rgba(0,255,100,0.4)' : i % 3 === 1 ? 'rgba(255,160,0,0.3)' : 'rgba(0,180,255,0.3)';
        ctx.fillRect(lx, ly, 3, 2);
      }
    }
    // Scanlines
    ctx.fillStyle = 'rgba(0,0,0,0.03)';
    for (var y = 0; y < h; y += 3) ctx.fillRect(0, y, w, 1);
  },
  'terminal': function(ctx, w, h, t) {
    ctx.fillStyle = 'rgba(8,13,20,0.92)';
    ctx.fillRect(0, 0, w, h);
    ctx.font = '10px monospace';
    var cols = Math.floor(w / 12);
    var chars = '01>_{}[];=+-*/<>&|~^%$#@!';
    for (var i = 0; i < cols; i++) {
      var ch = chars[Math.floor(Math.random() * chars.length)];
      var yy = ((t * 30 + i * 47) % (h + 100)) - 50;
      ctx.fillStyle = 'rgba(0,224,154,' + (0.05 + Math.random() * 0.12) + ')';
      ctx.fillText(ch, i * 12, yy);
      if (Math.random() < 0.03) {
        ctx.fillStyle = 'rgba(0,224,154,0.4)';
        ctx.fillText(ch, i * 12, yy);
      }
    }
    ctx.fillStyle = 'rgba(0,0,0,0.04)';
    for (var y = 0; y < h; y += 3) ctx.fillRect(0, y, w, 1);
  },
  'void': function(ctx, w, h, t) {
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, w, h);
    for (var i = 0; i < 40; i++) {
      var px = (Math.sin(t * 0.1 + i * 2.5) * 0.5 + 0.5) * w;
      var py = (Math.cos(t * 0.08 + i * 1.9) * 0.5 + 0.5) * h;
      var a = 0.03 + Math.sin(t * 0.5 + i) * 0.02;
      ctx.fillStyle = 'rgba(255,255,255,' + Math.max(0, a) + ')';
      ctx.beginPath();
      ctx.arc(px, py, 1 + Math.sin(t * 0.3 + i) * 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
  },
  'city': function(ctx, w, h, t) {
    // Sky
    var grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#05050f');
    grad.addColorStop(0.6, '#0a0818');
    grad.addColorStop(1, '#100820');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    // Stars
    for (var i = 0; i < 25; i++) {
      var sx = (i * 137.5) % w;
      var sy = (i * 73.7) % (h * 0.4);
      ctx.fillStyle = 'rgba(255,255,255,' + (0.1 + Math.sin(t * 0.8 + i) * 0.08) + ')';
      ctx.beginPath(); ctx.arc(sx, sy, 0.8, 0, Math.PI * 2); ctx.fill();
    }
    // Buildings silhouette
    var bh = h * 0.6;
    ctx.fillStyle = '#08080d';
    for (var b = 0; b < w; b += 30 + (b * 7 % 20)) {
      var bw = 15 + (b * 13 % 25);
      var bt = bh - 40 - (b * 17 % 120);
      ctx.fillRect(b, bt, bw, h - bt);
      // Neon windows
      for (var wy = bt + 5; wy < h - 10; wy += 8) {
        for (var wx = b + 3; wx < b + bw - 3; wx += 6) {
          if (Math.sin(wx * 3 + wy * 7 + t * 0.2) > 0.4) {
            var nc = ['rgba(255,0,100,0.3)', 'rgba(0,200,255,0.3)', 'rgba(255,200,0,0.2)', 'rgba(150,0,255,0.25)'];
            ctx.fillStyle = nc[(wx + wy) % nc.length];
            ctx.fillRect(wx, wy, 3, 4);
          }
        }
      }
    }
    // Neon signs glow
    var ng = ctx.createRadialGradient(w * 0.3, bh - 60, 0, w * 0.3, bh - 60, 60);
    ng.addColorStop(0, 'rgba(255,0,100,' + (0.06 + Math.sin(t) * 0.03) + ')');
    ng.addColorStop(1, 'rgba(255,0,100,0)');
    ctx.fillStyle = ng;
    ctx.fillRect(0, 0, w, h);
  },
  'nature': function(ctx, w, h, t) {
    var grad = ctx.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#0a1a0d');
    grad.addColorStop(0.5, '#0d200f');
    grad.addColorStop(1, '#081008');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, w, h);
    // Ground
    ctx.fillStyle = '#0a150a';
    ctx.fillRect(0, h * 0.75, w, h * 0.25);
    // Procedural trees
    for (var i = 0; i < 8; i++) {
      var tx = (i * 137 + 50) % w;
      var ty = h * 0.75;
      var th = 40 + (i * 23 % 40);
      // Trunk
      ctx.fillStyle = 'rgba(60,40,20,0.4)';
      ctx.fillRect(tx - 2, ty - th, 4, th);
      // Canopy
      var sway = Math.sin(t * 0.3 + i) * 3;
      ctx.fillStyle = 'rgba(20,80,30,' + (0.25 + Math.sin(t * 0.2 + i) * 0.05) + ')';
      ctx.beginPath();
      ctx.arc(tx + sway, ty - th - 10, 18 + (i % 3) * 5, 0, Math.PI * 2);
      ctx.fill();
    }
    // Fireflies
    for (var f = 0; f < 10; f++) {
      var fx = (Math.sin(t * 0.15 + f * 3.1) * 0.4 + 0.5) * w;
      var fy = (Math.cos(t * 0.12 + f * 2.7) * 0.3 + 0.4) * h;
      var fa = Math.sin(t * 1.5 + f * 2) > 0.5 ? 0.4 : 0.05;
      ctx.fillStyle = 'rgba(200,255,100,' + fa + ')';
      ctx.beginPath(); ctx.arc(fx, fy, 2, 0, Math.PI * 2); ctx.fill();
    }
  },
  'office': function(ctx, w, h, t) {
    ctx.fillStyle = '#12100e';
    ctx.fillRect(0, 0, w, h);
    // Window with light
    var wl = w * 0.6, wt = h * 0.1, ww = w * 0.3, wh = h * 0.4;
    var wg = ctx.createRadialGradient(wl + ww / 2, wt + wh / 2, 0, wl + ww / 2, wt + wh / 2, ww);
    wg.addColorStop(0, 'rgba(255,220,150,0.08)');
    wg.addColorStop(1, 'rgba(255,220,150,0)');
    ctx.fillStyle = wg;
    ctx.fillRect(0, 0, w, h);
    // Window frame
    ctx.strokeStyle = 'rgba(255,220,150,0.1)';
    ctx.lineWidth = 2;
    ctx.strokeRect(wl, wt, ww, wh);
    ctx.beginPath(); ctx.moveTo(wl + ww / 2, wt); ctx.lineTo(wl + ww / 2, wt + wh); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(wl, wt + wh / 2); ctx.lineTo(wl + ww, wt + wh / 2); ctx.stroke();
    // Dust motes
    for (var d = 0; d < 8; d++) {
      var dx = wl + (Math.sin(t * 0.1 + d * 2) * 0.5 + 0.5) * ww;
      var dy = wt + (Math.cos(t * 0.08 + d * 1.5) * 0.5 + 0.5) * wh;
      ctx.fillStyle = 'rgba(255,220,150,' + (0.05 + Math.sin(t * 0.5 + d) * 0.03) + ')';
      ctx.beginPath(); ctx.arc(dx, dy, 1, 0, Math.PI * 2); ctx.fill();
    }
  },
  'space': function(ctx, w, h, t) {
    ctx.fillStyle = '#020208';
    ctx.fillRect(0, 0, w, h);
    // Starfield with parallax layers
    for (var layer = 0; layer < 3; layer++) {
      var count = 20 + layer * 15;
      var speed = (layer + 1) * 0.02;
      var size = 0.5 + layer * 0.3;
      var bright = 0.15 + layer * 0.1;
      for (var i = 0; i < count; i++) {
        var sx = ((i * 137.5 + layer * 50) % w);
        var sy = ((i * 97.3 + layer * 30 + t * speed * 10) % h);
        var a = bright + Math.sin(t * (0.5 + layer * 0.3) + i * 1.3) * 0.08;
        ctx.fillStyle = 'rgba(255,255,255,' + Math.max(0.02, a) + ')';
        ctx.beginPath(); ctx.arc(sx, sy, size, 0, Math.PI * 2); ctx.fill();
      }
    }
    // Nebula
    var ng = ctx.createRadialGradient(w * 0.7, h * 0.3, 0, w * 0.7, h * 0.3, w * 0.3);
    ng.addColorStop(0, 'rgba(80,20,120,' + (0.04 + Math.sin(t * 0.1) * 0.02) + ')');
    ng.addColorStop(1, 'rgba(80,20,120,0)');
    ctx.fillStyle = ng;
    ctx.fillRect(0, 0, w, h);
  }
};

// Aliases for back-compat
BACKGROUNDS['black'] = function(ctx, w, h) { ctx.fillStyle = '#08080d'; ctx.fillRect(0, 0, w, h); };
BACKGROUNDS['boot'] = function(ctx, w, h, t) {
  ctx.fillStyle = '#050a05';
  ctx.fillRect(0, 0, w, h);
  ctx.font = '11px monospace';
  ctx.fillStyle = 'rgba(0,180,100,0.3)';
  var line = '> initializing...';
  var sl = Math.floor(t * 3) % (line.length + 20);
  ctx.fillText(line.substring(0, Math.min(sl, line.length)), 20, h * 0.4);
  if (sl > line.length + 5) ctx.fillText('> ready', 20, h * 0.4 + 16);
};
BACKGROUNDS['gpu'] = function(ctx, w, h, t) {
  ctx.fillStyle = '#0d0808';
  ctx.fillRect(0, 0, w, h);
  for (var i = 0; i < 8; i++) {
    var px = w * 0.2 + Math.sin(t * 0.5 + i) * w * 0.3;
    var py = h * 0.3 + Math.cos(t * 0.3 + i * 0.7) * h * 0.2;
    var g = ctx.createRadialGradient(px, py, 0, px, py, 80 + Math.sin(t + i) * 20);
    g.addColorStop(0, 'rgba(228,119,255,0.06)');
    g.addColorStop(1, 'rgba(228,119,255,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
  }
  ctx.strokeStyle = 'rgba(228,119,255,0.04)';
  ctx.lineWidth = 0.5;
  for (var x = 0; x < w; x += 20) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
  for (var y = 0; y < h; y += 20) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
};
BACKGROUNDS['shelf'] = function(ctx, w, h, t) {
  ctx.fillStyle = '#0d0d14';
  ctx.fillRect(0, 0, w, h);
  for (var i = 0; i < 15; i++) {
    var px = (Math.sin(t * 0.2 + i * 2.3) * 0.5 + 0.5) * w;
    var py = (Math.cos(t * 0.15 + i * 1.7) * 0.5 + 0.5) * h;
    ctx.fillStyle = 'rgba(100,120,180,' + (0.03 + Math.sin(t + i) * 0.02) + ')';
    ctx.beginPath(); ctx.arc(px, py, 2 + Math.sin(t * 0.5 + i) * 1, 0, Math.PI * 2); ctx.fill();
  }
};
BACKGROUNDS['dawn'] = function(ctx, w, h, t) {
  var g = ctx.createLinearGradient(0, 0, 0, h);
  var hue = 270 + Math.sin(t * 0.1) * 15;
  g.addColorStop(0, 'hsl(' + hue + ',30%,8%)');
  g.addColorStop(0.5, 'hsl(' + (hue - 20) + ',25%,7%)');
  g.addColorStop(1, 'hsl(' + (hue - 40) + ',20%,5%)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, w, h);
  for (var i = 0; i < 20; i++) {
    var sx = (i * 137.5) % w, sy = (i * 73.7) % (h * 0.6);
    ctx.fillStyle = 'rgba(255,255,255,' + (0.1 + Math.sin(t * 0.8 + i * 1.5) * 0.08) + ')';
    ctx.beginPath(); ctx.arc(sx, sy, 1, 0, Math.PI * 2); ctx.fill();
  }
};
BACKGROUNDS['crisis'] = function(ctx, w, h, t) {
  ctx.fillStyle = '#0d0505';
  ctx.fillRect(0, 0, w, h);
  var p = Math.sin(t * 2) * 0.5 + 0.5;
  ctx.fillStyle = 'rgba(255,30,30,' + (p * 0.08) + ')';
  ctx.fillRect(0, 0, w, h);
  ctx.strokeStyle = 'rgba(255,50,50,0.06)';
  ctx.lineWidth = 2;
  for (var x = -h; x < w + h; x += 30) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x + h, h); ctx.stroke();
  }
};

// ============================================================
// VISUAL EFFECTS
// ============================================================
var FX = {
  shake: function(container, intensity, duration) {
    var str = intensity || 5;
    var dur = duration || 400;
    var start = Date.now();
    var orig = container.style.transform;
    function step() {
      var elapsed = Date.now() - start;
      if (elapsed > dur) { container.style.transform = orig || ''; return; }
      var decay = 1 - elapsed / dur;
      var dx = (Math.random() - 0.5) * str * 2 * decay;
      var dy = (Math.random() - 0.5) * str * 2 * decay;
      container.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
      requestAnimationFrame(step);
    }
    step();
  },
  flash: function(container, color, duration) {
    var el = document.createElement('div');
    el.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:100;pointer-events:none;background:' + (color || '#fff') + ';opacity:0.7;transition:opacity ' + ((duration || 300) / 1000) + 's ease;';
    container.appendChild(el);
    requestAnimationFrame(function() { el.style.opacity = '0'; });
    setTimeout(function() { if (el.parentNode) el.parentNode.removeChild(el); }, (duration || 300) + 50);
  },
  particles: function(ctx, w, h, t, type) {
    var count = 60;
    for (var i = 0; i < count; i++) {
      var seed = i * 137.508;
      if (type === 'rain') {
        var rx = (seed % w);
        var ry = ((t * 200 + seed * 3) % (h + 20)) - 10;
        ctx.strokeStyle = 'rgba(150,180,220,0.15)';
        ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(rx, ry); ctx.lineTo(rx - 1, ry + 8); ctx.stroke();
      } else if (type === 'snow') {
        var sx = (seed % w) + Math.sin(t * 0.5 + i) * 20;
        var sy = ((t * 20 + seed * 2) % (h + 10)) - 5;
        ctx.fillStyle = 'rgba(220,230,255,' + (0.1 + Math.sin(i) * 0.05) + ')';
        ctx.beginPath(); ctx.arc(sx, sy, 1.5 + (i % 3) * 0.5, 0, Math.PI * 2); ctx.fill();
      }
    }
  },
  crt: function(ctx, w, h) {
    ctx.fillStyle = 'rgba(0,0,0,0.03)';
    for (var y = 0; y < h; y += 2) ctx.fillRect(0, y, w, 1);
    // Corner vignette
    var vg = ctx.createRadialGradient(w / 2, h / 2, w * 0.3, w / 2, h / 2, w * 0.7);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,0.3)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, w, h);
  },
  vignette: function(ctx, w, h) {
    var vg = ctx.createRadialGradient(w / 2, h / 2, w * 0.25, w / 2, h / 2, w * 0.7);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(0,0,0,0.5)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, w, h);
  }
};

// ============================================================
// TRANSITIONS
// ============================================================
function doTransition(container, type, duration, cb) {
  var dur = duration || 600;
  var overlay = document.createElement('div');
  overlay.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:90;pointer-events:none;';

  if (type === 'fade') {
    overlay.style.background = '#000';
    overlay.style.opacity = '0';
    overlay.style.transition = 'opacity ' + (dur / 2000) + 's ease';
    container.appendChild(overlay);
    requestAnimationFrame(function() { overlay.style.opacity = '1'; });
    setTimeout(function() {
      if (cb) cb();
      requestAnimationFrame(function() { overlay.style.opacity = '0'; });
      setTimeout(function() { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, dur / 2 + 50);
    }, dur / 2);
  } else if (type === 'dissolve') {
    overlay.style.background = '#000';
    overlay.style.opacity = '0';
    overlay.style.transition = 'opacity ' + (dur / 1000) + 's ease';
    container.appendChild(overlay);
    requestAnimationFrame(function() { overlay.style.opacity = '0.6'; });
    setTimeout(function() {
      if (cb) cb();
      requestAnimationFrame(function() { overlay.style.opacity = '0'; });
      setTimeout(function() { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, dur + 50);
    }, dur / 2);
  } else if (type === 'slide-left' || type === 'slide-right') {
    var dir = type === 'slide-left' ? '-100%' : '100%';
    overlay.style.background = '#000';
    overlay.style.transform = 'translateX(' + dir + ')';
    overlay.style.transition = 'transform ' + (dur / 2000) + 's ease';
    container.appendChild(overlay);
    requestAnimationFrame(function() { overlay.style.transform = 'translateX(0)'; });
    setTimeout(function() {
      if (cb) cb();
      overlay.style.transform = 'translateX(' + (type === 'slide-left' ? '100%' : '-100%') + ')';
      setTimeout(function() { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }, dur / 2 + 50);
    }, dur / 2);
  } else if (type === 'curtain') {
    var left = document.createElement('div');
    var right = document.createElement('div');
    var base = 'position:absolute;top:0;bottom:0;width:50%;z-index:90;pointer-events:none;background:#000;transition:transform ' + (dur / 2000) + 's ease;';
    left.style.cssText = base + 'left:0;transform:translateX(-100%);';
    right.style.cssText = base + 'right:0;transform:translateX(100%);';
    container.appendChild(left);
    container.appendChild(right);
    requestAnimationFrame(function() {
      left.style.transform = 'translateX(0)';
      right.style.transform = 'translateX(0)';
    });
    setTimeout(function() {
      if (cb) cb();
      left.style.transform = 'translateX(-100%)';
      right.style.transform = 'translateX(100%)';
      setTimeout(function() {
        if (left.parentNode) left.parentNode.removeChild(left);
        if (right.parentNode) right.parentNode.removeChild(right);
      }, dur / 2 + 50);
    }, dur / 2);
    if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
    return;
  } else {
    // No transition, immediate
    if (cb) cb();
    return;
  }
}

// ============================================================
// AUDIO — text blips and sound effects
// ============================================================
var Audio = {
  _ctx: null,
  _master: null,
  getCtx: function() {
    if (!this._ctx) {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)();
      this._master = this._ctx.createGain();
      this._master.gain.value = 0.3;
      this._master.connect(this._ctx.destination);
    }
    if (this._ctx.state === 'suspended') this._ctx.resume();
    return this._ctx;
  },
  blip: function(pitch) {
    try {
      var ctx = this.getCtx();
      var t = ctx.currentTime;
      var osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(pitch || 440, t);
      var g = ctx.createGain();
      g.gain.setValueAtTime(0.08, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
      osc.connect(g);
      g.connect(this._master);
      osc.start(t);
      osc.stop(t + 0.06);
    } catch (e) {}
  },
  sfx: function(type) {
    try {
      var ctx = this.getCtx();
      var t = ctx.currentTime;
      var osc = ctx.createOscillator();
      var g = ctx.createGain();
      osc.connect(g);
      g.connect(this._master);
      if (type === 'door') {
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(200, t);
        osc.frequency.linearRampToValueAtTime(80, t + 0.2);
        g.gain.setValueAtTime(0.15, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + 0.25);
        osc.start(t); osc.stop(t + 0.25);
      } else if (type === 'alert') {
        osc.type = 'square';
        osc.frequency.setValueAtTime(880, t);
        osc.frequency.setValueAtTime(660, t + 0.1);
        osc.frequency.setValueAtTime(880, t + 0.2);
        g.gain.setValueAtTime(0.1, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + 0.3);
        osc.start(t); osc.stop(t + 0.3);
      } else if (type === 'ambient') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(120, t);
        g.gain.setValueAtTime(0.03, t);
        g.gain.exponentialRampToValueAtTime(0.001, t + 2);
        osc.start(t); osc.stop(t + 2);
      }
    } catch (e) {}
  },
  setVolume: function(v) {
    if (this._master) this._master.gain.value = Math.max(0, Math.min(1, v));
  }
};

// ============================================================
// NOVEL ENGINE
// ============================================================
function NovelEngine(container, opts) {
  opts = opts || {};
  this.container = container;
  this.gameId = opts.gameId || 'novel_' + Math.random().toString(36).slice(2, 8);
  this.characters = {};
  this.script = [];
  this.labels = {};
  this.vars = {};
  this.state = {
    pc: 0,
    typing: false,
    typingTimer: null,
    currentText: '',
    charIndex: 0,
    started: false,
    ended: false,
    history: [],
    choiceHistory: [],
    visibleChars: {},
    currentBg: '',
    autoAdvance: false,
    skipMode: false
  };
  this.seenText = {};
  this.TYPE_SPEED = opts.typeSpeed || 25;
  this.SAVE_KEY = 'novel_save_' + this.gameId;
  this.backgrounds = {};
  this.effects = { particles: null, crt: false, vignette: false };
  this.onEnd = opts.onEnd || null;
  this.audioEnabled = opts.audio !== false;

  // Merge built-in backgrounds
  for (var k in BACKGROUNDS) this.backgrounds[k] = BACKGROUNDS[k];

  this._buildDOM();
  this._bindInput();
  this._animFrame = null;
  this._animStart = 0;
}

var P = NovelEngine.prototype;

// ============================================================
// DOM CONSTRUCTION
// ============================================================
P._buildDOM = function() {
  var c = this.container;
  c.style.position = 'relative';
  c.style.overflow = 'hidden';
  c.style.background = '#08080d';
  c.innerHTML = '';

  // Canvas for backgrounds
  this._canvas = document.createElement('canvas');
  this._canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;z-index:0;pointer-events:none;image-rendering:pixelated;';
  c.appendChild(this._canvas);
  this._ctx = this._canvas.getContext('2d');

  // Scene layer (CSS gradient fallback)
  this._sceneEl = document.createElement('div');
  this._sceneEl.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:1;transition:background 1s ease;';
  c.appendChild(this._sceneEl);

  // Characters layer
  this._charsEl = document.createElement('div');
  this._charsEl.style.cssText = 'position:absolute;bottom:200px;left:0;right:0;display:flex;justify-content:center;gap:40px;z-index:2;transition:opacity 0.5s ease;';
  c.appendChild(this._charsEl);

  // Chapter indicator
  this._chapterEl = document.createElement('div');
  this._chapterEl.style.cssText = 'position:absolute;top:16px;left:20px;font-family:monospace;font-size:0.65rem;color:rgba(255,255,255,0.2);z-index:5;letter-spacing:2px;text-transform:uppercase;';
  c.appendChild(this._chapterEl);

  // Save indicator
  this._saveInd = document.createElement('div');
  this._saveInd.style.cssText = 'position:absolute;top:16px;right:60px;font-family:monospace;font-size:0.6rem;color:rgba(0,224,154,0.4);z-index:5;opacity:0;transition:opacity 0.3s;';
  this._saveInd.textContent = 'saved';
  c.appendChild(this._saveInd);

  // Menu button
  this._menuBtn = document.createElement('button');
  this._menuBtn.textContent = '\u2630';
  this._menuBtn.style.cssText = 'position:absolute;top:12px;right:16px;z-index:60;background:rgba(0,0,0,0.4);border:2px solid rgba(255,255,255,0.15);color:#aaa;padding:4px 8px;cursor:pointer;font-family:monospace;font-size:1rem;border-radius:0;';
  c.appendChild(this._menuBtn);

  // Menu overlay
  this._menuEl = document.createElement('div');
  this._menuEl.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:55;background:rgba(0,0,0,0.85);display:none;flex-direction:column;align-items:center;justify-content:center;gap:12px;';
  this._menuEl.innerHTML = '<div style="font-family:monospace;font-size:1rem;color:#888;margin-bottom:16px;letter-spacing:3px;">MENU</div>';
  var menuBtns = [
    { id: 'resume', text: 'BACK TO GAME' },
    { id: 'save1', text: 'SAVE SLOT 1' },
    { id: 'save2', text: 'SAVE SLOT 2' },
    { id: 'save3', text: 'SAVE SLOT 3' },
    { id: 'load1', text: 'LOAD SLOT 1' },
    { id: 'load2', text: 'LOAD SLOT 2' },
    { id: 'load3', text: 'LOAD SLOT 3' },
    { id: 'history', text: 'HISTORY' },
    { id: 'settings', text: 'SETTINGS' }
  ];
  var self = this;
  menuBtns.forEach(function(b) {
    var btn = document.createElement('button');
    btn.textContent = b.text;
    btn.style.cssText = 'font-family:monospace;font-size:0.8rem;padding:10px 32px;background:transparent;border:2px solid rgba(255,255,255,0.1);color:#aaa;cursor:pointer;border-radius:0;width:220px;text-align:center;';
    btn.addEventListener('mouseenter', function() { btn.style.borderColor = 'rgba(255,255,255,0.3)'; btn.style.color = '#fff'; });
    btn.addEventListener('mouseleave', function() { btn.style.borderColor = 'rgba(255,255,255,0.1)'; btn.style.color = '#aaa'; });
    btn.addEventListener('click', function() { self._handleMenu(b.id); });
    self._menuEl.appendChild(btn);
  });
  c.appendChild(this._menuEl);

  // History overlay
  this._historyEl = document.createElement('div');
  this._historyEl.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:56;background:rgba(0,0,0,0.92);display:none;flex-direction:column;overflow-y:auto;padding:40px 24px 24px;';
  var histClose = document.createElement('button');
  histClose.textContent = 'CLOSE';
  histClose.style.cssText = 'position:sticky;top:0;align-self:flex-end;font-family:monospace;font-size:0.75rem;padding:6px 16px;background:rgba(0,0,0,0.8);border:2px solid rgba(255,255,255,0.15);color:#aaa;cursor:pointer;border-radius:0;margin-bottom:16px;z-index:1;';
  histClose.addEventListener('click', function() { self._historyEl.style.display = 'none'; });
  this._historyEl.appendChild(histClose);
  this._historyContent = document.createElement('div');
  this._historyEl.appendChild(this._historyContent);
  c.appendChild(this._historyEl);

  // Settings overlay
  this._settingsEl = document.createElement('div');
  this._settingsEl.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;z-index:56;background:rgba(0,0,0,0.92);display:none;flex-direction:column;align-items:center;justify-content:center;gap:16px;';
  this._settingsEl.innerHTML = '<div style="font-family:monospace;font-size:0.9rem;color:#888;letter-spacing:2px;margin-bottom:8px;">SETTINGS</div>';
  // Text speed
  var speedRow = document.createElement('div');
  speedRow.style.cssText = 'display:flex;align-items:center;gap:12px;';
  speedRow.innerHTML = '<span style="font-family:monospace;font-size:0.75rem;color:#888;width:100px;">TEXT SPEED</span>';
  var speedSlider = document.createElement('input');
  speedSlider.type = 'range';
  speedSlider.min = '5'; speedSlider.max = '60'; speedSlider.value = String(this.TYPE_SPEED);
  speedSlider.style.cssText = 'width:150px;accent-color:#00ffaa;';
  speedSlider.addEventListener('input', function() { self.TYPE_SPEED = 65 - parseInt(speedSlider.value); });
  speedRow.appendChild(speedSlider);
  this._settingsEl.appendChild(speedRow);
  // Auto advance
  var autoRow = document.createElement('div');
  autoRow.style.cssText = 'display:flex;align-items:center;gap:12px;';
  autoRow.innerHTML = '<span style="font-family:monospace;font-size:0.75rem;color:#888;width:100px;">AUTO ADVANCE</span>';
  this._autoBtn = document.createElement('button');
  this._autoBtn.textContent = 'OFF';
  this._autoBtn.style.cssText = 'font-family:monospace;font-size:0.75rem;padding:4px 16px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#888;cursor:pointer;border-radius:0;';
  this._autoBtn.addEventListener('click', function() {
    self.state.autoAdvance = !self.state.autoAdvance;
    self._autoBtn.textContent = self.state.autoAdvance ? 'ON' : 'OFF';
    self._autoBtn.style.color = self.state.autoAdvance ? '#00ffaa' : '#888';
  });
  autoRow.appendChild(this._autoBtn);
  this._settingsEl.appendChild(autoRow);
  // Volume
  var volRow = document.createElement('div');
  volRow.style.cssText = 'display:flex;align-items:center;gap:12px;';
  volRow.innerHTML = '<span style="font-family:monospace;font-size:0.75rem;color:#888;width:100px;">VOLUME</span>';
  var volSlider = document.createElement('input');
  volSlider.type = 'range';
  volSlider.min = '0'; volSlider.max = '100'; volSlider.value = '30';
  volSlider.style.cssText = 'width:150px;accent-color:#00ffaa;';
  volSlider.addEventListener('input', function() { Audio.setVolume(parseInt(volSlider.value) / 100); });
  volRow.appendChild(volSlider);
  this._settingsEl.appendChild(volRow);
  // Close
  var setClose = document.createElement('button');
  setClose.textContent = 'CLOSE';
  setClose.style.cssText = 'font-family:monospace;font-size:0.75rem;padding:8px 24px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#aaa;cursor:pointer;border-radius:0;margin-top:16px;';
  setClose.addEventListener('click', function() { self._settingsEl.style.display = 'none'; });
  this._settingsEl.appendChild(setClose);
  c.appendChild(this._settingsEl);

  // Choices layer
  this._choicesEl = document.createElement('div');
  this._choicesEl.style.cssText = 'position:absolute;bottom:200px;left:50%;transform:translateX(-50%);z-index:20;display:flex;flex-direction:column;gap:8px;width:90%;max-width:480px;';
  c.appendChild(this._choicesEl);

  // Dialogue box
  this._dialogueEl = document.createElement('div');
  this._dialogueEl.style.cssText = 'position:absolute;bottom:0;left:0;right:0;background:linear-gradient(to top,rgba(8,8,13,0.98) 70%,rgba(8,8,13,0.85));backdrop-filter:blur(8px);padding:24px 32px 28px;z-index:10;min-height:180px;cursor:pointer;border-top:2px solid rgba(255,255,255,0.06);display:none;-webkit-tap-highlight-color:transparent;touch-action:manipulation;border-radius:0;';
  this._dialogueEl.tabIndex = 0;

  // Inner layout: portrait + text
  var inner = document.createElement('div');
  inner.style.cssText = 'display:flex;gap:14px;align-items:flex-start;';

  this._speakerPortrait = document.createElement('img');
  this._speakerPortrait.style.cssText = 'width:64px;height:64px;border:2px solid rgba(255,255,255,0.1);object-fit:cover;flex-shrink:0;display:none;border-radius:0;image-rendering:pixelated;';
  inner.appendChild(this._speakerPortrait);

  var content = document.createElement('div');
  content.style.cssText = 'flex:1;min-width:0;';

  this._speakerEl = document.createElement('div');
  this._speakerEl.style.cssText = 'font-family:monospace;font-size:0.8rem;font-weight:600;margin-bottom:8px;letter-spacing:1px;';
  content.appendChild(this._speakerEl);

  this._textEl = document.createElement('div');
  this._textEl.style.cssText = 'font-family:monospace;font-size:0.95rem;line-height:1.8;color:#c8c8d0;min-height:3.6em;';
  content.appendChild(this._textEl);

  inner.appendChild(content);
  this._dialogueEl.appendChild(inner);

  // Advance hint
  this._advanceEl = document.createElement('div');
  this._advanceEl.style.cssText = 'position:absolute;bottom:8px;right:16px;font-family:monospace;font-size:0.65rem;color:rgba(255,255,255,0.25);';
  this._dialogueEl.appendChild(this._advanceEl);

  // Skip / Auto buttons in dialogue
  var dBtns = document.createElement('div');
  dBtns.style.cssText = 'position:absolute;bottom:8px;left:16px;display:flex;gap:8px;';
  this._skipBtn = document.createElement('button');
  this._skipBtn.textContent = 'SKIP';
  this._skipBtn.style.cssText = 'font-family:monospace;font-size:0.6rem;padding:2px 8px;background:transparent;border:1px solid rgba(255,255,255,0.1);color:rgba(255,255,255,0.25);cursor:pointer;border-radius:0;';
  this._skipBtn.addEventListener('click', function(e) { e.stopPropagation(); self._toggleSkip(); });
  dBtns.appendChild(this._skipBtn);

  this._autoAdvBtn = document.createElement('button');
  this._autoAdvBtn.textContent = 'AUTO';
  this._autoAdvBtn.style.cssText = 'font-family:monospace;font-size:0.6rem;padding:2px 8px;background:transparent;border:1px solid rgba(255,255,255,0.1);color:rgba(255,255,255,0.25);cursor:pointer;border-radius:0;';
  this._autoAdvBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    self.state.autoAdvance = !self.state.autoAdvance;
    self._autoAdvBtn.style.color = self.state.autoAdvance ? '#00ffaa' : 'rgba(255,255,255,0.25)';
    self._autoAdvBtn.style.borderColor = self.state.autoAdvance ? 'rgba(0,255,170,0.3)' : 'rgba(255,255,255,0.1)';
  });
  dBtns.appendChild(this._autoAdvBtn);

  this._dialogueEl.appendChild(dBtns);
  c.appendChild(this._dialogueEl);

  // Title screen
  this._titleEl = document.createElement('div');
  this._titleEl.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:50;background:radial-gradient(ellipse at center,#0d0d18 0%,#08080d 70%);transition:opacity 1s ease;';
  c.appendChild(this._titleEl);
};

// ============================================================
// INPUT BINDING
// ============================================================
P._bindInput = function() {
  var self = this;
  this._dialogueEl.addEventListener('click', function() { self._advance(); });
  document.addEventListener('keydown', function(e) {
    if (!self.state.started) return;
    if (self._menuEl.style.display === 'flex' || self._historyEl.style.display === 'flex' || self._settingsEl.style.display === 'flex') return;
    if (e.key === ' ' || e.key === 'Enter') {
      e.preventDefault();
      if (self._choicesEl.children.length > 0) return;
      self._advance();
    }
  });
  this._menuBtn.addEventListener('click', function() {
    if (!self.state.started) return;
    if (self._menuEl.style.display === 'flex') {
      self._menuEl.style.display = 'none';
    } else {
      self._menuEl.style.display = 'flex';
    }
  });
};

// ============================================================
// MENU HANDLING
// ============================================================
P._handleMenu = function(id) {
  var self = this;
  this._menuEl.style.display = 'none';
  if (id === 'resume') return;
  if (id.indexOf('save') === 0) {
    var slot = id.charAt(4);
    this._saveToSlot(parseInt(slot));
  } else if (id.indexOf('load') === 0) {
    var ls = id.charAt(4);
    this._loadFromSlot(parseInt(ls));
  } else if (id === 'history') {
    this._showHistory();
  } else if (id === 'settings') {
    this._settingsEl.style.display = 'flex';
  }
};

// ============================================================
// CHARACTER SYSTEM
// ============================================================
P.defineCharacter = function(id, opts) {
  this.characters[id] = {
    name: opts.name || id,
    color: opts.color || '#ffffff',
    textColor: opts.textColor || '#c8c8d0',
    portrait: opts.portrait || null,
    sprite: opts.sprite || '',
    blipPitch: opts.blipPitch || (300 + id.charCodeAt(0) * 3),
    role: opts.role || ''
  };
};

// ============================================================
// BACKGROUND REGISTRATION
// ============================================================
P.defineBackground = function(name, fn) {
  this.backgrounds[name] = fn;
};

// ============================================================
// SCRIPT LOADING
// ============================================================
P.loadScript = function(script) {
  this.script = script;
  this.labels = {};
  for (var i = 0; i < script.length; i++) {
    if (script[i].type === 'label') {
      this.labels[script[i].name] = i;
    }
  }
};

// ============================================================
// TITLE SCREEN
// ============================================================
P.setTitle = function(title, subtitle) {
  this._gameTitle = title || 'VISUAL NOVEL';
  this._gameSubtitle = subtitle || '';
};

P.start = function() {
  var self = this;
  var titleHTML = '<h1 style="font-family:monospace;font-size:3rem;font-weight:600;letter-spacing:0.3em;color:#e8e8ef;margin:0 0 8px;border:none;padding:0;">' + (this._gameTitle || 'VISUAL NOVEL') + '</h1>';
  if (this._gameSubtitle) {
    titleHTML += '<div style="font-family:monospace;font-size:0.9rem;color:#6a6a78;margin-bottom:48px;letter-spacing:0.1em;">' + this._gameSubtitle + '</div>';
  } else {
    titleHTML += '<div style="margin-bottom:48px;"></div>';
  }
  titleHTML += '<button id="ne-start-btn" style="font-family:monospace;font-size:0.85rem;padding:12px 40px;background:transparent;border:2px solid rgba(255,255,255,0.15);color:#c8c8d0;cursor:pointer;letter-spacing:2px;margin-bottom:12px;border-radius:0;">BEGIN</button>';
  if (this._hasSave()) {
    titleHTML += '<button id="ne-continue-btn" style="font-family:monospace;font-size:0.75rem;padding:8px 24px;background:transparent;border:2px solid rgba(255,255,255,0.08);color:#6a6a78;cursor:pointer;border-radius:0;">CONTINUE</button>';
  }
  this._titleEl.innerHTML = titleHTML;

  var startBtn = this._titleEl.querySelector('#ne-start-btn');
  var contBtn = this._titleEl.querySelector('#ne-continue-btn');

  startBtn.addEventListener('click', function() {
    self.state.started = true;
    self._titleEl.style.opacity = '0';
    self._titleEl.style.pointerEvents = 'none';
    self.vars = {};
    self.state.choiceHistory = [];
    self.state.history = [];
    self.seenText = {};
    setTimeout(function() { self._titleEl.style.display = 'none'; self._exec(0); }, 500);
  });

  if (contBtn) {
    contBtn.addEventListener('click', function() {
      var save = self._loadAuto();
      if (!save) return;
      self.state.started = true;
      self.vars = save.vars || {};
      self.state.choiceHistory = save.choiceHistory || [];
      self.state.history = save.history || [];
      self.seenText = save.seenText || {};
      self._titleEl.style.opacity = '0';
      self._titleEl.style.pointerEvents = 'none';
      setTimeout(function() { self._titleEl.style.display = 'none'; self._exec(save.pc); }, 500);
    });
  }
};

// ============================================================
// SCRIPT EXECUTION
// ============================================================
P._exec = function(pc) {
  if (pc < 0 || pc >= this.script.length) {
    this._end();
    return;
  }
  this.state.pc = pc;
  var cmd = this.script[pc];
  if (!cmd) { this._end(); return; }

  var self = this;

  switch (cmd.type) {
    case 'label':
      // Just a marker, skip
      this._exec(pc + 1);
      break;

    case 'scene':
      this._autoSave();
      var bgKey = cmd.bg || 'black';
      var trans = cmd.transition || null;
      if (cmd.chapter) this._chapterEl.textContent = cmd.chapter;
      if (trans) {
        doTransition(this.container, trans, cmd.duration || 600, function() {
          self._setBg(bgKey);
          self.effects.particles = cmd.particles || null;
          self.effects.crt = !!cmd.crt;
          self.effects.vignette = !!cmd.vignette;
        });
        setTimeout(function() { self._exec(pc + 1); }, (cmd.duration || 600) + 50);
      } else {
        this._setBg(bgKey);
        this.effects.particles = cmd.particles || null;
        this.effects.crt = !!cmd.crt;
        this.effects.vignette = !!cmd.vignette;
        this._exec(pc + 1);
      }
      break;

    case 'chapter':
      this._chapterEl.textContent = cmd.text || '';
      this._exec(pc + 1);
      break;

    case 'show':
      this._showChar(cmd.char, cmd.position || 'center');
      this._exec(pc + 1);
      break;

    case 'hide':
      this._hideChar(cmd.char);
      this._exec(pc + 1);
      break;

    case 'hideall':
      this._charsEl.innerHTML = '';
      this.state.visibleChars = {};
      this._exec(pc + 1);
      break;

    case 'say':
      this._showDialogue(cmd.char, cmd.text, false, false);
      break;

    case 'narrate':
      this._showDialogue(null, cmd.text, false, false);
      break;

    case 'think':
      this._showDialogue(cmd.char, cmd.text, true, false);
      break;

    case 'shout':
      this._showDialogue(cmd.char, cmd.text, false, true);
      break;

    case 'choice':
      this._showChoices(cmd.prompt || null, cmd.choices);
      break;

    case 'set':
      this.vars[cmd.var] = cmd.value;
      this._exec(pc + 1);
      break;

    case 'add':
      this.vars[cmd.var] = (this.vars[cmd.var] || 0) + (cmd.value || 1);
      this._exec(pc + 1);
      break;

    case 'jump':
      var target = this.labels[cmd.to];
      if (target !== undefined) {
        this._exec(target);
      } else {
        this._exec(pc + 1);
      }
      break;

    case 'if':
      if (this._evalCondition(cmd.condition || cmd)) {
        var jt = this.labels[cmd.then];
        if (jt !== undefined) this._exec(jt);
        else this._exec(pc + 1);
      } else {
        if (cmd.else) {
          var je = this.labels[cmd.else];
          if (je !== undefined) this._exec(je);
          else this._exec(pc + 1);
        } else {
          this._exec(pc + 1);
        }
      }
      break;

    case 'sfx':
      if (this.audioEnabled) Audio.sfx(cmd.sound);
      this._exec(pc + 1);
      break;

    case 'effect':
      if (cmd.effect === 'shake') FX.shake(this.container, cmd.intensity, cmd.duration);
      else if (cmd.effect === 'flash') FX.flash(this.container, cmd.color, cmd.duration);
      this._exec(pc + 1);
      break;

    case 'wait':
      setTimeout(function() { self._exec(pc + 1); }, cmd.duration || 1000);
      break;

    case 'end':
      this._end();
      break;

    default:
      this._exec(pc + 1);
      break;
  }
};

// ============================================================
// CONDITION EVALUATION
// ============================================================
P._evalCondition = function(cond) {
  if (!cond) return false;
  var v = this.vars[cond.var];
  if (v === undefined) v = 0;
  var val = cond.val;
  switch (cond.op) {
    case '==': case '===': return v == val;
    case '!=': case '!==': return v != val;
    case '>': return v > val;
    case '<': return v < val;
    case '>=': return v >= val;
    case '<=': return v <= val;
    case 'is': return !!v;
    case 'not': return !v;
    default: return !!v;
  }
};

// ============================================================
// BACKGROUND RENDERING
// ============================================================
P._setBg = function(key) {
  this.state.currentBg = key;
  this._startBgAnim(key);
};

P._startBgAnim = function(key) {
  var self = this;
  if (this._animFrame) cancelAnimationFrame(this._animFrame);
  this._animStart = performance.now();

  var bgFn = this.backgrounds[key] || BACKGROUNDS['black'];

  function frame() {
    var canvas = self._canvas;
    var ctx = self._ctx;
    if (!canvas || !ctx) return;
    var rect = canvas.parentElement.getBoundingClientRect();
    if (canvas.width !== rect.width || canvas.height !== rect.height) {
      canvas.width = rect.width;
      canvas.height = rect.height;
    }
    var t = (performance.now() - self._animStart) / 1000;
    var w = canvas.width, h = canvas.height;
    bgFn(ctx, w, h, t);
    // Overlay effects
    if (self.effects.particles) FX.particles(ctx, w, h, t, self.effects.particles);
    if (self.effects.crt) FX.crt(ctx, w, h);
    if (self.effects.vignette) FX.vignette(ctx, w, h);
    self._animFrame = requestAnimationFrame(frame);
  }
  frame();
};

// ============================================================
// CHARACTER DISPLAY
// ============================================================
P._showChar = function(charId, position) {
  var ch = this.characters[charId];
  if (!ch) return;

  // Remove if already visible
  this._hideChar(charId);

  var el = document.createElement('div');
  el.setAttribute('data-char', charId);
  el.style.cssText = 'text-align:center;transition:transform 0.5s steps(8),opacity 0.5s steps(8),filter 0.5s ease;filter:brightness(0.5);opacity:0;';

  // Position
  var positions = { 'far-left': '10%', 'left': '25%', 'center': '50%', 'right': '75%', 'far-right': '90%' };
  el.style.position = 'absolute';
  el.style.left = positions[position] || '50%';
  el.style.transform = 'translateX(-50%)';
  el.style.bottom = '0';

  if (ch.portrait) {
    var img = document.createElement('img');
    img.src = ch.portrait;
    img.alt = ch.name;
    img.style.cssText = 'width:100px;height:100px;border:2px solid ' + ch.color + ';object-fit:cover;border-radius:0;image-rendering:pixelated;';
    el.appendChild(img);
  } else if (ch.sprite) {
    var sp = document.createElement('div');
    sp.style.cssText = 'font-family:monospace;font-size:4rem;line-height:1;user-select:none;color:' + ch.color + ';';
    sp.textContent = ch.sprite;
    el.appendChild(sp);
  }

  var nameTag = document.createElement('div');
  nameTag.style.cssText = 'font-family:monospace;font-size:0.65rem;margin-top:4px;opacity:0.6;letter-spacing:1px;text-transform:uppercase;color:' + ch.color + ';';
  nameTag.textContent = ch.name;
  el.appendChild(nameTag);

  this.state.visibleChars[charId] = position;

  // Use flex container, reset to relative positioning
  el.style.position = '';
  el.style.left = '';
  el.style.transform = '';
  el.style.bottom = '';

  // Order characters by position
  this._charsEl.style.justifyContent = 'center';
  this._charsEl.appendChild(el);
  this._reorderChars();

  requestAnimationFrame(function() { el.style.opacity = '1'; });
};

P._hideChar = function(charId) {
  delete this.state.visibleChars[charId];
  var existing = this._charsEl.querySelector('[data-char="' + charId + '"]');
  if (existing) {
    existing.style.opacity = '0';
    setTimeout(function() { if (existing.parentNode) existing.parentNode.removeChild(existing); }, 500);
  }
};

P._reorderChars = function() {
  var order = ['far-left', 'left', 'center', 'right', 'far-right'];
  var chars = this.state.visibleChars;
  var els = Array.prototype.slice.call(this._charsEl.children);
  els.sort(function(a, b) {
    var pa = chars[a.getAttribute('data-char')] || 'center';
    var pb = chars[b.getAttribute('data-char')] || 'center';
    return order.indexOf(pa) - order.indexOf(pb);
  });
  var parent = this._charsEl;
  els.forEach(function(el) { parent.appendChild(el); });
};

P._highlightSpeaker = function(charId) {
  var els = this._charsEl.querySelectorAll('[data-char]');
  for (var i = 0; i < els.length; i++) {
    var el = els[i];
    if (el.getAttribute('data-char') === charId) {
      el.style.filter = 'brightness(1)';
      el.style.transform = 'scale(1.05)';
    } else {
      el.style.filter = 'brightness(0.5)';
      el.style.transform = 'scale(1)';
    }
  }
};

// ============================================================
// DIALOGUE SYSTEM
// ============================================================
P._showDialogue = function(charId, text, isThought, isShout) {
  var ch = charId ? this.characters[charId] : null;
  this._dialogueEl.style.display = 'block';
  this._choicesEl.innerHTML = '';

  // Speaker name
  if (ch && ch.name) {
    this._speakerEl.textContent = ch.name;
    this._speakerEl.style.color = ch.color;
  } else {
    this._speakerEl.textContent = '';
  }

  // Speaker portrait in dialogue box
  if (ch && ch.portrait) {
    this._speakerPortrait.src = ch.portrait;
    this._speakerPortrait.alt = ch.name;
    this._speakerPortrait.style.display = 'block';
    this._speakerPortrait.style.borderColor = ch.color;
  } else {
    this._speakerPortrait.style.display = 'none';
  }

  // Highlight speaker in scene
  if (charId) this._highlightSpeaker(charId);

  // Shout effect
  if (isShout) {
    this._textEl.style.fontSize = '1.2rem';
    this._textEl.style.fontWeight = '700';
    FX.shake(this.container, 4, 300);
  } else {
    this._textEl.style.fontSize = '0.95rem';
    this._textEl.style.fontWeight = '400';
  }

  // Thought style
  if (isThought) {
    this._textEl.style.fontStyle = 'italic';
    this._textEl.style.color = 'rgba(200,200,210,0.7)';
  } else {
    this._textEl.style.fontStyle = 'normal';
    this._textEl.style.color = (ch && ch.textColor) ? ch.textColor : '#c8c8d0';
  }

  // Add to history
  this.state.history.push({
    char: charId,
    name: ch ? ch.name : '',
    color: ch ? ch.color : '#888',
    text: text,
    thought: isThought
  });

  // Track seen text for skip
  var textKey = this.state.pc + ':' + text.substring(0, 20);
  var seen = !!this.seenText[textKey];
  this.seenText[textKey] = true;

  // Typewriter
  this._typeText(text, ch, seen && this.state.skipMode);
};

P._typeText = function(text, ch, instant) {
  var self = this;
  this.state.typing = true;
  this.state.charIndex = 0;
  this.state.currentText = text;
  this._textEl.textContent = '';
  this._advanceEl.textContent = '';

  if (this.state.typingTimer) clearInterval(this.state.typingTimer);

  if (instant) {
    this._textEl.textContent = text;
    this.state.typing = false;
    this._advanceEl.textContent = 'click to continue';
    // Auto advance in skip mode
    setTimeout(function() { self._advance(); }, 50);
    return;
  }

  var blipCounter = 0;
  this.state.typingTimer = setInterval(function() {
    if (self.state.charIndex < text.length) {
      self.state.charIndex++;
      self._textEl.textContent = text.substring(0, self.state.charIndex);
      // Text blip every few characters
      if (self.audioEnabled && blipCounter % 3 === 0 && ch) {
        Audio.blip(ch.blipPitch || 440);
      }
      blipCounter++;
    } else {
      clearInterval(self.state.typingTimer);
      self.state.typingTimer = null;
      self.state.typing = false;
      self._advanceEl.textContent = 'click to continue';
      // Auto advance
      if (self.state.autoAdvance) {
        setTimeout(function() {
          if (self.state.autoAdvance && !self.state.typing) self._advance();
        }, 1500);
      }
    }
  }, this.TYPE_SPEED);
};

P._skipType = function() {
  if (this.state.typing) {
    if (this.state.typingTimer) clearInterval(this.state.typingTimer);
    this.state.typingTimer = null;
    this._textEl.textContent = this.state.currentText;
    this.state.typing = false;
    this.state.charIndex = this.state.currentText.length;
    this._advanceEl.textContent = 'click to continue';
  }
};

P._toggleSkip = function() {
  this.state.skipMode = !this.state.skipMode;
  this._skipBtn.style.color = this.state.skipMode ? '#00ffaa' : 'rgba(255,255,255,0.25)';
  this._skipBtn.style.borderColor = this.state.skipMode ? 'rgba(0,255,170,0.3)' : 'rgba(255,255,255,0.1)';
  if (this.state.skipMode && !this.state.typing) {
    this._advance();
  }
};

P._advance = function() {
  if (this.state.ended) {
    this._restart();
    return;
  }
  if (this.state.typing) {
    this._skipType();
    return;
  }
  this._exec(this.state.pc + 1);
};

// ============================================================
// CHOICE SYSTEM
// ============================================================
P._showChoices = function(prompt, choices) {
  var self = this;
  this._dialogueEl.style.display = 'none';
  this._choicesEl.innerHTML = '';

  if (prompt) {
    var promptEl = document.createElement('div');
    promptEl.style.cssText = 'font-family:monospace;font-size:0.8rem;color:rgba(255,255,255,0.4);text-align:center;margin-bottom:8px;letter-spacing:1px;';
    promptEl.textContent = prompt;
    this._choicesEl.appendChild(promptEl);
  }

  var filteredChoices = [];
  for (var i = 0; i < choices.length; i++) {
    var c = choices[i];
    if (c.condition) {
      if (!this._evalCondition(c.condition)) continue;
    }
    filteredChoices.push(c);
  }

  filteredChoices.forEach(function(choice, idx) {
    var btn = document.createElement('button');
    btn.textContent = choice.text;
    btn.style.cssText = 'font-family:monospace;font-size:0.9rem;padding:14px 20px;background:rgba(20,20,30,0.9);border:2px solid rgba(255,255,255,0.1);color:#c8c8d0;cursor:pointer;text-align:left;backdrop-filter:blur(4px);-webkit-tap-highlight-color:transparent;touch-action:manipulation;min-height:48px;border-radius:0;transition:border-color 0.2s,color 0.2s,transform 0.2s;';
    btn.addEventListener('mouseenter', function() {
      btn.style.borderColor = 'rgba(255,255,255,0.25)';
      btn.style.color = '#fff';
      btn.style.transform = 'translateX(4px)';
    });
    btn.addEventListener('mouseleave', function() {
      btn.style.borderColor = 'rgba(255,255,255,0.1)';
      btn.style.color = '#c8c8d0';
      btn.style.transform = 'translateX(0)';
    });
    btn.addEventListener('click', function() {
      self.state.choiceHistory.push({ pc: self.state.pc, choice: idx, text: choice.text });
      self._choicesEl.innerHTML = '';
      // Set variables from choice
      if (choice.set) {
        for (var k in choice.set) self.vars[k] = choice.set[k];
      }
      self._autoSave();
      if (choice.next) {
        var target = self.labels[choice.next];
        if (target !== undefined) {
          self._exec(target);
        } else {
          self._exec(self.state.pc + 1);
        }
      } else {
        self._exec(self.state.pc + 1);
      }
    });
    self._choicesEl.appendChild(btn);
  });
};

// ============================================================
// VARIABLE SYSTEM (Public API)
// ============================================================
P.setVar = function(name, value) { this.vars[name] = value; };
P.getVar = function(name) { return this.vars[name]; };
P.ifVar = function(name, op, val, thenLabel, elseLabel) {
  if (this._evalCondition({ var: name, op: op, val: val })) {
    if (thenLabel) { var t = this.labels[thenLabel]; if (t !== undefined) this._exec(t); }
  } else {
    if (elseLabel) { var e = this.labels[elseLabel]; if (e !== undefined) this._exec(e); }
  }
};

// ============================================================
// HISTORY VIEWER
// ============================================================
P._showHistory = function() {
  this._historyContent.innerHTML = '';
  var hist = this.state.history;
  for (var i = 0; i < hist.length; i++) {
    var h = hist[i];
    var line = document.createElement('div');
    line.style.cssText = 'margin-bottom:12px;font-family:monospace;font-size:0.85rem;line-height:1.6;';
    if (h.name) {
      var nameSpan = document.createElement('span');
      nameSpan.style.cssText = 'font-weight:600;letter-spacing:1px;color:' + h.color + ';';
      nameSpan.textContent = h.name + '  ';
      line.appendChild(nameSpan);
    }
    var textSpan = document.createElement('span');
    textSpan.style.cssText = 'color:#c8c8d0;' + (h.thought ? 'font-style:italic;opacity:0.7;' : '');
    textSpan.textContent = h.text;
    line.appendChild(textSpan);
    this._historyContent.appendChild(line);
  }
  this._historyEl.style.display = 'flex';
  this._historyEl.scrollTop = this._historyEl.scrollHeight;
};

// ============================================================
// SAVE / LOAD SYSTEM
// ============================================================
P._saveData = function() {
  return {
    pc: this.state.pc,
    vars: JSON.parse(JSON.stringify(this.vars)),
    choiceHistory: this.state.choiceHistory.slice(),
    history: this.state.history.slice(-100),
    seenText: this.seenText,
    visibleChars: JSON.parse(JSON.stringify(this.state.visibleChars)),
    bg: this.state.currentBg,
    chapter: this._chapterEl.textContent,
    ts: Date.now()
  };
};

P._autoSave = function() {
  try {
    localStorage.setItem(this.SAVE_KEY + '_auto', JSON.stringify(this._saveData()));
  } catch (e) {}
  this._saveInd.style.opacity = '1';
  var self = this;
  setTimeout(function() { self._saveInd.style.opacity = '0'; }, 1500);
};

P._saveToSlot = function(slot) {
  try {
    localStorage.setItem(this.SAVE_KEY + '_' + slot, JSON.stringify(this._saveData()));
  } catch (e) {}
  this._saveInd.style.opacity = '1';
  this._saveInd.textContent = 'saved slot ' + slot;
  var self = this;
  setTimeout(function() { self._saveInd.style.opacity = '0'; self._saveInd.textContent = 'saved'; }, 1500);
};

P._loadFromSlot = function(slot) {
  try {
    var data = JSON.parse(localStorage.getItem(this.SAVE_KEY + '_' + slot));
    if (data && data.pc !== undefined) {
      this._restoreSave(data);
    }
  } catch (e) {}
};

P._loadAuto = function() {
  try {
    return JSON.parse(localStorage.getItem(this.SAVE_KEY + '_auto'));
  } catch (e) {}
  return null;
};

P._hasSave = function() {
  try {
    var d = localStorage.getItem(this.SAVE_KEY + '_auto');
    return !!d;
  } catch (e) {}
  return false;
};

P._restoreSave = function(data) {
  this.vars = data.vars || {};
  this.state.choiceHistory = data.choiceHistory || [];
  this.state.history = data.history || [];
  this.seenText = data.seenText || {};
  this.state.visibleChars = {};
  this._charsEl.innerHTML = '';

  // Restore background
  if (data.bg) this._setBg(data.bg);
  if (data.chapter) this._chapterEl.textContent = data.chapter;

  // Restore visible characters
  if (data.visibleChars) {
    for (var cid in data.visibleChars) {
      this._showChar(cid, data.visibleChars[cid]);
    }
  }

  // Make sure game is started
  this.state.started = true;
  this.state.ended = false;
  this._titleEl.style.display = 'none';
  this._titleEl.style.opacity = '0';
  this._titleEl.style.pointerEvents = 'none';

  this._exec(data.pc);
};

// ============================================================
// END / RESTART
// ============================================================
P._end = function() {
  this.state.ended = true;
  this._advanceEl.textContent = 'click to restart';
  this._autoSave();
  if (this.onEnd) this.onEnd();
};

P._restart = function() {
  this.state.ended = false;
  this.state.started = false;
  this.state.history = [];
  this.state.choiceHistory = [];
  this.state.visibleChars = {};
  this.vars = {};
  this.seenText = {};
  if (this.state.typingTimer) clearInterval(this.state.typingTimer);
  this._dialogueEl.style.display = 'none';
  this._charsEl.innerHTML = '';
  this._choicesEl.innerHTML = '';
  this._chapterEl.textContent = '';
  this._titleEl.style.display = 'flex';
  this._titleEl.style.opacity = '1';
  this._titleEl.style.pointerEvents = 'auto';
  try { localStorage.removeItem(this.SAVE_KEY + '_auto'); } catch (e) {}
  this.start();
};

// ============================================================
// EXPORT
// ============================================================
root.NovelEngine = NovelEngine;
root.NovelEngine.BACKGROUNDS = BACKGROUNDS;
root.NovelEngine.FX = FX;
root.NovelEngine.Audio = Audio;

})(typeof window !== 'undefined' ? window : this);
