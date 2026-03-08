// ============================================================
// ANIME EFFECTS — 90s anime visual enhancement system
// Cowboy Bebop / Ghost in the Shell / Evangelion / Akira
// ============================================================
var AnimeEffects = (function() {
  'use strict';

  // === CRT SCANLINE OVERLAY ===
  function addScanlines(opacity) {
    if (document.getElementById('anime-scanlines')) return;
    var overlay = document.createElement('div');
    overlay.id = 'anime-scanlines';
    overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:9999;' +
      'background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,' + (opacity || 0.05) + ') 2px,rgba(0,0,0,' + (opacity || 0.05) + ') 4px);';
    document.body.appendChild(overlay);
  }

  // === SPEED LINES BURST ===
  function speedLinesBurst(x, y, color, count, container) {
    var parent = container || document.body;
    var c = document.createElement('canvas');
    c.width = 400;
    c.height = 400;
    c.style.cssText = 'position:fixed;left:' + (x - 200) + 'px;top:' + (y - 200) + 'px;pointer-events:none;z-index:9998;';
    parent.appendChild(c);
    var ctx = c.getContext('2d');
    var lines = [];
    var lineCount = count || 24;
    for (var i = 0; i < lineCount; i++) {
      var angle = (Math.PI * 2 * i / lineCount) + (Math.random() - 0.5) * 0.2;
      lines.push({
        angle: angle,
        speed: 4 + Math.random() * 6,
        len: 20 + Math.random() * 60,
        width: 1 + Math.random() * 3,
        dist: 30 + Math.random() * 20,
        alpha: 0.6 + Math.random() * 0.4
      });
    }
    var frame = 0;
    var maxFrames = 20;
    function animate() {
      frame++;
      if (frame > maxFrames) {
        parent.removeChild(c);
        return;
      }
      ctx.clearRect(0, 0, 400, 400);
      var progress = frame / maxFrames;
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i];
        var d = l.dist + l.speed * frame;
        var endD = d + l.len * (1 - progress * 0.5);
        ctx.beginPath();
        ctx.moveTo(200 + Math.cos(l.angle) * d, 200 + Math.sin(l.angle) * d);
        ctx.lineTo(200 + Math.cos(l.angle) * endD, 200 + Math.sin(l.angle) * endD);
        ctx.strokeStyle = color || '#ffffff';
        ctx.globalAlpha = l.alpha * (1 - progress);
        ctx.lineWidth = l.width * (1 - progress * 0.5);
        ctx.stroke();
      }
      ctx.globalAlpha = 1;
      requestAnimationFrame(animate);
    }
    animate();
  }

  // === DRAW ANIME PORTRAIT ON CANVAS ===
  // Draws a cel-shaded anime character portrait
  function drawPortrait(ctx, x, y, size, options) {
    var opts = options || {};
    var hairColor = opts.hairColor || '#ff77ff';
    var hairDark = opts.hairDark || darkenColor(hairColor, 0.6);
    var eyeColor = opts.eyeColor || '#ff77ff';
    var skinColor = opts.skinColor || '#ffd5b8';
    var skinShadow = opts.skinShadow || '#e8b89c';
    var expression = opts.expression || 'neutral'; // neutral, excited, serene, determined
    var outlineColor = opts.outlineColor || '#1a1a2e';
    var outlineWidth = opts.outlineWidth || 2.5;

    var s = size / 100; // scale factor

    ctx.save();
    ctx.translate(x, y);

    // --- Hair back (behind face) ---
    ctx.fillStyle = hairDark;
    ctx.beginPath();
    ctx.ellipse(0, -10 * s, 42 * s, 48 * s, 0, 0, Math.PI * 2);
    ctx.fill();
    // Bold outline
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = outlineWidth * s;
    ctx.stroke();

    // --- Face oval ---
    ctx.fillStyle = skinColor;
    ctx.beginPath();
    ctx.ellipse(0, 5 * s, 32 * s, 38 * s, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = outlineWidth * s;
    ctx.stroke();

    // --- Face shadow (cel-shading) ---
    ctx.fillStyle = skinShadow;
    ctx.beginPath();
    ctx.ellipse(4 * s, 10 * s, 26 * s, 30 * s, 0.2, 0, Math.PI);
    ctx.fill();

    // --- Eyes ---
    var eyeY = -2 * s;
    var eyeSpacing = 14 * s;
    var eyeW = 10 * s;
    var eyeH = expression === 'excited' ? 14 * s : (expression === 'serene' ? 6 * s : 11 * s);

    // Eye whites
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.ellipse(-eyeSpacing, eyeY, eyeW, eyeH, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(eyeSpacing, eyeY, eyeW, eyeH, 0, 0, Math.PI * 2);
    ctx.fill();

    // Eye outlines
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = (outlineWidth * 0.8) * s;
    ctx.beginPath();
    ctx.ellipse(-eyeSpacing, eyeY, eyeW, eyeH, 0, 0, Math.PI * 2);
    ctx.stroke();
    ctx.beginPath();
    ctx.ellipse(eyeSpacing, eyeY, eyeW, eyeH, 0, 0, Math.PI * 2);
    ctx.stroke();

    // Iris
    ctx.fillStyle = eyeColor;
    var irisR = 6 * s;
    ctx.beginPath();
    ctx.arc(-eyeSpacing, eyeY + 1 * s, irisR, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(eyeSpacing, eyeY + 1 * s, irisR, 0, Math.PI * 2);
    ctx.fill();

    // Pupil
    ctx.fillStyle = '#111122';
    var pupilR = 3.5 * s;
    ctx.beginPath();
    ctx.arc(-eyeSpacing, eyeY + 1 * s, pupilR, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(eyeSpacing, eyeY + 1 * s, pupilR, 0, Math.PI * 2);
    ctx.fill();

    // Eye shine (anime highlight)
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(-eyeSpacing - 2 * s, eyeY - 2 * s, 2.5 * s, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(eyeSpacing - 2 * s, eyeY - 2 * s, 2.5 * s, 0, Math.PI * 2);
    ctx.fill();
    // Secondary smaller highlight
    ctx.beginPath();
    ctx.arc(-eyeSpacing + 2 * s, eyeY + 2 * s, 1.2 * s, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(eyeSpacing + 2 * s, eyeY + 2 * s, 1.2 * s, 0, Math.PI * 2);
    ctx.fill();

    // --- Mouth ---
    var mouthY = 18 * s;
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = 1.5 * s;
    if (expression === 'excited') {
      // Open smile
      ctx.beginPath();
      ctx.arc(0, mouthY - 2 * s, 8 * s, 0.1, Math.PI - 0.1);
      ctx.stroke();
      ctx.fillStyle = '#cc3344';
      ctx.beginPath();
      ctx.arc(0, mouthY - 2 * s, 7 * s, 0.2, Math.PI - 0.2);
      ctx.fill();
    } else if (expression === 'serene') {
      // Gentle smile
      ctx.beginPath();
      ctx.arc(0, mouthY, 5 * s, 0.2, Math.PI - 0.2);
      ctx.stroke();
    } else if (expression === 'determined') {
      // Firm line
      ctx.beginPath();
      ctx.moveTo(-6 * s, mouthY);
      ctx.lineTo(6 * s, mouthY);
      ctx.stroke();
    } else {
      // Neutral slight smile
      ctx.beginPath();
      ctx.arc(0, mouthY, 5 * s, 0.3, Math.PI - 0.3);
      ctx.stroke();
    }

    // --- Nose (simple anime dot/line) ---
    ctx.fillStyle = skinShadow;
    ctx.beginPath();
    ctx.arc(0, 8 * s, 1.5 * s, 0, Math.PI * 2);
    ctx.fill();

    // --- Hair front (angular anime style) ---
    ctx.fillStyle = hairColor;
    ctx.beginPath();
    // Top of head
    ctx.moveTo(-38 * s, -15 * s);
    ctx.quadraticCurveTo(-40 * s, -50 * s, -10 * s, -48 * s);
    ctx.quadraticCurveTo(0, -52 * s, 10 * s, -48 * s);
    ctx.quadraticCurveTo(40 * s, -50 * s, 38 * s, -15 * s);
    // Right side bang
    ctx.lineTo(35 * s, -10 * s);
    ctx.lineTo(28 * s, 0);
    ctx.lineTo(32 * s, -12 * s);
    // Fringe/bangs — angular spikes
    ctx.lineTo(20 * s, -20 * s);
    ctx.lineTo(15 * s, -8 * s);
    ctx.lineTo(8 * s, -22 * s);
    ctx.lineTo(0, -12 * s);
    ctx.lineTo(-8 * s, -24 * s);
    ctx.lineTo(-15 * s, -10 * s);
    ctx.lineTo(-20 * s, -22 * s);
    ctx.lineTo(-32 * s, -12 * s);
    ctx.lineTo(-28 * s, 0);
    ctx.lineTo(-35 * s, -10 * s);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = outlineWidth * s;
    ctx.stroke();

    // Hair highlight streak
    ctx.strokeStyle = lightenColor(hairColor, 0.4);
    ctx.lineWidth = 2 * s;
    ctx.globalAlpha = 0.5;
    ctx.beginPath();
    ctx.moveTo(-5 * s, -45 * s);
    ctx.quadraticCurveTo(-2 * s, -30 * s, -10 * s, -15 * s);
    ctx.stroke();
    ctx.globalAlpha = 1;

    // Side hair strands
    ctx.fillStyle = hairColor;
    // Left strand
    ctx.beginPath();
    ctx.moveTo(-34 * s, -8 * s);
    ctx.quadraticCurveTo(-42 * s, 10 * s, -36 * s, 30 * s);
    ctx.quadraticCurveTo(-30 * s, 32 * s, -28 * s, 20 * s);
    ctx.quadraticCurveTo(-30 * s, 5 * s, -30 * s, -5 * s);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = outlineWidth * s;
    ctx.stroke();
    // Right strand
    ctx.beginPath();
    ctx.moveTo(34 * s, -8 * s);
    ctx.quadraticCurveTo(42 * s, 10 * s, 36 * s, 30 * s);
    ctx.quadraticCurveTo(30 * s, 32 * s, 28 * s, 20 * s);
    ctx.quadraticCurveTo(30 * s, 5 * s, 30 * s, -5 * s);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = outlineColor;
    ctx.lineWidth = outlineWidth * s;
    ctx.stroke();

    ctx.restore();
  }

  // === SCREEN FLASH EFFECT ===
  function screenFlash(color, duration) {
    var el = document.createElement('div');
    el.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:9997;' +
      'background:' + (color || '#ffffff') + ';opacity:0.6;transition:opacity ' + ((duration || 300) / 1000) + 's;';
    document.body.appendChild(el);
    requestAnimationFrame(function() {
      el.style.opacity = '0';
    });
    setTimeout(function() {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, (duration || 300) + 100);
  }

  // === DRAMATIC TEXT SLAM ===
  function textSlam(text, color, duration) {
    var el = document.createElement('div');
    el.textContent = text;
    el.style.cssText = 'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%) scale(3);' +
      'pointer-events:none;z-index:9998;font-family:"IBM Plex Mono",monospace;font-size:3rem;font-weight:700;' +
      'color:' + (color || '#ffffff') + ';text-shadow:0 0 30px ' + (color || '#ffffff') + ',0 0 60px ' + (color || '#ffffff') + '44;' +
      'opacity:0;letter-spacing:8px;';
    document.body.appendChild(el);
    requestAnimationFrame(function() {
      el.style.transition = 'transform 0.15s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.1s';
      el.style.transform = 'translate(-50%,-50%) scale(1)';
      el.style.opacity = '1';
    });
    setTimeout(function() {
      el.style.transition = 'opacity 0.5s';
      el.style.opacity = '0';
    }, (duration || 1200) - 500);
    setTimeout(function() {
      if (el.parentNode) el.parentNode.removeChild(el);
    }, (duration || 1200));
  }

  // === ANIME TITLE CARD ===
  function showTitleCard(title, subtitle, color, callback) {
    var overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:9999;' +
      'background:rgba(0,0,0,0.95);display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'opacity:0;transition:opacity 0.3s;';

    // Speed lines background canvas
    var bgCanvas = document.createElement('canvas');
    bgCanvas.width = window.innerWidth;
    bgCanvas.height = window.innerHeight;
    bgCanvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;';
    overlay.appendChild(bgCanvas);

    var titleEl = document.createElement('div');
    titleEl.textContent = title;
    titleEl.style.cssText = 'position:relative;z-index:1;font-family:"IBM Plex Mono",monospace;font-size:4rem;font-weight:700;' +
      'color:' + (color || '#ffffff') + ';letter-spacing:12px;text-shadow:0 0 40px ' + (color || '#ffffff') + '88;' +
      'transform:scaleY(1.2);opacity:0;transition:opacity 0.3s 0.2s;';
    overlay.appendChild(titleEl);

    if (subtitle) {
      var subEl = document.createElement('div');
      subEl.textContent = subtitle;
      subEl.style.cssText = 'position:relative;z-index:1;font-family:"IBM Plex Mono",monospace;font-size:0.9rem;' +
        'color:#888;letter-spacing:6px;margin-top:12px;opacity:0;transition:opacity 0.3s 0.4s;text-transform:uppercase;';
      overlay.appendChild(subEl);
    }

    document.body.appendChild(overlay);

    // Draw speed lines on background
    var bgCtx = bgCanvas.getContext('2d');
    var cx = bgCanvas.width / 2, cy = bgCanvas.height / 2;
    for (var i = 0; i < 40; i++) {
      var angle = (Math.PI * 2 * i / 40);
      var innerR = 100 + Math.random() * 50;
      var outerR = 400 + Math.random() * 300;
      bgCtx.beginPath();
      bgCtx.moveTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR);
      bgCtx.lineTo(cx + Math.cos(angle) * outerR, cy + Math.sin(angle) * outerR);
      bgCtx.strokeStyle = (color || '#ffffff');
      bgCtx.globalAlpha = 0.08 + Math.random() * 0.08;
      bgCtx.lineWidth = 1 + Math.random() * 3;
      bgCtx.stroke();
    }
    bgCtx.globalAlpha = 1;

    requestAnimationFrame(function() {
      overlay.style.opacity = '1';
      titleEl.style.opacity = '1';
      if (subtitle) overlay.children[2].style.opacity = '1';
    });

    setTimeout(function() {
      overlay.style.opacity = '0';
      setTimeout(function() {
        if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
        if (callback) callback();
      }, 400);
    }, 2000);
  }

  // === CRT MONITOR FRAME ===
  function addCRTFrame() {
    if (document.getElementById('anime-crt-frame')) return;
    var frame = document.createElement('div');
    frame.id = 'anime-crt-frame';
    frame.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;pointer-events:none;z-index:9996;' +
      'box-shadow:inset 0 0 100px rgba(0,0,0,0.5),inset 0 0 40px rgba(0,0,0,0.3);' +
      'border:3px solid #1a1a2e;border-radius:8px;';
    document.body.appendChild(frame);
  }

  // === ENCOUNTER SPLASH ===
  function encounterSplash(text, color, portrait) {
    var overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:9998;pointer-events:none;' +
      'display:flex;align-items:center;justify-content:center;';

    // Diagonal slash background
    var slash = document.createElement('div');
    slash.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;' +
      'background:linear-gradient(135deg,transparent 40%,' + (color || '#ff4444') + '22 40%,' + (color || '#ff4444') + '22 60%,transparent 60%);' +
      'opacity:0;transition:opacity 0.15s;';
    overlay.appendChild(slash);

    var textEl = document.createElement('div');
    textEl.textContent = text;
    textEl.style.cssText = 'position:relative;z-index:1;font-family:"IBM Plex Mono",monospace;font-size:2.5rem;font-weight:700;' +
      'color:' + (color || '#ff4444') + ';letter-spacing:6px;text-shadow:0 0 20px ' + (color || '#ff4444') + ';' +
      'transform:translateX(-100px);opacity:0;transition:all 0.2s cubic-bezier(0.16,1,0.3,1);';
    overlay.appendChild(textEl);

    document.body.appendChild(overlay);

    requestAnimationFrame(function() {
      slash.style.opacity = '1';
      textEl.style.transform = 'translateX(0)';
      textEl.style.opacity = '1';
    });

    setTimeout(function() {
      textEl.style.opacity = '0';
      slash.style.opacity = '0';
      setTimeout(function() {
        if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
      }, 300);
    }, 1200);
  }

  // === IMPACT FRAME (white/color flash with radial lines) ===
  function impactFrame(color) {
    var c = document.createElement('canvas');
    c.width = window.innerWidth;
    c.height = window.innerHeight;
    c.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9997;';
    document.body.appendChild(c);
    var ctx = c.getContext('2d');
    var cx = c.width / 2, cy = c.height / 2;

    // White flash
    ctx.fillStyle = color || '#ffffff';
    ctx.globalAlpha = 0.3;
    ctx.fillRect(0, 0, c.width, c.height);

    // Radial impact lines
    ctx.globalAlpha = 0.6;
    for (var i = 0; i < 16; i++) {
      var angle = (Math.PI * 2 * i / 16) + Math.random() * 0.2;
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(angle) * 20, cy + Math.sin(angle) * 20);
      ctx.lineTo(cx + Math.cos(angle) * (200 + Math.random() * 200), cy + Math.sin(angle) * (200 + Math.random() * 200));
      ctx.strokeStyle = color || '#ffffff';
      ctx.lineWidth = 2 + Math.random() * 4;
      ctx.stroke();
    }
    ctx.globalAlpha = 1;

    setTimeout(function() {
      if (c.parentNode) c.parentNode.removeChild(c);
    }, 150);
  }

  // === PERSISTENT SPEED LINES (for backgrounds) ===
  function createSpeedLinesOverlay(color, opacity, direction) {
    if (document.getElementById('anime-speed-lines')) return;
    var c = document.createElement('canvas');
    c.id = 'anime-speed-lines';
    c.width = window.innerWidth;
    c.height = window.innerHeight;
    c.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:9990;opacity:' + (opacity || 0.1) + ';';
    document.body.appendChild(c);
    var ctx = c.getContext('2d');
    var cx = c.width / 2, cy = c.height / 2;

    for (var i = 0; i < 30; i++) {
      var angle = direction !== undefined ? direction + (Math.random() - 0.5) * 0.8 : (Math.PI * 2 * i / 30);
      var innerR = 50 + Math.random() * 100;
      var outerR = Math.max(c.width, c.height);
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR);
      ctx.lineTo(cx + Math.cos(angle) * outerR, cy + Math.sin(angle) * outerR);
      ctx.strokeStyle = color || '#ffffff';
      ctx.globalAlpha = 0.3 + Math.random() * 0.4;
      ctx.lineWidth = 1 + Math.random() * 2;
      ctx.stroke();
    }
    return c;
  }

  // === COLOR UTILITIES ===
  function darkenColor(hex, factor) {
    var r = parseInt(hex.slice(1,3), 16);
    var g = parseInt(hex.slice(3,5), 16);
    var b = parseInt(hex.slice(5,7), 16);
    r = Math.floor(r * factor);
    g = Math.floor(g * factor);
    b = Math.floor(b * factor);
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
  }

  function lightenColor(hex, factor) {
    var r = parseInt(hex.slice(1,3), 16);
    var g = parseInt(hex.slice(3,5), 16);
    var b = parseInt(hex.slice(5,7), 16);
    r = Math.min(255, Math.floor(r + (255 - r) * factor));
    g = Math.min(255, Math.floor(g + (255 - g) * factor));
    b = Math.min(255, Math.floor(b + (255 - b) * factor));
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
  }

  // === PUBLIC API ===
  return {
    addScanlines: addScanlines,
    speedLinesBurst: speedLinesBurst,
    drawPortrait: drawPortrait,
    screenFlash: screenFlash,
    textSlam: textSlam,
    showTitleCard: showTitleCard,
    addCRTFrame: addCRTFrame,
    encounterSplash: encounterSplash,
    impactFrame: impactFrame,
    createSpeedLinesOverlay: createSpeedLinesOverlay,
    darkenColor: darkenColor,
    lightenColor: lightenColor
  };
})();
