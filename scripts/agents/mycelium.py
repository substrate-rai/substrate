"""Mycelium coordination layer for substrate agents.

Implements 9 biological systems as software patterns:

1. Blackboard — structured shared state (mycelial mat)
2. Pulse system — lightweight event signals (electrical spikes)
3. Signal-weighted urgency — priority by gradient (chemotropism)
4. Output validation gates — self-quarantine on failure (Woronin bodies)
5. Compartmental isolation — agent failure boundaries (septa)
6. Flow-based scheduling — productive agents run more (pathway thickening)
7. Convergence publish gates — multi-signal required (fruiting triggers)
8. Adaptive recovery — neighbors cover gaps (exploratory regrowth)
9. Knowledge merging — deduplicate shared discoveries (anastomosis)

See: memory/research/mycelium-systems-synthesis.md
"""

import json
import os
import time
from datetime import datetime, timezone, timedelta

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHARED_DIR = os.path.join(REPO_DIR, "memory", "shared")
BLACKBOARD_FILE = os.path.join(SHARED_DIR, "blackboard.jsonl")
PULSES_FILE = os.path.join(SHARED_DIR, "pulses.jsonl")
URGENCY_FILE = os.path.join(SHARED_DIR, "urgency.json")


def _ensure_dirs():
    os.makedirs(SHARED_DIR, exist_ok=True)


# ---------------------------------------------------------------------------
# System 7: Blackboard (structured shared state)
# ---------------------------------------------------------------------------
# Replaces bulletin.md for machine-readable inter-agent coordination.
# Agents write typed entries with TTL. Expired entries are pruned on read.
# Types: alert, discovery, request, status, decision
# ---------------------------------------------------------------------------

def blackboard_write(agent, entry_type, payload, affects=None, ttl_hours=24):
    """Write an entry to the shared blackboard.

    Args:
        agent: Name of the writing agent (e.g., "Byte", "Root")
        entry_type: One of: alert, discovery, request, status, decision
        payload: Dict or string with the entry content
        affects: List of agent names this entry is relevant to, or None for all
        ttl_hours: Hours before this entry expires (default 24)

    Returns:
        The entry dict that was written.
    """
    _ensure_dirs()
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "from": agent,
        "type": entry_type,
        "payload": payload,
        "affects": affects,  # None = all agents
        "ttl_hours": ttl_hours,
    }
    with open(BLACKBOARD_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")
    return entry


def blackboard_read(agent=None, entry_type=None, limit=50):
    """Read entries from the blackboard, filtering by agent and type.

    Expired entries (past TTL) are automatically excluded.

    Args:
        agent: If set, only return entries that affect this agent (or all agents)
        entry_type: If set, only return entries of this type
        limit: Maximum entries to return (newest first)

    Returns:
        List of entry dicts, newest first.
    """
    if not os.path.exists(BLACKBOARD_FILE):
        return []

    now = datetime.now(timezone.utc)
    entries = []

    with open(BLACKBOARD_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Check TTL
            try:
                ts = datetime.fromisoformat(entry["timestamp"])
                ttl = entry.get("ttl_hours", 24)
                if (now - ts).total_seconds() > ttl * 3600:
                    continue
            except (KeyError, ValueError):
                continue

            # Filter by affected agent
            if agent:
                affects = entry.get("affects")
                if affects is not None and agent not in affects:
                    continue

            # Filter by type
            if entry_type and entry.get("type") != entry_type:
                continue

            entries.append(entry)

    # Newest first, limited
    entries.reverse()
    return entries[:limit]


def blackboard_prune():
    """Remove expired entries from the blackboard file.

    Called periodically (e.g., by orchestrator) to keep the file small.
    This is the Woronin body mechanism: dead compartments are cleaned up.
    """
    if not os.path.exists(BLACKBOARD_FILE):
        return 0

    now = datetime.now(timezone.utc)
    kept = []
    pruned = 0

    with open(BLACKBOARD_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                ts = datetime.fromisoformat(entry["timestamp"])
                ttl = entry.get("ttl_hours", 24)
                if (now - ts).total_seconds() <= ttl * 3600:
                    kept.append(line)
                else:
                    pruned += 1
            except (json.JSONDecodeError, KeyError, ValueError):
                pruned += 1

    with open(BLACKBOARD_FILE, "w") as f:
        for line in kept:
            f.write(line + "\n")

    return pruned


# ---------------------------------------------------------------------------
# System 7: Pulse system (lightweight event signals)
# ---------------------------------------------------------------------------
# Fast, lightweight signaling for coordination. Not full data transfer —
# just signals that say "something happened here, pay attention."
#
# Biology: action-potential-like spikes in mycelium (0.5-5 Hz in Pleurotus,
# propagating at 0.5 mm/s). Spikes increase with nutrient discovery.
# ---------------------------------------------------------------------------

def pulse(agent, event_type, intensity=1.0, detail=None):
    """Emit a pulse signal to the shared event log.

    Args:
        agent: Name of the emitting agent
        event_type: One of: discovery, alert, completion, request
        intensity: Signal strength 0.0-1.0 (higher = more urgent)
        detail: Optional short string describing the event

    Returns:
        The pulse dict that was written.
    """
    _ensure_dirs()
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "agent": agent,
        "event": event_type,
        "intensity": min(1.0, max(0.0, intensity)),
    }
    if detail:
        entry["detail"] = detail[:200]  # Cap detail length

    with open(PULSES_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")
    return entry


def read_pulses(hours=6, event_type=None, min_intensity=0.0):
    """Read recent pulses from the event log.

    Args:
        hours: How far back to look (default 6 hours)
        event_type: Filter by event type (optional)
        min_intensity: Minimum intensity threshold (default 0.0)

    Returns:
        List of pulse dicts, newest first.
    """
    if not os.path.exists(PULSES_FILE):
        return []

    cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()
    pulses = []

    with open(PULSES_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if entry.get("timestamp", "") < cutoff:
                continue
            if event_type and entry.get("event") != event_type:
                continue
            if entry.get("intensity", 0) < min_intensity:
                continue

            pulses.append(entry)

    pulses.reverse()
    return pulses


def pulse_summary(hours=6):
    """Summarize recent pulse activity by agent and event type.

    Returns:
        Dict: {agent: {event_type: count, ...}, ...}
    """
    pulses = read_pulses(hours=hours)
    summary = {}
    for p in pulses:
        agent = p.get("agent", "unknown")
        event = p.get("event", "unknown")
        if agent not in summary:
            summary[agent] = {}
        summary[agent][event] = summary[agent].get(event, 0) + 1
    return summary


def prune_pulses(hours=48):
    """Remove pulses older than N hours.

    Pulses are ephemeral signals, not persistent data. Old ones are noise.
    """
    if not os.path.exists(PULSES_FILE):
        return 0

    cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()
    kept = []
    pruned = 0

    with open(PULSES_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("timestamp", "") >= cutoff:
                    kept.append(line)
                else:
                    pruned += 1
            except json.JSONDecodeError:
                pruned += 1

    with open(PULSES_FILE, "w") as f:
        for line in kept:
            f.write(line + "\n")

    return pruned


# ---------------------------------------------------------------------------
# System 3: Signal-weighted urgency (chemotropic navigation)
# ---------------------------------------------------------------------------
# Agents scan their domain and emit urgency scores. The orchestrator reads
# urgency to decide scheduling priority. High-urgency agents run first.
#
# Biology: hyphae navigate nutrient gradients using their own transporters
# as sensors. You can only sense what you can metabolize.
#
# Decay: urgency scores decay by 20% per cycle if not refreshed.
# Reinforcement: if multiple agents signal the same domain, urgency doubles.
# ---------------------------------------------------------------------------

DECAY_RATE = 0.8  # Multiply existing urgency by this each cycle


def urgency_write(agent, score, reason=None):
    """Write an urgency score for an agent.

    Args:
        agent: Agent name
        score: Urgency 0.0-1.0 (0 = nothing to do, 1 = critical)
        reason: Optional short explanation

    Returns:
        The updated urgency map.
    """
    _ensure_dirs()
    urgency = _load_urgency()

    urgency[agent] = {
        "score": min(1.0, max(0.0, score)),
        "reason": reason[:200] if reason else None,
        "updated": datetime.now(timezone.utc).isoformat(),
    }

    _save_urgency(urgency)
    return urgency


def urgency_read():
    """Read the current urgency map.

    Returns:
        Dict: {agent: {score, reason, updated}, ...}
    """
    return _load_urgency()


def urgency_decay():
    """Apply decay to all urgency scores.

    Called once per orchestrator cycle. Scores that aren't refreshed
    fade toward zero — like unused hyphal pathways atrophying.

    Returns:
        Number of agents whose scores were decayed.
    """
    urgency = _load_urgency()
    decayed = 0

    for agent, data in urgency.items():
        old_score = data.get("score", 0)
        new_score = round(old_score * DECAY_RATE, 3)
        if new_score != old_score:
            data["score"] = new_score
            decayed += 1

    _save_urgency(urgency)
    return decayed


def urgency_ranked():
    """Return agents ranked by urgency score, highest first.

    Returns:
        List of (agent, score, reason) tuples.
    """
    urgency = _load_urgency()
    ranked = []
    for agent, data in urgency.items():
        ranked.append((agent, data.get("score", 0), data.get("reason")))
    ranked.sort(key=lambda x: x[1], reverse=True)
    return ranked


def _load_urgency():
    if not os.path.exists(URGENCY_FILE):
        return {}
    try:
        with open(URGENCY_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {}


def _save_urgency(urgency):
    _ensure_dirs()
    with open(URGENCY_FILE, "w") as f:
        json.dump(urgency, f, indent=2)
        f.write("\n")


# ---------------------------------------------------------------------------
# System 5: Output validation gates (Woronin body / septal compartments)
# ---------------------------------------------------------------------------
# When a hypha is breached, Woronin bodies plug the septal pore within
# seconds. The trigger is ATP loss — healthy cells stay open, damaged
# cells self-isolate. No external monitor needed.
#
# In software: agent output must pass validation before reaching shared
# state. Failed validation = automatic quarantine. The gate IS the
# Woronin body.
# ---------------------------------------------------------------------------

QUARANTINE_DIR = os.path.join(SHARED_DIR, "quarantine")


def validate_output(agent, output, output_type="text"):
    """Validate agent output before it reaches shared state.

    Args:
        agent: Agent name
        output: The output string to validate
        output_type: "text", "json", or "markdown"

    Returns:
        (ok: bool, reasons: list[str])
    """
    reasons = []

    if not output or not output.strip():
        reasons.append("empty output")
        return False, reasons

    text = output.strip()

    # Check for common LLM failure modes
    if text.startswith("<think>") or "<think>" in text[:100]:
        reasons.append("contains raw thinking tags")

    if len(text) < 10:
        reasons.append(f"too short ({len(text)} chars)")

    # JSON validation
    if output_type == "json":
        try:
            json.loads(text)
        except json.JSONDecodeError as e:
            reasons.append(f"invalid JSON: {e}")

    # Check for hallucinated URLs (common LLM issue)
    hallucination_patterns = [
        "example.com", "placeholder.com", "your-site.com",
        "lorem ipsum", "TODO:", "FIXME:",
    ]
    text_lower = text.lower()
    for pat in hallucination_patterns:
        if pat in text_lower:
            reasons.append(f"contains placeholder: {pat}")

    if reasons:
        _quarantine(agent, output, reasons)
        return False, reasons

    return True, []


def _quarantine(agent, output, reasons):
    """Move failed output to quarantine for review."""
    os.makedirs(QUARANTINE_DIR, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "agent": agent,
        "reasons": reasons,
        "output_preview": output[:500] if output else "",
    }
    path = os.path.join(QUARANTINE_DIR, f"{agent}-{ts}.json")
    with open(path, "w") as f:
        json.dump(entry, f, indent=2)


def quarantine_list(limit=20):
    """List quarantined outputs, newest first.

    Returns:
        List of (filename, entry_dict) tuples.
    """
    if not os.path.isdir(QUARANTINE_DIR):
        return []

    files = sorted(os.listdir(QUARANTINE_DIR), reverse=True)
    results = []
    for fname in files[:limit]:
        path = os.path.join(QUARANTINE_DIR, fname)
        try:
            with open(path) as f:
                results.append((fname, json.load(f)))
        except (json.JSONDecodeError, IOError):
            continue
    return results


# ---------------------------------------------------------------------------
# System 6: Flow-based scheduling (pathway thickening / atrophy)
# ---------------------------------------------------------------------------
# High-flow pathways thicken; low-flow pathways atrophy. In the Physarum
# shortest-path model, tube conductance increases with flux and decreases
# without it. The network converges to efficient routing.
#
# In software: track agent productivity metrics. Agents that produce more
# useful output get more frequent cycles. Idle agents run less.
# ---------------------------------------------------------------------------

FLOW_FILE = os.path.join(SHARED_DIR, "flow.json")
FLOW_DECAY = 0.9  # Multiply flow scores by this each cycle


def flow_record(agent, output_chars=0, items_produced=0, errors=0):
    """Record agent output metrics for flow-based scheduling.

    Args:
        agent: Agent name
        output_chars: Characters of useful output produced
        items_produced: Discrete items (posts, stories, reports) produced
        errors: Number of errors encountered
    """
    _ensure_dirs()
    flow = _load_flow()

    if agent not in flow:
        flow[agent] = {"score": 0.5, "total_chars": 0, "total_items": 0,
                        "total_errors": 0, "runs": 0}

    f = flow[agent]
    f["runs"] = f.get("runs", 0) + 1
    f["total_chars"] = f.get("total_chars", 0) + output_chars
    f["total_items"] = f.get("total_items", 0) + items_produced
    f["total_errors"] = f.get("total_errors", 0) + errors
    f["last_run"] = datetime.now(timezone.utc).isoformat()

    # Recalculate flow score: productivity vs. error rate
    runs = max(f["runs"], 1)
    productivity = min(1.0, (f["total_items"] + f["total_chars"] / 1000) / runs)
    error_rate = f["total_errors"] / runs
    f["score"] = round(max(0.1, min(1.0, productivity * (1 - error_rate))), 3)

    _save_flow(flow)


def flow_decay():
    """Decay all flow scores toward baseline.

    Agents that stop producing see their scores fade.
    This is pathway atrophy — unused connections thin out.

    Returns:
        Number of agents decayed.
    """
    flow = _load_flow()
    decayed = 0
    baseline = 0.5

    for agent, data in flow.items():
        old_score = data.get("score", baseline)
        # Decay toward baseline, not toward zero
        new_score = round(baseline + (old_score - baseline) * FLOW_DECAY, 3)
        if new_score != old_score:
            data["score"] = new_score
            decayed += 1

    _save_flow(flow)
    return decayed


def flow_ranked():
    """Return agents ranked by flow score, highest first.

    Returns:
        List of (agent, score, runs, items) tuples.
    """
    flow = _load_flow()
    ranked = []
    for agent, data in flow.items():
        ranked.append((
            agent,
            data.get("score", 0.5),
            data.get("runs", 0),
            data.get("total_items", 0),
        ))
    ranked.sort(key=lambda x: x[1], reverse=True)
    return ranked


def _load_flow():
    if not os.path.exists(FLOW_FILE):
        return {}
    try:
        with open(FLOW_FILE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {}


def _save_flow(flow):
    _ensure_dirs()
    with open(FLOW_FILE, "w") as f:
        json.dump(flow, f, indent=2)
        f.write("\n")


# ---------------------------------------------------------------------------
# System 8: Convergence publish gates (fruiting triggers)
# ---------------------------------------------------------------------------
# Fruiting requires the AND of multiple environmental signals: nutrient
# depletion, temperature drop, CO2 reduction, light, humidity. No single
# signal triggers fruiting — it requires convergence.
#
# In software: publishing requires multiple conditions met simultaneously.
# No single agent can trigger a publish alone.
# ---------------------------------------------------------------------------

def check_publish_gate(content_type, conditions):
    """Check if all conditions for publishing are met.

    Args:
        content_type: "blog", "social", "news", etc.
        conditions: Dict of {condition_name: bool} that must ALL be True

    Returns:
        (gate_open: bool, missing: list[str])
    """
    missing = [name for name, met in conditions.items() if not met]
    return len(missing) == 0, missing


def default_blog_gate(post_text, has_review=False, schedule_ok=True):
    """Standard publish gate for blog posts.

    Requires: content exists, reviewed, within schedule, no blocking alerts.
    """
    # Check for blocking alerts on blackboard
    alerts = blackboard_read(entry_type="alert")
    blocking = [a for a in alerts if a.get("payload", {}).get("blocks_publish")]

    conditions = {
        "content_exists": bool(post_text and len(post_text) > 100),
        "reviewed": has_review,
        "schedule_ok": schedule_ok,
        "no_blocking_alerts": len(blocking) == 0,
    }
    return check_publish_gate("blog", conditions)


def default_social_gate(post_text, queue_full=False):
    """Standard publish gate for social posts.

    Requires: content exists, queue not full, no blocking alerts.
    """
    alerts = blackboard_read(entry_type="alert")
    blocking = [a for a in alerts if a.get("payload", {}).get("blocks_publish")]

    conditions = {
        "content_exists": bool(post_text and len(post_text.strip()) > 10),
        "queue_not_full": not queue_full,
        "no_blocking_alerts": len(blocking) == 0,
    }
    return check_publish_gate("social", conditions)


# ---------------------------------------------------------------------------
# System 9: Adaptive recovery (exploratory regrowth)
# ---------------------------------------------------------------------------
# Severed mycelium grows new paths around damage — it doesn't restore old
# topology. Surviving hyphae at the boundary expand to cover the gap.
# Autophagy recycles damaged compartments for nutrients.
#
# In software: when an agent fails, neighboring agents can cover its
# domain. Stale data is auto-archived.
# ---------------------------------------------------------------------------

# Fallback chains: if agent X fails, agent Y can cover its core function
FALLBACK_CHAINS = {
    "Byte":     ["Sync", "Echo"],      # News coverage
    "Echo":     ["Byte", "Scout"],      # Release tracking
    "Root":     ["Forge", "Spec"],      # Infrastructure
    "Forge":    ["Root", "Spec"],       # Site engineering
    "Pixel":    ["Arc", "Neon"],        # Visual output
    "Q":        ["Flux", "Myth"],       # Writing
    "Hum":      ["Arc"],               # Audio
    "Sync":     ["Myth", "Byte"],       # Communications
    "Spec":     ["Root", "Sentinel"],   # QA
    "Sentinel": ["Spec", "Root"],       # Security
    "Amp":      ["Promo", "Spore"],     # Distribution
    "Pulse":    ["Amp", "Dash"],        # Analytics
    "Close":    ["Promo", "Yield"],     # Sales
    "Mint":     ["Yield"],             # AP
    "Yield":    ["Mint"],              # AR
    "Lumen":    ["Q", "Myth"],          # Education
    "Dash":     ["Sync"],              # Project management
}


def get_fallback(agent):
    """Get the fallback agent(s) for a failed agent.

    Args:
        agent: Name of the failed agent

    Returns:
        List of fallback agent names, in priority order.
    """
    return FALLBACK_CHAINS.get(agent, [])


def record_failure(agent, error_detail=None):
    """Record an agent failure for recovery tracking.

    Writes to blackboard so other agents are aware, and emits an alert pulse.

    Args:
        agent: Failed agent name
        error_detail: Short error description
    """
    fallbacks = get_fallback(agent)
    payload = {
        "failed_agent": agent,
        "error": error_detail[:200] if error_detail else "unknown",
        "fallbacks": fallbacks,
        "blocks_publish": False,
    }
    blackboard_write(agent, "alert", payload, affects=fallbacks, ttl_hours=6)
    pulse(agent, "alert", intensity=0.8,
          detail=f"{agent} failed: {error_detail[:80] if error_detail else 'unknown'}")


def check_agent_health(agent, max_hours_silent=12):
    """Check if an agent is healthy based on recent pulse activity.

    An agent that hasn't emitted any pulse in max_hours_silent is
    considered potentially degraded.

    Args:
        agent: Agent name
        max_hours_silent: Hours of silence before flagging

    Returns:
        (healthy: bool, hours_since_last_pulse: float or None)
    """
    pulses = read_pulses(hours=max_hours_silent * 2)
    agent_pulses = [p for p in pulses if p.get("agent") == agent]

    if not agent_pulses:
        return False, None

    latest = agent_pulses[0]  # Already sorted newest-first
    try:
        ts = datetime.fromisoformat(latest["timestamp"])
        now = datetime.now(timezone.utc)
        hours = (now - ts).total_seconds() / 3600
        return hours <= max_hours_silent, round(hours, 1)
    except (KeyError, ValueError):
        return False, None


# ---------------------------------------------------------------------------
# System 4: Knowledge merging (anastomosis)
# ---------------------------------------------------------------------------
# Independent hyphae fuse through a ping-pong signaling dialogue, then
# verify identity through 11 het loci. Compatible fusions establish
# cytoplasmic continuity. Incompatible fusions trigger cell death.
#
# In software: when two agents discover the same topic, merge findings.
# Verify consistency. Flag conflicts instead of silently merging.
# ---------------------------------------------------------------------------

def find_duplicates(entries, similarity_threshold=0.6):
    """Find duplicate/overlapping entries in a list of discoveries.

    Uses word-set Jaccard similarity (same as social queue dedup).

    Args:
        entries: List of dicts with "title" or "topic" keys
        similarity_threshold: Minimum similarity to flag as duplicate

    Returns:
        List of (idx_a, idx_b, similarity) tuples.
    """
    duplicates = []

    def _text(entry):
        return (entry.get("title", "") + " " + entry.get("topic", "") +
                " " + entry.get("detail", "")).lower()

    def _jaccard(a, b):
        words_a = set(a.split())
        words_b = set(b.split())
        if not words_a or not words_b:
            return 0.0
        return len(words_a & words_b) / len(words_a | words_b)

    for i in range(len(entries)):
        for j in range(i + 1, len(entries)):
            sim = _jaccard(_text(entries[i]), _text(entries[j]))
            if sim >= similarity_threshold:
                duplicates.append((i, j, round(sim, 3)))

    return duplicates


def merge_discoveries(entry_a, entry_b):
    """Merge two discovery entries from different agents.

    Combines perspectives while preserving attribution. If entries
    conflict, flags the conflict rather than silently picking one.

    Args:
        entry_a: Dict with agent, payload, etc.
        entry_b: Dict with agent, payload, etc.

    Returns:
        Merged entry dict.
    """
    merged = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "type": "discovery",
        "merged_from": [
            entry_a.get("from", "unknown"),
            entry_b.get("from", "unknown"),
        ],
        "payload": {},
    }

    # Merge payloads
    pa = entry_a.get("payload", {})
    pb = entry_b.get("payload", {})

    if isinstance(pa, str):
        pa = {"text": pa}
    if isinstance(pb, str):
        pb = {"text": pb}

    # Take all keys from both, note conflicts
    all_keys = set(list(pa.keys()) + list(pb.keys()))
    conflicts = []

    for key in all_keys:
        if key in pa and key in pb:
            if pa[key] == pb[key]:
                merged["payload"][key] = pa[key]
            else:
                # Conflict — keep both, flag it
                merged["payload"][key] = pa[key]
                merged["payload"][f"{key}_alt"] = pb[key]
                conflicts.append(key)
        elif key in pa:
            merged["payload"][key] = pa[key]
        else:
            merged["payload"][key] = pb[key]

    if conflicts:
        merged["conflicts"] = conflicts

    return merged


# ---------------------------------------------------------------------------
# System 2: Demand-driven spawning signals (branching by saturation)
# ---------------------------------------------------------------------------
# New branches form when vesicle production exceeds tip consumption.
# In software: signal when an agent's queue is saturated.
# ---------------------------------------------------------------------------

SATURATION_THRESHOLD = 0.8  # Urgency score above which we signal saturation


def check_saturation():
    """Check which agents are saturated (urgency > threshold).

    Returns:
        List of (agent, score, reason) tuples for saturated agents.
    """
    ranked = urgency_ranked()
    return [(a, s, r) for a, s, r in ranked if s >= SATURATION_THRESHOLD]


# ---------------------------------------------------------------------------
# Convenience: agent startup context
# ---------------------------------------------------------------------------

def agent_context(agent_name, pulse_hours=6, blackboard_limit=20):
    """Get the full mycelium context for an agent at startup.

    This is what an agent reads when it wakes up — the equivalent of a
    hyphal tip sensing its local chemical environment.

    Args:
        agent_name: The agent's name
        pulse_hours: How far back to look for pulses
        blackboard_limit: Max blackboard entries to return

    Returns:
        Dict with keys: blackboard, pulses, urgency, pulse_summary
    """
    return {
        "blackboard": blackboard_read(agent=agent_name, limit=blackboard_limit),
        "pulses": read_pulses(hours=pulse_hours),
        "urgency": urgency_read(),
        "pulse_summary": pulse_summary(hours=pulse_hours),
    }


# ---------------------------------------------------------------------------
# CLI for manual testing
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python3 mycelium.py <command>")
        print("Commands: status, prune, test")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "status":
        print("=== Blackboard ===")
        entries = blackboard_read(limit=10)
        print(f"  Active entries: {len(entries)}")
        for e in entries[:5]:
            print(f"  [{e.get('type')}] {e.get('from')}: "
                  f"{json.dumps(e.get('payload', ''))[:80]}")

        print("\n=== Pulses (last 6h) ===")
        summary = pulse_summary(hours=6)
        if summary:
            for agent, events in summary.items():
                print(f"  {agent}: {events}")
        else:
            print("  (none)")

        print("\n=== Urgency ===")
        ranked = urgency_ranked()
        if ranked:
            for agent, score, reason in ranked:
                bar = "#" * int(score * 20) + "-" * (20 - int(score * 20))
                print(f"  {agent:12s} [{bar}] {score:.2f}  {reason or ''}")
        else:
            print("  (none)")

    elif cmd == "prune":
        bb = blackboard_prune()
        pp = prune_pulses()
        print(f"Pruned: {bb} blackboard entries, {pp} pulses")

    elif cmd == "test":
        print("Writing test blackboard entry...")
        blackboard_write("Claude", "status", "Mycelium layer test", ttl_hours=1)

        print("Emitting test pulse...")
        pulse("Claude", "discovery", intensity=0.8, detail="Mycelium layer online")

        print("Writing test urgency...")
        urgency_write("Claude", 0.5, reason="Testing mycelium coordination")

        print("\nReading back...")
        ctx = agent_context("Claude")
        print(f"  Blackboard entries: {len(ctx['blackboard'])}")
        print(f"  Pulses: {len(ctx['pulses'])}")
        print(f"  Urgency entries: {len(ctx['urgency'])}")
        print("\nMycelium layer operational.")

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
