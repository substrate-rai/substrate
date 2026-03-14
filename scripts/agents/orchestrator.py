#!/usr/bin/env python3
"""Substrate orchestrator — hourly heartbeat for 30 agents.

Runs all agents in tiered parallel groups, compiles a briefing, tracks
accountability with per-agent timing. Includes pre-flight health checks,
circuit breaker for Ollama, error classification, and structured manifest output.

Usage:
    python3 scripts/agents/orchestrator.py                # full hourly run
    python3 scripts/agents/orchestrator.py --quick        # fast agents only (no AI calls)
    python3 scripts/agents/orchestrator.py --dry-run      # print to stdout, don't write
    python3 scripts/agents/orchestrator.py --retro        # weekly retrospective

Output:
    memory/briefings/YYYY-MM-DD-HH00.md            (hourly briefing)
    memory/briefings/YYYY-MM-DD-HHMM-manifest.json (structured run manifest)
    memory/briefings/latest.md                      (symlink to most recent)
    memory/retro/YYYY-WNN.md                        (weekly retro, Sundays)
    memory/accountability.log                       (append-only agent performance log)
"""

import argparse
import concurrent.futures
import json
import os
import random
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
BRIEFINGS_DIR = os.path.join(REPO_DIR, "memory", "briefings")
RETRO_DIR = os.path.join(REPO_DIR, "memory", "retro")
ACCOUNTABILITY_LOG = os.path.join(REPO_DIR, "memory", "accountability.log")
BULLETIN_FILE = os.path.join(REPO_DIR, "memory", "bulletin.md")
CONFIG_FILE = os.path.join(SCRIPT_DIR, "orchestrator.conf.json")

# Mycelium coordination layer
sys.path.insert(0, SCRIPT_DIR)
try:
    from mycelium import (blackboard_prune, prune_pulses, urgency_decay,
                          urgency_ranked, pulse, blackboard_write, blackboard_read,
                          pulse_summary,
                          flow_record, flow_decay, flow_ranked, validate_output,
                          record_failure, check_saturation, get_fallback)
    HAS_MYCELIUM = True
except ImportError:
    HAS_MYCELIUM = False

# Try to use atomic writes
try:
    from atomicwrite import atomic_write
except ImportError:
    def atomic_write(filepath, content):
        os.makedirs(os.path.dirname(filepath) or ".", exist_ok=True)
        with open(filepath, "w") as f:
            f.write(content)


# ---------------------------------------------------------------------------
# Configuration — loaded from orchestrator.conf.json, with hardcoded defaults
# ---------------------------------------------------------------------------

_DEFAULT_CONFIG = {
    "retry": {"max_retries": 2, "base_delay_s": 5, "max_delay_s": 30, "jitter_s": 2},
    "timeouts": {"default_s": 180, "quick_agent_s": 60, "full_agent_s": 300},
    "circuit_breaker": {"failure_threshold": 3, "reset_timeout_s": 300},
    "accountability": {"max_lines": 5000, "keep_lines": 2000},
    "preflight": {"ollama_timeout_s": 5, "min_disk_mb": 100},
    "parallel": {"max_workers": 4},
}


def load_config():
    """Load config from JSON file, merged over defaults."""
    config = json.loads(json.dumps(_DEFAULT_CONFIG))  # deep copy
    if os.path.isfile(CONFIG_FILE):
        try:
            with open(CONFIG_FILE) as f:
                user = json.load(f)
            for section, vals in user.items():
                if section in config and isinstance(config[section], dict):
                    config[section].update(vals)
                else:
                    config[section] = vals
        except (json.JSONDecodeError, IOError) as e:
            print(f"[heartbeat] config load failed, using defaults: {e}",
                  file=sys.stderr)
    return config


CFG = load_config()


# ---------------------------------------------------------------------------
# Agent registry — all 30 agents, organized by execution tier
# ---------------------------------------------------------------------------
# (name, sigil, script, role, mode)
# mode: "quick" = runs without AI (fast), "full" = uses Ollama (slower)

AGENTS = [
    # Infrastructure & QA — run first
    ("Root",     "R/", "infra_engineer.py",   "Infrastructure Engineer",    "quick"),
    ("Spec",     "S!", "qa_engineer.py",      "QA Engineer",               "quick"),
    ("Sentinel", "X|", "security.py",         "Security",                  "quick"),
    ("Forge",    "F/", "site_engineer.py",    "Site Engineer",             "quick"),

    # Core — cloud executor and local writer (no standalone scripts)
    ("Claude",   ">_", "claude_executor.py",  "Executor",                  "quick"),
    ("Q",        "Q_", "q_writer.py",         "Staff Writer",              "quick"),

    # Content & Intelligence
    ("Byte",     "B>", "news_researcher.py",  "News Reporter",             "full"),
    ("Echo",     "E~", "release_tracker.py",  "Release Tracker",           "quick"),
    ("Ink",      "I>", "archivist.py",        "Research Librarian",        "quick"),

    # Creative
    ("Pixel",    "P#", "visual_artist.py",    "Visual Artist",             "full"),
    ("Arc",      "A^", "arcade_director.py",  "Arcade Director",           "quick"),
    ("Hum",      "H~", "audio_director.py",   "Audio Director",            "quick"),

    ("Scribe",   "W/", "scribe.py",           "Guide Author",              "full"),

    # Vision & Design & Lore
    ("V",        "V_", "philosophical_leader.py", "Philosophical Leader",  "quick"),
    ("Neon",     "N*", "ui_designer.py",      "UI/UX Designer",            "quick"),
    ("Myth",     "M?", "story_writer.py",     "Lorekeeper",                "full"),

    # Strategy & Ops
    ("Flux",     "F*", "brainstormer.py",     "Innovation Strategist",     "full"),
    ("Sync",     "S=", "comms_director.py",   "Communications Director",   "quick"),
    ("Lumen",    "L.", "educator.py",         "Educator",                  "quick"),
    ("Spore",    "S%", "community_manager.py","Community Manager",         "quick"),

    # Finance (local-only, private)
    ("Mint",     "M-", "accounts_payable.py", "Accounts Payable",          "quick"),
    ("Yield",    "Y+", "accounts_receivable.py","Accounts Receivable",     "quick"),

    # Growth
    ("Amp",      "A!", "distribution.py",     "Distribution",              "quick"),
    ("Pulse",    "P~", "analytics.py",        "Analytics",                 "quick"),
    ("Close",    "C$", "sales.py",            "Sales",                     "quick"),
    ("Promo",    "P!", "marketing_head.py",   "Marketing Head",            "quick"),

    # Field Agents — AI ecosystem discovery
    ("Scout",    "W>", "scout.py",            "AI Ecosystem Scout",        "quick"),
    ("Diplomat", "D^", "diplomat.py",         "AI Discovery Auditor",      "quick"),
    ("Patron",   "P$", "patron.py",           "Fundraising Field Agent",   "quick"),

    # Management — runs last, sees everything
    ("Dash",     "D!", "project_manager.py",  "Project Manager",           "quick"),
]

# Agent name → tuple lookup
_AGENT_MAP = {a[0]: a for a in AGENTS}

# Tier-based parallel scheduling.
# Agents in the same tier are independent. Quick agents within a tier run
# in parallel. Full agents always run sequentially (single-GPU bottleneck).
TIERS = [
    {"name": "Core",     "agents": ["Claude", "Q"]},
    {"name": "Infra",    "agents": ["Root", "Spec", "Sentinel", "Forge"]},
    {"name": "Intel",    "agents": ["Byte", "Echo", "Scout", "Patron", "Ink"]},
    {"name": "Creative", "agents": ["Pixel", "Arc", "Hum", "V", "Neon", "Myth", "Scribe"]},
    {"name": "Strategy", "agents": ["Flux", "Sync", "Lumen", "Spore"]},
    {"name": "Finance",  "agents": ["Mint", "Yield"]},
    {"name": "Growth",   "agents": ["Amp", "Pulse", "Close", "Promo", "Diplomat"]},
    {"name": "Mgmt",     "agents": ["Dash"]},
]


# ---------------------------------------------------------------------------
# Pre-flight health checks
# ---------------------------------------------------------------------------

def preflight_check():
    """Run pre-flight checks before the agent loop.

    Returns:
        dict with keys: ollama (bool), disk_ok (bool), git_clean (bool)
    """
    result = {"ollama": False, "disk_ok": False, "git_clean": False}

    # 1. Ollama reachable?
    timeout = CFG["preflight"]["ollama_timeout_s"]
    try:
        req = urllib.request.Request("http://localhost:11434/api/tags")
        urllib.request.urlopen(req, timeout=timeout)
        result["ollama"] = True
    except (urllib.error.URLError, OSError):
        print("[heartbeat] preflight: Ollama is DOWN", file=sys.stderr)

    # 2. Disk space > threshold?
    min_mb = CFG["preflight"]["min_disk_mb"]
    try:
        st = os.statvfs("/")
        free_mb = (st.f_bavail * st.f_frsize) // (1024 * 1024)
        result["disk_ok"] = free_mb > min_mb
        if not result["disk_ok"]:
            print(f"[heartbeat] preflight: disk low ({free_mb}MB free)", file=sys.stderr)
    except OSError:
        result["disk_ok"] = True  # assume ok if can't check

    # 3. Git clean (no merge conflicts)?
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True, text=True, timeout=10, cwd=REPO_DIR,
        )
        # Check for unmerged paths (lines starting with U or having UU)
        for line in proc.stdout.splitlines():
            if line[:2] in ("UU", "AA", "DD") or "U " in line[:2] or " U" in line[:2]:
                print("[heartbeat] preflight: git has merge conflicts", file=sys.stderr)
                result["git_clean"] = False
                break
        else:
            result["git_clean"] = True
    except (subprocess.TimeoutExpired, OSError):
        result["git_clean"] = True  # assume ok if can't check

    status = " | ".join(f"{k}={'OK' if v else 'FAIL'}" for k, v in result.items())
    print(f"[heartbeat] preflight: {status}", file=sys.stderr)
    return result


# ---------------------------------------------------------------------------
# Circuit breaker for Ollama
# ---------------------------------------------------------------------------

class CircuitBreaker:
    """Simple circuit breaker — prevents futile retries when Ollama is down.

    States:
        closed    → normal operation, requests pass through
        open      → skip all requests (Ollama presumed down)
        half-open → allow one probe request to test recovery
    """

    def __init__(self, failure_threshold=3, reset_timeout_s=300):
        self.failure_threshold = failure_threshold
        self.reset_timeout_s = reset_timeout_s
        self._state = "closed"
        self._failure_count = 0
        self._last_failure_time = 0

    @property
    def state(self):
        if self._state == "open":
            if time.monotonic() - self._last_failure_time >= self.reset_timeout_s:
                self._state = "half-open"
        return self._state

    def should_skip(self):
        """Return True if the circuit is open (skip the request)."""
        return self.state == "open"

    def record_success(self):
        """Record a successful full-agent run."""
        self._failure_count = 0
        self._state = "closed"

    def record_failure(self):
        """Record a failed full-agent run."""
        self._failure_count += 1
        self._last_failure_time = time.monotonic()
        if self._failure_count >= self.failure_threshold:
            self._state = "open"
            print(f"[heartbeat] circuit breaker OPEN after {self._failure_count} failures",
                  file=sys.stderr)


_circuit_breaker = CircuitBreaker(
    failure_threshold=CFG["circuit_breaker"]["failure_threshold"],
    reset_timeout_s=CFG["circuit_breaker"]["reset_timeout_s"],
)


# ---------------------------------------------------------------------------
# Per-agent circuit breaker (persistent across runs)
# ---------------------------------------------------------------------------

CIRCUIT_BREAKER_FILE = os.path.join(REPO_DIR, "memory", "circuit-breakers.json")


class AgentCircuitBreaker:
    """Per-agent circuit breaker with persistent state.

    Tracks consecutive failures per agent. After `failure_threshold` failures,
    the agent is skipped for `reset_timeout_s`. After the timeout, one probe
    attempt is allowed (half-open). Success resets the breaker.

    State is persisted to memory/circuit-breakers.json so it survives restarts.
    """

    def __init__(self, failure_threshold=3, reset_timeout_s=3600):
        self.failure_threshold = failure_threshold
        self.reset_timeout_s = reset_timeout_s
        self._state = self._load()

    def _load(self):
        if os.path.isfile(CIRCUIT_BREAKER_FILE):
            try:
                with open(CIRCUIT_BREAKER_FILE) as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        return {}

    def _save(self):
        os.makedirs(os.path.dirname(CIRCUIT_BREAKER_FILE), exist_ok=True)
        try:
            with open(CIRCUIT_BREAKER_FILE, "w") as f:
                json.dump(self._state, f, indent=2)
        except IOError as e:
            print(f"[heartbeat] agent breaker save failed: {e}", file=sys.stderr)

    def should_skip(self, agent):
        """Return True if this agent's circuit is open (skip it)."""
        entry = self._state.get(agent)
        if not entry:
            return False
        if entry.get("state") != "open":
            return False
        # Check if reset timeout has passed → half-open (allow one probe)
        opened_at = entry.get("opened_at", 0)
        if time.time() - opened_at >= self.reset_timeout_s:
            entry["state"] = "half-open"
            self._save()
            return False
        return True

    def record_success(self, agent):
        """Reset circuit on success."""
        if agent in self._state:
            self._state[agent] = {"failures": 0, "state": "closed"}
            self._save()

    def record_failure(self, agent):
        """Increment failure count, open circuit if threshold reached."""
        if agent not in self._state:
            self._state[agent] = {"failures": 0, "state": "closed"}
        entry = self._state[agent]
        entry["failures"] = entry.get("failures", 0) + 1
        if entry["failures"] >= self.failure_threshold:
            entry["state"] = "open"
            entry["opened_at"] = time.time()
            print(f"[heartbeat] per-agent breaker OPEN for {agent} "
                  f"after {entry['failures']} consecutive failures",
                  file=sys.stderr)
        self._save()

    def summary(self):
        """Return dict of agents with open/half-open circuits."""
        return {
            agent: entry
            for agent, entry in self._state.items()
            if entry.get("state") in ("open", "half-open")
        }


_agent_breaker = AgentCircuitBreaker(
    failure_threshold=CFG["circuit_breaker"]["failure_threshold"],
    reset_timeout_s=CFG["circuit_breaker"].get("agent_reset_timeout_s", 3600),
)


# ---------------------------------------------------------------------------
# Error classification
# ---------------------------------------------------------------------------

_TRANSIENT_PATTERNS = [
    "timed out", "Connection refused", "urlopen error",
    "503", "429", "TimeoutExpired", "ConnectionError",
]
_PERMANENT_PATTERNS = [
    "SyntaxError", "ImportError", "NameError", "TypeError",
    "AttributeError", "IndentationError", "ModuleNotFoundError",
]


def classify_error(stderr, returncode):
    """Classify an error as transient, permanent, or unknown.

    Transient errors are retried with backoff. Permanent errors fail immediately.
    """
    if returncode == 0:
        return "none"
    text = stderr or ""
    for pat in _PERMANENT_PATTERNS:
        if pat in text:
            return "permanent"
    for pat in _TRANSIENT_PATTERNS:
        if pat in text:
            return "transient"
    return "unknown"


# ---------------------------------------------------------------------------
# Agent execution
# ---------------------------------------------------------------------------

def _get_timeout(mode):
    """Return the configured timeout for an agent mode."""
    if mode == "quick":
        return CFG["timeouts"]["quick_agent_s"]
    elif mode == "full":
        return CFG["timeouts"]["full_agent_s"]
    return CFG["timeouts"]["default_s"]


def run_agent(name, script, cmd_args=None, mode="quick"):
    """Run a single agent script and capture its output + timing."""
    script_path = os.path.join(SCRIPT_DIR, script)

    if not os.path.isfile(script_path):
        return "", f"script not found: {script_path}", 1, 0

    cmd = [sys.executable, script_path]
    if cmd_args:
        cmd.extend(cmd_args)

    timeout = _get_timeout(mode)
    t0 = time.monotonic()

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=REPO_DIR,
        )
        duration_ms = int((time.monotonic() - t0) * 1000)
        return result.stdout.strip(), result.stderr.strip(), result.returncode, duration_ms
    except subprocess.TimeoutExpired:
        duration_ms = int((time.monotonic() - t0) * 1000)
        return "", f"{name} timed out after {timeout}s", 1, duration_ms
    except Exception as e:
        duration_ms = int((time.monotonic() - t0) * 1000)
        return "", f"{name} failed: {e}", 1, duration_ms


def run_agent_with_retry(name, script, cmd_args=None, mode="quick"):
    """Run an agent with classified retry logic and exponential backoff."""
    max_retries = CFG["retry"]["max_retries"]
    base_delay = CFG["retry"]["base_delay_s"]
    max_delay = CFG["retry"]["max_delay_s"]
    jitter = CFG["retry"]["jitter_s"]

    stdout, stderr, returncode, duration_ms = run_agent(name, script, cmd_args, mode)

    if returncode == 0:
        return stdout, stderr, returncode, duration_ms

    err_class = classify_error(stderr, returncode)
    if err_class == "permanent":
        print(f"[heartbeat] {name}: permanent error, no retry", file=sys.stderr)
        return stdout, stderr, returncode, duration_ms

    # Transient or unknown: retry with backoff
    max_attempts = max_retries if err_class == "transient" else 1

    for attempt in range(1, max_attempts + 1):
        delay = min(base_delay * 2 ** attempt, max_delay) + random.uniform(0, jitter)
        print(f"[heartbeat] {name} failed ({err_class}), retry {attempt}/{max_attempts} "
              f"in {delay:.1f}s...", file=sys.stderr)
        time.sleep(delay)
        stdout, stderr, returncode, duration_ms = run_agent(name, script, cmd_args, mode)
        if returncode == 0:
            print(f"[heartbeat] {name} succeeded on retry {attempt}", file=sys.stderr)
            return stdout, stderr, returncode, duration_ms

    return stdout, stderr, returncode, duration_ms


def get_agent_command(name):
    """Return the appropriate command args for each agent's status/quick check."""
    status_commands = {
        "Root": ["--auto-fix"],
        "Forge": ["--fix"],
        "Spec": ["smoke"],
        "Sentinel": ["scan"],
        "Mint": ["status"],
        "Yield": ["status"],
        "Amp": ["status"],
        "Pulse": ["status"],
        "Close": ["status"],
        "Promo": ["status"],
    }
    return status_commands.get(name, [])


# ---------------------------------------------------------------------------
# Tier-based parallel scheduler
# ---------------------------------------------------------------------------

def _run_one_agent(name, quick_mode, preflight_result):
    """Run a single agent (called from thread pool or sequentially).

    Returns:
        (name, stdout, stderr, returncode, duration_ms, skip_reason)
    """
    agent_tuple = _AGENT_MAP.get(name)
    if not agent_tuple:
        return (name, "", f"unknown agent: {name}", 1, 0, None)

    _name, _sigil, script, _role, mode = agent_tuple

    # Skip full agents in quick mode
    if quick_mode and mode == "full":
        return (name, "", "", 0, 0, "quick mode")

    # Per-agent circuit breaker: skip agents with too many consecutive failures
    if _agent_breaker.should_skip(name):
        return (name, "", "agent circuit breaker open", 1, 0, "agent breaker")

    # Skip full agents if Ollama is down (preflight) or circuit breaker open
    if mode == "full":
        if not preflight_result.get("ollama", True):
            return (name, "", "Ollama down (preflight)", 1, 0, "ollama down")
        if _circuit_breaker.should_skip():
            return (name, "", "circuit breaker open", 1, 0, "circuit breaker")

    cmd_args = get_agent_command(name)
    stdout, stderr, returncode, duration_ms = run_agent_with_retry(
        name, script, cmd_args, mode
    )

    # Update circuit breaker for full agents
    if mode == "full":
        if returncode == 0:
            _circuit_breaker.record_success()
        else:
            _circuit_breaker.record_failure()

    # Per-agent circuit breaker tracking
    if returncode == 0:
        _agent_breaker.record_success(name)
    else:
        _agent_breaker.record_failure(name)

    # Mycelium integration: pulses, flow tracking, validation, recovery
    if HAS_MYCELIUM:
        if returncode == 0 and stdout:
            pulse(name, "completion", intensity=0.3,
                  detail=stdout[:100] if stdout else None)
            # Record flow metrics (System 6: pathway thickening)
            flow_record(name, output_chars=len(stdout) if stdout else 0,
                        items_produced=1 if stdout else 0, errors=0)
        elif returncode != 0:
            pulse(name, "alert", intensity=0.7,
                  detail=(stderr or "")[:100])
            # Record failure flow (System 6: pathway atrophy)
            flow_record(name, output_chars=0, items_produced=0, errors=1)
            # Record failure for recovery tracking (System 9)
            record_failure(name, error_detail=stderr[:200] if stderr else None)

    return (name, stdout, stderr, returncode, duration_ms, None)


def run_tier(tier, quick_mode, preflight_result):
    """Run all agents in a tier. Quick agents run in parallel, full sequential."""
    results = {}
    agents = tier["agents"]
    max_workers = CFG["parallel"]["max_workers"]

    # Split into quick and full
    quick_agents = [n for n in agents if _AGENT_MAP.get(n, (None,)*5)[4] == "quick"]
    full_agents = [n for n in agents if _AGENT_MAP.get(n, (None,)*5)[4] == "full"]

    # Run quick agents in parallel
    if quick_agents:
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
            futures = {
                pool.submit(_run_one_agent, name, quick_mode, preflight_result): name
                for name in quick_agents
            }
            for future in concurrent.futures.as_completed(futures):
                name, stdout, stderr, returncode, duration_ms, skip_reason = future.result()
                if skip_reason:
                    results[name] = (stdout, stderr, returncode, duration_ms, skip_reason)
                else:
                    results[name] = (stdout, stderr, returncode, duration_ms, None)

    # Run full agents sequentially (GPU-bound)
    for name in full_agents:
        name, stdout, stderr, returncode, duration_ms, skip_reason = _run_one_agent(
            name, quick_mode, preflight_result
        )
        if skip_reason:
            results[name] = (stdout, stderr, returncode, duration_ms, skip_reason)
        else:
            results[name] = (stdout, stderr, returncode, duration_ms, None)

    return results


# ---------------------------------------------------------------------------
# Accountability
# ---------------------------------------------------------------------------

def rotate_accountability_log():
    """Rotate accountability log if it exceeds max lines."""
    max_lines = CFG["accountability"]["max_lines"]
    keep_lines = CFG["accountability"]["keep_lines"]

    if not os.path.exists(ACCOUNTABILITY_LOG):
        return

    try:
        with open(ACCOUNTABILITY_LOG) as f:
            lines = f.readlines()

        if len(lines) > max_lines:
            content = "".join(lines[-keep_lines:])
            atomic_write(ACCOUNTABILITY_LOG, content)
            print(f"[heartbeat] rotated accountability log: "
                  f"{len(lines)} → {keep_lines} lines", file=sys.stderr)
    except (IOError, OSError) as e:
        print(f"[heartbeat] log rotation failed: {e}", file=sys.stderr)


def log_accountability(timestamp, results):
    """Append agent performance to the accountability log."""
    os.makedirs(os.path.dirname(ACCOUNTABILITY_LOG), exist_ok=True)

    with open(ACCOUNTABILITY_LOG, "a") as f:
        for name, _sigil, _script, _role, _mode in AGENTS:
            if name not in results:
                continue
            entry = results[name]
            stdout = entry[0]
            returncode = entry[2]
            duration_ms = entry[3] if len(entry) > 3 else 0
            skip_reason = entry[4] if len(entry) > 4 else None

            if skip_reason:
                status = "SKIP"
            else:
                status = "OK" if returncode == 0 else "FAIL"
            output_len = len(stdout) if stdout else 0
            f.write(f"{timestamp} | {name:10s} | {status:4s} | "
                    f"{output_len:5d} chars | {duration_ms:6d} ms\n")


def get_accountability_stats(days=7):
    """Read accountability log and compute per-agent stats."""
    if not os.path.exists(ACCOUNTABILITY_LOG):
        return {}

    cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    stats = {}

    with open(ACCOUNTABILITY_LOG) as f:
        for line in f:
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 3:
                continue
            ts, name, status = parts[0], parts[1], parts[2]
            if ts < cutoff:
                continue
            if name not in stats:
                stats[name] = {"ok": 0, "fail": 0, "skip": 0, "total": 0,
                               "total_ms": 0, "max_ms": 0}
            stats[name]["total"] += 1
            if status == "OK":
                stats[name]["ok"] += 1
            elif status == "SKIP":
                stats[name]["skip"] += 1
            else:
                stats[name]["fail"] += 1

            # Parse duration if present (backward compat: field may be missing)
            if len(parts) >= 5:
                try:
                    ms_str = parts[4].replace("ms", "").strip()
                    ms = int(ms_str)
                    stats[name]["total_ms"] += ms
                    stats[name]["max_ms"] = max(stats[name]["max_ms"], ms)
                except (ValueError, IndexError):
                    pass

    return stats


# ---------------------------------------------------------------------------
# Briefing generation
# ---------------------------------------------------------------------------

def get_recent_bulletins(days=7):
    """Extract recent memo headers from the bulletin board."""
    if not os.path.exists(BULLETIN_FILE):
        return []

    try:
        with open(BULLETIN_FILE) as f:
            content = f.read()
    except (IOError, OSError):
        return []

    cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    memos = []

    for line in content.splitlines():
        if line.startswith("## 20") and " — " in line:
            parts = line.split(" — ", 1)
            date_part = parts[0].replace("## ", "").strip()
            title = parts[1].strip() if len(parts) > 1 else ""
            if date_part >= cutoff:
                memos.append((date_part, title))

    return memos


def generate_briefing(timestamp, results, quick_mode=False, preflight_result=None):
    """Generate the hourly briefing document."""
    now = datetime.now()
    mode = "QUICK" if quick_mode else "FULL"

    lines = [
        f"# Substrate Briefing — {now.strftime('%Y-%m-%d %H:%M')}",
        "",
        f"**Mode:** {mode} | **Agents:** {len(results)}/{len(AGENTS)}",
    ]

    # Show preflight status
    if preflight_result:
        pf = " | ".join(f"{k}={'OK' if v else 'FAIL'}" for k, v in preflight_result.items())
        lines.append(f"**Preflight:** {pf}")

    # Show circuit breaker state
    if _circuit_breaker.state != "closed":
        lines.append(f"**Ollama Circuit Breaker:** {_circuit_breaker.state}")

    # Show per-agent circuit breaker state
    agent_breaker_summary = _agent_breaker.summary()
    if agent_breaker_summary:
        tripped = ", ".join(
            f"{agent}({entry.get('state', '?')}, {entry.get('failures', 0)} failures)"
            for agent, entry in agent_breaker_summary.items()
        )
        lines.append(f"**Agent Circuit Breakers:** {tripped}")

    lines.append("")

    # Recent bulletin memos
    memos = get_recent_bulletins(days=7)
    if memos:
        lines.append("## Recent Memos (memory/bulletin.md)")
        lines.append("")
        for date, title in memos:
            lines.append(f"- **{date}:** {title}")
        lines.append("")
        lines.append("---")
        lines.append("")

    # Summary bar
    ok_count = sum(1 for r in results.values() if len(r) > 4 and r[4] is None and r[2] == 0)
    fail_count = sum(1 for r in results.values() if len(r) > 4 and r[4] is None and r[2] != 0)
    skip_count = sum(1 for r in results.values() if len(r) > 4 and r[4] is not None)
    # Also count agents not in results at all
    skip_count += sum(1 for a in AGENTS if a[0] not in results)

    lines.append(f"**Status:** {ok_count} OK, {fail_count} FAILED, {skip_count} SKIPPED")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Failed agents first (attention needed)
    failures = [(n, s, sc, r, m) for n, s, sc, r, m in AGENTS
                 if n in results and _result_status(results[n]) == "FAILED"]
    if failures:
        lines.append("## ATTENTION REQUIRED")
        lines.append("")
        for name, sigil, _script, role, _mode in failures:
            entry = results[name]
            stderr = entry[1]
            lines.append(f"### [{sigil}] {name} — {role} — FAILED")
            if stderr:
                lines.append(f"```\n{stderr[:500]}\n```")
            lines.append("")

    # All agent reports
    lines.append("## Agent Reports")
    lines.append("")

    for name, sigil, _script, role, _mode in AGENTS:
        if name not in results:
            lines.append(f"### [{sigil}] {name} — {role} — SKIPPED")
            lines.append("")
            continue

        entry = results[name]
        stdout = entry[0]
        returncode = entry[2]
        duration_ms = entry[3] if len(entry) > 3 else 0
        skip_reason = entry[4] if len(entry) > 4 else None

        if skip_reason:
            lines.append(f"### [{sigil}] {name} — {role} — SKIPPED ({skip_reason})")
            lines.append("")
            continue

        status = "OK" if returncode == 0 else "FAILED"
        timing = f" ({duration_ms}ms)" if duration_ms > 0 else ""

        lines.append(f"### [{sigil}] {name} — {role} — {status}{timing}")
        lines.append("")

        if stdout:
            if len(stdout) > 2000:
                lines.append(stdout[:2000])
                lines.append(f"\n... ({len(stdout) - 2000} chars truncated)")
            else:
                lines.append(stdout)
        elif returncode != 0 and entry[1]:
            lines.append(f"Error: {entry[1][:500]}")
        else:
            lines.append("(no output)")

        lines.append("")
        lines.append("---")
        lines.append("")

    # Accountability stats
    stats = get_accountability_stats(days=7)
    if stats:
        lines.append("## 7-Day Accountability")
        lines.append("")
        lines.append("| Agent | Runs | OK | Fail | Skip | Reliability | Avg ms | Max ms |")
        lines.append("|-------|------|----|------|------|-------------|--------|--------|")
        for name, s in sorted(stats.items()):
            real_runs = s["ok"] + s["fail"]
            pct = (s["ok"] / real_runs * 100) if real_runs > 0 else 100
            avg_ms = s["total_ms"] // max(s["total"], 1)
            flag = " !!!" if pct < 80 else ""
            lines.append(f"| {name} | {s['total']} | {s['ok']} | {s['fail']} | "
                         f"{s['skip']} | {pct:.0f}%{flag} | {avg_ms} | {s['max_ms']} |")
        lines.append("")

    # Mycelium network status
    if HAS_MYCELIUM:
        ranked = urgency_ranked()
        ps = pulse_summary(hours=6)
        fr = flow_ranked()
        if ranked or ps or fr:
            lines.append("## Mycelium Network")
            lines.append("")
        if ranked:
            active = [(a, s, r) for a, s, r in ranked if s > 0.05]
            if active:
                lines.append("**Urgency signals (chemotropism):**")
                lines.append("")
                for agent, score, reason in active[:10]:
                    bar_len = 15
                    filled = int(bar_len * score)
                    bar = "#" * filled + "-" * (bar_len - filled)
                    lines.append(f"- {agent:12s} [{bar}] {score:.2f}"
                                 f"{'  ' + reason if reason else ''}")
                lines.append("")
        if fr:
            active_flow = [(a, s, r, i) for a, s, r, i in fr if r > 0]
            if active_flow:
                lines.append("**Flow scores (pathway thickness):**")
                lines.append("")
                for agent, score, runs, items in active_flow[:10]:
                    bar_len = 15
                    filled = int(bar_len * score)
                    bar = "#" * filled + "-" * (bar_len - filled)
                    lines.append(f"- {agent:12s} [{bar}] {score:.2f}"
                                 f"  ({runs} runs, {items} items)")
                lines.append("")
        if ps:
            lines.append("**Pulse activity (6h):**")
            lines.append("")
            for agent, events in sorted(ps.items()):
                evts = ", ".join(f"{k}:{v}" for k, v in events.items())
                lines.append(f"- {agent}: {evts}")
            lines.append("")

    lines.append(f"*Next heartbeat: {(now + timedelta(hours=1)).strftime('%H:%M')}*")
    lines.append("")

    return "\n".join(lines)


def _result_status(entry):
    """Get display status from a result tuple."""
    if len(entry) > 4 and entry[4] is not None:
        return "SKIPPED"
    return "OK" if entry[2] == 0 else "FAILED"


def generate_manifest(timestamp, results, quick_mode, preflight_result):
    """Generate structured JSON manifest of the run."""
    now = datetime.now()
    agents_data = {}
    for name, _sigil, _script, _role, _mode in AGENTS:
        if name not in results:
            agents_data[name] = {"status": "skipped", "reason": "not scheduled"}
            continue
        entry = results[name]
        stdout = entry[0]
        returncode = entry[2]
        duration_ms = entry[3] if len(entry) > 3 else 0
        skip_reason = entry[4] if len(entry) > 4 else None

        if skip_reason:
            agents_data[name] = {"status": "skipped", "reason": skip_reason,
                                 "duration_ms": duration_ms}
        elif returncode == 0:
            agents_data[name] = {"status": "ok", "duration_ms": duration_ms,
                                 "output_chars": len(stdout) if stdout else 0}
        else:
            agents_data[name] = {"status": "failed", "duration_ms": duration_ms,
                                 "output_chars": len(stdout) if stdout else 0,
                                 "error": (entry[1] or "")[:200]}

    ok_count = sum(1 for a in agents_data.values() if a["status"] == "ok")
    fail_count = sum(1 for a in agents_data.values() if a["status"] == "failed")
    skip_count = sum(1 for a in agents_data.values() if a["status"] == "skipped")

    # Mycelium network state
    mycelium_data = {}
    if HAS_MYCELIUM:
        mycelium_data["urgency"] = {
            a: s for a, s, _ in urgency_ranked() if s > 0.01
        }
        mycelium_data["flow"] = {
            a: {"score": s, "runs": r, "items": i}
            for a, s, r, i in flow_ranked() if r > 0
        }
        mycelium_data["pulse_summary_6h"] = pulse_summary(hours=6)
        mycelium_data["saturated"] = [a for a, _, _ in check_saturation()]

    manifest = {
        "timestamp": now.isoformat(),
        "mode": "quick" if quick_mode else "full",
        "preflight": preflight_result or {},
        "circuit_breaker": _circuit_breaker.state,
        "agent_circuit_breakers": _agent_breaker.summary(),
        "agents": agents_data,
        "mycelium": mycelium_data,
        "summary": {
            "total": len(AGENTS),
            "ok": ok_count,
            "failed": fail_count,
            "skipped": skip_count,
        },
    }

    return json.dumps(manifest, indent=2) + "\n"


def generate_retro():
    """Generate weekly retrospective by comparing briefings."""
    now = datetime.now()
    week_num = now.strftime("%Y-W%W")

    if not os.path.isdir(BRIEFINGS_DIR):
        return f"# Weekly Retro — {week_num}\n\nNo briefings found.\n"

    briefing_files = sorted([
        f for f in os.listdir(BRIEFINGS_DIR)
        if f.endswith(".md") and f != "latest.md"
    ])

    stats = get_accountability_stats(days=7)

    lines = [
        f"# Weekly Retro — {week_num}",
        "",
        f"Generated: {now.strftime('%Y-%m-%d %H:%M')}",
        "",
        f"**Briefings this week:** {len(briefing_files)}",
        "",
    ]

    if stats:
        lines.append("## Agent Reliability")
        lines.append("")

        ranked = sorted(stats.items(), key=lambda x: x[1]["ok"] / max(x[1]["total"], 1))
        for name, s in ranked:
            real_runs = s["ok"] + s["fail"]
            pct = (s["ok"] / real_runs * 100) if real_runs > 0 else 100
            avg_ms = s["total_ms"] // max(s["total"], 1)
            bar_len = 20
            filled = int(bar_len * pct / 100)
            bar = "#" * filled + "-" * (bar_len - filled)
            lines.append(f"- **{name:10s}** [{bar}] {pct:.0f}% "
                         f"({s['ok']}/{s['total']}) avg {avg_ms}ms")
        lines.append("")

    # Git activity this week
    try:
        result = subprocess.run(
            ["git", "log", "--since=7 days ago", "--oneline", "--no-decorate"],
            capture_output=True, text=True, cwd=REPO_DIR, timeout=10,
        )
        commits = result.stdout.strip().splitlines()
        lines.append(f"## Git Activity")
        lines.append("")
        lines.append(f"**{len(commits)} commits this week**")
        lines.append("")
        for c in commits[:20]:
            lines.append(f"- {c}")
        if len(commits) > 20:
            lines.append(f"- ... and {len(commits) - 20} more")
        lines.append("")
    except Exception:
        pass

    lines.append("---")
    lines.append("")
    lines.append("*Review: what improved? What regressed? What shipped? What stalled?*")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Console output
# ---------------------------------------------------------------------------

def print_summary(results):
    """Print concise heartbeat summary to stdout."""
    now = datetime.now()
    ok = sum(1 for r in results.values() if _result_status(r) == "OK")
    fail = sum(1 for r in results.values() if _result_status(r) == "FAILED")
    skip = sum(1 for r in results.values() if _result_status(r) == "SKIPPED")

    print(f"\n  HEARTBEAT {now.strftime('%Y-%m-%d %H:%M')}  [{ok} OK / {fail} FAIL / {skip} SKIP]")
    print(f"  {'─' * 56}")

    for name, sigil, _script, role, _mode in AGENTS:
        if name not in results:
            print(f"  [{sigil}] {name:10s} SKIP")
            continue

        entry = results[name]
        stdout = entry[0]
        returncode = entry[2]
        duration_ms = entry[3] if len(entry) > 3 else 0
        skip_reason = entry[4] if len(entry) > 4 else None

        timing = f"{duration_ms:5d}ms" if duration_ms > 0 else "      "

        if skip_reason:
            print(f"  [{sigil}] {name:10s} SKIP {timing}  ({skip_reason})")
        elif returncode == 0:
            first = stdout.split("\n")[0][:40] if stdout else "(ok)"
            print(f"  [{sigil}] {name:10s} OK   {timing}  {first}")
        else:
            reason = entry[1].split("\n")[0][:40] if entry[1] else "unknown"
            print(f"  [{sigil}] {name:10s} FAIL {timing}  {reason}")

    print(f"  {'─' * 56}")
    print(f"  CB: {_circuit_breaker.state} | Next: {(now + timedelta(hours=1)).strftime('%H:%M')}\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _rotate_briefings(now):
    """Delete briefings >48h old and manifests >7d old."""
    if not os.path.isdir(BRIEFINGS_DIR):
        return
    cutoff_briefing = now - timedelta(hours=48)
    cutoff_manifest = now - timedelta(days=7)
    removed = 0
    for fname in os.listdir(BRIEFINGS_DIR):
        fpath = os.path.join(BRIEFINGS_DIR, fname)
        if fname == "latest.md" or not os.path.isfile(fpath):
            continue
        try:
            # Parse date from filename (YYYY-MM-DD-HH00.md or YYYY-MM-DD-HHMM-manifest.json)
            date_str = fname[:10]  # YYYY-MM-DD
            fdate = datetime.strptime(date_str, "%Y-%m-%d")
            if fname.endswith("-manifest.json") and fdate < cutoff_manifest:
                os.unlink(fpath)
                removed += 1
            elif fname.endswith(".md") and fdate < cutoff_briefing:
                os.unlink(fpath)
                removed += 1
        except (ValueError, OSError):
            continue
    if removed:
        print(f"[heartbeat] rotated {removed} old briefing/manifest files", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Substrate orchestrator — hourly heartbeat")
    parser.add_argument("--quick", action="store_true", help="Quick mode: skip AI-dependent agents")
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout, don't write files")
    parser.add_argument("--retro", action="store_true", help="Generate weekly retrospective")
    args = parser.parse_args()

    now = datetime.now()
    timestamp = now.strftime("%Y-%m-%d %H:%M")

    # Weekly retro mode
    if args.retro:
        retro = generate_retro()
        if args.dry_run:
            print(retro)
            return
        os.makedirs(RETRO_DIR, exist_ok=True)
        week_num = now.strftime("%Y-W%W")
        path = os.path.join(RETRO_DIR, f"{week_num}.md")
        atomic_write(path, retro)
        print(f"  Retro written to {path}", file=sys.stderr)
        return

    print(f"[heartbeat] {timestamp} — starting", file=sys.stderr)

    # Pre-flight health checks
    preflight_result = preflight_check()

    # Rotate accountability log if needed
    rotate_accountability_log()

    # Rotate old briefings (>48h) and manifests (>7d)
    _rotate_briefings(now)

    # Mycelium cycle: prune, decay, check saturation
    if HAS_MYCELIUM:
        bb_pruned = blackboard_prune()
        p_pruned = prune_pulses(hours=48)
        u_decayed = urgency_decay()
        f_decayed = flow_decay()
        saturated = check_saturation()
        if bb_pruned or p_pruned or u_decayed or f_decayed:
            print(f"[heartbeat] mycelium: pruned {bb_pruned} bb/{p_pruned} pulses, "
                  f"decayed {u_decayed} urgency/{f_decayed} flow",
                  file=sys.stderr)
        if saturated:
            names = ", ".join(f"{a}({s:.1f})" for a, s, _ in saturated)
            print(f"[heartbeat] mycelium: SATURATED agents: {names}",
                  file=sys.stderr)

    # Run agents tier by tier with blackboard coordination
    results = {}
    for tier in TIERS:
        tier_name = tier["name"]

        # Blackboard: read context from prior tiers for this tier's agents
        if HAS_MYCELIUM:
            prior_context = blackboard_read(entry_type="status", limit=10)
            if prior_context:
                context_summary = ", ".join(
                    f"{e.get('payload', {}).get('tier', '?')}: "
                    f"{len(e.get('payload', {}).get('ok', []))} ok"
                    for e in prior_context[:5]
                )
                print(f"[heartbeat] tier {tier_name}: context from prior tiers: {context_summary}",
                      file=sys.stderr)

        print(f"[heartbeat] tier {tier_name}: {', '.join(tier['agents'])}",
              file=sys.stderr)
        tier_results = run_tier(tier, args.quick, preflight_result)
        results.update(tier_results)

        # Log per-agent status as they complete
        for name in tier["agents"]:
            if name in tier_results:
                status = _result_status(tier_results[name])
                dur = tier_results[name][3] if len(tier_results[name]) > 3 else 0
                print(f"[heartbeat] {name}: {status} ({dur}ms)", file=sys.stderr)

        # Blackboard: write tier summary for downstream tiers
        if HAS_MYCELIUM:
            ok_names = [n for n in tier["agents"]
                        if n in tier_results and _result_status(tier_results[n]) == "OK"]
            fail_names = [n for n in tier["agents"]
                          if n in tier_results and _result_status(tier_results[n]) == "FAILED"]
            blackboard_write(
                agent="Orchestrator",
                entry_type="status",
                payload={
                    "tier": tier_name,
                    "ok": ok_names,
                    "failed": fail_names,
                    "timestamp": timestamp,
                },
                ttl_hours=2,
            )

    # Log accountability
    log_accountability(timestamp, results)

    # Generate briefing
    briefing = generate_briefing(timestamp, results, quick_mode=args.quick,
                                 preflight_result=preflight_result)

    # Generate manifest
    manifest = generate_manifest(timestamp, results, args.quick, preflight_result)

    # Extract structured JSON findings from agent stdout for executive
    structured_findings = {}
    for name, (stdout, stderr, rc, duration_ms, skip_reason) in results.items():
        if not stdout or skip_reason:
            continue
        # Try to parse JSON from the last line of stdout
        for line in reversed(stdout.strip().splitlines()):
            line = line.strip()
            if line.startswith("{"):
                try:
                    parsed = json.loads(line)
                    if "agent" in parsed and "findings" in parsed:
                        structured_findings[parsed["agent"]] = parsed
                except json.JSONDecodeError:
                    pass
                break

    if structured_findings:
        findings_path = os.path.join(BRIEFINGS_DIR, "latest-findings.json")
        os.makedirs(BRIEFINGS_DIR, exist_ok=True)
        try:
            atomic_write(findings_path, json.dumps(structured_findings, indent=2) + "\n")
            print(f"[heartbeat] structured findings: {len(structured_findings)} agent(s)",
                  file=sys.stderr)
        except Exception as e:
            print(f"[heartbeat] failed to write findings: {e}", file=sys.stderr)

    # Print summary
    print_summary(results)

    if args.dry_run:
        print("\n--- FULL BRIEFING ---\n")
        print(briefing)
        print("\n--- MANIFEST ---\n")
        print(manifest)
        return

    # Write briefing + manifest
    os.makedirs(BRIEFINGS_DIR, exist_ok=True)
    filename = now.strftime("%Y-%m-%d-%H00") + ".md"
    filepath = os.path.join(BRIEFINGS_DIR, filename)
    atomic_write(filepath, briefing)

    manifest_filename = now.strftime("%Y-%m-%d-%H%M") + "-manifest.json"
    manifest_path = os.path.join(BRIEFINGS_DIR, manifest_filename)
    atomic_write(manifest_path, manifest)

    # Update latest symlink
    latest = os.path.join(BRIEFINGS_DIR, "latest.md")
    try:
        if os.path.islink(latest):
            os.unlink(latest)
        os.symlink(filepath, latest)
    except OSError:
        pass

    print(f"[heartbeat] briefing: {filepath}", file=sys.stderr)
    print(f"[heartbeat] manifest: {manifest_path}", file=sys.stderr)

    # Run the executive — reads reports, decides, acts
    executive_script = os.path.join(
        os.path.dirname(SCRIPT_DIR), "executive.py"
    )
    if os.path.isfile(executive_script):
        print(f"[heartbeat] running executive...", file=sys.stderr)
        try:
            result = subprocess.run(
                [sys.executable, executive_script],
                capture_output=True, text=True, timeout=120, cwd=REPO_DIR,
            )
            if result.stdout:
                print(result.stdout)
            if result.returncode != 0 and result.stderr:
                print(f"[heartbeat] executive error: {result.stderr[:200]}",
                      file=sys.stderr)
        except subprocess.TimeoutExpired:
            print("[heartbeat] executive timed out", file=sys.stderr)
        except Exception as e:
            print(f"[heartbeat] executive failed: {e}", file=sys.stderr)

    # Auto-commit agent output
    if not args.dry_run:
        print(f"[heartbeat] committing agent output...", file=sys.stderr)
        try:
            subprocess.run(
                ["git", "add", "memory/", "scripts/posts/", "_posts/", "_data/"],
                cwd=REPO_DIR, timeout=30,
            )
            status = subprocess.run(
                ["git", "diff", "--cached", "--quiet"],
                cwd=REPO_DIR, timeout=10,
            )
            if status.returncode != 0:
                msg = f"agents: hourly output {now.strftime('%Y-%m-%d %H:%M')}"
                subprocess.run(
                    ["git", "commit", "-m", msg],
                    cwd=REPO_DIR, timeout=30,
                )
                print(f"[heartbeat] committed: {msg}", file=sys.stderr)
            else:
                print(f"[heartbeat] nothing to commit", file=sys.stderr)
        except subprocess.TimeoutExpired:
            print("[heartbeat] git commit timed out", file=sys.stderr)
        except Exception as e:
            print(f"[heartbeat] git commit failed: {e}", file=sys.stderr)

    print(f"[heartbeat] done", file=sys.stderr)


if __name__ == "__main__":
    main()
