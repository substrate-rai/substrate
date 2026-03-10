#!/usr/bin/env python3
"""build.py — Substrate autonomous build executor.

Reads the latest mirror report, extracts the Next Build proposal,
generates scaffolds via Ollama, runs smoke tests, and commits on success.

Usage:
    python3 scripts/build.py              # execute next build from latest mirror
    python3 scripts/build.py --dry-run    # show what would be built, don't execute
    python3 scripts/build.py --list       # show all incomplete milestones

Safety:
    - NEVER deletes files
    - NEVER force pushes
    - NEVER modifies nix/ without --nix-ok flag
    - Reverts and logs incidents on test failure
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
MIRROR_DIR = REPO_ROOT / "memory" / "mirror"
GOAL_FILE = REPO_ROOT / "memory" / "goal.md"
BUILDS_LOG = REPO_ROOT / "memory" / "builds.log"
INCIDENTS_FILE = REPO_ROOT / "memory" / "incidents.md"

# ---------------------------------------------------------------------------
# Ollama config
# ---------------------------------------------------------------------------

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"


# ---------------------------------------------------------------------------
# Mirror report parsing
# ---------------------------------------------------------------------------

def find_latest_mirror():
    """Find the most recent mirror report by filename date."""
    if not MIRROR_DIR.exists():
        return None
    reports = sorted(MIRROR_DIR.glob("*.md"), reverse=True)
    for r in reports:
        if re.match(r"\d{4}-\d{2}-\d{2}\.md", r.name):
            return r
    return None


def parse_next_build(report_path):
    """Parse the Next Build section from a mirror report.

    Returns dict with keys: milestone, tier, action, files, effort
    or None if no build is proposed.
    """
    text = report_path.read_text()

    # Find the "## Next Build" section
    match = re.search(r"## Next Build\s*\n(.+?)(?:\n## |\Z)", text, re.DOTALL)
    if not match:
        return None

    section = match.group(1).strip()
    if not section or "all milestones complete" in section.lower():
        return None

    build = {
        "milestone": None,
        "tier": None,
        "action": None,
        "files": [],
        "effort": None,
    }

    # First line: **milestone** (Tier N)
    title_match = re.match(r"\*\*(.+?)\*\*\s*\((.+?)\)", section)
    if title_match:
        build["milestone"] = title_match.group(1).strip()
        build["tier"] = title_match.group(2).strip()

    # Action line
    action_match = re.search(r"^Action:\s*(.+)$", section, re.MULTILINE)
    if action_match:
        build["action"] = action_match.group(1).strip()

    # Files line
    files_match = re.search(r"^Files:\s*(.+)$", section, re.MULTILINE)
    if files_match:
        raw = files_match.group(1).strip()
        build["files"] = [f.strip() for f in raw.split(",") if f.strip()]

    # Effort line
    effort_match = re.search(r"^Effort:\s*(.+)$", section, re.MULTILINE)
    if effort_match:
        build["effort"] = effort_match.group(1).strip()

    if not build["milestone"] or not build["action"]:
        return None

    return build


def parse_all_gaps(report_path):
    """Parse all incomplete milestones from the Gaps section."""
    text = report_path.read_text()

    match = re.search(r"## Gaps\s*\n(.+?)(?:\n## |\Z)", text, re.DOTALL)
    if not match:
        return []

    section = match.group(1)
    gaps = []
    current_tier = None

    for line in section.splitlines():
        tier_match = re.match(r"^### (.+)", line)
        if tier_match:
            current_tier = tier_match.group(1).strip()
            continue

        item_match = re.match(r"^- \*\*(.+?)\*\*", line)
        if item_match:
            gaps.append({
                "tier": current_tier or "unknown",
                "milestone": item_match.group(1).strip(),
            })

    return gaps


# ---------------------------------------------------------------------------
# File existence checks
# ---------------------------------------------------------------------------

def check_files_exist(files):
    """Check which target files already exist. Returns (existing, missing)."""
    existing = []
    missing = []
    for f in files:
        path = REPO_ROOT / f
        if path.exists():
            existing.append(f)
        else:
            missing.append(f)
    return existing, missing


# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

def safety_check(files, nix_ok=False):
    """Verify the build is safe to execute. Returns (ok, reason)."""
    for f in files:
        # Never modify nix/ without explicit flag
        if f.startswith("nix/") and not nix_ok:
            return False, f"target {f} is in nix/ — pass --nix-ok to allow"

        # Never touch security-sensitive files
        if any(s in f for s in [".env", "credentials", "secrets", "ssh"]):
            return False, f"target {f} looks like a secrets file — refusing"

    return True, ""


# ---------------------------------------------------------------------------
# Ollama scaffold generation
# ---------------------------------------------------------------------------

def ollama_generate(prompt, timeout=120):
    """Call Ollama chat API (qwen3:8b) and return the response text.

    Uses standard library only (urllib).
    """
    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a code generator for Substrate, an autonomous AI workstation "
                    "running NixOS. Generate clean, production-ready Python or shell scripts. "
                    "Use only the Python standard library (no pip packages). "
                    "Include a shebang line, docstring, argparse CLI where appropriate, "
                    "and clear section comments. Output ONLY the file content — no "
                    "markdown fences, no explanation."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        "stream": False,
        "think": False,
        "options": {"think": False},
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OLLAMA_URL,
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            content = body.get("message", {}).get("content", "")
            return content.strip()
    except urllib.error.URLError as e:
        print(f"error: cannot reach ollama: {e}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"error: ollama request failed: {e}", file=sys.stderr)
        return None


def generate_scaffold(action, target_file):
    """Generate a script scaffold for the given action and target file."""
    ext = Path(target_file).suffix

    if ext == ".py":
        lang = "Python"
        extra = (
            "Use only the Python standard library. Include argparse CLI. "
            "Print status to stderr. Follow the pattern of other Substrate scripts."
        )
    elif ext in (".sh", ""):
        lang = "Bash"
        extra = (
            "Use #!/usr/bin/env bash with set -euo pipefail. "
            "Include usage comments."
        )
    elif ext == ".nix":
        lang = "Nix"
        extra = "Write a NixOS module. Use standard NixOS module conventions."
    else:
        lang = "text"
        extra = ""

    prompt = (
        f"Generate a {lang} file for the following task:\n\n"
        f"Task: {action}\n"
        f"Target file: {target_file}\n\n"
        f"This is part of the Substrate project — an autonomous AI workstation "
        f"running NixOS on a Lenovo Legion 5 with an RTX 4060 and Ollama "
        f"(qwen3:8b) for local inference.\n\n"
        f"{extra}\n\n"
        f"Output ONLY the file content. No markdown fences. No explanation."
    )

    return ollama_generate(prompt)


# ---------------------------------------------------------------------------
# Smoke tests
# ---------------------------------------------------------------------------

def smoke_test(filepath):
    """Run basic smoke tests on a generated file. Returns (passed, message)."""
    path = REPO_ROOT / filepath
    if not path.exists():
        return False, f"file not found: {filepath}"

    ext = path.suffix

    # Python: syntax check
    if ext == ".py":
        result = subprocess.run(
            [sys.executable, "-m", "py_compile", str(path)],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return False, f"python syntax error: {result.stderr.strip()}"
        return True, "python syntax ok"

    # Shell: bash -n syntax check
    if ext == ".sh":
        result = subprocess.run(
            ["bash", "-n", str(path)],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return False, f"bash syntax error: {result.stderr.strip()}"
        return True, "bash syntax ok"

    # Nix: nix-instantiate --parse
    if ext == ".nix":
        result = subprocess.run(
            ["nix-instantiate", "--parse", str(path)],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            return False, f"nix parse error: {result.stderr.strip()}"
        return True, "nix syntax ok"

    # Unknown extension: just check it's not empty
    content = path.read_text().strip()
    if not content:
        return False, "file is empty"
    return True, "file exists and is non-empty"


# ---------------------------------------------------------------------------
# Git operations
# ---------------------------------------------------------------------------

def git_add_commit(files, message):
    """Stage files and commit. Returns (success, output)."""
    for f in files:
        result = subprocess.run(
            ["git", "add", str(REPO_ROOT / f)],
            capture_output=True, text=True, cwd=str(REPO_ROOT),
        )
        if result.returncode != 0:
            return False, f"git add failed for {f}: {result.stderr}"

    result = subprocess.run(
        ["git", "commit", "-m", message],
        capture_output=True, text=True, cwd=str(REPO_ROOT),
    )
    if result.returncode != 0:
        return False, f"git commit failed: {result.stderr}"
    return True, result.stdout.strip()


def git_revert_files(files):
    """Revert uncommitted changes to specific files."""
    for f in files:
        path = REPO_ROOT / f
        if path.exists():
            subprocess.run(
                ["git", "checkout", "--", str(path)],
                capture_output=True, text=True, cwd=str(REPO_ROOT),
            )
            # If the file was newly created (untracked), remove it
            result = subprocess.run(
                ["git", "status", "--porcelain", str(path)],
                capture_output=True, text=True, cwd=str(REPO_ROOT),
            )
            if result.stdout.startswith("??"):
                path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def log_build(status, milestone, files, message=""):
    """Append a build record to memory/builds.log."""
    BUILDS_LOG.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    file_list = ", ".join(files) if files else "(none)"
    entry = f"{timestamp} | {status:7s} | {milestone} | {file_list}"
    if message:
        entry += f" | {message}"
    entry += "\n"
    with open(BUILDS_LOG, "a") as f:
        f.write(entry)


def log_incident(milestone, files, error_msg):
    """Append an incident to memory/incidents.md."""
    INCIDENTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    file_list = ", ".join(files) if files else "(none)"

    entry = (
        f"\n- {timestamp}: Build failed for \"{milestone}\". "
        f"Files: {file_list}. Error: {error_msg}. Reverted.\n"
    )

    # Append or create
    if INCIDENTS_FILE.exists():
        with open(INCIDENTS_FILE, "a") as f:
            f.write(entry)
    else:
        with open(INCIDENTS_FILE, "w") as f:
            f.write("# Incident Log\n")
            f.write(entry)


# ---------------------------------------------------------------------------
# Build execution
# ---------------------------------------------------------------------------

def strip_markdown_fences(text):
    """Remove markdown code fences if the LLM wrapped its output."""
    # Remove opening fence (```python, ```bash, ```, etc.)
    text = re.sub(r"^```\w*\s*\n", "", text)
    # Remove closing fence
    text = re.sub(r"\n```\s*$", "", text)
    return text.strip()


def execute_build(build, nix_ok=False):
    """Execute a single build proposal. Returns (success, message)."""
    milestone = build["milestone"]
    action = build["action"]
    files = build["files"]

    print(f"[build] milestone: {milestone}", file=sys.stderr)
    print(f"[build] action: {action}", file=sys.stderr)
    print(f"[build] files: {', '.join(files) if files else '(none)'}", file=sys.stderr)
    print(f"[build] effort: {build.get('effort', 'unknown')}", file=sys.stderr)

    if not files:
        msg = "no target files specified — skipping"
        print(f"[build] {msg}", file=sys.stderr)
        log_build("SKIP", milestone, files, msg)
        return False, msg

    # Safety check
    safe, reason = safety_check(files, nix_ok=nix_ok)
    if not safe:
        msg = f"safety check failed: {reason}"
        print(f"[build] {msg}", file=sys.stderr)
        log_build("BLOCKED", milestone, files, msg)
        return False, msg

    # Check existing files
    existing, missing = check_files_exist(files)
    if existing and not missing:
        msg = f"all target files already exist: {', '.join(existing)}"
        print(f"[build] {msg}", file=sys.stderr)
        log_build("SKIP", milestone, files, msg)
        return False, msg

    if existing:
        print(f"[build] existing (will skip): {', '.join(existing)}", file=sys.stderr)

    # Generate scaffolds for missing files
    created = []
    for target in missing:
        print(f"[build] generating scaffold: {target}", file=sys.stderr)

        content = generate_scaffold(action, target)
        if content is None:
            msg = f"ollama generation failed for {target}"
            print(f"[build] {msg}", file=sys.stderr)
            # Revert any files we already created this run
            git_revert_files(created)
            log_build("FAIL", milestone, files, msg)
            log_incident(milestone, files, msg)
            return False, msg

        # Strip markdown fences if present
        content = strip_markdown_fences(content)

        # Write the file
        path = REPO_ROOT / target
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content + "\n")

        # Make executable if script
        if path.suffix in (".py", ".sh"):
            path.chmod(0o755)

        created.append(target)
        print(f"[build] wrote {target} ({len(content)} bytes)", file=sys.stderr)

    # Smoke test all created files
    all_passed = True
    test_results = []
    for target in created:
        passed, msg = smoke_test(target)
        test_results.append((target, passed, msg))
        status_str = "PASS" if passed else "FAIL"
        print(f"[build] test {target}: {status_str} — {msg}", file=sys.stderr)
        if not passed:
            all_passed = False

    if not all_passed:
        # Revert all created files
        fail_msgs = [f"{t}: {m}" for t, p, m in test_results if not p]
        error_msg = "; ".join(fail_msgs)
        print(f"[build] tests failed — reverting", file=sys.stderr)
        git_revert_files(created)
        log_build("FAIL", milestone, files, error_msg)
        log_incident(milestone, files, error_msg)
        return False, f"smoke tests failed: {error_msg}"

    # Commit
    commit_msg = f"build: {milestone.lower()}"
    # Truncate long commit messages
    if len(commit_msg) > 72:
        commit_msg = commit_msg[:69] + "..."
    success, output = git_add_commit(created, commit_msg)

    if not success:
        print(f"[build] commit failed: {output}", file=sys.stderr)
        git_revert_files(created)
        log_build("FAIL", milestone, files, f"commit failed: {output}")
        log_incident(milestone, files, f"commit failed: {output}")
        return False, f"commit failed: {output}"

    print(f"[build] committed: {commit_msg}", file=sys.stderr)
    log_build("OK", milestone, created, commit_msg)
    return True, f"built and committed: {', '.join(created)}"


# ---------------------------------------------------------------------------
# CLI commands
# ---------------------------------------------------------------------------

def cmd_list(report_path):
    """Show all incomplete milestones from the latest mirror report."""
    gaps = parse_all_gaps(report_path)
    if not gaps:
        print("No incomplete milestones found.")
        return

    print(f"Incomplete milestones ({len(gaps)}):\n")
    current_tier = None
    for gap in gaps:
        if gap["tier"] != current_tier:
            current_tier = gap["tier"]
            print(f"  {current_tier}")
        print(f"    - {gap['milestone']}")
    print()


def cmd_dry_run(build):
    """Show what would be built without executing."""
    print("Dry run — next build proposal:\n")
    print(f"  Milestone: {build['milestone']}")
    print(f"  Tier:      {build['tier']}")
    print(f"  Action:    {build['action']}")
    print(f"  Files:     {', '.join(build['files']) if build['files'] else '(none)'}")
    print(f"  Effort:    {build.get('effort', 'unknown')}")
    print()

    if build["files"]:
        existing, missing = check_files_exist(build["files"])
        if existing:
            print(f"  Already exist: {', '.join(existing)}")
        if missing:
            print(f"  Would create:  {', '.join(missing)}")
        if existing and not missing:
            print("  Status: all files exist — build would be skipped")
    else:
        print("  Status: no target files — build would be skipped")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Substrate build executor — reads mirror proposals, executes builds"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="show what would be built, don't execute"
    )
    parser.add_argument(
        "--list", action="store_true",
        help="show all incomplete milestones"
    )
    parser.add_argument(
        "--nix-ok", action="store_true",
        help="allow builds that modify nix/ (requires operator approval)"
    )
    parser.add_argument(
        "--report", type=str, default=None,
        help="path to a specific mirror report (default: latest)"
    )
    args = parser.parse_args()

    # Find mirror report
    if args.report:
        report_path = Path(args.report)
    else:
        report_path = find_latest_mirror()

    if not report_path or not report_path.exists():
        print("error: no mirror report found", file=sys.stderr)
        print("  run: python3 scripts/mirror.py", file=sys.stderr)
        sys.exit(1)

    print(f"[build] using report: {report_path.name}", file=sys.stderr)

    # --list mode
    if args.list:
        cmd_list(report_path)
        return

    # Parse next build
    build = parse_next_build(report_path)
    if not build:
        print("[build] no actionable build found in report", file=sys.stderr)
        return

    # --dry-run mode
    if args.dry_run:
        cmd_dry_run(build)
        return

    # Execute build
    success, message = execute_build(build, nix_ok=args.nix_ok)
    if success:
        print(f"\n[build] SUCCESS: {message}", file=sys.stderr)
    else:
        print(f"\n[build] STOPPED: {message}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
