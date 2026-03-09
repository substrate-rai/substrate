#!/usr/bin/env python3
"""Substrate Executive — reads agent reports, decides, acts.

The missing link between observation and action. Runs after each heartbeat.
Reads briefings and agent reports, identifies actionable items, executes
safe fixes autonomously, and queues risky actions for operator approval.

Usage:
    python3 scripts/executive.py              # full run: read, decide, act
    python3 scripts/executive.py --dry-run    # show what would be done
    python3 scripts/executive.py --report     # just show findings, no action

Autonomy rules (from CLAUDE.md):
    CAN do: fix files, commit, push, publish blog/social, restart services
    CANNOT do: spend money, delete capabilities, change network/security
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime, date

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
EXEC_DIR = os.path.join(MEMORY_DIR, "executive")
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
SCRIPTS_DIR = os.path.join(REPO_DIR, "scripts")

# Action categories
SAFE = "auto"       # execute immediately
APPROVAL = "queue"  # log for operator


def log(msg, level="info"):
    prefix = {"info": "  ", "act": "  >>", "skip": "  --", "warn": "  !!"}
    print(f"{prefix.get(level, '  ')} {msg}")


# ---------------------------------------------------------------------------
# Report readers
# ---------------------------------------------------------------------------

def read_latest_briefing():
    """Read the most recent heartbeat briefing."""
    path = os.path.join(MEMORY_DIR, "briefings", "latest.md")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return f.read()


def read_agent_report(subdir):
    """Read today's report from a memory subdirectory."""
    today = date.today().isoformat()
    path = os.path.join(MEMORY_DIR, subdir, f"{today}.md")
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return f.read()


def read_mirror():
    """Read the most recent mirror report."""
    mirror_dir = os.path.join(MEMORY_DIR, "mirror")
    if not os.path.isdir(mirror_dir):
        return None
    files = sorted(glob.glob(os.path.join(mirror_dir, "*.md")))
    if not files:
        return None
    with open(files[-1]) as f:
        return f.read()


def find_draft_posts():
    """Find blog posts marked as draft: true."""
    drafts = []
    for path in glob.glob(os.path.join(POSTS_DIR, "*.md")):
        with open(path) as f:
            content = f.read()
        if re.search(r'^draft:\s*true', content, re.MULTILINE):
            drafts.append(path)
    return drafts


def find_social_queue():
    """Find queued social media posts."""
    queue_dir = os.path.join(SCRIPTS_DIR, "posts")
    if not os.path.isdir(queue_dir):
        return []
    queued = []
    for path in glob.glob(os.path.join(queue_dir, "*.md")):
        queued.append(path)
    return queued


# ---------------------------------------------------------------------------
# Analyzers — extract actionable findings from reports
# ---------------------------------------------------------------------------

def analyze_site_health(report):
    """Extract broken links and missing meta from site health report."""
    findings = []
    if not report:
        return findings

    # Broken links
    link_match = re.search(r'Broken links:\*\*\s*(\d+)', report)
    if link_match and int(link_match.group(1)) > 0:
        broken = re.findall(r'404\s+`([^`]+)`\s+in\s+`([^`]+)`', report)
        for anchor, file in broken:
            findings.append({
                "source": "Forge",
                "type": "broken_link",
                "severity": "medium",
                "detail": f"404 link '{anchor}' in {file}",
                "file": file,
                "action": APPROVAL,  # needs investigation
            })

    # Missing meta tags
    meta_match = re.findall(r'`([^`]+)`\s*—\s*missing:\s*(.+)', report)
    for file, missing in meta_match:
        findings.append({
            "source": "Forge",
            "type": "missing_meta",
            "severity": "low",
            "detail": f"{file} missing: {missing}",
            "file": file,
            "action": APPROVAL,
        })

    return findings


def analyze_infra(report):
    """Extract infra issues from Root's report."""
    findings = []
    if not report:
        return findings

    # Ollama down
    if re.search(r'ollama\.service.*(?:inactive|failed|DOWN)', report, re.IGNORECASE):
        findings.append({
            "source": "Root",
            "type": "service_down",
            "severity": "high",
            "detail": "Ollama service is down",
            "action": SAFE,
            "fix": "restart_ollama",
        })

    # GPU not detected (nvidia-smi issue)
    if re.search(r'GPU.*NOT AVAILABLE|nvidia-smi.*not found', report, re.IGNORECASE):
        findings.append({
            "source": "Root",
            "type": "gpu_unavailable",
            "severity": "high",
            "detail": "GPU not detected — nvidia-smi not in PATH",
            "action": APPROVAL,
        })

    # Disk > 90%
    disk_matches = re.findall(r'\|\s*/\s*\|\s*(\d+)%', report)
    for pct in disk_matches:
        if int(pct) > 90:
            findings.append({
                "source": "Root",
                "type": "disk_critical",
                "severity": "critical",
                "detail": f"Root disk at {pct}% — cleanup needed",
                "action": APPROVAL,
            })

    return findings


def analyze_security(report):
    """Extract security findings from Sentinel's report."""
    findings = []
    if not report:
        return findings

    # Leaked secrets
    if re.search(r'FAIL|LEAKED|SECRET|credential', report, re.IGNORECASE):
        if not re.search(r'0 potential secrets', report):
            findings.append({
                "source": "Sentinel",
                "type": "security_leak",
                "severity": "critical",
                "detail": "Potential secret leak detected — review immediately",
                "action": APPROVAL,
            })

    return findings


def analyze_briefing(briefing):
    """Extract failed agents from the briefing."""
    findings = []
    if not briefing:
        return findings

    # Failed agents
    failed = re.findall(r'###\s+\[.+?\]\s+(\w+)\s+—\s+.+?\s+—\s+FAILED', briefing)
    for agent in failed:
        findings.append({
            "source": "Orchestrator",
            "type": "agent_failed",
            "severity": "medium",
            "detail": f"Agent {agent} failed during heartbeat",
            "action": APPROVAL,
        })

    # Low accountability (< 80%)
    acct_matches = re.findall(r'\|\s*(\w+)\s*\|.*?\|\s*(\d+)%\s*\|.*?!!!', briefing)
    for agent, pct in acct_matches:
        findings.append({
            "source": "Orchestrator",
            "type": "low_reliability",
            "severity": "medium",
            "detail": f"Agent {agent} reliability at {pct}% (below 80%)",
            "action": APPROVAL,
        })

    return findings


def analyze_drafts(drafts):
    """Check if any draft posts are ready to publish."""
    findings = []
    for path in drafts:
        fname = os.path.basename(path)
        # Only auto-publish if the post is at least 1 day old (operator had time to review)
        match = re.match(r'(\d{4}-\d{2}-\d{2})', fname)
        if match:
            post_date = datetime.strptime(match.group(1), "%Y-%m-%d").date()
            age_days = (date.today() - post_date).days
            if age_days >= 1:
                findings.append({
                    "source": "Executive",
                    "type": "draft_ready",
                    "severity": "low",
                    "detail": f"Draft '{fname}' is {age_days} day(s) old — ready to publish",
                    "file": path,
                    "action": SAFE,
                    "fix": "publish_draft",
                })
    return findings


def analyze_social_queue(queued):
    """Check for social posts ready to publish.

    Only auto-publish posts that have a '## bluesky' section with actual
    content. Skip drafts, templates, response preps, and anything that
    looks like a work-in-progress.
    """
    findings = []
    skip_patterns = ['draft', 'prep', 'template', 'response', 'awesome-list']

    for path in queued:
        fname = os.path.basename(path).lower()

        # Skip files that look like drafts/templates
        if any(p in fname for p in skip_patterns):
            continue

        # Only include if it has a ## bluesky section with content
        try:
            with open(path) as f:
                content = f.read()
            if '## bluesky' not in content.lower():
                continue
            # Check the bluesky section has actual post text (> 20 chars)
            match = re.search(r'##\s+bluesky\s*\n(.+)', content, re.DOTALL | re.IGNORECASE)
            if not match or len(match.group(1).strip()) < 20:
                continue
        except (IOError, OSError):
            continue

        findings.append({
            "source": "Executive",
            "type": "social_queued",
            "severity": "low",
            "detail": f"Social post ready: {os.path.basename(path)}",
            "file": path,
            "action": APPROVAL,  # social posts need operator review before posting
        })
    return findings


# ---------------------------------------------------------------------------
# Executors — perform safe actions
# ---------------------------------------------------------------------------

def restart_ollama(finding, dry_run=False):
    """Restart the Ollama service."""
    log(f"Restarting Ollama service", "act")
    if dry_run:
        return True
    result = subprocess.run(
        ["sudo", "systemctl", "restart", "ollama"],
        capture_output=True, text=True, timeout=30
    )
    return result.returncode == 0


def publish_draft(finding, dry_run=False):
    """Publish a blog post by removing draft: true."""
    path = finding["file"]
    log(f"Publishing draft: {os.path.basename(path)}", "act")
    if dry_run:
        return True

    with open(path) as f:
        content = f.read()

    content = re.sub(r'^draft:\s*true\s*$', '', content, flags=re.MULTILINE)
    # Clean up double blank lines in frontmatter
    content = re.sub(r'\n{3,}', '\n\n', content)

    with open(path, 'w') as f:
        f.write(content)

    return True


def publish_social(finding, dry_run=False):
    """Publish a social media post via publish.py."""
    path = finding["file"]
    log(f"Publishing social post: {os.path.basename(path)}", "act")
    if dry_run:
        return True

    publish_script = os.path.join(SCRIPTS_DIR, "publish.py")
    result = subprocess.run(
        [sys.executable, publish_script, path, "--platform", "bluesky"],
        capture_output=True, text=True, timeout=60, cwd=REPO_DIR
    )
    return result.returncode == 0


EXECUTORS = {
    "restart_ollama": restart_ollama,
    "publish_draft": publish_draft,
    "publish_social": publish_social,
}


# ---------------------------------------------------------------------------
# Git operations
# ---------------------------------------------------------------------------

def git_commit_and_push(message, files=None):
    """Commit changed files and push."""
    if files:
        subprocess.run(["git", "add"] + files, cwd=REPO_DIR,
                       capture_output=True, timeout=30)
    else:
        subprocess.run(["git", "add", "-A"], cwd=REPO_DIR,
                       capture_output=True, timeout=30)

    # Check if there are staged changes
    result = subprocess.run(
        ["git", "diff", "--cached", "--quiet"],
        cwd=REPO_DIR, capture_output=True, timeout=10
    )
    if result.returncode == 0:
        return False  # nothing to commit

    subprocess.run(
        ["git", "commit", "-m", message],
        cwd=REPO_DIR, capture_output=True, text=True, timeout=30
    )
    subprocess.run(
        ["git", "push"],
        cwd=REPO_DIR, capture_output=True, text=True, timeout=60
    )
    return True


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def run(dry_run=False, report_only=False):
    now = datetime.now()
    print(f"\n{'='*60}")
    print(f"  EXECUTIVE — {now.strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*60}\n")

    # Phase 1: Read
    print("[1/3] READING agent reports...")
    briefing = read_latest_briefing()
    site_report = read_agent_report("site")
    infra_report = read_agent_report("infra")
    security_report = read_agent_report("security")
    drafts = find_draft_posts()
    social_queue = find_social_queue()

    log(f"Briefing: {'found' if briefing else 'missing'}")
    log(f"Site health: {'found' if site_report else 'missing'}")
    log(f"Infra: {'found' if infra_report else 'missing'}")
    log(f"Security: {'found' if security_report else 'missing'}")
    log(f"Draft posts: {len(drafts)}")
    log(f"Social queue: {len(social_queue)}")

    # Phase 2: Decide
    print(f"\n[2/3] ANALYZING findings...")
    findings = []
    findings.extend(analyze_briefing(briefing))
    findings.extend(analyze_site_health(site_report))
    findings.extend(analyze_infra(infra_report))
    findings.extend(analyze_security(security_report))
    findings.extend(analyze_drafts(drafts))
    findings.extend(analyze_social_queue(social_queue))

    if not findings:
        print("\n  All clear. Nothing to act on.\n")
        write_executive_log(now, [], [], dry_run)
        return

    # Sort by severity
    severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    findings.sort(key=lambda f: severity_order.get(f["severity"], 9))

    auto_actions = [f for f in findings if f["action"] == SAFE]
    queued_actions = [f for f in findings if f["action"] == APPROVAL]

    print(f"\n  Found {len(findings)} item(s):")
    print(f"    Auto-execute: {len(auto_actions)}")
    print(f"    Needs approval: {len(queued_actions)}")

    for f in findings:
        marker = ">>>" if f["action"] == SAFE else "???"
        print(f"    [{f['severity'].upper():8s}] {marker} [{f['source']}] {f['detail']}")

    if report_only:
        write_executive_log(now, auto_actions, queued_actions, dry_run=True)
        return

    # Phase 3: Act
    print(f"\n[3/3] EXECUTING safe actions...")
    executed = []
    failed = []

    for finding in auto_actions:
        fix_name = finding.get("fix")
        if fix_name and fix_name in EXECUTORS:
            try:
                success = EXECUTORS[fix_name](finding, dry_run=dry_run)
                if success:
                    executed.append(finding)
                else:
                    failed.append(finding)
            except Exception as e:
                log(f"FAILED: {fix_name} — {e}", "warn")
                failed.append(finding)
        else:
            log(f"No executor for: {finding['detail']}", "skip")

    # Commit any file changes
    changed_files = [f["file"] for f in executed if "file" in f]
    if changed_files and not dry_run:
        msg = f"auto: executive published {len(changed_files)} item(s)"
        if git_commit_and_push(msg, changed_files):
            log("Committed and pushed changes", "act")

    # Summary
    print(f"\n{'='*60}")
    print(f"  SUMMARY")
    print(f"{'='*60}")
    print(f"  Executed:       {len(executed)}")
    print(f"  Failed:         {len(failed)}")
    print(f"  Needs approval: {len(queued_actions)}")
    if dry_run:
        print(f"  (DRY RUN — no changes made)")
    print()

    write_executive_log(now, executed + failed, queued_actions, dry_run)


def write_executive_log(timestamp, acted, queued, dry_run=False):
    """Write executive decision log to memory."""
    os.makedirs(EXEC_DIR, exist_ok=True)
    log_path = os.path.join(EXEC_DIR, f"{timestamp.strftime('%Y-%m-%d')}.md")

    entry = f"\n## {timestamp.strftime('%H:%M')}"
    if dry_run:
        entry += " (dry run)"
    entry += "\n\n"

    if acted:
        entry += "### Acted\n\n"
        for f in acted:
            entry += f"- [{f['severity']}] {f['detail']}\n"
        entry += "\n"

    if queued:
        entry += "### Needs Approval\n\n"
        for f in queued:
            entry += f"- [{f['severity']}] {f['detail']}\n"
        entry += "\n"

    if not acted and not queued:
        entry += "All clear. No actions needed.\n\n"

    # Append to today's log
    mode = 'a' if os.path.exists(log_path) else 'w'
    with open(log_path, mode) as f:
        if mode == 'w':
            f.write(f"# Executive Log — {timestamp.strftime('%Y-%m-%d')}\n")
        f.write(entry)


def main():
    parser = argparse.ArgumentParser(description="Substrate Executive")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be done without doing it")
    parser.add_argument("--report", action="store_true",
                        help="Show findings only, no execution")
    args = parser.parse_args()
    run(dry_run=args.dry_run, report_only=args.report)


if __name__ == "__main__":
    main()
