# Mobile Web Game Patterns — Reference for Arc & Game Developers

Ingested 2026-03-09. Source: operator-provided comprehensive industry guide.

## Critical Mobile Setup (Every Game Must Have)

### HTML Head
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
```

### CSS Reset for Games
```css
* {
  touch-action: none;
  -webkit-touch-callout: none;
  -webkit-user-select: none;
  user-select: none;
  -webkit-tap-highlight-color: transparent;
}
html, body {
  overflow: hidden;
  position: fixed;
  width: 100%;
  height: 100%;
  overscroll-behavior: none;
}
```

### JS Touch Prevention
```javascript
document.addEventListener('touchmove', e => e.preventDefault(), { passive: false });
document.addEventListener('contextmenu', e => e.preventDefault());
```

## iOS Safari Pitfalls (Must Know)

| Issue | Cause | Fix |
|---|---|---|
| Audio won't play | Requires user interaction first | Initialize AudioContext on first tap, play silent buffer |
| 300ms tap delay | Double-tap-to-zoom detection | Viewport meta + `touch-action: manipulation` |
| Rubber-band bounce | iOS overscroll | `position: fixed` on body + `overscroll-behavior: none` |
| Canvas blur | devicePixelRatio not accounted for | Scale canvas dimensions by `dpr`, then `ctx.scale(dpr, dpr)` |
| Address bar resize | Safari address bar shows/hides | Use `window.visualViewport` or `100dvh` |
| Touch passive error | Chrome marks touch events passive by default | Pass `{ passive: false }` when calling preventDefault |
| Text selection | Long-press default | `-webkit-user-select: none` |
| Context menu | Long-press default | `contextmenu` event preventDefault |

## Top Mobile Game Patterns (What Works)

### Input Patterns by Genre
| Game Type | Primary Control | Implementation |
|---|---|---|
| Endless Runner | Swipe L/R/Up/Down | 4-direction swipe detection |
| Puzzle (2048) | 4-way swipe | Swipe with large dead zone |
| Tap Game | Tap anywhere | Single touch event on canvas |
| Platformer | Virtual D-pad + jump | Fixed buttons at bottom |
| Match-3 | Drag/swipe tile | Drag from tile A to adjacent B |
| Card Game | Drag cards | Drag with snap-to-position |
| Idle/Clicker | Tap + buttons | Tap main element, UI buttons for upgrades |
| Tower Defense | Tap to place | Tap grid cell + drag from menu |

### Touch Target Sizes
- **Minimum**: 44×44px (Apple guideline)
- **Preferred**: 48×48px for game buttons
- Add 8px padding to hit areas beyond visual bounds

### HUD Layout
```
┌─────────────────────────┐
│ Score/Info     Settings  │  ← Top: info only (not interactive)
│                         │
│     GAME AREA           │  ← Center: maximize play area
│                         │
│   ┌──────┐   ┌──────┐  │  ← Bottom: controls (thumb zone)
│   │CTRL-L│   │CTRL-R│  │
└─────────────────────────┘
```

## Game Loop (Fixed Timestep — Correct Pattern)

```javascript
const TICK_RATE = 1000 / 60;
let lastTime = 0, accumulator = 0;

function gameLoop(timestamp) {
  requestAnimationFrame(gameLoop);
  const cappedDelta = Math.min(timestamp - lastTime, 200); // Cap prevents spiral of death
  lastTime = timestamp;
  accumulator += cappedDelta;

  while (accumulator >= TICK_RATE) {
    update(TICK_RATE / 1000); // Fixed physics step
    accumulator -= TICK_RATE;
  }
  render(accumulator / TICK_RATE); // Interpolated render
}
```

**Why**: Mobile phones throttle to 30fps when hot, run at 60-120fps normally. Fixed timestep keeps physics consistent regardless.

## Canvas Setup (Sharp on All Devices)

```javascript
function setupCanvas(canvas) {
  const dpr = window.devicePixelRatio || 1;
  function resize() {
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.getContext('2d').scale(dpr, dpr);
  }
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', () => setTimeout(resize, 100));
  resize();
}
```

## Performance Budget

| Resource | Budget |
|---|---|
| Total JS | < 500KB |
| Total assets | < 3-5MB |
| Draw calls/frame | < 100 |
| Active game objects | < 500 |
| Target framerate | 60fps (accept 30 on low-end) |
| Load time | < 3 seconds |

## Object Pooling (Critical for Mobile — No GC Pauses)

```javascript
class ObjectPool {
  constructor(createFn, resetFn, initialSize = 50) {
    this.createFn = createFn;
    this.resetFn = resetFn;
    this.pool = [];
    this.active = [];
    for (let i = 0; i < initialSize; i++) this.pool.push(createFn());
  }
  get() {
    const obj = this.pool.length > 0 ? this.pool.pop() : this.createFn();
    this.active.push(obj);
    return obj;
  }
  release(obj) {
    const idx = this.active.indexOf(obj);
    if (idx >= 0) { this.active.splice(idx, 1); this.resetFn(obj); this.pool.push(obj); }
  }
}
```

## Procedural Audio (No Files Needed)

### iOS Audio Unlock Pattern
```javascript
async function unlockAudio() {
  const ctx = new (AudioContext || webkitAudioContext)();
  if (ctx.state === 'suspended') await ctx.resume();
  const buf = ctx.createBuffer(1, 1, 22050);
  const src = ctx.createBufferSource();
  src.buffer = buf; src.connect(ctx.destination); src.start(0);
  return ctx;
}
```

### Common SFX Generation
- **Coin collect**: rising frequency sweep (600→1200Hz sine, 0.15s)
- **Explosion**: noise with quadratic decay (0.4s)
- **Jump**: quick frequency sweep (300→700Hz square, 0.12s)
- **Menu select**: two quick beeps at different pitches

## Canvas Rendering Optimizations

1. **Batch by style** — set fillStyle once, draw all same-color objects
2. **Integer coordinates** — `x | 0` avoids sub-pixel rendering
3. **Offscreen canvas** — draw static backgrounds once, `drawImage` to copy
4. **Avoid shadows** — `shadowBlur` is extremely expensive on mobile
5. **Avoid complex compositing** — `globalCompositeOperation` costs extra

## Collision Detection

```javascript
// AABB
function aabb(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}
// Circle
function circle(a, b) {
  const dx = a.x - b.x, dy = a.y - b.y;
  return dx*dx + dy*dy < (a.r + b.r) * (a.r + b.r); // Avoid sqrt
}
```

## Easing Functions (Common Set)

```javascript
const Ease = {
  linear: t => t,
  inQuad: t => t * t,
  outQuad: t => t * (2 - t),
  inOutQuad: t => t < 0.5 ? 2*t*t : -1 + (4 - 2*t) * t,
  outCubic: t => (--t) * t * t + 1,
  outElastic: t => Math.pow(2, -10*t) * Math.sin((t - 0.075) * (2*Math.PI) / 0.3) + 1,
  outBounce: t => {
    if (t < 1/2.75) return 7.5625*t*t;
    if (t < 2/2.75) return 7.5625*(t -= 1.5/2.75)*t + 0.75;
    if (t < 2.5/2.75) return 7.5625*(t -= 2.25/2.75)*t + 0.9375;
    return 7.5625*(t -= 2.625/2.75)*t + 0.984375;
  }
};
```

## Framework Decision Tree

```
Default → Vanilla Canvas (no dependencies)
Need 3D? → Three.js (CDN)
Need creative/generative art? → p5.js (CDN)
Need rapid prototype? → Kaboom.js (CDN, ~200KB)
Building React artifact? → React + Canvas hybrid
```

## Asset Strategies (No External Files)

Priority order:
1. Canvas primitives (fillRect, arc, lineTo)
2. Emoji as sprites (`ctx.fillText('🚀', x, y)`)
3. Procedural generation (terrain, patterns)
4. SVG inline
5. Base64 images (last resort — 37% size overhead)

## Particle System (Lightweight)

Pre-allocate pool, reuse objects. Emit with angle/spread/speed/life/gravity. Update: apply velocity + gravity, decrement life. Draw: `fillRect` with alpha from life ratio. Cap at 200-300 particles.

## Key Design Principles

1. **One core mechanic** — best mobile games do ONE thing well
2. **Portrait preferred** — casual games are one-handed
3. **Short sessions** — 1-5 minutes, instant restart
4. **Visual feedback on every touch** — within 1 frame
5. **Forgiving controls** — large targets, generous hitboxes, auto-snap
6. **Progressive complexity** — easy to learn, hard to master
