# Simulation & Algorithmic Patterns — Reference for Game Systems

Ingested 2026-03-09. Source: Daniel Shiffman *The Nature of Code* (2012).

## Core Philosophy

Simulating natural systems with code. Define rules that govern behavior, then implement them. Every algorithm models a real-world phenomenon.

## Motion Fundamentals

### Vectors
- Mathematical entity with magnitude and direction
- Position, velocity, acceleration are all vectors
- **Motion algorithm**: `location += velocity; velocity += acceleration`
- This simple pattern drives virtually all simulated motion

### Forces (Newton's Second Law: F = ma)
- Multiple forces accumulate: wind + gravity + friction → net force
- Each frame: reset acceleration → apply forces → update velocity → update position
- **Friction**: opposite to velocity, proportional to normal force
- **Drag**: proportional to velocity², opposite to motion
- **Gravitational attraction**: F = (G × m1 × m2) / distance²

### Oscillation
- Sine/cosine for periodic motion
- Angular velocity for rotation
- **Springs**: Hooke's Law (F = -kx)
- **Pendulums**: gravity + angular constraints

## Particle Systems
- Collection of independent objects governed by rules
- Each particle: position, velocity, lifespan, visual properties
- System manages creation (emitter) and destruction (death)
- Foundation for: fire, smoke, explosions, flocking
- **Key pattern**: pre-allocate pool, reuse objects (no GC pauses)

## Autonomous Agents (Craig Reynolds)

### Steering Behaviors
- Agents that make their own decisions based on environment perception
- **Steering = Desired - Velocity** (vector subtraction)
- Core behaviors: seek, flee, arrive, wander, pursue, evade, path following

### Flocking (Three Rules)
1. **Separation**: avoid crowding neighbors
2. **Alignment**: match neighbors' heading
3. **Cohesion**: steer toward average neighbor position

Complex emergent behavior from simple individual rules.

## Cellular Automata

### Wolfram's Elementary CA
- 1D grid, 2 states, 3-cell neighborhood → 256 possible rule sets
- Rule 30: chaotic
- Rule 110: Turing-complete
- Rule 184: traffic flow

### Conway's Game of Life
- 2D grid; birth (3 neighbors), survival (2-3), death (< 2 or > 3)
- Complex patterns emerge from simple rules

## Genetic Algorithms

### Process
1. Create population
2. Evaluate fitness
3. Selection (fitness-proportional or tournament)
4. Reproduction (crossover + mutation)
5. Repeat

- **Crossover**: combine genetic material from two parents
- **Mutation**: random changes at low probability to maintain diversity
- **Application**: "Smart Rockets" — population evolves thrust sequences to hit target

## Neural Networks
- **Perceptron**: weighted inputs → sum → activation function → output
- Learning: adjust weights based on error (supervised)
- **Feed-forward**: multiple layers, information flows one direction
- Can learn to classify, steer agents, make decisions

---

## Application to Substrate Games

### For CASCADE / Emergent Systems
- Cellular automata for emergent investigation dynamics
- Autonomous agents for NPC behavior in game worlds
- Genetic algorithms for adaptive difficulty

### For Any Game
- Vectors/forces for momentum-based mechanics
- Particle systems for visual effects (pooled, no GC)
- Flocking for crowd/swarm behavior
- Oscillation for ambient animation (floating, breathing, pulsing)

### Implementation Priority
1. Vector motion (every game needs this)
2. Particle systems (visual polish, already covered in mobile-patterns.md)
3. Steering behaviors (any game with NPCs)
4. Cellular automata (emergent systems, special-purpose)
