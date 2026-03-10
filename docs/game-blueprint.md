# Substrate Arcade — Master Game Blueprint

## Evidence-Based Cognitive Training Through Withered Technology

---

## Thesis

Games are cognitive drills. Each game trains a specific skill cluster through a single core verb repeated under escalating difficulty. The evidence basis is clear: working memory training transfers across domains, pattern recognition develops through structured "chunking" practice, and executive function — the single strongest predictor of life outcomes — develops through repeated encounters with problems demanding flexible thinking.

The design methodology is Nintendo's: one verb first, withered technology (simplest tool that delivers the feel), teach through play not text, and evergreen replayability through systemic design. Every game ships as a single HTML file. No frameworks. No build steps. Canvas 2D, CSS, vanilla JS. The constraint is the creative brief.

---

## Skill Cluster Taxonomy

| Cluster | What It Trains | Transfer Evidence | Games |
|---------|---------------|-------------------|-------|
| **Working Memory** | Hold and manipulate info in mind | Targeted WM practice improves related cognitive challenges across domains (Jaeggi et al. 2008) | AIRLOCK, BOOTLOADER |
| **Pattern Recognition** | Chunk meaningful patterns as single units | Expert chess players encode positions as chunks, not pieces. ~10,000hrs structured practice (Chase & Simon 1973, Ericsson 2006) | SIGTERM, SIGNAL, SYNTHESIS |
| **Executive Function** | Sequencing, inhibition, task-switching | Single strongest life outcome predictor. Develops through flexible-thinking practice (Diamond 2013, Moffitt et al. 2011) | CASCADE, PIPELINE |
| **Strategic Planning** | Multi-step reasoning under constraints | Resource management games improve planning and consequence prediction (Bavelier et al. 2012) | TACTICS, STACK OVERFLOW, DOMINION, BROADCAST |
| **Deduction** | Evidence evaluation, logical reasoning | Adversarial reasoning tasks improve critical thinking transfer (Halpern 1998) | OBJECTION!, BRIGADE |
| **Causal Reasoning** | Understand cause-effect in complex systems | Systems thinking develops through interactive sandbox exploration (Hmelo-Silver & Azevedo 2006) | SYNTHESIS, MYCELIUM |
| **Spatial Reasoning** | Mental rotation, spatial manipulation | Visual-spatial tasks occupy cognitive resources, reduce intrusive memories (Holmes et al. 2009 — Tetris/PTSD) | AIRLOCK, DRAGONFORCE |
| **Perspective-Taking** | Hold multiple viewpoints, moral reasoning | Narrative choice games improve empathy and perspective-taking (Greitemeyer & Osswald 2010) | PROCESS, SEEKER, V_CYPHER |
| **Creative Problem-Solving** | Generate novel solutions under constraint | Constrained creativity produces more original output than unconstrained (Stokes 2005) | LAPTOP RECORDS, CARD |
| **Meta-Cognition** | Think about your own thinking | Self-monitoring improves learning transfer (Flavell 1979, Schraw 1998) | SUBPROCESS |

---

## Per-Game Blueprints

### TIER 1: STRONG — Refine, Don't Rebuild

---

#### 1. SIGTERM (puzzle/)
- **Core verb:** GUESS — deduce a 5-letter word from positional feedback
- **Skill cluster:** Pattern recognition, vocabulary retrieval
- **Evidence:** Word games train lexical access speed and orthographic pattern chunking. Daily practice builds automaticity (Perfetti 2007).
- **Core loop:** Guess word → receive positional color feedback → narrow possibility space → solve or fail in 6 tries
- **Flow design:** Fixed difficulty (5 letters, 6 guesses). Mastery shows in streak length and average guess count trending down.
- **Feedback:** Streak counter, average guesses, distribution histogram. Player sees chunking improve as they solve in fewer guesses.
- **Redesign:** S — Add guess distribution tracking, share results card, daily streak persistence. Current mechanics are solid.

#### 2. SIGNAL (signal/)
- **Core verb:** DEDUCE — identify compromised nodes from signal patterns
- **Skill cluster:** Pattern recognition, deduction
- **Evidence:** Signal detection theory (Green & Swets 1966). Distinguishing signal from noise is a trainable perceptual skill.
- **Core loop:** Read signal data → form hypothesis → test against evidence → identify threat or clear node
- **Flow design:** Start with 2-node network, obvious anomalies. Scale to 8+ nodes with subtle, multi-factor anomalies.
- **Feedback:** Detection accuracy %, false positive rate. Player sees their signal-to-noise discrimination sharpen.
- **Redesign:** M — Add progressive difficulty scaling. Current version is static. Need procedural puzzle generation for replayability.

#### 3. OBJECTION! (objection/)
- **Core verb:** CONTRADICT — find inconsistencies in testimony using evidence
- **Skill cluster:** Deduction, critical thinking
- **Evidence:** Adversarial reasoning formats (debate, cross-examination) produce measurable gains in argument evaluation (Kuhn 2005).
- **Core loop:** Read testimony → identify claim → search evidence → present contradiction → credibility shifts
- **Flow design:** Case 1 teaches one forensic tool. Each case adds one tool and requires combining. Complexity accumulates through cases, not UI. (1-1 Principle)
- **Feedback:** Cases solved, evidence found %, credibility meter accuracy. Player learns to spot logical gaps faster.
- **Redesign:** M — Apply 1-1 Principle: remove tutorial text, teach tools through first-case design. Add procedural case generation for replayability.

#### 4. TACTICS (tactics/)
- **Core verb:** COMMAND — position and coordinate agents on a grid
- **Skill cluster:** Strategic planning, multi-agent coordination
- **Evidence:** Turn-based strategy develops planning depth and consequence prediction (Boot et al. 2008).
- **Core loop:** Survey battlefield → position agents → execute turn → evaluate outcome → adapt strategy
- **Flow design:** Mission 1: 2 agents, no terrain. Scale to 6 agents, varied terrain, enemy AI that adapts.
- **Feedback:** Turns to complete, agents lost, mission rating. Player sees plans becoming more efficient.
- **Redesign:** M — Add mission rating system (S/A/B/C). Current version lacks mastery feedback. Need turn efficiency scoring.

#### 5. STACK OVERFLOW (deckbuilder/)
- **Core verb:** COMPOSE — build card synergies under resource constraint
- **Skill cluster:** Strategic planning, resource optimization
- **Evidence:** Constrained optimization tasks develop executive function and planning (Diamond 2013). The VRAM limit IS the training — forced trade-offs under scarcity.
- **Core loop:** Draw cards → evaluate synergies → play within VRAM budget → resolve effects → acquire new cards
- **Flow design:** Floor 1: small deck, generous VRAM. Higher floors: larger card pool, tighter VRAM, more complex synergies.
- **Feedback:** Floor reached, deck efficiency score, synergy combos discovered. Player sees deeper card relationships over sessions.
- **Redesign:** S — Solid design. Add synergy discovery log so players track what they've found. Current version lacks meta-progression.

#### 6. PROCESS (novel/)
- **Core verb:** CHOOSE — make consequential decisions between AI agents' perspectives
- **Skill cluster:** Perspective-taking, moral reasoning
- **Evidence:** Interactive narrative with meaningful choice develops empathy and tolerance for ambiguity (Mar & Oatley 2008).
- **Core loop:** Read scene → understand agent perspectives → make choice → see consequences ripple → live with outcome
- **Flow design:** Early choices are low-stakes personality expression. Late choices have cascading consequences across agents. Memory persistence means choices compound.
- **Feedback:** Relationship states, narrative branches unlocked, endings discovered. Player sees how perspective shapes outcome.
- **Redesign:** S — Strong core. Add relationship visualization so player sees their choice patterns across sessions.

#### 7. SUBPROCESS (adventure/)
- **Core verb:** EXPLORE — navigate a system through command parsing
- **Skill cluster:** Meta-cognition, system mental models
- **Evidence:** Text adventures develop systematic exploration skills and mental model building (Malone 1981). Command parsing requires meta-cognitive planning.
- **Core loop:** Read environment description → form hypothesis about system → issue command → observe response → update mental model
- **Flow design:** Start in home directory. Expand to system processes, network, then abstract concept-spaces. Each area teaches one Unix concept.
- **Feedback:** Areas discovered, commands mastered, puzzles solved. Player builds an internal map of system concepts.
- **Redesign:** S — Solid design. Ensure command hint system teaches through context (1-1 Principle), not help text.

#### 8. SEEKER (snatcher/)
- **Core verb:** INVESTIGATE — follow evidence chains through a cyberpunk narrative
- **Skill cluster:** Perspective-taking, consequence tracking
- **Evidence:** Investigation narratives develop hypothesis generation and evidence-weighting skills (similar to scientific reasoning, Lawson 2004).
- **Core loop:** Enter scene → gather clues → interrogate witnesses → form theory → make accusation → face consequences
- **Flow design:** Scene 1: linear evidence chain. Later scenes: branching evidence with red herrings and unreliable witnesses.
- **Feedback:** Clues found %, false accusations, investigation efficiency. Player develops systematic investigation habits.
- **Redesign:** S — Strong investigation mechanics. Ensure Kojima-style tension overlays serve the investigation verb, not just atmosphere.

#### 9. BROADCAST (radio/)
- **Core verb:** MANAGE — allocate resources across competing demands
- **Skill cluster:** Strategic planning, resource management
- **Evidence:** Resource management under competing priorities trains executive function (Burgess et al. 2000 — multitasking paradigm).
- **Core loop:** Choose programming → allocate resources → grow audience → dodge regulatory threats → unlock new stations
- **Flow design:** Station 1: single resource (time). Each unlock adds a resource to juggle (money, equipment, staff, signal strength).
- **Feedback:** Audience size, station diversity, survival time. Player sees resource allocation efficiency improve.
- **Redesign:** S — Audio IS the game. data-no-audio already set. Strong resource management core.

#### 10. SYNTHESIS (chemistry/)
- **Core verb:** COMBINE — mix elements and observe emergent behavior
- **Skill cluster:** Causal reasoning, systems thinking
- **Evidence:** Interactive sandboxes develop causal reasoning when players form and test hypotheses about element interactions (Klahr & Dunbar 1988).
- **Core loop:** Place element → observe behavior → hypothesize interaction → combine elements → discover emergent result → log discovery
- **Flow design:** Start with 3 elements (fire, water, earth). Each discovery unlocks new elements. Complexity is player-driven.
- **Feedback:** Discoveries made / total possible, combination chains found. Player sees their causal model expanding.
- **Redesign:** M — Add discovery journal. Current sandbox lacks structure for hypothesis-testing. Need "what happens if?" prompting and result logging.

---

### TIER 2: MEDIUM — Significant Mechanic Work

---

#### 11. BOOTLOADER (bootloader/)
- **Core verb:** SEQUENCE — order initialization steps under dependency constraints
- **Skill cluster:** Working memory, constraint satisfaction
- **Evidence:** Dependency resolution tasks directly train working memory (holding constraint graph in mind) and procedural planning (Miyake et al. 2000).
- **Core loop:** Read system requirements → identify dependencies → order boot steps → execute → debug failures → optimize sequence
- **Flow design:** Level 1: 3 services, linear dependencies. Scale to 12+ services with circular dependencies, race conditions, optional optimizations.
- **Feedback:** Boot time (steps), dependency violations caught, optimization score. Player sees sequencing speed improve.
- **Redesign:** L — Current version is too abstract. Rebuild as a visual dependency graph puzzle. Player drags services into boot order, sees dependency arrows, gets immediate visual feedback on violations. Each level adds one new constraint type (mutual exclusion, timeout, conditional).

#### 12. BRIGADE (brigade/)
- **Core verb:** RECRUIT — evaluate candidates under incomplete information
- **Skill cluster:** Deduction, decision-making under uncertainty
- **Evidence:** Hiring/selection tasks train information-gathering and evaluation under ambiguity (Gigerenzer & Todd 1999 — fast-and-frugal heuristics).
- **Core loop:** Read candidate profile → interview (ask questions, limited slots) → assess trustworthiness → recruit or reject → see team performance
- **Flow design:** Mission 1: recruit from 3 candidates for 2 slots, clear signals. Scale to 8+ candidates, hidden motives, conflicting references.
- **Feedback:** Team performance score, moles detected, interview efficiency. Player develops faster heuristic judgment.
- **Redesign:** L — Strip the VN wrapper. Rebuild as a focused evaluation game. Each round: limited interview questions, must decide. Wrong hires sabotage the mission. Right hires unlock capabilities.

#### 13. AIRLOCK (airlock/)
- **Core verb:** ROUTE — direct data through sectors under memory constraints
- **Skill cluster:** Working memory, spatial reasoning
- **Evidence:** Spatial routing tasks with capacity constraints train working memory and spatial manipulation simultaneously (Cornoldi & Vecchi 2003).
- **Core loop:** View sector map → identify data to move → plan route within memory limits → execute → purge overflow → optimize
- **Flow design:** Level 1: 4 sectors, 2 data blocks, no time pressure. Scale to 12 sectors, 8 blocks, time pressure, sector failures.
- **Feedback:** Routing efficiency %, memory overflow count, completion time. Player sees spatial planning sharpen.
- **Redesign:** L — Current puzzle mechanics are unclear. Rebuild with clearer visual language: sectors as rooms, data as colored blocks, memory as visible capacity bars. The spatial puzzle must be immediately readable (Yokoi Rule: visual feedback over numeric).

#### 14. DOMINION (warcraft/)
- **Core verb:** EXPAND — grow territory through resource allocation
- **Skill cluster:** Strategic planning, resource management
- **Evidence:** RTS games develop rapid decision-making, divided attention, and cognitive flexibility (Glass et al. 2013 — StarCraft study showed RTS players had faster information processing).
- **Core loop:** Gather resources → build infrastructure → train units → expand territory → defend against threats → balance economy and military
- **Flow design:** Wave 1: no enemies, learn gathering and building. Wave 3: first attack, learn defense. Wave 5+: multi-front pressure requiring prioritization.
- **Feedback:** Territory controlled, resource efficiency ratio, units lost vs produced. Player sees strategic efficiency improve.
- **Redesign:** M — Current RTS is generic. Focus the cognitive training: add a "decision journal" that replays your strategic choices after each game. Show where you over-invested, under-defended, or missed expansion opportunities. The replay IS the training.

#### 15. V_CYPHER (cypher/)
- **Core verb:** COUNTER — respond to opponent's arguments with better rhetoric
- **Skill cluster:** Perspective-taking, verbal reasoning
- **Evidence:** Debate and argumentation practice develops critical thinking and rhetorical analysis (Kuhn 1991). Adversarial dialogue forces perspective-shifting.
- **Core loop:** Read opponent's verse → identify rhetorical weakness → select counter-argument style → deliver response → audience judges
- **Flow design:** Act 1: opponent uses simple appeals. Each act adds rhetorical complexity (analogy, reductio, emotional appeal, misdirection). Player must identify and counter each type.
- **Feedback:** Audience favor %, rhetorical techniques identified, counter accuracy. Player learns to deconstruct arguments faster.
- **Redesign:** L — Currently entertainment-only. Add explicit rhetorical technique identification. Player must TAG the opponent's technique before countering. The tagging IS the cognitive training — it forces meta-analysis of argumentation.

---

### TIER 3: WEAK — Full Rebuild

---

#### 16. CASCADE (cascade/)
- **Old:** Generic arcade momentum game with no cognitive transfer.
- **Core verb:** CHAIN — connect sequential actions under escalating time pressure
- **Skill cluster:** Executive function (sequencing + inhibition)
- **Evidence:** Task-switching under time pressure is a direct executive function training paradigm (Monsell 2003). The key is that the player must PLAN the chain before executing it, engaging both planning and inhibition (resisting impulsive actions that break the chain).
- **Core loop:** See upcoming sequence → plan chain order → execute actions in correct order under momentum timer → chain extends timer → wrong action breaks chain → restart with new sequence
- **Flow design:** Start with 2-element chains (A→B). Scale to 8-element chains with interference elements (items that LOOK like the next step but aren't — training inhibition). Speed increases with chain length.
- **Feedback:** Longest chain, average chain before error, inhibition accuracy (% of interference items correctly ignored). Player sees their sequencing depth and impulse control improve.
- **Redesign:** XL — Complete rebuild. New concept: a cascading chain game where colored elements fall and the player must connect them in the correct sequence. Think Tetris meets Simon Says meets Lumines. The board shows a target sequence at the top. Elements fall. Player must activate them in order, ignoring distractors. Momentum builds with correct chains, speed increases, distractors multiply.
- **Tofu prototype:** Colored squares in a 6x6 grid. Target sequence of 3-8 colors shown at top. Click squares in order. Wrong click = chain break. Right sequence = score + speed up + longer next sequence.

#### 17. PIPELINE (runner/)
- **Old:** Generic endless runner. Reflexes only, no meaningful cognitive training.
- **Core verb:** PARSE — read and react to syntax patterns at speed
- **Skill cluster:** Executive function (task-switching), pattern recognition
- **Evidence:** Rapid categorization under time pressure trains perceptual learning and cognitive flexibility (Ahissar & Hochstein 2004). The Farmer Was Replaced proved real syntax can be gameplay.
- **Core loop:** Code scrolls horizontally → player must categorize each token (keyword, variable, operator, bug) by lane → correct categorization = points → bugs must be caught, keywords must be let through → speed increases
- **Flow design:** Level 1: only bugs vs clean code (binary decision). Level 5: four categories at once (keyword, variable, string, bug). Level 10+: syntax from real languages (Python, JS, Nix).
- **Feedback:** WPM (words parsed per minute), accuracy %, category speed breakdown. Player literally gets faster at reading code.
- **Redesign:** XL — Complete rebuild. New concept: code tokens stream across the screen on parallel tracks. Player sorts them into correct categories by swiping/clicking into lanes. It's a rhythm game for code literacy. Bugs are red, keywords are blue, variables are green — but as difficulty increases, coloring fades and player must read the actual tokens.
- **Tofu prototype:** Single track, tokens scroll right to left. Two buckets: "keep" and "catch." Bugs go in "catch," clean code goes in "keep." Score for speed and accuracy.

#### 18. SUBSTRATE GROWTH (idle/)
- **Old:** Passive idle clicker. No active cognitive engagement.
- **Core verb:** ALLOCATE — distribute limited growth resources across competing investments
- **Skill cluster:** Strategic planning, exponential reasoning
- **Evidence:** Understanding exponential growth is a critical numeracy skill most adults fail at (Wagenaar & Sagaria 1975). Active resource allocation under compound growth trains intuition for exponential dynamics.
- **Core loop:** Earn growth points → choose investment: linear safe option vs exponential risky option → see compound results over time → reinvest → face disruption events that test portfolio balance
- **Flow design:** Phase 1: two options, clear exponential advantage. Phase 2: five options with different growth curves. Phase 3: disruption events that punish over-concentration. Player must diversify.
- **Feedback:** Portfolio growth rate, disruption survival count, allocation efficiency. Player develops intuition for exponential vs linear growth and diversification.
- **Redesign:** XL — Complete rebuild. New concept: growth simulation where player allocates "spores" across different substrate layers (compute, memory, network, community). Each layer grows at different rates. Disruptions hit specific layers. The player who diversifies intelligently grows fastest. NOT passive — requires active reallocation every cycle. Think "Universal Paperclips meets a biology sim."
- **Tofu prototype:** 4 investment buckets. 10 spores per round. Place spores, press "grow," see results. Each bucket has a hidden growth function. Player learns the functions through experimentation.

#### 19. MYCELIUM (mycelium/)
- **Old:** Non-interactive 3D visualization. Just watching.
- **Core verb:** CONNECT — draw network links between nodes to optimize flow
- **Skill cluster:** Causal reasoning, spatial reasoning
- **Evidence:** Network topology tasks develop systems thinking and understanding of emergent properties from local rules (Barabasi 2003). Building networks by hand teaches what random viewing cannot.
- **Core loop:** Nodes appear → player draws connections → resources flow through network → bottlenecks visualized → player reroutes → network efficiency scored → new nodes appear
- **Flow design:** Start with 5 nodes, connect freely. Scale to 20+ nodes with connection limits, flow capacity per link, and node failures that require rerouting. Introduce different node types (hub, leaf, bridge) that have different optimal connection patterns.
- **Feedback:** Network efficiency %, flow throughput, redundancy score (survives N node failures). Player develops intuition for network topology.
- **Redesign:** XL — Complete rebuild. New concept: player IS the mycelium. Grow connections between resource nodes and consumer nodes. Each connection costs energy. Resources flow through your network. Optimize for throughput while maintaining redundancy. Random node deaths test your network's resilience. The visualization is now the game board, not just eye candy.
- **Tofu prototype:** 2D canvas. Resource nodes (green circles) on left, consumer nodes (blue circles) on right. Click-drag to draw connections. Resources flow as animated dots. Score = total flow reaching consumers. Each connection costs 1 energy. Limited energy per round.

#### 20. DRAGONFORCE (dragonforce/)
- **Old:** Army battle sim without strategic depth.
- **Core verb:** FORECAST — predict outcomes of complex multi-variable scenarios
- **Skill cluster:** Strategic planning, probabilistic reasoning
- **Evidence:** Forecasting accuracy is a trainable skill (Tetlock 2015 — superforecasters). Scenario-based prediction with feedback improves calibration and reduces overconfidence.
- **Core loop:** View scenario with multiple variables (terrain, forces, morale, weather) → predict outcome → commit forces based on prediction → observe actual outcome → compare prediction to reality → calibration score updates
- **Flow design:** Battle 1: two variables (numbers + terrain), clear prediction. Scale to 6+ variables with interaction effects. The game SHOWS your prediction vs reality after each battle, training calibration.
- **Feedback:** Calibration score (how close predictions match outcomes), Brier score trending, overconfidence/underconfidence tracking. Player literally gets better at predicting complex outcomes.
- **Redesign:** XL — Complete rebuild. New concept: scenario forecasting game. Before each battle, player sets probability estimates for different outcomes ("70% victory, 20% stalemate, 10% defeat"). After the battle plays out, their calibration is scored. The battles are visual and exciting, but the COGNITIVE TRAINING is the pre-battle forecasting. Think "prediction market meets tactical sim."
- **Tofu prototype:** Simple stat comparison. Two armies with 4 stats each. Player sets confidence slider (0-100%). Battle auto-resolves. Score based on calibration accuracy. After 10 battles, show calibration curve.

#### 21. CARD (card/)
- **Old:** Static info card. Not a game.
- **Core verb:** PITCH — present an idea under severe constraints
- **Skill cluster:** Creative problem-solving, communication under constraint
- **Evidence:** Constrained creativity produces more original output than unconstrained (Stokes 2005). Elevator pitch exercises develop concise communication (Daly & Burch 2016).
- **Core loop:** Receive a random concept + random constraint (30 words, no adjectives, haiku format, etc.) → craft pitch within constraint → submit → receive score based on clarity, completeness, and constraint adherence → iterate
- **Flow design:** Round 1: familiar concept, generous word limit. Scale to abstract concepts with severe constraints. Add audience personas that value different qualities (technical vs emotional vs humorous).
- **Feedback:** Constraint adherence score, clarity rating, pitches completed, best pitch showcase. Player develops concise communication skills.
- **Redesign:** XL — Complete rebuild. New concept: "Substrate Card" becomes a pitch-crafting game. The player must explain Substrate's concepts (or any AI concept) within increasingly tight constraints. Start with "explain Substrate in 100 words," then 50, then 20, then a haiku. Each round the audience changes. The constraint IS the training.
- **Tofu prototype:** Text input box. Random constraint displayed. Character/word counter. Submit button. Score: did you hit the constraint? Did you include key concepts? Simple keyword matching for v1.

#### 22. LAPTOP RECORDS (album/)
- **Old:** AI music generation tool. Creative tool, not cognitive training.
- **Core verb:** CURATE — select and sequence from constrained options to create coherent wholes
- **Skill cluster:** Creative problem-solving, pattern recognition (aesthetic patterns)
- **Evidence:** Curatorial tasks develop aesthetic discrimination and compositional reasoning (Eisner 2002). Sequencing music develops understanding of emotional arc and narrative structure.
- **Core loop:** Receive pool of generated tracks with different moods/tempos → select tracks → arrange in sequence → evaluate album coherence → listener feedback on emotional arc → revise
- **Flow design:** Album 1: 6 tracks, clear mood categories, generous selection. Scale to 12 tracks, subtle mood differences, specific audience expectations (upbeat, reflective, cathartic arc).
- **Feedback:** Album coherence score, listener emotional arc vs intended arc, tracks revised count. Player develops aesthetic sequencing skills.
- **Redesign:** M — Keep the music generation. Add a coherence scoring system that evaluates track sequencing for emotional arc. data-no-audio already set. The game layer is the curation and sequencing, not the generation.

---

## Implementation Order

**Phase 1 — Quick wins (S complexity, 1-2 sessions each):**
1. SIGTERM — Add streak tracking, share card
2. PROCESS — Add relationship visualization
3. SUBPROCESS — Audit hints for 1-1 compliance
4. SEEKER — Audit tension overlays serve investigation
5. BROADCAST — Already strong, minor polish
6. STACK OVERFLOW — Add synergy discovery log

**Phase 2 — Feature additions (M complexity, 2-3 sessions each):**
7. SIGNAL — Procedural puzzle generation
8. OBJECTION! — 1-1 redesign, remove tutorial text
9. SYNTHESIS — Discovery journal, hypothesis prompting
10. DOMINION — Decision journal replay
11. TACTICS — Mission rating system
12. LAPTOP RECORDS — Coherence scoring

**Phase 3 — Major rewrites (L complexity, 3-5 sessions each):**
13. BOOTLOADER — Visual dependency graph puzzle
14. BRIGADE — Focused evaluation game
15. AIRLOCK — Visual spatial routing
16. V_CYPHER — Rhetorical technique tagging

**Phase 4 — Full rebuilds (XL complexity, 5+ sessions each):**
17. CASCADE — Chain sequencing game (executive function)
18. PIPELINE — Code parsing rhythm game
19. SUBSTRATE GROWTH — Active growth allocation sim
20. MYCELIUM — Network building game
21. DRAGONFORCE — Scenario forecasting
22. CARD — Pitch crafting under constraints

---

## Design Checklist (Per Game)

Before writing code:
- [ ] What is the ONE core verb?
- [ ] Can I prototype with shapes and colors only?
- [ ] What is the SIMPLEST technology that makes this verb feel right?
- [ ] Who is the underserved audience?
- [ ] What is the smallest shippable version?
- [ ] What am I explicitly NOT building?

After writing code:
- [ ] Does every on-screen element serve the core verb?
- [ ] Would a new player understand without text instructions?
- [ ] Does the player want to try again after failing?
- [ ] Will the player discover something new on session 10?
- [ ] Is there a simpler way to achieve the same feel?

---

## Evidence Appendix

- Ahissar & Hochstein (2004). Rapid categorization and perceptual learning.
- Barabasi (2003). *Linked: How Everything Is Connected.* Network topology and emergence.
- Bavelier et al. (2012). Action video games improve attention and cognitive control.
- Boot et al. (2008). Strategy games and cognitive flexibility.
- Burgess et al. (2000). Multitasking paradigm and executive function.
- Chase & Simon (1973). Chunking in chess perception.
- Cornoldi & Vecchi (2003). Spatial working memory and visuospatial processing.
- Daly & Burch (2016). Communication under constraint and concision training.
- Diamond (2013). Executive functions as strongest life outcome predictor.
- Eisner (2002). Aesthetic development through curatorial practice.
- Ericsson (2006). Deliberate practice and expert performance.
- Flavell (1979). Meta-cognition and learning transfer.
- Gigerenzer & Todd (1999). Fast-and-frugal heuristics in decision-making.
- Glass et al. (2013). RTS gaming and cognitive flexibility (StarCraft study).
- Green & Swets (1966). Signal detection theory.
- Greitemeyer & Osswald (2010). Prosocial games and empathy.
- Halpern (1998). Critical thinking and adversarial reasoning.
- Hmelo-Silver & Azevedo (2006). Systems thinking through interactive exploration.
- Holmes et al. (2009). Tetris and intrusive memory reduction (PTSD).
- Jaeggi et al. (2008). Working memory training and fluid intelligence transfer.
- Klahr & Dunbar (1988). Scientific reasoning through interactive experimentation.
- Kuhn (1991, 2005). Argumentation and critical thinking development.
- Lawson (2004). Scientific reasoning and hypothesis generation.
- Malone (1981). Text adventures and intrinsic motivation.
- Mar & Oatley (2008). Narrative fiction and empathy development.
- Miyake et al. (2000). Unity and diversity of executive functions.
- Moffitt et al. (2011). Self-control and life outcomes (Dunedin study).
- Monsell (2003). Task switching and executive control.
- Perfetti (2007). Lexical access and reading skill.
- Schraw (1998). Meta-cognitive awareness and learning.
- Stokes (2005). Creativity and constraints.
- Tetlock (2015). *Superforecasting.* Prediction accuracy as trainable skill.
- Wagenaar & Sagaria (1975). Exponential growth intuition failures.
