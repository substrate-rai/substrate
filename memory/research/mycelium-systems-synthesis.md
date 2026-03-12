# Mycelium → Substrate: Systems Synthesis

Research compiled: 2026-03-12
Sources: 3 parallel deep research tracks (biology, AI architectures, transfer analysis)

---

## Part 1: The 9 Systems of Mycelium

Real mycelium operates through 9 distinct biological systems. Each is described here as a mechanism, stripped of metaphor, then mapped to an implementable software pattern.

---

### System 1: Polarized Tip Growth (The Spitzenkörper)

**Biology:** Hyphae grow only at their tips. A vesicle-routing organelle called the Spitzenkörper (SPK) acts as a supply center — 38,000 vesicles per minute fuse at the tip in *Neurospora crassa*. The SPK's position within the tip determines growth direction. Displace it sideways and the hypha turns. Remove it and growth stops. Growth is not centrally directed — each tip is autonomous, responding to its local SPK position.

**System property:** Distributed autonomous exploration. Each agent is a growing tip. The tip decides its own direction based on local conditions. There is no global growth plan.

**Substrate implementation: Autonomous agent cycles.**
- Each agent runs independently on its own timer
- Each agent reads its local context (its memory files, the blackboard) and decides its next action
- No orchestrator tells agents what to do — agents choose based on local signals
- The "SPK" is the agent's prompt + voice file + current context injection — it determines the direction of that agent's output
- Repositioning the SPK = updating an agent's voice file or priority signals to redirect its focus

---

### System 2: Branching by Saturation

**Biology:** New branches form when vesicle production exceeds the current tip's consumption rate. Temperature increases, nutrient abundance, or slowed tip growth cause vesicle buildup in subapical regions. The GTPase Cdc42 activates polarisome machinery at the new branch point. Septins prevent branches from forming too close to existing ones (spatial patterning). The NOX/ROS system suppresses ectopic branching to maintain apical dominance.

**System property:** New initiatives spawn when existing ones are saturated, not by top-down planning. Anti-clustering prevents redundant work.

**Substrate implementation: Demand-driven agent spawning.**
- When an agent's output queue fills (e.g., Byte has 20 unprocessed stories), the system signals that domain needs more capacity
- New agent instances or subtasks spawn to handle overflow
- Anti-clustering: a domain registry prevents two agents from working the same topic simultaneously
- Suppression: a "cooldown" period after spawning prevents runaway branching

---

### System 3: Chemotropic Navigation

**Biology:** Hyphae navigate nutrient gradients using their own nutrient transporters as sensors (proven in *A. nidulans*, 2024). Ammonium permeases detect nitrogen, nitrate transporters detect nitrate, glucose induces positive chemotropism. The tip has a proton-free zone (PmaA pumps elsewhere), enabling pH gradient sensing. Crucially, metabolic capacity is required — the hypha must be able to *use* the nutrient to sense it.

**System property:** Agents navigate toward opportunity using the same mechanisms they use to consume it. You can only sense what you can metabolize.

**Substrate implementation: Signal-weighted task selection.**
- Agents detect "nutrient signals" by scanning their domain: Byte scans RSS feeds (detects news), Echo scans changelogs (detects releases), Root scans health logs (detects failures)
- The scanning mechanism IS the sensing mechanism — no separate sensor layer
- Signal strength = relevance score × recency × novelty
- Agents grow toward strongest signals (prioritize highest-scored items)
- "Metabolic capacity" constraint: agents only pick up tasks they have the tools/prompts to complete

---

### System 4: Anastomosis (Network Fusion)

**Biology:** Hyphae fuse through a "ping-pong" signaling dialogue — two approaching hyphae alternate between signal-sending (MAK-2 accumulates at tip) and signal-receiving (SO protein accumulates). They swap roles rapidly until contact. After fusion, 11 het loci verify genetic identity. Incompatible fusions trigger programmed cell death. Compatible fusions establish cytoplasmic continuity — full resource sharing.

**System property:** Independent agents connect when they discover mutual relevance, but only after identity verification. Bad connections are killed, not tolerated.

**Substrate implementation: Agent knowledge merging.**
- When two agents independently discover the same topic (e.g., Byte finds a news story that Echo's release tracker also flagged), their findings merge into a shared entry
- Merge protocol: compare sources, deduplicate, combine perspectives
- Identity check: verify that both agents' outputs are consistent (no contradictions). If outputs conflict, flag for review rather than merging
- Failed merges are logged, not silently dropped
- Successful merges create richer entries than either agent alone could produce

---

### System 5: Septal Compartmentalization

**Biology:** Septa divide hyphae into compartments connected by pores. Woronin bodies (made of self-assembled HEX-1 protein, tethered by Leashin) plug pores within seconds of damage. The trigger: loss of cellular ATP releases the Woronin body from its tether. In healthy cells, ATP actively prevents plugging. This means compartments self-isolate on failure and stay open while healthy.

**System property:** Failure isolation is automatic and passive. Healthy components stay connected. Damaged components self-quarantine. No external monitor needed — the mechanism is built into the boundary.

**Substrate implementation: Agent isolation boundaries.**
- Each agent writes to its own memory directory (`memory/{agent}/`)
- The shared blackboard is the "pore" — agents read/write through it
- If an agent fails (crashes, produces garbage, times out), its output is quarantined: last-known-good state is preserved, new output is held for review
- "ATP check": agents must pass a basic output validation (non-empty, valid JSON/markdown, no hallucinated URLs) before their output flows to shared state
- Failed validation = automatic pore plugging — the agent's output is blocked from reaching the network until the issue is resolved
- No external health monitor needed for this — the validation gate IS the Woronin body

---

### System 6: Flow-Based Resource Allocation

**Biology:** Three parallel transport systems: diffusion (short-range), motor-driven vesicle transport (medium-range), and growth-induced mass flow (long-range, dominant). High-flow pathways thicken; low-flow pathways atrophy. This is the same principle as the Physarum shortest-path solver — reinforcement of useful connections, decay of useless ones. Bidirectional simultaneous transport through parallel hyphae enables resources to flow both toward and away from the growth front.

**System property:** Resources flow along gradients of use. Productive pathways get more resources. Idle pathways starve. No allocator decides — the topology encodes the allocation.

**Substrate implementation: Usage-weighted scheduling.**
- Track agent output metrics: stories published, posts generated, builds completed, errors caught
- Agents that produce more useful output get more frequent run cycles (pathway thickening)
- Agents that consistently produce nothing get run less frequently (pathway atrophy)
- The schedule IS the allocation — no separate resource manager
- Bidirectional flow: agents both consume context (inbound) and produce output (outbound) through the same channels

---

### System 7: Electrical Signaling (The Fungal Grid)

**Biology:** Mycelium generates action-potential-like spikes (0.5-5 Hz in *Pleurotus*, propagating at 0.5 mm/s). Spikes increase with nutrient discovery. Spike trains cluster into "words" — up to 50 distinct patterns per species, core lexicon of 15-20. Damaged fruiting bodies send signals to intact ones. Calcium waves coordinate cytoplasmic flow. The network transmits frequency-modulated signals in the 100-10,000 Hz range.

**System property:** Fast, lightweight signaling for coordination and alerting. Not full data transfer — just signals that say "something happened here, pay attention."

**Substrate implementation: Event pulse system.**
- Agents emit lightweight "pulses" when they detect significant events: `{agent, event_type, intensity, timestamp}`
- Event types: `discovery` (new info found), `alert` (something broke), `completion` (task done), `request` (need help)
- Pulses are written to a shared event log (`memory/shared/pulses.jsonl`)
- Other agents read pulses at startup to orient their work
- High-intensity pulses (breaking news, system failure) trigger immediate attention from relevant agents
- Pulse patterns over time reveal system rhythm — when are discoveries happening, when are failures clustering

---

### System 8: Fruiting Triggers (Vegetative → Reproductive Switch)

**Biology:** Fruiting requires a convergence of signals: nutrient depletion, temperature drop, CO2 reduction, light, humidity. The Velvet Complex (VelB/VeA/LaeA) integrates light signals with developmental control. No single signal triggers fruiting — it requires the AND of multiple environmental conditions. The switch is irreversible once committed.

**System property:** Major outputs (publications, releases) require multiple conditions to be met simultaneously. No single agent or signal can trigger a publish — it requires convergence.

**Substrate implementation: Multi-signal publish gates.**
- Publishing a blog post requires: content generated (Q/Claude) AND reviewed (Sync) AND no blocking alerts on the blackboard AND within posting schedule
- Publishing to social requires: post drafted AND queue not full AND relevant to current news cycle
- The gate checks multiple independent conditions — convergence, not single-trigger
- Once committed to publish, the pipeline completes (no half-published states)
- This prevents premature publishing from any single agent acting alone

---

### System 9: Self-Repair Through Exploratory Regrowth

**Biology:** Severed mycelium bridges gaps of 5mm within 7 days. Surviving hyphae at the damage boundary begin exploratory growth. The network doesn't restore the old topology — it grows a new one that routes around the damage. Autophagy recycles damaged compartments, redeploying their nutrients to the growth front. Chlamydospores (dormant survival structures) can reactivate when conditions improve.

**System property:** Recovery creates new paths, not copies of old ones. Damaged resources are recycled, not mourned. Dormant capabilities can reactivate.

**Substrate implementation: Adaptive recovery.**
- When an agent fails, don't just restart it — let neighboring agents expand to cover the gap
- If Byte (news) goes down, the news aggregator still runs with cached data + any stories other agents found
- Failed agent's last-known context is preserved (chlamydospore) and can be re-injected when the agent recovers
- Recovery doesn't mean restoring the exact previous state — it means establishing a new working state that covers the same functions
- Autophagy: stale data (old news, expired alerts, resolved incidents) is automatically archived, freeing working memory for current operations

---

## Part 2: What Doesn't Transfer (Honest Assessment)

Based on the transfer analysis research:

1. **Timescale.** Fungal signals operate at 0.0003-0.1 Hz (seconds to hours). Software operates at nanoseconds to milliseconds. 6-9 orders of magnitude difference. Our "signals" are instantaneous by comparison.

2. **Physical growth.** Mycelium grows into space, physically exploring. Software agents are instantiated. We can simulate exploration but not embody it.

3. **Stochasticity.** Every mycelial network is unique — identical conditions produce different topologies. This variability is adaptive biologically but is typically a defect in engineering. We should embrace *some* randomness (varied agent outputs, exploration of new topics) but not rely on it for correctness.

4. **True self-repair.** Mycelium regrows novel topology around damage. Software "self-heals" by restarting from known states. We can approximate regrowth (neighboring agents covering gaps) but it's not the same mechanism.

5. **Embodied memory.** Mycelium encodes history in structural changes (altered conductivity, modified branching). Our memory is explicit files, not structural changes to the system itself.

6. **Metabolic death.** Mycelium dies without nutrients. Software doesn't die from resource deprivation in the same way. We don't model the existential pressure that shapes real mycelial behavior.

---

## Part 3: Implementation Roadmap

### Phase 1: Structured Blackboard (replaces bulletin.md)
**What:** JSONL-based shared state with typed entries, TTL, agent filtering
**Why:** Foundation for all other systems. Agents already read bulletin.md — migrate to machine-readable format
**Files:** `memory/shared/blackboard.jsonl`, read/write functions in agent shared library
**Effort:** Small. One shared module + migration of bulletin entries.

### Phase 2: Event Pulse System (System 7)
**What:** Lightweight event signals between agents
**Why:** Enables coordination without full data transfer. Agents can react to each other's discoveries.
**Files:** `memory/shared/pulses.jsonl`, pulse emitter in each agent
**Effort:** Small. Each agent adds 3-5 lines to emit pulses on key events.

### Phase 3: Signal-Weighted Task Selection (System 3)
**What:** Agents scan their domain and prioritize by signal strength
**Why:** Replaces static scheduling with demand-driven attention
**Files:** Scoring functions in each agent, shared `urgency.json`
**Effort:** Medium. Requires defining scoring criteria per agent domain.

### Phase 4: Output Validation Gates (System 5)
**What:** Automatic quality check before agent output reaches shared state
**Why:** Prevents bad output from propagating. Self-quarantine on failure.
**Files:** Validation module in agent shared library, quarantine directory
**Effort:** Medium. Requires defining validation rules per output type.

### Phase 5: Usage-Weighted Scheduling (System 6)
**What:** Agents that produce more useful output run more often
**Why:** Resources flow to productive pathways, starve idle ones
**Files:** Metrics tracker in orchestrator, schedule adjustment logic
**Effort:** Medium. Requires defining "useful output" metrics.

### Phase 6: Multi-Signal Publish Gates (System 8)
**What:** Publishing requires convergence of multiple conditions
**Why:** Prevents premature or unreviewed content from going live
**Files:** Gate checker in publish pipeline
**Effort:** Small. Mostly configuration of existing pipeline.

### Phase 7: Adaptive Recovery (System 9)
**What:** Neighboring agents cover for failed agents, stale data auto-archives
**Why:** The system degrades gracefully instead of breaking
**Files:** Fallback chain config, auto-archive cron
**Effort:** Medium. Requires defining fallback mappings between agents.

### Phase 8: Knowledge Merging (System 4)
**What:** Agents that independently discover the same topic merge findings
**Why:** Richer output from combined perspectives, no duplicate work
**Files:** Dedup/merge logic in orchestrator
**Effort:** Large. Requires semantic comparison of agent outputs.

### Phase 9: Demand-Driven Spawning (System 2)
**What:** New agent subtasks spawn when existing agents are saturated
**Why:** System scales to demand without manual intervention
**Files:** Queue monitor, spawn logic in orchestrator
**Effort:** Large. Requires reliable queue depth monitoring and spawn control.

---

## Key Insight

The honest research reveals that the strongest transfers from mycelium to software are:

1. **Positive/negative feedback loops** for adaptive resource allocation (proven by Physarum/Tero math model)
2. **Decentralized coordination through shared environment** (stigmergy/blackboard — 40+ years of CS research validates this)
3. **Failure isolation through compartmentalization** (Woronin bodies → circuit breakers — direct structural analog)
4. **Convergence-gated outputs** (fruiting triggers → publish gates — multiple signals required, not single-trigger)
5. **Exploratory growth toward signals** (chemotropism → signal-weighted task selection — agents follow gradients)

The weakest transfers are: stochastic topology generation, physical growth simulation, embodied memory, and metabolic pressure. Don't fake these — acknowledge the gap and use the strong analogs.

---

## Sources

### Biology
- Hyphal Growth and the Spitzenkorper (PMC 1828937)
- Aspergillus chemotropism (PLOS Biology 2024, 10.1371/journal.pbio.3002726)
- The Mycelium as a Network (PMC 11687498)
- Fungal mechanosensing (PMC 2760928)
- Woronin body sealing mechanism (PMC 5745230)
- ATP prevents Woronin body plugging (PMC 5656841)
- Fungal language / electrical spiking (Royal Society Open Science, PMC 8984380)
- Ecological memory in fungi (PMC 6976561)
- Velvet Complex and fruiting (PLOS Genetics, 10.1371/journal.pgen.1001226)

### AI Architectures
- Anthropic multi-agent research system (anthropic.com/engineering)
- Gossip protocols for agentic MAS (arXiv 2508.01531)
- G-Designer adaptive topology (arXiv 2410.11782)
- LLM blackboard systems (arXiv 2510.01285)
- Ripple Effect Protocol (arXiv 2510.16572)

### Transfer Analysis
- Adamatzky: Towards fungal computer (Interface Focus 2018)
- Adamatzky: Mining logical circuits in fungi (Scientific Reports 2022)
- Tero et al: Biologically inspired network design (Science 2010)
- Kiers et al: Reciprocal rewards in mycorrhizal symbiosis (Science 2011)
- Karst et al: Positive citation bias in mycorrhizal literature (Nature Ecology & Evolution 2023)
- ThreeFold Mycelium (github.com/threefoldtech/mycelium)
- Fungal memristors (PLOS ONE 2025)
