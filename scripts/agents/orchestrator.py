#!/usr/bin/env python3
"""Substrate orchestrator — hourly heartbeat for 28 agents.

Runs all agents in sequence, compiles a briefing, tracks accountability.
Designed to run every hour via systemd timer. Never stops.

Usage:
    python3 scripts/agents/orchestrator.py                # full hourly run
    python3 scripts/agents/orchestrator.py --quick        # fast agents only (no AI calls)
    python3 scripts/agents/orchestrator.py --dry-run      # print to stdout, don't write
    python3 scripts/agents/orchestrator.py --retro        # weekly retrospective

Output:
    memory/briefings/YYYY-MM-DD-HH00.md   (hourly briefing)
    memory/briefings/latest.md             (symlink to most recent)
    memory/retro/YYYY-WNN.md              (weekly retro, Sundays)
    memory/accountability.log              (append-only agent performance log)
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
BRIEFINGS_DIR = os.path.join(REPO_DIR, "memory", "briefings")
RETRO_DIR = os.path.join(REPO_DIR, "memory", "retro")
ACCOUNTABILITY_LOG = os.path.join(REPO_DIR, "memory", "accountability.log")
BULLETIN_FILE = os.path.join(REPO_DIR, "memory", "bulletin.md")

# ---------------------------------------------------------------------------
# Agent registry — all 28 agents
# ---------------------------------------------------------------------------
# (name, sigil, script, role, mode)
# mode: "quick" = runs without AI (fast), "full" = uses Ollama (slower)

MAX_RETRIES = 2
RETRY_DELAY = 5  # seconds
ACCOUNTABILITY_MAX_LINES = 5000
ACCOUNTABILITY_KEEP_LINES = 2000

AGENTS = [
    # Infrastructure & QA — run first
    ("Root",     "R/", "infra_engineer.py",   "Infrastructure Engineer",    "quick"),
    ("Spec",     "S!", "qa_engineer.py",      "QA Engineer",               "quick"),
    ("Sentinel", "X|", "security.py",         "Security",                  "quick"),
    ("Forge",    "F/", "site_engineer.py",    "Site Engineer",             "quick"),

    # Content & Intelligence
    ("Byte",     "B>", "news_researcher.py",  "News Reporter",             "full"),
    ("Echo",     "E~", "release_tracker.py",  "Release Tracker",           "quick"),

    # Creative
    ("Pixel",    "P#", "visual_artist.py",    "Visual Artist",             "full"),
    ("Arc",      "A^", "arcade_director.py",  "Arcade Director",           "quick"),
    ("Hum",      "H~", "audio_director.py",   "Audio Director",            "quick"),

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


# ---------------------------------------------------------------------------
# Agent execution
# ---------------------------------------------------------------------------

def run_agent(name, script, cmd_args=None):
    """Run a single agent script and capture its output."""
    script_path = os.path.join(SCRIPT_DIR, script)

    if not os.path.isfile(script_path):
        return "", f"script not found: {script_path}", 1

    cmd = [sys.executable, script_path]
    if cmd_args:
        cmd.extend(cmd_args)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=180,
            cwd=REPO_DIR,
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", f"{name} timed out after 180s", 1
    except Exception as e:
        return "", f"{name} failed: {e}", 1


def run_agent_with_retry(name, script, cmd_args=None):
    """Run an agent with retry logic on failure."""
    stdout, stderr, returncode = run_agent(name, script, cmd_args)

    if returncode == 0:
        return stdout, stderr, returncode

    for attempt in range(1, MAX_RETRIES + 1):
        print(f"[heartbeat] {name} failed, retry {attempt}/{MAX_RETRIES}...",
              file=sys.stderr)
        time.sleep(RETRY_DELAY)
        stdout, stderr, returncode = run_agent(name, script, cmd_args)
        if returncode == 0:
            print(f"[heartbeat] {name} succeeded on retry {attempt}",
                  file=sys.stderr)
            return stdout, stderr, returncode

    return stdout, stderr, returncode


def rotate_accountability_log():
    """Rotate accountability log if it exceeds max lines."""
    if not os.path.exists(ACCOUNTABILITY_LOG):
        return

    try:
        with open(ACCOUNTABILITY_LOG) as f:
            lines = f.readlines()

        if len(lines) > ACCOUNTABILITY_MAX_LINES:
            # Keep the most recent lines
            with open(ACCOUNTABILITY_LOG, "w") as f:
                f.writelines(lines[-ACCOUNTABILITY_KEEP_LINES:])
            print(f"[heartbeat] rotated accountability log: "
                  f"{len(lines)} → {ACCOUNTABILITY_KEEP_LINES} lines",
                  file=sys.stderr)
    except (IOError, OSError) as e:
        print(f"[heartbeat] log rotation failed: {e}", file=sys.stderr)


def get_agent_command(name):
    """Return the appropriate command args for each agent's status/quick check."""
    # Map agents to their quick-check commands
    status_commands = {
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
# Accountability
# ---------------------------------------------------------------------------

def log_accountability(timestamp, results):
    """Append agent performance to the accountability log."""
    os.makedirs(os.path.dirname(ACCOUNTABILITY_LOG), exist_ok=True)

    with open(ACCOUNTABILITY_LOG, "a") as f:
        for name, _sigil, _script, _role, _mode in AGENTS:
            if name not in results:
                continue
            stdout, stderr, returncode = results[name]
            status = "OK" if returncode == 0 else "FAIL"
            output_len = len(stdout) if stdout else 0
            f.write(f"{timestamp} | {name:10s} | {status:4s} | {output_len:5d} chars\n")


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
                stats[name] = {"ok": 0, "fail": 0, "total": 0}
            stats[name]["total"] += 1
            if status == "OK":
                stats[name]["ok"] += 1
            else:
                stats[name]["fail"] += 1

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
            # Extract date and title: "## 2026-03-09 — Pipeline Upgrade"
            parts = line.split(" — ", 1)
            date_part = parts[0].replace("## ", "").strip()
            title = parts[1].strip() if len(parts) > 1 else ""
            if date_part >= cutoff:
                memos.append((date_part, title))

    return memos


def generate_briefing(timestamp, results, quick_mode=False):
    """Generate the hourly briefing document."""
    now = datetime.now()
    mode = "QUICK" if quick_mode else "FULL"

    lines = [
        f"# Substrate Briefing — {now.strftime('%Y-%m-%d %H:%M')}",
        "",
        f"**Mode:** {mode} | **Agents:** {len(results)}/{len(AGENTS)}",
        "",
    ]

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
    ok_count = sum(1 for r in results.values() if r[2] == 0)
    fail_count = sum(1 for r in results.values() if r[2] != 0)
    lines.append(f"**Status:** {ok_count} OK, {fail_count} FAILED")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Failed agents first (attention needed)
    failures = [(n, s, sc, r, m) for n, s, sc, r, m in AGENTS
                 if n in results and results[n][2] != 0]
    if failures:
        lines.append("## ATTENTION REQUIRED")
        lines.append("")
        for name, sigil, _script, role, _mode in failures:
            stdout, stderr, returncode = results[name]
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

        stdout, stderr, returncode = results[name]
        status = "OK" if returncode == 0 else "FAILED"

        lines.append(f"### [{sigil}] {name} — {role} — {status}")
        lines.append("")

        if stdout:
            # Truncate long outputs
            if len(stdout) > 2000:
                lines.append(stdout[:2000])
                lines.append(f"\n... ({len(stdout) - 2000} chars truncated)")
            else:
                lines.append(stdout)
        elif returncode != 0 and stderr:
            lines.append(f"Error: {stderr[:500]}")
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
        lines.append("| Agent | Runs | OK | Fail | Reliability |")
        lines.append("|-------|------|----|------|-------------|")
        for name, s in sorted(stats.items()):
            pct = (s["ok"] / s["total"] * 100) if s["total"] > 0 else 0
            flag = " !!!" if pct < 80 else ""
            lines.append(f"| {name} | {s['total']} | {s['ok']} | {s['fail']} | {pct:.0f}%{flag} |")
        lines.append("")

    lines.append(f"*Next heartbeat: {(now + timedelta(hours=1)).strftime('%H:%M')}*")
    lines.append("")

    return "\n".join(lines)


def generate_retro():
    """Generate weekly retrospective by comparing briefings."""
    now = datetime.now()
    week_num = now.strftime("%Y-W%W")

    # Find briefings from this week
    if not os.path.isdir(BRIEFINGS_DIR):
        return f"# Weekly Retro — {week_num}\n\nNo briefings found.\n"

    briefing_files = sorted([
        f for f in os.listdir(BRIEFINGS_DIR)
        if f.endswith(".md") and f != "latest.md"
    ])

    # Count stats from accountability log
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

        # Sort by reliability
        ranked = sorted(stats.items(), key=lambda x: x[1]["ok"] / max(x[1]["total"], 1))
        for name, s in ranked:
            pct = (s["ok"] / s["total"] * 100) if s["total"] > 0 else 0
            bar_len = 20
            filled = int(bar_len * pct / 100)
            bar = "#" * filled + "-" * (bar_len - filled)
            lines.append(f"- **{name:10s}** [{bar}] {pct:.0f}% ({s['ok']}/{s['total']})")
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
    ok = sum(1 for r in results.values() if r[2] == 0)
    fail = sum(1 for r in results.values() if r[2] != 0)

    print(f"\n  HEARTBEAT {now.strftime('%Y-%m-%d %H:%M')}  [{ok} OK / {fail} FAIL]")
    print(f"  {'─' * 48}")

    for name, sigil, _script, role, _mode in AGENTS:
        if name not in results:
            print(f"  [{sigil}] {name:10s} SKIP")
            continue

        stdout, stderr, returncode = results[name]
        if returncode == 0:
            first = stdout.split("\n")[0][:50] if stdout else "(ok)"
            print(f"  [{sigil}] {name:10s} OK   {first}")
        else:
            reason = stderr.split("\n")[0][:40] if stderr else "unknown"
            print(f"  [{sigil}] {name:10s} FAIL {reason}")

    print(f"  {'─' * 48}")
    print(f"  Next: {(now + timedelta(hours=1)).strftime('%H:%M')}\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

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
        with open(path, "w") as f:
            f.write(retro)
        print(f"  Retro written to {path}", file=sys.stderr)
        return

    print(f"[heartbeat] {timestamp} — starting", file=sys.stderr)

    # Rotate accountability log if needed
    rotate_accountability_log()

    # Run agents
    results = {}
    for name, sigil, script, role, mode in AGENTS:
        # In quick mode, skip AI-heavy agents
        if args.quick and mode == "full":
            continue

        cmd_args = get_agent_command(name)
        print(f"[heartbeat] running {name}...", file=sys.stderr)
        stdout, stderr, returncode = run_agent_with_retry(name, script, cmd_args)
        results[name] = (stdout, stderr, returncode)

        status = "ok" if returncode == 0 else "FAIL"
        print(f"[heartbeat] {name}: {status}", file=sys.stderr)

    # Log accountability
    log_accountability(timestamp, results)

    # Generate briefing
    briefing = generate_briefing(timestamp, results, quick_mode=args.quick)

    # Print summary
    print_summary(results)

    if args.dry_run:
        print("\n--- FULL BRIEFING ---\n")
        print(briefing)
        return

    # Write briefing
    os.makedirs(BRIEFINGS_DIR, exist_ok=True)
    filename = now.strftime("%Y-%m-%d-%H00") + ".md"
    filepath = os.path.join(BRIEFINGS_DIR, filename)

    with open(filepath, "w") as f:
        f.write(briefing)

    # Update latest symlink
    latest = os.path.join(BRIEFINGS_DIR, "latest.md")
    try:
        if os.path.islink(latest):
            os.unlink(latest)
        os.symlink(filepath, latest)
    except OSError:
        pass

    print(f"[heartbeat] briefing: {filepath}", file=sys.stderr)

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
            # Stage all changes in memory/ and scripts/posts/
            subprocess.run(
                ["git", "add", "memory/", "scripts/posts/", "_posts/"],
                cwd=REPO_DIR, timeout=30,
            )
            # Check if there's anything to commit
            status = subprocess.run(
                ["git", "diff", "--cached", "--quiet"],
                cwd=REPO_DIR, timeout=10,
            )
            if status.returncode != 0:
                # There are staged changes — commit them
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
