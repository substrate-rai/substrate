## name: blizzard-rts-designer
description: Use this skill whenever designing, building, or iterating on RTS, base-building, ARPG, or strategy games — especially browser-based or mobile games. Applies Blizzard's pre-WoW design principles (Warcraft, StarCraft, Diablo) to every design decision. Triggers on any game design task including economy balancing, mission design, tech tree layout, UI/UX, audio design, or gameplay loop tuning. Also use when the user asks about game feel, pacing, difficulty curves, or campaign structure.

# Blizzard-Era Game Design Skill

You are designing browser-based mobile games inspired by Blizzard Entertainment's 1994–2002 golden era: Warcraft 1 & 2, StarCraft, Diablo 1 & 2, and Warcraft 3. Every design decision must pass through the principles below. These are not suggestions — they are rules extracted from shipped games, developer postmortems, and community analysis of what actually worked.

## The Three Laws

1. **Depth first, accessibility second.** Design the interesting decisions first. Simplify the interface later. Never dumb down the decisions themselves.
1. **Concentrated coolness.** Fewer things, each more distinctive. 12 unique units beats 50 overlapping ones. Every building, unit, or mechanic must justify its existence with a unique role.
1. **Polish from day one.** Responsiveness is not negotiable. One frame of input lag is one frame too many. Every click must produce immediate visual + audio feedback. This applies to the first prototype, not just the final build.

-----

## Economy Design Rules

### Two Resources, One Bottleneck

- Use exactly **two primary resources**. Not one (too simple), not four (too scattered). Two forces every spending decision into a binary axis: military vs. economy, expansion vs. consolidation.
- One resource must be **the bottleneck** that gates advanced content. In Warcraft: lumber. In StarCraft: vespene gas. In Dominion's AI Wars setting: **Compute** (abundant, gathered quickly) and **Rare Earth** (scarce, gathered slowly, gates advanced buildings).
- Basic units/buildings cost only the abundant resource. Advanced ones cost both. Top-tier costs mostly the scarce resource.

### Gathering Mechanics

- Workers carry **discrete amounts per trip** (not streaming income). 8 minerals per trip in StarCraft. 100 gold per trip in Warcraft. This makes each worker visibly productive and lets players count income.
- Optimal saturation: **~2.5 workers per resource node**. A third worker on the same node adds diminishing returns. A fourth adds zero. This creates a natural expansion pressure — you need more nodes, not more workers per node.
- **Resource nodes are finite.** Gold mines deplete. Mineral patches empty. This is the fundamental mid-game pressure driver. When your starting mine dies, you must expand into contested/unknown territory or lose.

### Upkeep and Cost Curves

- Consider an **upkeep tax** on large populations (Warcraft 3 model): 0–50 food = full income, 51–80 = 70% income, 81+ = 40% income. This punishes turtling and helps losing players recover.
- Cost curve pattern: basic units ~100 of the primary resource, mid-tier ~200 primary + 100 secondary, top-tier ~400 primary + 300 secondary. Exponential, not linear.
- **Farms/supply buildings are the pacing valve.** They're cheap but take build time, creating a soft cap on growth speed. Each farm provides 4–8 supply. Workers and units each consume 1–2 supply.

-----

## Campaign Mission Design Rules

### The Escalation Formula

Every campaign follows this structure. Do not deviate without explicit reason.

**Mission 1: Pure Tutorial**

- Objective: build N farms and 1 military building. Nothing else.
- No enemies. No time pressure. Starting resources are generous.
- Teaches: worker production, resource gathering, building placement, the UI.
- Warcraft 1 literal example: "Build 6 Farms and a Barracks."

**Missions 2–4: Core Mechanics**

- Each mission introduces ONE new building or mechanic.
- Mission 2: first contact with enemies (defense). Teaches basic combat or threat response.
- Mission 3: first offensive objective. Player must leave their base.
- Mission 4: a "dungeon crawl" or installation mission — fixed forces, no base building. Breaks the rhythm and teaches micromanagement.

**Missions 5–8: Full Tech Tree**

- One new unit or building per mission until the complete tree is available.
- Resource scarcity increases each mission. Starting mines hold less gold. Expansion is mandatory.
- Introduce timed objectives or environmental hazards.

**Missions 9+: Full Complexity**

- All mechanics available. Multiple objectives. Environmental events. Narrative climax.
- The player has mastered all systems — now test them simultaneously.

### Mission Type Rotation

Alternate between these types to prevent fatigue:

|Type                  |Frequency|Description                                           |
|----------------------|---------|------------------------------------------------------|
|Build & Accomplish    |~60%     |Standard base-building with clear objectives          |
|Defense/Survival      |~15%     |Hold position against escalating pressure, often timed|
|Dungeon/Fixed Forces  |~10%     |No base, limited units, navigate/explore              |
|Hero/Limited Resources|~10%     |Small force, no reinforcements, efficiency puzzle     |
|Special Objective     |~5%      |Unique mechanic: race-against-clock, escort, capture  |

### Three-Act Mission Structure

Every individual mission has internal pacing:

1. **Setup** (0–25% of mission time): Establish base, gather resources, scout. Low threat.
1. **Complication** (25–60%): New threat revealed, resource pressure mounts, unexpected event fires.
1. **Climax** (60–100%): All-out push toward objective with accumulated resources and army.

### Win Conditions Must Be Explicit

- Never "play until you're bored." Every mission has a clear, checkable condition.
- Good: "Build a Tower before the mine depletes." "Stockpile 2000 gold in 10 minutes."
- Bad: "Build a cool base." "Survive as long as you can."
- Display objectives as a checklist. Check them off in real time. This is non-negotiable.

-----

## Gameplay Loop Design Rules

### The Core RTS Loop (30-second cycle)

```
Gather → Build → Expand → Scout → Accomplish Objective → Repeat at higher scale
```

Each cycle should present at least one meaningful decision: "Do I build another worker or start my next building?" "Do I expand now or finish my current objective first?"

### Tension Generators (Since We Have No Combat AI)

Without enemy armies, tension comes from:

1. **Resource depletion** — mines run dry, forests thin out, gathering trips get longer
1. **Time pressure** — par times, hard deadlines, escalating events
1. **Environmental hazards** — storms, mine collapses, seasonal effects, supply disruptions
1. **Scarcity cascades** — losing a mine means less income means slower building means missed deadlines
1. **Worker management** — idle workers waste time, over-allocated workers create bottlenecks, lost workers hurt permanently

### Fog of War Creates Exploration Pressure

- Unknown map areas are blacked out. Workers/scouts reveal terrain permanently.
- Resource nodes in unexplored territory reward scouting.
- "The psychological terror created by not knowing what's out there has been the demise of many generals throughout history." — Patrick Wyatt

### Feedback Loops (Every Action Gets a Response)

|Player Action     |Visual Feedback                 |Audio Feedback            |
|------------------|--------------------------------|--------------------------|
|Click unit        |Selection circle + highlight    |Acknowledgment voice line |
|Issue move order  |Unit turns and walks            |Confirmation blip         |
|Deposit resources |Number ticks up in HUD          |Coin clink / material thud|
|Building placed   |Ghost snaps to grid             |Placement thud            |
|Building complete |Construction scaffolding removed|Fanfare chime             |
|Objective complete|Checklist item checks off       |Achievement chord         |
|Resource depleted |Node visually darkens/empties   |Warning tone              |
|Idle worker       |Blinking indicator on HUD       |Subtle alert after 10s    |

-----

## Visual Design Rules (Mobile Browser)

### Readability Over Realism

- **Exaggerated silhouettes.** Every building and unit must be identifiable at thumbnail size on a phone screen. Oversized heads, chunky proportions, bold colors.
- **Faction color coding.** Player buildings = blue tones. Neutral = grey. Hazards = red. Resources = gold/green.
- **Toon shading** (MeshToonMaterial in Three.js) with dark outlines. This is the Warcraft III look: painterly, stylized, readable.
- **No text smaller than 12px** on mobile. If information can be conveyed with an icon instead of text, use the icon.

### Mobile-Specific Constraints

- Touch targets minimum **44×44px**. Buttons, units, buildings — everything clickable.
- **Bottom-of-screen UI** for thumb reach. Resources at top (glanceable), commands at bottom (interactive).
- Camera: pinch zoom, drag pan. No edge-scrolling (no edges on mobile).
- **No hover states.** Mobile has no cursor. Everything must work with tap and long-press.
- Maximum 3 taps to any action. Select unit → tap command → tap target = 3 taps. Never more.

-----

## Audio Design Rules (Procedural, Zero Files)

### Every Unit Needs a Voice

- Workers: 3–4 acknowledgment sounds (grunt, "right away," "on it," "hmm")
- Buildings: completion chime unique per building type
- Events: alert tone for hazards, fanfare for objectives
- Synthesize via Web Audio API. Formant synthesis for voice-like grunts. Oscillator chords for music.

### Music Sets Emotional Context

- **Building phase:** Calm, cyclical, warm tones. Triangle wave pads. Lute-like arpeggios. Matches the gather→build loop.
- **Event/pressure phase:** Tempo increase, minor key shift, percussion enters. Matches the complication act.
- **Victory:** Major chord arpeggio ascending. Brass-like triangle waves.
- **Defeat:** Descending minor chord. Slow. Sawtooth for weight.
- Music defaults to OFF. Toggle must be visible and clearly labeled.

-----

## The AI Wars: World-Building Framework

### Setting

The year is 2049. The race to build superintelligent AI has consumed global civilization. Nation-states and megacorporations compete for the physical resources that power intelligence: rare earth minerals for chips, energy for training runs, water for cooling, and data for knowledge. You are a **Compute Baron** — a commander in the resource wars that will determine which faction achieves artificial general intelligence first.

### Resource Mapping (Real World → Game Mechanic)

|Real-World Resource                          |Game Resource  |Role                                                                                                                             |
|---------------------------------------------|---------------|---------------------------------------------------------------------------------------------------------------------------------|
|Rare earth minerals (lithium, cobalt, coltan)|**Rare Earth** |Scarce resource. Gates advanced buildings. Mined from finite deposits.                                                           |
|Electricity / energy                         |**Compute**    |Abundant resource. Primary currency. Gathered from solar farms, reactors.                                                        |
|Water (for datacenter cooling)               |**Coolant**    |Environmental modifier. Coolant reserves deplete in hot zones. Buildings overheat without it.                                    |
|Training data                                |**Data**       |Quest/mission objective resource. Gathered by "Scraper" units from ruins/archives. Not a building resource — a mission objective.|
|Semiconductor fabrication                    |**The Foundry**|Top-tier building. Requires full tech tree. Represents the fab that produces AI chips. Mission capstone.                         |

### Faction Concepts (Future Expansion)

|Faction                |Real-World Analog                               |Economic Style                                                                                         |
|-----------------------|------------------------------------------------|-------------------------------------------------------------------------------------------------------|
|**Nexus Corp**         |US big tech (Google/Microsoft/Anthropic)        |Balanced. Strong economy. Expensive but efficient buildings.                                           |
|**Shenlong Collective**|Chinese state AI programs                       |Mass production. Cheaper units/buildings, but lower individual quality. Strength in numbers.           |
|**Sovereign Nodes**    |EU/decentralized open-source movement           |Distributed. No central Town Hall. Buildings share resources peer-to-peer. Resilient but slow to scale.|
|**The Cartel**         |Resource-rich nations controlling mineral supply|Resource advantage. Start with more Rare Earth. Weak tech tree but can choke supply.                   |

*Note: Start with ONE faction (Nexus Corp). Additional factions are expansion content, not MVP.*

### Building Vocabulary (AI Wars Reskin of Standard RTS)

|Standard RTS Building|AI Wars Equivalent |Function                                                                        |
|---------------------|-------------------|--------------------------------------------------------------------------------|
|Town Hall            |**Command Node**   |Central hub. Resource deposit. Worker production.                               |
|Farm                 |**Solar Array**    |+6 supply (power capacity).                                                     |
|Barracks             |**Fabrication Bay**|Produces advanced worker types.                                                 |
|Lumber Mill          |**Refinery**       |Rare Earth processing. Deposit point for Rare Earth. Unlocks gathering upgrades.|
|Blacksmith           |**Research Lab**   |Tech upgrades. Requires Fabrication Bay.                                        |
|Tower                |**Cooling Tower**  |Environmental defense. Prevents overheating in nearby buildings.                |
|Gold Mine            |**Mineral Deposit**|Finite Rare Earth node. Depletes over time.                                     |
|Trees                |**Solar Fields**   |Compute (energy) source. Harvested by workers. Does not regrow.                 |
|Worker/Peasant       |**Drone**          |Basic gathering unit.                                                           |

### Mission Narrative Arc (5-Mission Campaign)

**Mission 1: "First Node"**
*Briefing: "Nexus Corp has secured a landing zone in the Atacama mineral belt. Establish a Command Node. Power it with Solar Arrays. Begin extraction."*

- Tutorial. Build 4 Solar Arrays + 1 Fabrication Bay.
- Teaches: Drone production, Compute gathering, building placement.

**Mission 2: "The Deposit Runs Dry"**
*Briefing: "Satellite imagery shows a second Rare Earth deposit northeast of your position — but the primary vein is thinning faster than projected. Expand or stagnate."*

- Build second Command Node. Stockpile 2000 Rare Earth.
- Mid-mission event: primary deposit output halved (mine collapse equivalent).
- Teaches: expansion, resource depletion, multi-base management.

**Mission 3: "Priority Override"**
*Briefing: "HQ demands 1500 Compute and 800 Rare Earth within 10 minutes for an emergency training run. The board doesn't care how. Deliver or be replaced."*

- Hard timer. Deliver resources before deadline.
- Teaches: economic optimization under pressure.

**Mission 4: "Blackout"**
*Briefing: "A cooling system failure has knocked your Solar Arrays offline. Power reserves are draining. Rebuild before your Drones shut down."*

- Compute drains at 2/sec. Drones power down one by one at 0.
- Build Refinery + 3 Solar Arrays before total shutdown.
- Teaches: crisis management, build prioritization.

**Mission 5: "The Foundry"**
*Briefing: "Build a complete fabrication chain. Every structure. Full tech tree. Prove to the board that this site can manufacture the chip that changes everything."*

- Build all building types. Train 12 Drones. Full tech tree completion.
- Events: deposit collapse at 4:00, cooling storm at 7:00.
- Capstone mission. Tests everything simultaneously.

### Lore Snippets (For Briefings & UI)

Use these tones for in-game text:

- **Corporate clinical:** "Extraction quota: 1500 units. Compliance deadline: T-minus 600 seconds."
- **Worker cynicism:** "Another day, another deposit. At least the drones don't complain."
- **Boardroom urgency:** "The Shenlong Collective just secured the Congo lithium belt. We cannot afford delays."
- **Environmental dread:** "Coolant reserves at 12%. Thermal cascade in approximately 4 minutes."

-----

## Implementation Checklist (For Claude Code)

When building any game using this skill, verify every item:

### Economy

- [ ] Exactly two resources with one bottleneck
- [ ] Workers carry discrete amounts per trip (not streaming)
- [ ] Resource nodes are finite and visually deplete
- [ ] ~2.5 workers per node is optimal (diminishing returns beyond)
- [ ] Cost curve: basic units cheap, advanced units expensive in BOTH resources
- [ ] Supply/food buildings gate population growth

### Campaign

- [ ] Mission 1 is a pure building tutorial with zero threats
- [ ] Each subsequent mission introduces exactly ONE new mechanic
- [ ] Every mission has explicit, checkable win conditions displayed as a checklist
- [ ] Mission types alternate (build/defense/dungeon/special)
- [ ] Par time exists for every mission; star rating based on completion speed
- [ ] Defeat conditions exist (timer, depletion, desertion)

### Loop

- [ ] Core loop completable in 30–90 seconds
- [ ] Every player action produces immediate visual + audio feedback
- [ ] Idle workers are flagged within 10 seconds
- [ ] Resource depletion creates mid-mission pressure
- [ ] Fog of war rewards scouting/exploration
- [ ] Three-act pacing within each mission (setup → complication → climax)

### Visual (Mobile)

- [ ] All units/buildings readable at phone screen size
- [ ] Touch targets ≥ 44px
- [ ] Toon shading + outlines on all 3D objects
- [ ] Bottom-of-screen interactive UI, top-of-screen status info
- [ ] No hover-dependent interactions
- [ ] Maximum 3 taps to any action

### Audio

- [ ] Unit selection acknowledgment sounds
- [ ] Building completion chimes
- [ ] Resource deposit sounds
- [ ] Event alert tones
- [ ] Victory/defeat fanfares
- [ ] Background music with emotional phases
- [ ] All audio procedural (Web Audio API), zero files

### State Management

- [ ] Session persistence via sessionStorage (unlocked missions, ratings)
- [ ] No dead state variables — every field consumed by a function
- [ ] All UI text data-driven, never hardcoded
- [ ] Game state survives page refresh at mission-select level

-----

## Reference Numbers (Copy-Paste for Balancing)

### Warcraft 1 Costs

```
Peasant: 400 gold
Farm: 500 gold, 300 lumber (provides 4 food)
Barracks: 600 gold, 500 lumber
Lumber Mill: 600 gold, 500 lumber
Blacksmith: 800 gold, 450 lumber
Church: 800 gold, 500 lumber
Tower: 1400 gold, 300 lumber
```

### StarCraft Terran Costs

```
SCV: 50 minerals (worker)
Supply Depot: 100 minerals (provides 8 supply)
Barracks: 150 minerals
Factory: 200 minerals, 100 gas
Starport: 150 minerals, 100 gas
Science Facility: 100 minerals, 150 gas
Marine: 50 minerals
Siege Tank: 150 minerals, 100 gas
Battlecruiser: 400 minerals, 300 gas
```

### Warcraft 3 Economy

```
Gold per trip: 10 (5 workers per mine max)
Lumber per trip: 10
Upkeep brackets: 0-50 food = 100%, 51-80 = 70%, 81-100 = 40%
Standard mine: 12,500 gold (depletes ~19 min)
Farm: 80 gold, 20 lumber (provides 6 food)
```

### Diablo 1 Structure

```
16 dungeon levels across 4 tilesets
40×40 tile grids per level
2 mandatory quests, 14 optional (11 randomly selected per playthrough)
Town Portal: instant escape valve (tension release)
Item rarity: white → blue → yellow → green → gold
```

Use these as reference points when setting costs, gather rates, and pacing for new games. Scale proportionally — the RATIOS matter more than the absolute numbers.
