# Mycelial Agent Architectures: Biological Network Patterns Mapped to AI Systems

Research compiled: 2026-03-12

---

## Executive Summary

This report maps biological network patterns — primarily from fungal mycelium, ant colonies, and slime molds — to concrete, implementable AI multi-agent architectures. Each section pairs a biological mechanism with its computational analog, cites real implementations, and identifies what Substrate could build.

---

## 1. Stigmergic Coordination: Indirect Communication Through Shared Environment

### Biological Pattern
Ants deposit pheromones on trails. Other ants sense the concentration and follow stronger trails. No ant talks to another ant directly. The environment *is* the communication channel. Pheromones decay over time (evaporation) and strengthen with reinforcement (more ants walking the same path). This produces emergent shortest-path routing without any central planner.

Mycelial networks do the same: nutrient gradients in soil guide hyphal growth. A mycelium doesn't "decide" to grow toward a food source — the chemical environment biases growth direction.

### Computational Analogs

**Digital Pheromones.** Virtual maps overlaid on an environment store "activity signals" at coordinates. Agents read and write to this map. Signals decay over time unless reinforced. This has been implemented for UAV swarm coordination (Parunak et al.) and underwater vehicle coverage (dual-trail stigmergic control, 2025). A stigmergic multi-agent deep reinforcement learning framework (S-MADRL) uses virtual pheromones to coordinate up to 8 agents, producing asymmetric workload distributions that reduce congestion.

**Ant Colony Optimization (ACO) for Task Scheduling.** ACO algorithms are actively used for cloud computing load balancing. A 2025 hybrid ACO + Water Wave Optimization achieved 18% makespan reduction, 15% energy decrease, and 20% load balancing improvement over standard approaches. Adaptive Cooperative ACO (AC-ACO) targets heterogeneous multi-core processors.

### Implementable Pattern for Substrate
A shared `pheromone.json` or in-memory store where agents write priority signals that decay. When an agent completes a task in a domain, it "deposits" a signal. Other agents read the map to decide where effort is most needed. Signals that go unreinforced fade, preventing stale priorities from dominating.

**Concrete mechanism:**
- Each agent writes `{domain, intensity, timestamp}` tuples to a shared file
- A decay function reduces intensity by ~20% per cycle
- Reinforcement: if two agents independently signal the same domain, intensity doubles
- Agents read the map before choosing their next task — highest-signal domains get attention first

---

## 2. Distributed Decision-Making Without Central Control

### Biological Pattern
Mycelial networks have no brain. No central node coordinates nutrient transport. Decisions emerge from local interactions: each hyphal tip responds to its immediate chemical gradient. The collective behavior — routing nutrients to where they're needed most — arises from millions of local decisions, not from a plan.

Ant colonies similarly make collective decisions (nest selection, foraging strategy) through quorum sensing — when enough individuals independently converge on the same signal, the colony "decides."

### Computational Analogs

**Gossip Protocols for Agent Coordination.** Two landmark 2025 papers propose gossip as a first-class coordination substrate for multi-agent AI:

1. *"Revisiting Gossip Protocols: A Vision for Emergent Coordination in Agentic MAS"* (arXiv 2508.01531, Aug 2025) — proposes gossip layered beneath MCP, A2A, and ACP to support decentralized discovery, load signaling, task-availability propagation, failure detection, and emergent consensus.

2. *"A Gossip-Enhanced Communication Substrate for Agentic AI"* (arXiv 2512.03285, Dec 2025) — introduces GEACL, a four-layer architecture for decentralized, low-overhead, context-rich communication supporting swarm-like behavior.

Key insight: gossip protocols are *layered with CRDTs* (Conflict-Free Replicated Data Types) to achieve eventual consistency without central coordination. Agents exchange partial state with random peers; mathematical properties of CRDTs guarantee convergence.

**Ripple Effect Protocol (MIT, Oct 2025).** Agents share not just decisions but *sensitivities* — lightweight signals expressing how their choices would change if variables shifted. These sensitivities "ripple" through local networks, enabling faster alignment than direct messaging. Benchmarks show 41-100% improvement over A2A on supply chain, scheduling, and resource allocation tasks.

**Consensus Through Gossip (arXiv 2508.18292).** Multiple LLMs exchange answers and gradually converge on shared solutions, analogous to quorum sensing in biological systems.

### Implementable Pattern for Substrate
Replace the current bulletin board (a human-written memo file) with a gossip-like protocol:

**Concrete mechanism:**
- Each agent maintains a local state vector: `{agent_id, beliefs: {}, last_updated}`
- On each cycle, an agent "gossips" by merging its state with 2-3 random peers' states
- Merge function uses CRDT semantics: last-writer-wins for scalar values, union for sets, max for counters
- After N rounds of gossip, all agents converge on consistent shared knowledge
- No coordinator needed — the orchestrator becomes optional, not required

---

## 3. Resource Allocation: Who Gets Compute, Context, and Priority

### Biological Pattern
In a mycorrhizal network, trees that photosynthesize more (producing surplus carbon) feed the network. Trees in shade receive more nutrients from the network. The network doesn't allocate resources by committee — it flows resources along gradients. Surplus flows to deficit. The topology itself encodes the allocation policy.

### Computational Analogs

**Market-Based Task Allocation.** Agents bid for tasks based on estimated utility. Distributed Market-based Auction (DMA) resolves conflicts through randomized priority. A 2025 Frontiers study uses cost-effectiveness maximization in multi-round auctions. The principle: each agent calculates its marginal value for a task and bids accordingly. No central allocator needed.

**Decentralized Adaptive Allocation (Nature, 2025).** A two-layer architecture operates under partial observability and noisy feedback. Adaptive controllers predict task parameters via recursive regression with forgetting — mimicking how biological networks strengthen connections to new resources and let unused connections atrophy.

**Multi-Agent Reinforcement Learning (MARL).** A 2025 survey (Springer) covers MARL for resource allocation optimization, modeling distributed decision-making where agents learn from interactions with complex environments.

### Implementable Pattern for Substrate
Agent priority auction system:

**Concrete mechanism:**
- Each agent calculates a `urgency_score` based on: time since last run, backlog size, external triggers (e.g., news events for Byte, release events for Echo)
- Agents "bid" by writing urgency scores to a shared ledger
- The scheduler allocates compute slots to highest-urgency agents first
- After execution, the agent's urgency resets (decay)
- Agents that consistently produce high-value output (measured by engagement, build success) get a reputation multiplier on future bids
- This mimics mycorrhizal nutrient flow: productive nodes get more resources, underperforming nodes get less

---

## 4. Adaptive Network Topology: Self-Organizing Communication Graphs

### Biological Pattern
Mycelial networks don't have a fixed topology. They grow toward food, retract from threats, and strengthen high-traffic pathways. Old-growth fungal networks exhibit small-world properties — the same mathematical structure that makes the internet robust. The topology is the strategy.

### Computational Analogs

**G-Designer (arXiv 2410.11782, 2024).** Uses a graph neural network to dynamically design task-aware communication topologies for multi-agent LLM systems. Achieves 84.5% on MMLU, 89.9% on HumanEval, while reducing token consumption by up to 95.33%. The key innovation: the communication graph between agents is *generated* per-task, not hardcoded.

**Autoregressive Graph Generation (arXiv 2507.18224, 2025).** "Assemble Your Crew" — automatically constructs task-specific multi-agent communication structures.

**DynTaskMAS (AAAI ICAPS 2025).** Dynamic task graph framework with priority-based scheduling considering dependencies, estimated execution time, and system load. Tasks form a DAG that reorganizes as the problem evolves.

**Internet of Agents (IoA) Framework (arXiv 2505.07176, 2025).** Moves beyond fixed designs with learning-based, task-driven approaches that adapt communication patterns and agent roles to contextual needs.

### Implementable Pattern for Substrate
Dynamic agent wiring based on task type:

**Concrete mechanism:**
- Define a `topology.json` mapping task categories to agent communication subgraphs
- For news tasks: Byte → Sync → Amp (linear pipeline)
- For creative tasks: Q + V + Pixel + Hum (fully connected mesh)
- For infrastructure tasks: Root → Forge → Spec (chain with verification)
- For crisis response: all agents → flat broadcast
- The orchestrator selects topology based on task classification, or agents can *vote* to reconfigure if the current topology is inefficient
- Topology changes are logged, creating data for future optimization

---

## 5. LLM-Specific Multi-Agent Patterns

### Current State of the Art (2025-2026)

**Anthropic's Multi-Agent Research System.** Orchestrator-worker pattern: a lead agent (Claude Opus 4) decomposes queries, spawns subagents (Claude Sonnet 4), each with clear objectives, output format specs, tool guidance, and task boundaries. Multi-agent outperformed single-agent by 90.2% on internal benchmarks. Key lesson: vague delegation fails — agents need specific, non-overlapping instructions.

**Claude Code Agent Teams (Feb 2026).** Teammates are independent Claude instances with 1M token context each, coordinating through:
- Shared task list with dependency tracking and auto-unblocking
- Inbox-based messaging (agents message each other directly)
- Git worktree isolation (each agent gets its own branch)
- Unlike subagents, teammates can communicate laterally, not just up to the parent

**Recursive Language Models (RLM, Dec 2025).** Context stored as Python variables in an external REPL, not in the prompt. The LLM writes code to inspect, partition, and recursively query its own context. Processes inputs 100x beyond context windows. Solves "context rot" — the degradation that occurs when contexts grow too large.

**Agentic Context Engineering (ACE, Oct 2025).** Three-agent loop: Generator (creates output using knowledge base), Reflector (extracts lessons from output), Curator (updates knowledge base with lessons). A self-improving cycle.

**Protocol Stack (2025-2026):**
- **MCP** (Anthropic, Nov 2024): connects agents to tools, APIs, data sources. 97M+ monthly SDK downloads by Feb 2026.
- **A2A** (Google, Apr 2025): agent-to-agent discovery, communication, delegation. Now under Linux Foundation.
- **Gossip substrate**: proposed as the layer *beneath* MCP and A2A for emergent coordination.

### Implementable Pattern for Substrate
Effort-scaled agent delegation:

**Concrete mechanism:**
- Simple tasks (fact lookup, status check): single agent, 3-10 tool calls
- Medium tasks (comparison, analysis): 2-4 agents with divided responsibilities
- Complex tasks (research, multi-domain builds): orchestrator + specialist agents with explicit non-overlapping scopes
- Each agent gets a scoped context injection (not the full repo state)
- Results flow back through a structured format, not free-text
- Use RLM-style context management: store long contexts as indexed variables, let agents query subsets

---

## 6. Mycelium-Inspired Computing: Direct Biological Implementations

### The Adamatzky Lab (University of the West of England)

Andrew Adamatzky's Unconventional Computing Lab is the world leader in fungal computing:

- **Fungal electrical spiking.** First lab to measure spiking activity in fungi via microelectrodes. Information is represented by spikes of electrical activity. Computation is implemented in the mycelium network. Interface is realized via fruit bodies.
- **Fungal electronics (2021).** Living electronic devices — chemical sensors, photosensors, oscillators — made of pure mycelium or mycelium-bound composites.
- **Fungal memristors (2025).** Mushroom-based memristors switch between electrical states up to 5,850 times/second with ~90% accuracy. Minimal power consumption.
- **Intelligent buildings.** Fungi grown inside building materials act as sensors for light, pollutants, and temperature changes.

### Physarum (Slime Mold) Computing

Physarum polycephalum finds shortest paths through mazes, recreates optimal transport networks (famously reproducing the Tokyo rail system), and performs basic logical operations. It's a single-celled organism that solves NP-hard problems through physical expansion.

### Computational Principles Extracted

| Biological Property | Computing Principle |
|---|---|
| Hyphal tip growth toward nutrients | Gradient descent / directed search |
| Trail reinforcement | Positive feedback loops / ant colony optimization |
| Trail decay | Forgetting / cache expiration |
| Network pruning (unused hyphae die) | Garbage collection / dead code elimination |
| Nutrient transport along gradients | Load balancing / flow optimization |
| Anastomosis (hyphal fusion) | Network merging / service mesh joining |
| Compartmentalization (septa) | Process isolation / container boundaries |
| Spore dispersal | Task distribution / work stealing |
| Fruiting body formation | Output aggregation / publish events |

### Implementable Pattern for Substrate
The mycelium metaphor maps directly to Substrate's agent network:

- **Hyphae** = communication channels between agents
- **Hyphal tips** = agents actively exploring/producing
- **Mycelial mat** = the shared memory layer (bulletin, memory files)
- **Nutrient flow** = context and compute allocation
- **Fruiting bodies** = published outputs (blog posts, social posts, games)
- **Spores** = distributed tasks seeking new substrate
- **Anastomosis** = agents merging findings into shared knowledge
- **Septa** = isolation boundaries (private vs. shared memory)

---

## 7. Self-Healing Agent Networks

### Biological Pattern
When a mycelial network is damaged (grazing, physical disruption), it doesn't need a repair crew. Surviving hyphae at the damage boundary detect the break (chemical signals from severed cells) and begin exploratory growth to reconnect. The network routes around damage automatically. Hub nodes (highly connected junctions) are more critical — but the network maintains redundant pathways specifically to survive hub loss.

### Computational Analogs

**Circuit Breaker Patterns for Agent Clusters.** Adapted from microservices: circuit breakers operate between clusters of related agents rather than at individual connections, simplifying fault containment. When an agent cluster fails, the circuit opens and traffic routes to fallback agents.

**Hierarchical Multi-Agent Self-Healing (2025).** LLM-driven diagnosis + digital-twin simulation + cross-domain coordination for automated fault detection, analysis, and repair. Achieves >95% alarm aggregation accuracy.

**Graceful Degradation via Requirement-Driven Adaptation (SEAMS 2024).** Systems maintain acceptable safety levels during unexpected conditions while facilitating recovery to normal function. Key: define minimum viable behavior for each agent, so the system degrades gracefully rather than failing catastrophically.

**Self-Healing Distribution Networks (2025 review).** Multi-agent frameworks with fault tolerance and automatic restoration. Agents independently detect faults, isolate damaged segments, and restore service through alternative paths.

### Implementable Pattern for Substrate
Agent health monitoring with automatic failover:

**Concrete mechanism:**
- Each agent writes a heartbeat to `memory/health/{agent_id}.json` with timestamp and status
- A lightweight monitor (cron job or systemd timer) checks heartbeats every cycle
- If an agent misses 2+ heartbeats: mark as degraded, redistribute its tasks to backup agents
- If an agent consistently fails: quarantine it, log the failure, alert operator
- Define fallback chains: if Byte (news) fails, Sync can cover basic news aggregation; if Root (infra) fails, Forge can handle critical infra tasks
- After recovery, the agent rejoins gradually (reduced load) before returning to full capacity
- Damage is logged in `memory/incidents.md` for post-mortem analysis

---

## 8. Bulletin Board / Shared Memory Architectures

### Biological Pattern
The forest floor is a shared medium. Chemical signals from roots, mycorrhizal network transport, and decomposition products create a chemical "bulletin board" that all organisms can read. A tree under insect attack releases volatile organic compounds — neighboring trees detect these and preemptively produce defensive chemicals. The environment is the message bus.

### Computational Analogs

**Blackboard Architecture (Revived, 2025).** Originally from 1980s AI, now experiencing a renaissance for LLM agents. Key papers:

- *"Exploring Advanced LLM Multi-Agent Systems Based on Blackboard Architecture"* (arXiv 2507.01701, 2025)
- *"LLM-Based Multi-Agent Blackboard System for Information Discovery"* (arXiv 2510.01285, 2025) — achieves 13-57% improvement over baselines

The pattern: a shared workspace (blackboard) where agents read and write. A control unit (which can itself be an LLM) selects which agents act in each round based on blackboard state. Agents don't talk to each other — they talk to the blackboard.

**Blackboard + MCP Integration (2025).** A practical implementation combines the blackboard pattern with Model Context Protocol, using the blackboard as the coordination layer and MCP for tool access.

**Collaborative Memory with Access Control (arXiv 2505.18279, 2025).** Two-tier memory: private fragments (visible only to originating agent) and shared fragments (selectively shared). Access encoded as bipartite graphs. Solves the information asymmetry problem — different agents have different knowledge and permissions.

**MAGMA: Multi-Graph Agentic Memory Architecture (arXiv 2601.03236, 2026).** Graph-based memory with typed nodes and edges. Supports cross-document and cross-episode dependencies. Temporally aware.

**Tuple Spaces / Linda Model.** The classic coordination primitive: agents write tuples to a shared space, other agents pattern-match to read them. No direct addressing needed. The blackboard is essentially a structured, intelligent tuple space.

### Implementable Pattern for Substrate
Evolve the current `memory/bulletin.md` into a structured blackboard:

**Concrete mechanism:**
- Replace flat markdown memo with structured JSONL: `{timestamp, from, affects, type, payload, ttl}`
- Types: `alert`, `discovery`, `request`, `status`, `decision`
- TTL (time-to-live): entries expire after N cycles unless refreshed
- Agents read the blackboard at startup and filter by `affects` field
- A control function selects which agents should act based on current blackboard state
- Private vs. shared: agents can write to `memory/private/{agent_id}/` for local state and `memory/shared/` for the blackboard
- The blackboard becomes the single source of truth for inter-agent coordination — no direct agent-to-agent messaging needed

---

## Synthesis: The Mycelial Agent Architecture

Mapping all eight patterns together produces a coherent architecture:

```
                    FRUITING BODIES (Published Outputs)
                    blog posts, social posts, games, radio
                           |
                    SPORULATION (Distribution)
                    Amp, Pulse distribute across platforms
                           |
              ┌────────────┼────────────┐
              |            |            |
         HYPHAL TIPS   HYPHAL TIPS   HYPHAL TIPS
         (Active Agents exploring/producing)
         Byte, Echo,   Q, V, Pixel,  Root, Forge,
         Flux           Hum, Arc      Spec, Sentinel
              |            |            |
              └────────┬───┘────────────┘
                       |
              MYCELIAL MAT (Shared Memory Layer)
              ┌─────────────────────────────┐
              | Blackboard (structured JSONL)|
              | Pheromone Map (urgency/heat) |
              | Knowledge Graph (facts/state)|
              └─────────────────────────────┘
                       |
              NUTRIENT FLOW (Resource Allocation)
              ┌─────────────────────────────┐
              | Auction: agents bid urgency  |
              | Gradient: surplus → deficit  |
              | Decay: unused paths atrophy  |
              └─────────────────────────────┘
                       |
              GOSSIP SUBSTRATE (Consistency Layer)
              ┌─────────────────────────────┐
              | CRDT-based state merging     |
              | Eventual consistency         |
              | No central coordinator       |
              └─────────────────────────────┘
                       |
              ROOT SYSTEM (Self-Healing)
              ┌─────────────────────────────┐
              | Heartbeat monitoring         |
              | Fallback chains              |
              | Graceful degradation         |
              | Automatic reconnection       |
              └─────────────────────────────┘
```

### Implementation Priority for Substrate

**Phase 1 — Structured Blackboard** (replaces bulletin.md)
- JSONL-based shared memory with typed entries, TTL, and agent filtering
- Lowest friction, highest immediate value
- Agents already read bulletin.md; migrate to structured format

**Phase 2 — Pheromone-Based Priority** (replaces manual orchestration)
- Agents write urgency signals that decay over time
- Scheduler reads pheromone map to allocate cycles
- Enables autonomous prioritization without operator intervention

**Phase 3 — Health Monitoring & Self-Healing**
- Heartbeat system for all agents
- Fallback chains defined in configuration
- Automatic task redistribution on agent failure

**Phase 4 — Adaptive Topology**
- Task-type-to-topology mapping
- Agents can vote to reconfigure communication structure
- Log topology changes for optimization data

**Phase 5 — Gossip Consensus** (full decentralization)
- CRDT-based state merging between agents
- Remove orchestrator as single point of failure
- Emergent coordination through local interactions only

---

## Key Sources

### Stigmergic Coordination
- [Collective Stigmergic Optimization for Multi-Agentic AI](https://medium.com/@jsmith0475/collective-stigmergic-optimization-leveraging-ant-colony-emergent-properties-for-multi-agent-ai-55fa5e80456a)
- [Automatic Design of Stigmergy-Based Behaviours for Robot Swarms](https://www.nature.com/articles/s44172-024-00175-7)
- [Stigmergy: The Future of Decentralized AI](https://www.numberanalytics.com/blog/stigmergy-future-decentralized-ai)
- [Swarm Intelligence in Agentic AI: Industry Report](https://powerdrill.ai/blog/swarm-intelligence-in-agentic-ai-an-industry-report)
- [Dual-Trail Stigmergic Coordination for 3D Underwater Swarm Coverage](https://www.mdpi.com/2077-1312/14/2/164)

### Gossip Protocols & Distributed Consensus
- [Revisiting Gossip Protocols: Emergent Coordination in Agentic MAS (arXiv 2508.01531)](https://arxiv.org/abs/2508.01531)
- [Gossip-Enhanced Communication Substrate for Agentic AI (arXiv 2512.03285)](https://arxiv.org/abs/2512.03285)
- [Consensus Is All You Need: Gossip-Based Reasoning Among LLMs (arXiv 2508.18292)](https://arxiv.org/html/2508.18292)
- [Ripple Effect Protocol: Coordinating Agent Populations (MIT, arXiv 2510.16572)](https://arxiv.org/abs/2510.16572)

### Resource Allocation
- [Multi-Agent Task Allocation via Cost-Effectiveness Maximization Auction (Frontiers, 2025)](https://www.frontiersin.org/articles/10.3389/fphy.2025.1617607/full)
- [Decentralized Adaptive Task Allocation (Nature Scientific Reports, 2025)](https://www.nature.com/articles/s41598-025-21709-9)
- [MARL for Resource Allocation Optimization (Springer, 2025)](https://link.springer.com/article/10.1007/s10462-025-11340-5)

### Adaptive Topology
- [G-Designer: Architecting Multi-Agent Communication Topologies via GNN (arXiv 2410.11782)](https://arxiv.org/abs/2410.11782)
- [Assemble Your Crew: Automatic Multi-Agent Topology Design (arXiv 2507.18224)](https://arxiv.org/html/2507.18224v1)
- [Internet of Agents: Fundamentals, Applications, Challenges (arXiv 2505.07176)](https://arxiv.org/html/2505.07176v1)
- [DynTaskMAS: Dynamic Task Graph Framework (AAAI ICAPS)](https://ojs.aaai.org/index.php/ICAPS/article/download/36130/38284/40203)

### LLM Multi-Agent Patterns
- [How Anthropic Built Their Multi-Agent Research System](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Effective Context Engineering for AI Agents (Anthropic)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Recursive Language Models (arXiv 2512.24601)](https://arxiv.org/abs/2512.24601)
- [Agentic Context Engineering (arXiv 2510.04618)](https://arxiv.org/abs/2510.04618)
- [MCP vs A2A Protocol Comparison](https://dev.to/pockit_tools/mcp-vs-a2a-the-complete-guide-to-ai-agent-protocols-in-2026-30li)
- [Claude Flow: AI Orchestration Framework](https://www.analyticsvidhya.com/blog/2026/03/claude-flow/)

### Mycelium-Inspired Computing
- [Towards Fungal Computer (Adamatzky, Interface Focus)](https://royalsocietypublishing.org/doi/10.1098/rsfs.2018.0029)
- [Living Computers Powered by Mushrooms (ScienceDaily, 2025)](https://www.sciencedaily.com/releases/2025/10/251026021724.htm)
- [Parallels Between Mycelium and Artificial Neural Networks](https://medium.com/@elbuenodeharry/parallels-between-mycelium-networks-and-artificial-neural-networks-insights-for-resilient-cb21624bb338)
- [The Mycelium as a Network (PMC, 2024)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11687498/)
- [Bio-Inspired Routing Based on Fungi Networks (HyphaNet)](https://www.sciencedirect.com/science/article/abs/pii/S1570870519308339)
- [Network Traits Predict Ecological Strategies in Fungi (Nature ISME)](https://www.nature.com/articles/s43705-021-00085-1)

### Self-Healing Networks
- [Multi-Agent AI Failure Recovery That Works (Galileo)](https://galileo.ai/blog/multi-agent-ai-system-failure-recovery)
- [Self-Healing Multi-Agent Techniques in Power Distribution (ScienceDirect, 2025)](https://www.sciencedirect.com/science/article/abs/pii/S1364032125008056)
- [Intelligent Fault Self-Healing for Cloud AI (arXiv 2506.07411)](https://arxiv.org/pdf/2506.07411)
- [Graceful Degradation Through Requirement-Driven Adaptation (SEAMS 2024)](https://dl.acm.org/doi/10.1145/3643915.3644090)

### Blackboard / Shared Memory
- [LLM-Based Multi-Agent Blackboard System (arXiv 2510.01285)](https://arxiv.org/abs/2510.01285)
- [Advanced LLM Multi-Agent Systems Based on Blackboard Architecture (arXiv 2507.01701)](https://arxiv.org/html/2507.01701v1)
- [Building MAS with MCPs and the Blackboard Pattern](https://medium.com/@dp2580/building-intelligent-multi-agent-systems-with-mcps-and-the-blackboard-pattern-to-build-systems-a454705d5672)
- [Collaborative Memory with Dynamic Access Control (arXiv 2505.18279)](https://arxiv.org/abs/2505.18279)
- [MAGMA: Multi-Graph Agentic Memory Architecture (arXiv 2601.03236)](https://arxiv.org/html/2601.03236v1)
- [CodeCRDT: Observation-Driven Multi-Agent Coordination (arXiv 2510.18893)](https://arxiv.org/abs/2510.18893)

### Protocols & Frameworks
- [A2A Protocol Announcement (Google)](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/)
- [OpenAI Agents SDK](https://openai.github.io/openai-agents-python/)
- [Swarms Framework (GitHub)](https://github.com/kyegomez/swarms)
- [Digital Pheromones for Unmanned Vehicle Coordination](https://www.researchgate.net/publication/221455924_Digital_Pheromones_for_Coordination_of_Unmanned_Vehicles)
- [Digital Pheromones: What Ants Know About Agent Coordination](https://www.distributedthoughts.org/digital-pheromones-what-ants-know-about-agent-coordination/)
