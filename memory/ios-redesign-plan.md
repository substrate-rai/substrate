# Site Redesign: iOS Home Screen Inspiration

## Source
Operator's personal iPhone home screen (March 2026). Two pages documented.

## Design Language to Translate

### Grid System
- **4-column grid** on mobile, 6-8 columns on desktop
- Three widget sizes:
  - **1x1** — app icon (small card, icon + label)
  - **2x1** — strip widget (calendar-style, shows key data in compact form)
  - **2x2** — rich widget (album art, weather, clock — the hero content)
- Consistent gap between all items (~16px)
- Items snap to grid, no free-floating elements

### Widget Types → Site Sections

| iOS Widget | Substrate Equivalent | Size | Content |
|------------|---------------------|------|---------|
| Clock (2x2) | System Status | 2x2 | Uptime, current time, "operational" status |
| Calendar (2x1) | Latest Post | 2x1 | Most recent blog post title + date |
| Weather (2x2) | System Health | 2x2 | CPU/GPU temp, VRAM usage, disk space |
| Spotify (2x2) | Radio Now Playing | 2x2 | Current station, track name, album art, play button |
| YouTube Music (2x2) | Featured Game | 2x2 | Game screenshot, title, play button |
| Books/Libby (2x2) | Training Q | 2x2 | "Learn AI with Q" CTA card |
| App folders | Page Groups | 1x1 | Grouped links (Arcade folder with game icons, Blog folder, etc.) |
| App icons | Quick Links | 1x1 | Individual pages (About, Staff, Fund, Press, etc.) |

### Visual Properties

**Frosted Glass / Glassmorphism:**
```css
background: rgba(18, 18, 26, 0.7);
backdrop-filter: blur(20px);
-webkit-backdrop-filter: blur(20px);
border: 1px solid rgba(255, 255, 255, 0.08);
border-radius: 22px;  /* iOS squircle */
```

**Notification Badges:**
```css
.badge {
  position: absolute;
  top: -6px;
  right: -6px;
  background: #ff3b30;
  color: white;
  font-size: 0.65rem;
  font-weight: 700;
  min-width: 20px;
  height: 20px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 6px;
  font-family: var(--mono);
}
```
Use for: new blog posts since last visit, unplayed games, unread news

**Color-Coded Widget Tints:**
Each widget gets a subtle background tint based on its section:
- Radio/Music: warm amber (#e8a040 at 15% opacity)
- Arcade/Games: gold (#ffdd44 at 15% opacity)
- Blog/Writing: green (#00e09a at 15% opacity)
- Training/Education: purple (#ff77ff at 15% opacity)
- System/Technical: blue (#8888ff at 15% opacity)
- Fund/Support: coral (#ff6666 at 15% opacity)

**Bottom Dock:**
```
[ Home ] [ Arcade ] [ Radio ] [ Staff ] [ Fund ]
```
Fixed at bottom, always visible, frosted glass background, 5 items max.
Icons + labels, active state highlighted.

**Search Bar:**
Above the dock, a subtle search input:
```
🔍 Search substrate...
```
Searches blog posts, games, staff, pages.

### Interaction Patterns

**Long-press / Hover:** Shows a context menu or preview (like iOS peek)
- Hover on a game widget → shows screenshot + description tooltip
- Hover on a staff widget → shows agent name + role

**Jiggly Edit Mode:** Fun easter egg — triple-click or long-press triggers iOS-style jiggle animation where all widgets shake slightly (purely cosmetic, just for fun)

**Swipe Between Pages:** On mobile, swipe left/right between "home screens" (page 1: overview widgets, page 2: arcade games grid, page 3: blog posts). Dot indicators at bottom.

### Page Layout

```
┌─────────────────────────────────┐
│        substrate  [search]       │  ← minimal header
├─────────────────────────────────┤
│                                 │
│  [Clock/Status 2x2] [Calendar  │  ← widget grid
│                       2x1]     │
│  [Blog] [Arcade] [Staff] [Fund]│  ← 1x1 app icons
│  [Radio Now Playing     2x2]   │
│  [Featured Game         2x2]   │
│  [Training Q            2x2]   │
│  [System Health         2x2]   │
│                                 │
│            · · ·                │  ← page dots
│         🔍 Search               │  ← search bar
├─────────────────────────────────┤
│  [Home] [Arcade] [Radio] [Staff]│  ← dock
└─────────────────────────────────┘
```

### Background
- Full-screen background image (like the sunset wallpaper)
- Could use one of the SD-generated scenes (scene-city.png for cyberpunk vibe)
- Or a custom SD wallpaper: "cyberpunk sunset over digital ocean, dark silhouette, orange and purple sky, wide angle, cinematic"
- Content sits on top with frosted glass cards

### Implementation Notes
- This is a MAJOR redesign — should be a separate branch
- Current homepage (index.md) is a clean terminal aesthetic
- New design coexists or replaces it based on operator preference
- Could A/B test: classic terminal vs iOS widget layout
- Mobile-first: the 4-column grid IS the mobile layout
- Desktop expands to 6-8 columns naturally
- All widgets are interactive — click to navigate, not just display
- LocalStorage tracks "last visit" for notification badge counts
- The radio widget actually plays (embedded mini-player)

### Phase Plan
1. **Design prototype** — Static HTML/CSS of the grid layout with dummy data
2. **Interactive widgets** — Connect to real data (blog posts, game count, system status)
3. **Live widgets** — Radio mini-player, real-time health data
4. **Polish** — Animations, gestures, search, page dots
5. **Launch** — Replace or add as alternate homepage

### Music Taste Note (from screenshots)
- Operator listens to: MC K.K/DJ TG Beats ("Agudo Magico 3"), Metal Gear Rising OST
- Audio Production folder = operator is a music person
- Gaming folder = games are core interest
- This validates: the radio feature, the arcade, the Kojima/Snatcher tribute
- Brazilian funk + Japanese game OSTs + Metal Gear = eclectic, intense, high-energy
- Radio stations should reflect this taste range
