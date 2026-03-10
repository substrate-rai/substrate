# Mobile Web Game Development — Key Patterns

Reference ingested 2026-03-09. Source: operator-provided comprehensive guide.

## Critical Mobile Setup

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
```

```css
* { touch-action: none; -webkit-user-select: none; user-select: none; -webkit-tap-highlight-color: transparent; }
html, body { overflow: hidden; position: fixed; width: 100%; height: 100%; overscroll-behavior: none; }
```

```javascript
document.addEventListener('touchmove', e => e.preventDefault(), { passive: false });
document.addEventListener('contextmenu', e => e.preventDefault());
```

## iOS Safari Pitfalls

- Audio requires user interaction first (play silent buffer on first tap)
- 300ms tap delay: fixed by viewport meta + `touch-action: manipulation`
- Rubber-band bounce: `position: fixed` on body + `overscroll-behavior: none`
- Canvas blur: scale by `devicePixelRatio`
- Address bar resize: use `window.visualViewport` for true size
- Touch events: must pass `{ passive: false }` when calling `preventDefault()`

## Game Loop (Fixed Timestep)

```javascript
const TICK_RATE = 1000 / 60;
let lastTime = 0, accumulator = 0;
function gameLoop(timestamp) {
  requestAnimationFrame(gameLoop);
  const cappedDelta = Math.min(timestamp - lastTime, 200);
  lastTime = timestamp;
  accumulator += cappedDelta;
  while (accumulator >= TICK_RATE) { update(TICK_RATE / 1000); accumulator -= TICK_RATE; }
  render(accumulator / TICK_RATE);
}
```

## Performance Budget

- Total JS: < 500KB
- Active objects: < 500
- Draw calls/frame: < 100
- Target: 60fps (accept 30 on low-end)
- Load time: < 3 seconds

## Key Principles

1. One core mechanic, one primary input (tap/swipe/drag)
2. Touch targets: minimum 44px, prefer 48px+
3. Object pooling — never allocate in game loop
4. Integer canvas coordinates (`x | 0`) to avoid sub-pixel rendering
5. Batch canvas draw calls by style (minimize state changes)
6. Offscreen canvas for static backgrounds
7. Procedural assets > external files for single-file games
8. Every touch must produce visible response within 1 frame
9. Short sessions: 1-3 minute play cycles for mobile
10. Portrait orientation preferred for casual games

## Procedural Audio (No Files)

```javascript
// Unlock on first tap
const ctx = new (AudioContext || webkitAudioContext)();
if (ctx.state === 'suspended') await ctx.resume();
const silent = ctx.createBuffer(1, 1, 22050);
const src = ctx.createBufferSource();
src.buffer = silent; src.connect(ctx.destination); src.start(0);
```

Generate tones: frequency sweep for coins, noise decay for explosions, square wave sweep for jumps.

## Framework Decision

- Default: vanilla Canvas (HTML artifacts)
- React artifacts: React for UI + Canvas for rendering
- CDN only if needed: p5.js (~800KB), Kaboom.js (~200KB), Three.js (~600KB for 3D)
