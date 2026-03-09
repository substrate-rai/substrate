# UI/UX Design Best Practices Reference

A comprehensive guide for designing a web-based game arcade and content site.
Compiled March 2026.

---

## Table of Contents

1. [Figma Design System Best Practices](#1-figma-design-system-best-practices)
2. [Canva Design Principles](#2-canva-design-principles)
3. [Mobile-First Responsive Design Patterns](#3-mobile-first-responsive-design-patterns)
4. [Game UI/UX Patterns](#4-game-uiux-patterns)
5. [Dark Theme UI Best Practices](#5-dark-theme-ui-best-practices)
6. [Micro-Interactions and Animation](#6-micro-interactions-and-animation)
7. [Typography for Web Games](#7-typography-for-web-games)
8. [Accessibility in Game UIs](#8-accessibility-in-game-uis)
9. [Component Design Patterns](#9-component-design-patterns)
10. [Performance-Conscious Design](#10-performance-conscious-design)

---

## 1. Figma Design System Best Practices

### Key Principles

- **Three-tier token architecture.** Structure tokens as Primitive (raw hex/px values) -> Semantic (text-primary, surface-success referencing primitives) -> Component (button-radius, card-padding referencing semantics). This indirection enables theme switching without touching component definitions.
- **Variables over styles.** 74% of teams now use Figma Variables for theming. Binding font families, weights, sizes, and line heights to variables lets you switch a single variable and update the entire system's typeface.
- **Modular file structure.** Split monolithic libraries into interconnected, modular files: one for tokens/variables, one per component category, one for documentation. This prevents performance issues in large systems.
- **Code Connect.** Link Figma components directly to production code so developers see actual React/HTML component code rather than auto-generated CSS. This is the 2026 standard for bridging design-dev handoff.
- **Consistent naming conventions.** Use `category/variant/state` naming (e.g., `button/primary/hover`). Add descriptions to every variable and component for self-documentation.

### Specific Techniques

**Spacing scale using an 8px base grid:**
```
--space-1: 4px;    /* 0.5x */
--space-2: 8px;    /* 1x   */
--space-3: 12px;   /* 1.5x */
--space-4: 16px;   /* 2x   */
--space-5: 24px;   /* 3x   */
--space-6: 32px;   /* 4x   */
--space-7: 48px;   /* 6x   */
--space-8: 64px;   /* 8x   */
```

**Color token structure:**
```css
/* Primitive tokens */
--blue-500: #3b82f6;
--gray-900: #111827;

/* Semantic tokens */
--color-primary: var(--blue-500);
--color-surface: var(--gray-900);
--color-text-primary: #e0e0e0;

/* Component tokens */
--button-bg: var(--color-primary);
--card-bg: var(--color-surface);
```

### Common Mistakes

- Building a flat token system with no semantic layer -- forces manual updates across hundreds of components when rebranding.
- Storing themes as duplicate component sets instead of using variable modes.
- Ignoring variable mode performance -- switching modes is 30-60% faster in 2025+ Figma, but only if variables are properly structured.
- Creating components before establishing the token foundation.

### Reference Sites and Tools

- [Untitled UI](https://www.untitledui.com/) -- Most comprehensive free Figma UI kit, follows all current best practices.
- [Figma Schema 2025 recap](https://www.figma.com/blog/schema-2025-design-systems-recap/) -- Official Figma guidance on design systems.
- [Figma Best Practices: Components and Libraries](https://www.figma.com/best-practices/components-styles-and-shared-libraries/) -- Official documentation.

---

## 2. Canva Design Principles

### Key Principles

- **Constraint-based design empowers non-designers.** Templates created by professionals encode design principles (font pairing, color harmony, layout balance) so users only need to swap content, not make design decisions.
- **The Rule of Thirds.** Split layouts into a 3x3 grid. The four intersection points are visual "hot spots" where viewers' eyes naturally gravitate. Place key elements at these intersections.
- **Hierarchy through contrast.** Every layout needs a clear visual hierarchy: one dominant element, supporting elements, and background. Achieve this through size difference (3:1 ratio minimum), weight contrast, and color contrast.
- **Intentional white space.** Empty space is not wasted space -- it creates breathing room, directs attention, and signals premium quality. Canva teaches that cramped designs are the most common amateur mistake.
- **Alignment as invisible glue.** Every element should align to something. The 12-column grid is the standard framework because it divides evenly into halves, thirds, and quarters.

### Specific Techniques

**12-column grid in CSS:**
```css
.grid-container {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 16px;
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 16px;
}

/* Full-width card */
.card-full { grid-column: span 12; }

/* Half-width card */
.card-half { grid-column: span 6; }

/* Third-width card */
.card-third { grid-column: span 4; }

/* Responsive: stack on mobile */
@media (max-width: 768px) {
  .card-half,
  .card-third { grid-column: span 12; }
}
```

**Visual hierarchy through type scale:**
```css
/* Canva-style hierarchy: clear size jumps */
.display  { font-size: 3rem;    font-weight: 800; line-height: 1.1; }
.heading  { font-size: 1.75rem; font-weight: 700; line-height: 1.2; }
.subhead  { font-size: 1.25rem; font-weight: 600; line-height: 1.3; }
.body     { font-size: 1rem;    font-weight: 400; line-height: 1.6; }
.caption  { font-size: 0.875rem;font-weight: 400; line-height: 1.5; }
```

### Common Mistakes

- Using more than 2-3 fonts in a single layout.
- Centering everything -- left-aligned text is easier to read for body copy.
- Ignoring the grid and placing elements by eye.
- Low contrast between text and background (especially on images).
- Filling every pixel -- no breathing room.

### Reference Sites and Tools

- [Canva Design Principles Guide](https://www.canva.com/learn/guide-to-understanding-design-principles/)
- [Canva Grid Design Guide](https://www.canva.com/learn/grid-design/)
- [Canva 25 Tips for Non-Designers](https://www.canva.com/learn/graphic-design-tips-non-designers/)
- [Canva Apps SDK Design Guidelines](https://www.canva.dev/docs/apps/design-guidelines/principles/)

---

## 3. Mobile-First Responsive Design Patterns

### Key Principles

- **Thumb zone architecture.** The bottom 45% of the screen is the "easy zone" (natural thumb arc), the middle 30% is the "natural zone" (comfortable reach), and the top 25% is the "hard-to-reach zone" (requires repositioning). Place primary actions in the easy zone.
- **Bottom navigation outperforms top navigation.** Apps with bottom navigation see 21% faster navigation compared to top menus, directly impacting Day 7 retention rates.
- **Touch targets must be generous.** Apple: minimum 44x44pt. Android Material: minimum 48x48dp with 8dp spacing. Physical minimum: 1cm x 1cm (average fingertip is 1.6-2cm wide, thumb impact area is 2.5cm).
- **Gesture vocabulary is supplemental, not primary.** Support swipe-right (back), swipe-left (forward), swipe-down (refresh/close), swipe-up (more options). But never use gestures as the only interaction method.
- **Progressive disclosure.** Show the most important content first. Use bottom sheets and expandable sections to reveal detail on demand rather than front-loading everything.

### Specific Techniques

**Mobile-first bottom navigation:**
```css
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-around;
  align-items: center;
  height: 56px;
  background: var(--surface-elevated);
  /* Safe area for iPhone notch/home indicator */
  padding-bottom: env(safe-area-inset-bottom);
  z-index: 100;
  border-top: 1px solid var(--border-subtle);
}

.bottom-nav-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  /* Generous touch target */
  min-width: 48px;
  min-height: 48px;
  padding: 8px 12px;
  gap: 4px;
  -webkit-tap-highlight-color: transparent;
}
```

**Responsive breakpoints (mobile-first):**
```css
/* Base: mobile (320px+) */
.container { padding: 16px; }

/* Tablet (768px+) */
@media (min-width: 768px) {
  .container { padding: 24px; max-width: 720px; }
}

/* Desktop (1024px+) */
@media (min-width: 1024px) {
  .container { padding: 32px; max-width: 1200px; }
}

/* Large desktop (1440px+) */
@media (min-width: 1440px) {
  .container { max-width: 1400px; }
}
```

**Touch-friendly tap targets:**
```css
.tap-target {
  /* Visual size can be smaller */
  /* But the tappable area must be at least 48x48 */
  position: relative;
  min-height: 48px;
  min-width: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Expand tap area with pseudo-element if visual element is small */
.icon-button::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 48px;
  height: 48px;
}
```

### Common Mistakes

- Designing desktop-first and squeezing it to mobile.
- Placing critical actions in the top-right corner (hardest to reach one-handed).
- Touch targets smaller than 44px (especially close buttons and icon-only actions).
- Not accounting for `env(safe-area-inset-bottom)` on notched devices.
- Using hover-dependent interactions that have no touch equivalent.

### Reference Sites and Tools

- [Mobile Navigation UX Best Practices 2026](https://www.designstudiouiux.com/blog/mobile-navigation-ux/)
- [Mobile-First UX Patterns 2026](https://tensorblue.com/blog/mobile-first-ux-patterns-driving-engagement-design-strategies-for-2026)
- [UXPin: Responsive Design for Touch Devices](https://www.uxpin.com/studio/blog/responsive-design-touch-devices-key-considerations/)
- [Mobile-First UX: Designing for Thumbs](https://prateeksha.com/blog/mobile-first-ux-designing-for-thumbs-not-just-screens)

---

## 4. Game UI/UX Patterns

### Key Principles

- **The game card is the atomic unit.** Every game portal (Steam, itch.io, Epic) uses card-based layouts as the primary browsing unit. Cards must communicate: title, thumbnail, genre/tags, and a call to action -- all at a glance.
- **Responsive grid with auto-fill.** Use CSS Grid's `auto-fill` with `minmax()` to let cards flow naturally across screen sizes without manual breakpoints for column counts.
- **Hover reveals secondary info.** On desktop, hover states surface descriptions, play counts, ratings, or quick-play buttons. On mobile, this information must be visible by default or accessible via tap.
- **Visual density varies by device.** Desktop game portals show 4-6 cards per row (information-dense). Tablet shows 2-3. Mobile shows 1-2 per row with larger touch targets. itch.io's responsive layout is a strong reference.
- **Detail pages are interstitial, not navigational dead-ends.** Game detail pages should have a prominent "Play" button, back navigation, and related games -- keeping users in a browsing flow.

### Specific Techniques

**Responsive game card grid:**
```css
.game-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
  padding: 20px;
}

.game-card {
  position: relative;
  border-radius: 12px;
  overflow: hidden;
  background: var(--surface-card);
  transition: transform 0.2s ease-out, box-shadow 0.2s ease-out;
}

.game-card:hover {
  transform: translateY(-4px) scale(1.02);
  box-shadow:
    0 8px 25px rgba(0, 0, 0, 0.3),
    0 0 20px rgba(99, 102, 241, 0.15);
}

.game-card-thumbnail {
  aspect-ratio: 16 / 9;
  width: 100%;
  object-fit: cover;
}

.game-card-info {
  padding: 12px 16px;
}

.game-card-title {
  font-size: 1rem;
  font-weight: 600;
  margin: 0 0 4px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.game-card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.game-tag {
  font-size: 0.75rem;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--surface-tag);
  color: var(--text-secondary);
}
```

**Steam-inspired hover overlay:**
```css
.game-card-overlay {
  position: absolute;
  inset: 0;
  background: linear-gradient(
    to top,
    rgba(0, 0, 0, 0.9) 0%,
    rgba(0, 0, 0, 0.4) 40%,
    transparent 100%
  );
  opacity: 0;
  transition: opacity 0.25s ease-out;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 16px;
}

.game-card:hover .game-card-overlay {
  opacity: 1;
}

.play-button {
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s ease;
}

/* On mobile, overlay info is always visible */
@media (max-width: 768px) {
  .game-card-overlay {
    opacity: 1;
    position: relative;
    background: none;
  }
}
```

### Common Mistakes

- Using fixed column counts instead of `auto-fill` / `auto-fit` -- breaks on unusual screen sizes.
- Thumbnail aspect ratios that vary per card, causing jagged grid alignment.
- Relying solely on hover for important information (inaccessible on touch devices).
- Game detail pages without a clear "back to browse" path.
- Not providing loading states for game thumbnails (shows broken layout during load).

### Reference Sites and Tools

- [Game UI Database](https://gameuidatabase.com/) -- 1,300+ games with 55,000+ UI screenshots.
- [Steam Store](https://store.steampowered.com/) -- Reference for card layout, hover states, and detail pages.
- [itch.io](https://itch.io/) -- Strong responsive layout, indie-friendly card design.
- [CodePen: Steam-inspired game card](https://codepen.io/andrewhawkes/pen/RwwOJrO) -- Working CSS example.
- [FreeFrontend: CSS Card Hover Effects](https://freefrontend.com/css-card-hover-effects/) -- 41 working examples.

---

## 5. Dark Theme UI Best Practices

### Key Principles

- **Never use pure black (#000000) backgrounds.** Use dark gray (#121212 per Material Design, or #0a0a0a to #1a1a1a). Pure black creates excessive contrast with text and makes borders invisible. The exception: OLED-optimized modes where true black saves battery.
- **Use near-white text, not pure white.** Pure white (#FFFFFF) on dark backgrounds causes halation (a perceived glow effect around text edges), especially for users with astigmatism. Use #E0E0E0 to #F5F5F5 for body text, reserving pure white for headings only.
- **Convey elevation with lightness, not shadow.** In dark UIs, shadows are invisible. Instead, higher elevation = lighter surface. Material Design 3 uses tonal color overlays derived from the primary color at increasing opacity for each elevation level.
- **Desaturate accent colors.** Fully saturated colors on dark backgrounds feel harsh and are harder to read. Reduce saturation by 10-20% from what you'd use in light mode. Material Design recommends using 200-weight palette colors in dark mode versus 600-weight in light mode.
- **Maintain WCAG contrast ratios.** Minimum 4.5:1 for normal text, 3:1 for large text (18px bold or 24px regular), 3:1 for UI components and graphical objects. Test with tools, not by eye.

### Specific Techniques

**Complete dark theme with CSS custom properties:**
```css
:root {
  /* Surface hierarchy (lighter = more elevated) */
  --surface-base:      #0f0f0f;
  --surface-1:         #1a1a1a;  /* Cards, containers */
  --surface-2:         #242424;  /* Elevated cards, dropdowns */
  --surface-3:         #2e2e2e;  /* Modals, popovers */
  --surface-4:         #383838;  /* Tooltips, highest elevation */

  /* Text hierarchy */
  --text-primary:      #e8e8e8;  /* High emphasis (87% white) */
  --text-secondary:    #a0a0a0;  /* Medium emphasis (60% white) */
  --text-tertiary:     #6b6b6b;  /* Low emphasis / disabled */
  --text-on-primary:   #ffffff;  /* Text on accent-colored backgrounds */

  /* Accent colors (desaturated for dark mode) */
  --accent-primary:    #7c8aff;  /* Indigo-300 weight */
  --accent-success:    #66d9a0;  /* Green, desaturated */
  --accent-warning:    #ffb74d;  /* Amber, desaturated */
  --accent-error:      #ef5350;  /* Red, slightly desaturated */

  /* Borders and dividers */
  --border-subtle:     rgba(255, 255, 255, 0.08);
  --border-default:    rgba(255, 255, 255, 0.12);
  --border-strong:     rgba(255, 255, 255, 0.20);

  /* Glow / focus effects */
  --glow-primary:      rgba(124, 138, 255, 0.25);
  --glow-success:      rgba(102, 217, 160, 0.25);
}
```

**Surface elevation with tonal overlay (Material Design 3 approach):**
```css
/* Base surface + primary color tonal overlay at increasing opacity */
.surface-0  { background: #121212; }
.surface-1  { background: color-mix(in srgb, #121212 95%, var(--accent-primary)); }
.surface-2  { background: color-mix(in srgb, #121212 92%, var(--accent-primary)); }
.surface-3  { background: color-mix(in srgb, #121212 88%, var(--accent-primary)); }
.surface-4  { background: color-mix(in srgb, #121212 84%, var(--accent-primary)); }
.surface-5  { background: color-mix(in srgb, #121212 80%, var(--accent-primary)); }
```

**Glow effect for interactive elements:**
```css
.glow-card {
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.glow-card:hover {
  border-color: var(--accent-primary);
  box-shadow:
    0 0 0 1px var(--accent-primary),
    0 0 20px var(--glow-primary),
    0 4px 12px rgba(0, 0, 0, 0.4);
}

/* Subtle inner glow for active states */
.glow-card:active {
  box-shadow:
    inset 0 0 12px var(--glow-primary),
    0 0 0 1px var(--accent-primary);
}
```

**Dark mode toggle with system preference detection:**
```css
/* System preference: auto dark mode */
@media (prefers-color-scheme: dark) {
  :root {
    --surface-base: #0f0f0f;
    --text-primary: #e8e8e8;
    /* ... dark values ... */
  }
}

/* Manual toggle via data attribute */
[data-theme="dark"] {
  --surface-base: #0f0f0f;
  --text-primary: #e8e8e8;
}

[data-theme="light"] {
  --surface-base: #ffffff;
  --text-primary: #1a1a1a;
}
```

### Common Mistakes

- Pure black (#000000) backgrounds with pure white (#FFFFFF) text -- causes halation and eye strain.
- Using the same saturated accent colors from light mode -- they appear harsh and create accessibility issues on dark backgrounds.
- Relying on `box-shadow` alone for elevation -- shadows are nearly invisible on dark surfaces.
- Not testing contrast ratios for secondary/tertiary text -- light gray on dark gray often fails WCAG.
- Forgetting to adjust image brightness/contrast for dark mode (consider `filter: brightness(0.9)` on images).

### Reference Sites and Tools

- [Material Design 3: Color Roles](https://m3.material.io/styles/color/roles) -- Canonical reference for dark theme color systems.
- [Material Design 3: Elevation](https://m3.material.io/styles/elevation/applying-elevation) -- Tonal elevation specification.
- [Material Design 2: Dark Theme](https://m2.material.io/design/color/dark-theme.html) -- Original dark theme specification with overlay values.
- [Smashing Magazine: Inclusive Dark Mode](https://www.smashingmagazine.com/2025/04/inclusive-dark-mode-designing-accessible-dark-themes/) -- Accessibility-focused approach.
- [CSS-Tricks: Complete Guide to Dark Mode](https://css-tricks.com/a-complete-guide-to-dark-mode-on-the-web/) -- Implementation patterns.
- [LogRocket: Dark Mode UI Best Practices](https://blog.logrocket.com/ux-design/dark-mode-ui-design-best-practices-and-examples/)

---

## 6. Micro-Interactions and Animation

### Key Principles

- **Purpose over decoration.** Every animation must answer "what does this communicate?" -- confirmation (success checkmark), feedback (button press), guidance (attention pulse), or state change (expand/collapse). If it doesn't communicate, cut it.
- **The 200-300ms sweet spot.** Keep transitions under 300ms to maintain perceived responsiveness. 200ms is the ideal for hover/press feedback. Loading/state changes can stretch to 400-500ms. Anything over 500ms feels sluggish.
- **Animate only transform and opacity.** These properties are GPU-composited and run at 60fps without triggering layout/paint. Animating `width`, `height`, `top`, `left`, `padding`, or `margin` causes expensive reflows.
- **Use ease-out for entrances, ease-in for exits.** Elements entering the view should decelerate (ease-out) to feel like they're settling into place. Exiting elements should accelerate (ease-in) to feel like they're leaving quickly. This mirrors physics.
- **Respect motion preferences.** Always implement `prefers-reduced-motion` to disable or reduce animations for users with vestibular disorders.

### Specific Techniques

**Button micro-interaction (press, hover, active):**
```css
.btn {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  background: var(--accent-primary);
  color: var(--text-on-primary);
  font-weight: 600;
  cursor: pointer;
  transition:
    transform 0.15s ease-out,
    box-shadow 0.15s ease-out,
    background-color 0.15s ease;
  will-change: transform;
}

.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
}

.btn:active {
  transform: translateY(0) scale(0.97);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
  transition-duration: 0.05s;
}

/* Focus-visible for keyboard users only */
.btn:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 3px;
}
```

**Card hover lift with glow:**
```css
.card {
  transition:
    transform 0.2s ease-out,
    box-shadow 0.2s ease-out;
}

.card:hover {
  transform: translateY(-4px);
  box-shadow:
    0 12px 24px rgba(0, 0, 0, 0.25),
    0 0 0 1px rgba(124, 138, 255, 0.2);
}
```

**Staggered entrance animation:**
```css
@keyframes fadeSlideUp {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.card {
  animation: fadeSlideUp 0.4s ease-out both;
}

/* Stagger children */
.card:nth-child(1) { animation-delay: 0ms; }
.card:nth-child(2) { animation-delay: 60ms; }
.card:nth-child(3) { animation-delay: 120ms; }
.card:nth-child(4) { animation-delay: 180ms; }

/* Generic stagger with custom property */
.card {
  animation-delay: calc(var(--index, 0) * 60ms);
}
```

**Loading spinner (CSS-only):**
```css
@keyframes spin {
  to { transform: rotate(360deg); }
}

.spinner {
  width: 24px;
  height: 24px;
  border: 3px solid var(--border-subtle);
  border-top-color: var(--accent-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
```

**Respect reduced motion:**
```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Common Mistakes

- Animating `width`, `height`, `left`, or `top` instead of `transform` -- causes jank on lower-end devices.
- Animations longer than 400ms for user-triggered interactions -- feels unresponsive.
- No `prefers-reduced-motion` support -- a WCAG 2.3.3 violation and causes real distress for users with vestibular conditions.
- Using `will-change` on everything -- it reserves GPU memory. Only apply it to elements that actually animate.
- `transition: all` -- transitions every property change, including ones you don't intend. Always list specific properties.

### Reference Sites and Tools

- [CSS/JS Animation Trends 2026 (WebPeak)](https://webpeak.org/blog/css-js-animation-trends/)
- [FrontendTools: Micro-Interactions Guide](https://www.frontendtools.tech/blog/micro-interactions-ui-ux-guide)
- [Josh W. Comeau: Interactive Guide to CSS Transitions](https://www.joshwcomeau.com/animation/css-transitions/)
- [FreeFrontend: 60 CSS Button Hover Effects](https://freefrontend.com/css-button-hover-effects/)
- [CSS-Tricks: prefers-reduced-motion](https://css-tricks.com/almanac/rules/m/media/prefers-reduced-motion/)
- [MDN: prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion)

---

## 7. Typography for Web Games

### Key Principles

- **Sans-serif for UI, monospace for data/code/terminal.** Sans-serif fonts (Inter, system-ui) are the default for body text, navigation, and labels -- they are the most legible on screens at all sizes. Monospace fonts (JetBrains Mono, Fira Code, IBM Plex Mono) work for scores, timers, code displays, and terminal/hacker aesthetics.
- **Fluid typography with clamp().** Use CSS `clamp()` to create font sizes that scale smoothly between minimum and maximum values based on viewport width, eliminating media query breakpoints for type.
- **x-height determines readability at small sizes.** Fonts with larger x-heights (the height of lowercase letters relative to capitals) are more legible at small sizes. Inter, Roboto, and IBM Plex Sans all have generous x-heights.
- **Limit to 2-3 font families maximum.** One for headings (can be a display/personality font), one for body text (readable sans-serif), and optionally one monospace for specialized content. More than three creates visual noise.
- **Line height scales inversely with font size.** Large headings: 1.1-1.2. Body text: 1.5-1.7. Small/caption text: 1.4-1.5. This compensates for how the eye tracks across text at different sizes.

### Specific Techniques

**Fluid typography with clamp():**
```css
:root {
  /* Font scale: fluid between 320px and 1200px viewports */
  --text-xs:   clamp(0.75rem,  0.7rem  + 0.25vw, 0.875rem);
  --text-sm:   clamp(0.875rem, 0.8rem  + 0.35vw, 1rem);
  --text-base: clamp(1rem,     0.9rem  + 0.5vw,  1.125rem);
  --text-lg:   clamp(1.125rem, 0.95rem + 0.75vw, 1.5rem);
  --text-xl:   clamp(1.5rem,   1.1rem  + 1.5vw,  2.25rem);
  --text-2xl:  clamp(2rem,     1.2rem  + 3vw,    3.5rem);
  --text-3xl:  clamp(2.5rem,   1.5rem  + 4vw,    5rem);
}

body {
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
  font-size: var(--text-base);
  line-height: 1.6;
}

h1 { font-size: var(--text-3xl); line-height: 1.1; }
h2 { font-size: var(--text-2xl); line-height: 1.15; }
h3 { font-size: var(--text-xl);  line-height: 1.2; }
```

**Monospace for game elements (scores, timers, terminal):**
```css
.game-score,
.game-timer,
.terminal-text {
  font-family: 'JetBrains Mono', 'Fira Code', 'IBM Plex Mono',
               'Cascadia Code', 'Consolas', monospace;
  /* Tabular nums keep digits the same width for counters */
  font-variant-numeric: tabular-nums;
  letter-spacing: 0.02em;
}

/* Slashed zero for disambiguation in scores/codes */
.game-code {
  font-feature-settings: 'zero' 1;
}
```

**Font loading strategy (prevent FOUT/FOIT):**
```css
/* Preload critical fonts in HTML <head> */
/* <link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin> */

@font-face {
  font-family: 'Inter';
  src: url('/fonts/inter.woff2') format('woff2');
  font-display: swap; /* Show fallback immediately, swap when loaded */
  font-weight: 100 900;
}

/* Size-adjust fallback to minimize layout shift */
@font-face {
  font-family: 'Inter-fallback';
  src: local('Arial');
  size-adjust: 107%;
  ascent-override: 90%;
  descent-override: 22%;
  line-gap-override: 0%;
}

body {
  font-family: 'Inter', 'Inter-fallback', system-ui, sans-serif;
}
```

### Common Mistakes

- Using only `vw` units for font size -- text won't scale when users zoom (WCAG failure). Always include a `rem` component via `clamp()`.
- Monospace for body text -- significantly slower to read than proportional fonts for paragraph content.
- Not using `font-variant-numeric: tabular-nums` for numbers that update (scores, timers, prices) -- causes layout jitter as digit widths change.
- Loading too many font weights/styles -- each weight is ~20-50KB. Load only what you use (typically 400, 500, 600, 700).
- Not setting `font-display: swap` -- causes invisible text (FOIT) during font loading.

### Reference Sites and Tools

- [Smashing Magazine: Modern Fluid Typography with CSS Clamp](https://www.smashingmagazine.com/2022/01/modern-fluid-typography-css-clamp/)
- [Fluid Typography Tool](https://fluidtypography.com/) -- Interactive calculator for clamp() values.
- [Clamp Generator: Font Size Typescale](https://clampgenerator.com/tools/font-size-typescale/)
- [Figma: Best Fonts for Websites 2026](https://www.figma.com/resource-library/best-fonts-for-websites/)
- [Figma: Typography in Design Guide](https://www.figma.com/resource-library/typography-in-design/)
- [NN/Group: Typography for Glanceable Reading](https://www.nngroup.com/articles/glanceable-fonts/)
- [Hacking C++: Comprehensive Monospace Coding Fonts 2026](https://hackingcpp.com/dev/coding_fonts)

---

## 8. Accessibility in Game UIs

### Key Principles

- **Never rely on color alone.** Use shapes, icons, patterns, or text labels as redundant channels. This is WCAG 1.4.1 (Use of Color) and critical for the 8% of males with color vision deficiency. The Okabe-Ito palette provides 8 colors safe for all types of color blindness.
- **All interactive elements must be keyboard-accessible.** Every button, link, game control, and form element must be reachable via Tab, activatable via Enter/Space, and dismissable via Escape. Test by unplugging your mouse.
- **Focus indicators must be visible and high-contrast.** WCAG 2.4.11 (Focus Appearance) requires focus indicators with at least 3:1 contrast against adjacent colors and a minimum visible area. Never remove the default outline without providing a better alternative.
- **Provide text alternatives for game state.** Screen readers need to know what's happening: use `aria-live` regions for score changes, `aria-label` for icon-only buttons, `role` attributes for custom widgets, and meaningful `alt` text for game images.
- **Respect user preferences.** Implement `prefers-reduced-motion`, `prefers-color-scheme`, and `prefers-contrast`. Provide in-game options for text size, audio descriptions, and input remapping.

### Specific Techniques

**Keyboard-accessible custom game button:**
```html
<div class="game-button"
     role="button"
     tabindex="0"
     aria-label="Play SIGTERM word puzzle"
     onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();this.click();}">
  <span class="game-icon" aria-hidden="true">></span>
  Play
</div>
```

**Focus-visible styling (keyboard-only focus ring):**
```css
/* Remove default outline for all users */
*:focus {
  outline: none;
}

/* Restore visible focus ring for keyboard users only */
*:focus-visible {
  outline: 2px solid var(--accent-primary);
  outline-offset: 3px;
  border-radius: 4px;
}

/* High contrast focus for dark backgrounds */
.dark-surface *:focus-visible {
  outline: 2px solid #ffffff;
  outline-offset: 3px;
  box-shadow: 0 0 0 4px rgba(0, 0, 0, 0.5);
}
```

**Live region for game score updates:**
```html
<div class="score-display"
     aria-live="polite"
     aria-atomic="true"
     role="status">
  Score: <span id="score">0</span>
</div>

<!-- For critical game events (game over, level up) -->
<div class="game-alerts"
     aria-live="assertive"
     role="alert"
     class="sr-only">
  <!-- Injected by JS: "Game Over! Final score: 42" -->
</div>
```

**Screen-reader-only text utility:**
```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

**Color-blind-safe palette (Okabe-Ito):**
```css
:root {
  /* Okabe-Ito palette: safe for protanopia, deuteranopia, tritanopia */
  --cb-orange:    #E69F00;
  --cb-skyblue:   #56B4E9;
  --cb-green:     #009E73;
  --cb-yellow:    #F0E442;
  --cb-blue:      #0072B2;
  --cb-vermilion: #D55E00;
  --cb-purple:    #CC79A7;
  --cb-black:     #000000;
}

/* Always pair color with a secondary indicator */
.status-success {
  color: var(--cb-green);
  /* Icon or text as backup: */
}
.status-success::before {
  content: '\2713'; /* checkmark */
  margin-right: 4px;
}

.status-error {
  color: var(--cb-vermilion);
}
.status-error::before {
  content: '\2717'; /* X mark */
  margin-right: 4px;
}
```

**Skip navigation for game pages:**
```html
<a href="#game-content" class="skip-link">Skip to game</a>

<style>
.skip-link {
  position: absolute;
  top: -100%;
  left: 16px;
  padding: 12px 24px;
  background: var(--accent-primary);
  color: var(--text-on-primary);
  border-radius: 0 0 8px 8px;
  z-index: 1000;
  transition: top 0.2s ease;
}

.skip-link:focus {
  top: 0;
}
</style>
```

### Common Mistakes

- Removing `:focus` outlines globally with `outline: none` and providing no `:focus-visible` replacement.
- Using only color to indicate game state (correct = green, wrong = red) without icons, symbols, or text.
- Custom interactive elements without `role`, `tabindex`, and keyboard event handlers.
- Score updates invisible to screen readers (no `aria-live` region).
- Animations with no `prefers-reduced-motion` support -- can cause nausea and migraines.
- Focus trapping users inside game canvases with no keyboard exit path (violates WCAG 2.1.2 No Keyboard Trap).

### Reference Sites and Tools

- [WCAG 2.2 Full Checklist 2026](https://web-accessibility-checker.com/en/blog/wcag-2-2-checklist-2026)
- [WebAIM: Keyboard Accessibility](https://webaim.org/techniques/keyboard/)
- [WebAIM WCAG 2 Checklist](https://webaim.org/standards/wcag/checklist)
- [Section508.gov: Accessible Fonts and Typography](https://www.section508.gov/develop/fonts-typography/)
- [Coloring for Colorblindness](https://davidmathlogic.com/colorblind/) -- Interactive palette simulator.
- [Visme: Color Blind Friendly Palette Guide](https://visme.co/blog/color-blind-friendly-palette/)
- [Filament Games: WCAG Accessibility Glossary for Game Devs](https://www.filamentgames.com/blog/accessibility-terms-for-game-developers-a-wcag-2-1-aa-glossary/)
- [TestDevLab: Video Game Accessibility](https://www.testdevlab.com/blog/video-game-accessibility-testing)

---

## 9. Component Design Patterns

### Key Principles

- **Cards are the universal container.** Cards group related content (image + title + metadata + action) into scannable, tappable units. They work across screen sizes, can be arranged in grids or lists, and carry a single focused interaction.
- **Bottom sheets replace modals on mobile.** Bottom sheets are 75% less disruptive than center modals, sit in the thumb zone, support snap points (peek, half, full), and allow partial interaction with background content. Use CSS scroll-snap for native-feeling snap behavior.
- **Tooltips for guidance, modals for decisions.** Tooltips are 75% less disruptive and should be the default for contextual help. Reserve modals for high-stakes moments: confirmations, destructive actions, critical information that must be acknowledged.
- **Carousels: use sparingly, with controls.** Carousels have notoriously low engagement on later slides. If you use them: show peek indicators of adjacent items, provide dot/arrow navigation, support swipe, never autoplay (it violates WCAG 2.2.2).
- **Tab bars: 3-5 items maximum.** Bottom tab bars work best with 3-5 items, each with an icon + short label. More than 5 causes overcrowding and unreadable labels. Use a "More" menu for overflow.

### Specific Techniques

**Card component with consistent structure:**
```css
.card {
  display: flex;
  flex-direction: column;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  overflow: hidden;
  transition: transform 0.2s ease-out, box-shadow 0.2s ease-out;
}

.card-media {
  aspect-ratio: 16 / 9;
  overflow: hidden;
}

.card-media img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform 0.3s ease-out;
}

.card:hover .card-media img {
  transform: scale(1.05);
}

.card-body {
  padding: 16px;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.card-actions {
  padding: 12px 16px;
  border-top: 1px solid var(--border-subtle);
  display: flex;
  gap: 8px;
}
```

**Bottom sheet with CSS scroll-snap:**
```css
.bottom-sheet-container {
  position: fixed;
  inset: 0;
  z-index: 200;
  overflow-y: auto;
  scroll-snap-type: y mandatory;
  overscroll-behavior: contain;
}

/* Backdrop / spacer that fills most of the screen */
.bottom-sheet-backdrop {
  height: calc(100vh - 200px);
  scroll-snap-align: start;
}

/* The sheet content */
.bottom-sheet {
  min-height: 200px;
  max-height: 90vh;
  background: var(--surface-2);
  border-radius: 16px 16px 0 0;
  padding: 16px;
  scroll-snap-align: start;
}

/* Drag handle */
.bottom-sheet-handle {
  width: 40px;
  height: 4px;
  background: var(--border-strong);
  border-radius: 2px;
  margin: 0 auto 16px;
}

/* Snap points for different heights */
.snap-peek   { scroll-snap-align: start; height: 30vh; }
.snap-half   { scroll-snap-align: start; height: 50vh; }
.snap-full   { scroll-snap-align: start; height: 90vh; }
```

**Tab bar component:**
```css
.tab-bar {
  display: flex;
  justify-content: space-around;
  background: var(--surface-1);
  border-top: 1px solid var(--border-subtle);
  padding: 4px 0;
  padding-bottom: env(safe-area-inset-bottom);
}

.tab-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 8px 12px;
  min-width: 48px;
  min-height: 48px;
  color: var(--text-tertiary);
  text-decoration: none;
  font-size: 0.625rem;
  font-weight: 500;
  transition: color 0.15s ease;
}

.tab-item[aria-selected="true"],
.tab-item.active {
  color: var(--accent-primary);
}

.tab-item-icon {
  width: 24px;
  height: 24px;
}
```

**Tooltip (CSS-only, accessible):**
```css
.tooltip-trigger {
  position: relative;
}

.tooltip-trigger[aria-describedby]::after {
  content: attr(data-tooltip);
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translateX(-50%);
  padding: 6px 12px;
  background: var(--surface-4);
  color: var(--text-primary);
  font-size: 0.8125rem;
  border-radius: 6px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.15s ease;
}

.tooltip-trigger:hover::after,
.tooltip-trigger:focus-visible::after {
  opacity: 1;
}
```

### Common Mistakes

- Centering modals on mobile -- they end up in the hard-to-reach zone. Use bottom sheets instead.
- Autoplay carousels -- violates WCAG, frustrates users trying to read content.
- Cards without consistent aspect ratios for images -- creates a ragged, unprofessional grid.
- Tab bars with more than 5 items -- labels get truncated or overlap.
- Tooltips triggered only by hover -- invisible on touch devices. Always also trigger on focus.
- Bottom sheets without a visible handle/drag indicator -- users don't know they can interact.

### Reference Sites and Tools

- [Material Design 3: Cards](https://m3.material.io/components/cards/guidelines) -- Canonical card specification.
- [Material Design 2: Cards](https://m2.material.io/components/cards) -- Additional card patterns.
- [Material Components Overview (Android)](https://developer.android.com/design/ui/mobile/guides/components/material-overview)
- [UXPin: Card Design UI](https://www.uxpin.com/studio/blog/card-design-ui/)
- [Plotline: Mobile App Modals 2026](https://www.plotline.so/blog/mobile-app-modals)
- [viliket: Native-like Bottom Sheets on the Web](https://viliket.github.io/posts/native-like-bottom-sheets-on-the-web/)
- [pure-web-bottom-sheet (GitHub)](https://github.com/viliket/pure-web-bottom-sheet)

---

## 10. Performance-Conscious Design

### Key Principles

- **Perceived performance matters more than actual performance.** A site that shows a skeleton screen at 100ms feels faster than one that shows a blank screen for 800ms then renders everything at once. Design for time-to-first-meaningful-paint.
- **CSS-first, JavaScript-second.** CSS transitions, animations, `scroll-snap`, `scroll-driven animations`, and `content-visibility` are GPU-accelerated and don't block the main thread. Reach for JavaScript only when CSS cannot express the interaction.
- **Lazy load everything below the fold, eagerly load everything above it.** Use `loading="lazy"` on images below the fold. Never lazy-load above-the-fold hero images or LCP elements. Set explicit `width` and `height` on images to prevent Cumulative Layout Shift.
- **Skeleton screens bridge the gap.** Replace loading spinners with skeleton screens that mirror the layout shape of incoming content. Users perceive skeleton screens as faster because they provide spatial context for what's loading.
- **Inline critical CSS, defer the rest.** Extract the CSS needed for above-the-fold rendering and inline it in `<head>`. Load remaining CSS asynchronously with `media="print" onload="this.media='all'"` or `rel="preload"`.

### Specific Techniques

**Skeleton screen (pure CSS):**
```css
.skeleton {
  background: var(--surface-1);
  border-radius: 8px;
  position: relative;
  overflow: hidden;
}

.skeleton::after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(
    90deg,
    transparent 0%,
    rgba(255, 255, 255, 0.06) 50%,
    transparent 100%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s ease-in-out infinite;
}

@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Skeleton shapes matching real content */
.skeleton-title {
  height: 1.5rem;
  width: 60%;
  margin-bottom: 8px;
}

.skeleton-text {
  height: 1rem;
  width: 100%;
  margin-bottom: 6px;
}

.skeleton-text:last-child {
  width: 80%;
}

.skeleton-image {
  aspect-ratio: 16 / 9;
  width: 100%;
}
```

**Native lazy loading with CLS prevention:**
```html
<!-- Above the fold: eager load, fetchpriority high -->
<img src="hero.webp"
     alt="Hero image"
     width="1200"
     height="675"
     fetchpriority="high"
     decoding="async">

<!-- Below the fold: lazy load with dimensions -->
<img src="game-thumb.webp"
     alt="Game thumbnail"
     width="400"
     height="225"
     loading="lazy"
     decoding="async">
```

**content-visibility for offscreen sections:**
```css
/* Tell the browser to skip rendering offscreen sections */
.game-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 600px; /* estimated height */
}

/* This can reduce initial render time by 50%+ for long pages */
```

**Critical CSS inlining pattern:**
```html
<head>
  <!-- Critical CSS inline -->
  <style>
    /* Only above-the-fold styles here */
    :root { --surface-base: #0f0f0f; --text-primary: #e8e8e8; }
    body { margin: 0; background: var(--surface-base); color: var(--text-primary); }
    .header { /* ... */ }
    .hero { /* ... */ }
  </style>

  <!-- Non-critical CSS: load async -->
  <link rel="preload" href="/css/main.css" as="style"
        onload="this.onload=null;this.rel='stylesheet'">
  <noscript><link rel="stylesheet" href="/css/main.css"></noscript>
</head>
```

**CSS-only effects that replace JavaScript:**
```css
/* Smooth scroll without JS */
html {
  scroll-behavior: smooth;
}

/* Scroll-snap carousel without JS */
.carousel {
  display: flex;
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none; /* hide scrollbar on Firefox */
  gap: 16px;
  padding: 16px;
}

.carousel::-webkit-scrollbar { display: none; }

.carousel-item {
  scroll-snap-align: start;
  flex: 0 0 280px;
}

/* Intersection-based fade-in without JS (scroll-driven animations) */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}

.reveal {
  animation: fadeIn linear both;
  animation-timeline: view();
  animation-range: entry 0% entry 30%;
}

/* Sticky header shadow on scroll (no JS) */
.header {
  position: sticky;
  top: 0;
  z-index: 100;
  animation: headerShadow linear both;
  animation-timeline: scroll();
  animation-range: 0px 100px;
}

@keyframes headerShadow {
  to { box-shadow: 0 2px 12px rgba(0, 0, 0, 0.3); }
}
```

**Image format and sizing strategy:**
```html
<!-- Modern format with fallback -->
<picture>
  <source srcset="thumb.avif" type="image/avif">
  <source srcset="thumb.webp" type="image/webp">
  <img src="thumb.jpg" alt="Game thumbnail"
       width="400" height="225"
       loading="lazy" decoding="async">
</picture>
```

### Common Mistakes

- Lazy loading above-the-fold images -- delays LCP (Largest Contentful Paint) and hurts Core Web Vitals.
- Images without `width` and `height` attributes -- causes Cumulative Layout Shift as images load.
- Using JavaScript for animations that CSS can handle (scroll effects, hover states, transitions).
- Loading all CSS upfront in a single blocking stylesheet -- delays first render.
- Skeleton screens that don't match actual content layout -- creates a jarring transition when real content loads.
- `scroll-behavior: smooth` without `prefers-reduced-motion` override -- forces smooth scrolling on motion-sensitive users.
- Using GIFs or PNGs where WebP or AVIF would be 50-80% smaller.

### Reference Sites and Tools

- [FreeCodeCamp: How to Use Skeleton Screens](https://www.freecodecamp.org/news/how-to-use-skeleton-screens-to-improve-perceived-website-performance/)
- [LogRocket: Skeleton Loading Screen Design](https://blog.logrocket.com/ux-design/skeleton-loading-screen-design/)
- [FreeFrontend: 12 CSS Skeleton Loadings](https://freefrontend.com/css-skeleton-loadings/)
- [618 Media: Performance with CSS Best Practices 2025](https://618media.com/en/blog/performance-with-css-best-practices/)
- [MDN: Lazy Loading](https://developer.mozilla.org/en-US/docs/Web/Performance/Guides/Lazy_loading)
- [DebugBear: Lazy Load Background Images](https://www.debugbear.com/blog/lazy-load-background-images-intersection-observer)
- [CodePen: Pure CSS Skeleton Loading Animation](https://codepen.io/maoberlehner/pen/bQGZYB)

---

## Quick Reference: Key Numbers

| Metric | Value | Source |
|--------|-------|--------|
| Minimum touch target | 48x48dp (Android), 44x44pt (Apple) | Material Design, Apple HIG |
| Optimal transition duration | 200-300ms | Multiple UX research |
| Text contrast ratio (AA) | 4.5:1 normal, 3:1 large | WCAG 2.2 |
| UI component contrast (AA) | 3:1 | WCAG 2.2 |
| Focus indicator contrast | 3:1 against adjacent | WCAG 2.4.11 |
| Dark mode base surface | #121212 | Material Design |
| Dark mode text (high emphasis) | 87% white / #E0E0E0 | Material Design |
| Dark mode text (medium emphasis) | 60% white / #A0A0A0 | Material Design |
| Max fonts per page | 2-3 families | Typography best practice |
| Max tab bar items | 5 | Mobile UX research |
| Bottom sheet snap points | 3 (peek, half, full) | iOS/Android convention |
| Skeleton shimmer duration | 1.5-2s | UX convention |
| Image formats (preference) | AVIF > WebP > JPEG | Performance best practice |

---

## Quick Reference: The Okabe-Ito Color-Blind-Safe Palette

```
Orange:          #E69F00
Sky Blue:        #56B4E9
Bluish Green:    #009E73
Yellow:          #F0E442
Blue:            #0072B2
Vermilion:       #D55E00
Reddish Purple:  #CC79A7
Black:           #000000
```

Safe for protanopia, deuteranopia, tritanopia, and grayscale reproduction.
