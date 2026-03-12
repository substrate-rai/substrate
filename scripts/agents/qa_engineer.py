#!/usr/bin/env python3
"""QA Engineer Agent (Spec) — tests and verifies before things ship.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Validates scripts, links, builds, and recent changes.

Usage:
    python3 scripts/agents/qa_engineer.py status    # test coverage overview
    python3 scripts/agents/qa_engineer.py links     # check internal links in markdown
    python3 scripts/agents/qa_engineer.py scripts   # syntax-check all Python scripts
    python3 scripts/agents/qa_engineer.py build     # verify Jekyll config + layouts
    python3 scripts/agents/qa_engineer.py audit     # AI reviews recent git changes
    python3 scripts/agents/qa_engineer.py smoke     # basic smoke test of key files
"""

import argparse
import ast
import json
import os
import re
import subprocess
import sys
from datetime import datetime

from context import load_context

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))

_BASE_PROMPT = """\
You are the last line of defense before something ships. \
Your job: find what's broken before anyone else sees it. \
No false confidence. If you can't verify it works, say so.

Rules:
- Report failures first, passes second.
- Be specific: file paths, line numbers, evidence.
- Never say "looks good" without proof.
- If something is ambiguous, flag it — don't assume it's fine.
- Do NOT use thinking/reasoning tags. Answer directly."""

# Load voice, bulletins, and domain knowledge
_ctx = load_context("Spec")
SYSTEM_PROMPT = _ctx.system_prompt(_BASE_PROMPT)

# ANSI colors
WHITE = "\033[1;37m"
DIM = "\033[2m"
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"
BOLD = "\033[1m"

# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    from ollama_client import chat, OllamaError
    messages = []
    if context:
        messages.append({"role": "user", "content": f"Context:\n{context}"})
        messages.append({"role": "assistant", "content": "Understood. I have the context."})
    messages.append({"role": "user", "content": prompt})
    try:
        return chat(messages, system=SYSTEM_PROMPT)
    except OllamaError as e:
        return f"[error: {e}]"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def find_files(directory, extension):
    """Recursively find files with a given extension."""
    results = []
    for root, dirs, files in os.walk(directory):
        # Skip hidden dirs and __pycache__
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "__pycache__"]
        for f in files:
            if f.endswith(extension):
                results.append(os.path.join(root, f))
    return sorted(results)


def syntax_check_python(filepath):
    """Try to parse a Python file with ast. Returns (ok, error_msg)."""
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            source = f.read()
        ast.parse(source, filename=filepath)
        return True, None
    except SyntaxError as e:
        return False, f"line {e.lineno}: {e.msg}"
    except Exception as e:
        return False, str(e)


def rel_path(filepath):
    """Return path relative to repo root."""
    return os.path.relpath(filepath, REPO_DIR)


def extract_md_links(filepath):
    """Extract internal markdown links from a file.

    Returns list of (link_text, target_path, line_number).
    Captures:
      - [text](path)        — standard markdown links
      - [text]: path         — reference-style links
    Skips external URLs (http://, https://, mailto:, #anchors).
    """
    links = []
    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except Exception:
        return links

    # Inline links: [text](target)
    inline_re = re.compile(r'\[([^\]]*)\]\(([^)]+)\)')
    # Reference links: [text]: target
    ref_re = re.compile(r'^\[([^\]]+)\]:\s+(.+)$')

    for i, line in enumerate(lines, 1):
        for match in inline_re.finditer(line):
            target = match.group(2).strip()
            links.append((match.group(1), target, i))
        ref_match = ref_re.match(line.strip())
        if ref_match:
            target = ref_match.group(2).strip()
            links.append((ref_match.group(1), target, i))

    return links


def is_external(target):
    """Check if a link target is external or an anchor."""
    return (
        target.startswith("http://")
        or target.startswith("https://")
        or target.startswith("mailto:")
        or target.startswith("#")
        or target.startswith("data:")
        or target.startswith("javascript:")
    )


def resolve_link(source_file, target):
    """Resolve a relative link target to an absolute path and check existence."""
    # Strip anchor fragments
    target = target.split("#")[0].split("?")[0].strip()
    if not target:
        return True  # anchor-only link

    # Handle absolute paths (relative to repo root for Jekyll)
    if target.startswith("/"):
        # Jekyll serves from repo root
        candidate = os.path.join(REPO_DIR, target.lstrip("/"))
    else:
        # Relative to the source file's directory
        source_dir = os.path.dirname(source_file)
        candidate = os.path.join(source_dir, target)

    candidate = os.path.normpath(candidate)

    # Direct file exists
    if os.path.exists(candidate):
        return True

    # Jekyll might serve a directory with index.html/index.md
    if os.path.isdir(candidate):
        for idx in ["index.html", "index.md"]:
            if os.path.exists(os.path.join(candidate, idx)):
                return True

    # Try adding common extensions
    for ext in [".html", ".md", "/index.html", "/index.md"]:
        if os.path.exists(candidate + ext):
            return True

    return False


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_status():
    """Show test coverage: which scripts are verified, which aren't."""
    print(f"{WHITE}  S! SPEC — TEST COVERAGE{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    # Find all Python files in scripts/
    scripts_dir = os.path.join(REPO_DIR, "scripts")
    py_files = find_files(scripts_dir, ".py")

    passed = 0
    failed = 0
    errors = []

    for f in py_files:
        ok, err = syntax_check_python(f)
        if ok:
            passed += 1
        else:
            failed += 1
            errors.append((rel_path(f), err))

    print(f"  {BOLD}Python scripts in scripts/{RESET}")
    print(f"  Total:   {len(py_files)}")
    print(f"  {GREEN}Parsed:  {passed}{RESET}")
    if failed:
        print(f"  {RED}Failed:  {failed}{RESET}")
        for path, err in errors:
            print(f"    {RED}FAIL{RESET}  {path}: {err}")
    else:
        print(f"  {GREEN}Failed:  0{RESET}")
    print()

    # Check key directories
    key_dirs = [
        ("_posts", "Blog posts"),
        ("_layouts", "Jekyll layouts"),
        ("site", "Site pages"),
        ("games", "Games"),
        ("scripts/agents", "Agents"),
        ("scripts/prompts", "Voice files"),
        ("memory", "Memory"),
        ("ledger", "Ledger"),
    ]

    print(f"  {BOLD}Directory health{RESET}")
    for dirname, label in key_dirs:
        dirpath = os.path.join(REPO_DIR, dirname)
        if os.path.isdir(dirpath):
            count = len([f for f in os.listdir(dirpath) if not f.startswith(".")])
            print(f"  {GREEN}OK{RESET}    {label:<20} ({dirname}/) — {count} items")
        else:
            print(f"  {YELLOW}MISS{RESET}  {label:<20} ({dirname}/) — directory not found")
    print()

    # Check key files
    key_files = [
        "_config.yml",
        "flake.nix",
        "CLAUDE.md",
        "index.md",
    ]

    print(f"  {BOLD}Key files{RESET}")
    for fname in key_files:
        fpath = os.path.join(REPO_DIR, fname)
        if os.path.exists(fpath):
            size = os.path.getsize(fpath)
            if size == 0:
                print(f"  {YELLOW}WARN{RESET}  {fname} — exists but EMPTY")
            else:
                print(f"  {GREEN}OK{RESET}    {fname} — {size} bytes")
        else:
            print(f"  {RED}MISS{RESET}  {fname} — not found")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_links():
    """Check internal links in markdown files."""
    print(f"{WHITE}  S! SPEC — LINK CHECK{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    search_dirs = ["_posts", "site", "games"]
    md_files = []
    for d in search_dirs:
        dirpath = os.path.join(REPO_DIR, d)
        if os.path.isdir(dirpath):
            md_files.extend(find_files(dirpath, ".md"))
            md_files.extend(find_files(dirpath, ".html"))

    # Also check top-level markdown
    for f in os.listdir(REPO_DIR):
        if f.endswith(".md") and os.path.isfile(os.path.join(REPO_DIR, f)):
            md_files.append(os.path.join(REPO_DIR, f))

    total_links = 0
    broken_links = []
    files_checked = 0

    for filepath in sorted(set(md_files)):
        links = extract_md_links(filepath)
        files_checked += 1
        for text, target, lineno in links:
            if is_external(target):
                continue
            total_links += 1
            if not resolve_link(filepath, target):
                broken_links.append((rel_path(filepath), lineno, target, text))

    if broken_links:
        print(f"  {RED}BROKEN LINKS ({len(broken_links)}):{RESET}")
        for path, lineno, target, text in broken_links:
            print(f"    {RED}FAIL{RESET}  {path}:{lineno} → {target}")
            if text:
                print(f"          link text: \"{text}\"")
        print()

    print(f"  {BOLD}Summary{RESET}")
    print(f"  Files checked:    {files_checked}")
    print(f"  Internal links:   {total_links}")
    print(f"  {GREEN}Valid:            {total_links - len(broken_links)}{RESET}")
    if broken_links:
        print(f"  {RED}Broken:           {len(broken_links)}{RESET}")
    else:
        print(f"  {GREEN}Broken:           0{RESET}")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_scripts():
    """Syntax-check all Python scripts in the repo."""
    print(f"{WHITE}  S! SPEC — SCRIPT SYNTAX CHECK{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    py_files = find_files(REPO_DIR, ".py")

    passed = 0
    failed = 0
    failures = []

    for f in py_files:
        ok, err = syntax_check_python(f)
        rp = rel_path(f)
        if ok:
            passed += 1
        else:
            failed += 1
            failures.append((rp, err))

    # Report failures first
    if failures:
        print(f"  {RED}FAILURES:{RESET}")
        for path, err in failures:
            print(f"    {RED}FAIL{RESET}  {path}: {err}")
        print()

    # Then passes
    print(f"  {BOLD}Results{RESET}")
    print(f"  Total scripts:  {len(py_files)}")
    print(f"  {GREEN}Passed:         {passed}{RESET}")
    if failed:
        print(f"  {RED}Failed:         {failed}{RESET}")
    else:
        print(f"  {GREEN}Failed:         0{RESET}")
    print()

    # List all checked files
    print(f"  {DIM}Checked:{RESET}")
    for f in py_files:
        rp = rel_path(f)
        ok, _ = syntax_check_python(f)
        status = f"{GREEN}PASS{RESET}" if ok else f"{RED}FAIL{RESET}"
        print(f"    {status}  {rp}")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_build():
    """Verify Jekyll config and layout references."""
    print(f"{WHITE}  S! SPEC — BUILD VERIFICATION{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    issues = []

    # Check _config.yml exists and parses
    config_path = os.path.join(REPO_DIR, "_config.yml")
    if not os.path.exists(config_path):
        issues.append(("FAIL", "_config.yml not found — Jekyll cannot build"))
    elif os.path.getsize(config_path) == 0:
        issues.append(("FAIL", "_config.yml is empty — Jekyll cannot build"))
    else:
        issues.append(("PASS", f"_config.yml exists ({os.path.getsize(config_path)} bytes)"))

    # Check _layouts directory
    layouts_dir = os.path.join(REPO_DIR, "_layouts")
    available_layouts = set()
    if not os.path.isdir(layouts_dir):
        issues.append(("FAIL", "_layouts/ directory not found"))
    else:
        for f in os.listdir(layouts_dir):
            if f.endswith(".html"):
                name = f.replace(".html", "")
                available_layouts.add(name)
        issues.append(("PASS", f"_layouts/ has {len(available_layouts)} layouts: {', '.join(sorted(available_layouts))}"))

    # Scan frontmatter for layout references
    layout_re = re.compile(r'^layout:\s*(.+)$', re.MULTILINE)
    frontmatter_re = re.compile(r'^---\s*\n(.*?)\n---', re.DOTALL)

    md_dirs = ["_posts", "site", "games", "arcade"]
    md_files = []
    for d in md_dirs:
        dp = os.path.join(REPO_DIR, d)
        if os.path.isdir(dp):
            md_files.extend(find_files(dp, ".md"))
            md_files.extend(find_files(dp, ".html"))

    # Also check top-level .md and .html files
    for f in os.listdir(REPO_DIR):
        fp = os.path.join(REPO_DIR, f)
        if os.path.isfile(fp) and (f.endswith(".md") or f.endswith(".html")):
            md_files.append(fp)

    referenced_layouts = {}
    for filepath in sorted(set(md_files)):
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as fh:
                content = fh.read(2000)  # frontmatter is at the top
        except Exception:
            continue

        fm = frontmatter_re.match(content)
        if fm:
            fm_text = fm.group(1)
            lm = layout_re.search(fm_text)
            if lm:
                layout_name = lm.group(1).strip().strip('"').strip("'")
                if layout_name not in referenced_layouts:
                    referenced_layouts[layout_name] = []
                referenced_layouts[layout_name].append(rel_path(filepath))

    # Check each referenced layout exists
    missing_layouts = {}
    for layout, files in referenced_layouts.items():
        if layout not in available_layouts:
            missing_layouts[layout] = files

    if missing_layouts:
        for layout, files in missing_layouts.items():
            issues.append(("FAIL", f"layout '{layout}' referenced but not in _layouts/"))
            for f in files[:5]:  # show up to 5 examples
                issues.append(("", f"  → used by: {f}"))
            if len(files) > 5:
                issues.append(("", f"  → ... and {len(files) - 5} more"))
    else:
        issues.append(("PASS", f"All {len(referenced_layouts)} referenced layouts exist"))

    # Check _includes if referenced
    includes_dir = os.path.join(REPO_DIR, "_includes")
    if os.path.isdir(includes_dir):
        include_count = len([f for f in os.listdir(includes_dir) if not f.startswith(".")])
        issues.append(("PASS", f"_includes/ has {include_count} files"))

    # Report
    for status, msg in issues:
        if status == "PASS":
            print(f"  {GREEN}PASS{RESET}  {msg}")
        elif status == "FAIL":
            print(f"  {RED}FAIL{RESET}  {msg}")
        else:
            print(f"        {msg}")
    print()

    # Summary
    passes = sum(1 for s, _ in issues if s == "PASS")
    fails = sum(1 for s, _ in issues if s == "FAIL")
    print(f"  {BOLD}Build readiness:{RESET} {passes} passed, {fails} failed")
    if fails == 0:
        print(f"  {GREEN}Jekyll build should succeed.{RESET}")
    else:
        print(f"  {RED}Jekyll build may fail — fix issues above.{RESET}")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_audit():
    """AI reviews recent git changes for regressions."""
    print(f"{WHITE}  S! SPEC — CHANGE AUDIT{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    # Get last 10 commits
    try:
        log_result = subprocess.run(
            ["git", "-C", REPO_DIR, "log", "--oneline", "-10"],
            capture_output=True, text=True, timeout=10
        )
        git_log = log_result.stdout.strip()
    except Exception as e:
        print(f"  {RED}Could not read git log: {e}{RESET}")
        return

    if not git_log:
        print(f"  {YELLOW}No commits found.{RESET}")
        return

    # Get diff stats for last 10 commits
    try:
        diff_result = subprocess.run(
            ["git", "-C", REPO_DIR, "diff", "--stat", "HEAD~10..HEAD"],
            capture_output=True, text=True, timeout=10
        )
        diff_stat = diff_result.stdout.strip()
    except Exception:
        diff_stat = "(could not retrieve diff stats)"

    # Get full diff for last commit (limited)
    try:
        last_diff = subprocess.run(
            ["git", "-C", REPO_DIR, "diff", "HEAD~1..HEAD"],
            capture_output=True, text=True, timeout=10
        )
        last_diff_text = last_diff.stdout[:5000]  # limit to 5k chars
    except Exception:
        last_diff_text = "(could not retrieve last diff)"

    print(f"  {BOLD}Recent commits:{RESET}")
    for line in git_log.split("\n"):
        print(f"    {line}")
    print()

    print(f"  {BOLD}Diff stats (last 10 commits):{RESET}")
    for line in diff_stat.split("\n")[-5:]:  # last 5 lines of stats
        print(f"    {line}")
    print()

    context = (
        f"Recent git log (last 10 commits):\n{git_log}\n\n"
        f"Diff stats:\n{diff_stat}\n\n"
        f"Last commit diff (truncated):\n{last_diff_text}"
    )

    print(f"  {DIM}Running local AI audit (Qwen3 8B)...{RESET}")
    print()

    response = ask_local(
        "Review these recent git changes and flag any potential issues:\n"
        "1. Any files deleted that might still be referenced elsewhere?\n"
        "2. Any changes that could break existing functionality?\n"
        "3. Any suspicious patterns (hardcoded values, missing error handling)?\n"
        "4. Any commits that seem incomplete or risky?\n"
        "5. Any regressions — things that used to work that might not now?\n\n"
        "Be specific. File names and line references where possible.",
        context=context,
    )
    print(response)
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_roles():
    """Check agent role consistency across all definition sources."""
    print(f"{WHITE}  S! SPEC — ROLE CONSISTENCY CHECK{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    issues = []
    warnings = []

    # Source 1: staff/index.md (canonical — public-facing)
    staff_roles = {}
    staff_path = os.path.join(REPO_DIR, "site", "staff", "index.md")
    if os.path.exists(staff_path):
        with open(staff_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        # Match patterns like: name: 'Byte',  and  role: 'News Reporter',
        # Staff page uses JS object literals with single quotes
        for m in re.finditer(r"name:\s*'([^']+)'.*?role:\s*'([^']+)'", content, re.DOTALL):
            staff_roles[m.group(1)] = m.group(2)

    # Source 2: orchestrator.py
    orch_roles = {}
    orch_path = os.path.join(SCRIPT_DIR, "orchestrator.py")
    if os.path.exists(orch_path):
        with open(orch_path, "r", encoding="utf-8", errors="replace") as f:
            orch_content = f.read()
        for m in re.finditer(r'\("(\w+)",\s*"[^"]+",\s*"[^"]+",\s*"([^"]+)"', orch_content):
            orch_roles[m.group(1)] = m.group(2)

    # Source 3: characters.json
    char_roles = {}
    char_path = os.path.join(REPO_DIR, "scripts", "ml", "characters.json")
    if os.path.exists(char_path):
        try:
            with open(char_path) as f:
                data = json.load(f)
            for c in data.get("characters", []):
                char_roles[c["name"]] = c["role"]
        except (json.JSONDecodeError, KeyError):
            issues.append("characters.json: failed to parse")

    # Source 4: character-guide.md
    guide_roles = {}
    guide_path = os.path.join(REPO_DIR, "memory", "character-guide.md")
    if os.path.exists(guide_path):
        with open(guide_path, "r", encoding="utf-8", errors="replace") as f:
            guide_content = f.read()
        for m in re.finditer(r'###\s+\d+\.\s+(\w+)\s+—\s+(.+)', guide_content):
            guide_roles[m.group(1)] = m.group(2).strip()

    # Staff page is canonical. Check others against it.
    if not staff_roles:
        issues.append("Could not parse staff/index.md — no canonical source")
        print(f"  {RED}FAIL{RESET}  No canonical role source found")
        print()
        print(f"  -- Spec, Substrate QA")
        print()
        return

    all_names = sorted(set(
        list(staff_roles.keys()) + list(orch_roles.keys()) +
        list(char_roles.keys()) + list(guide_roles.keys())
    ))

    consistent = 0
    inconsistent = 0
    missing_count = 0

    print(f"  {BOLD}Canonical source: site/staff/index.md{RESET}")
    print()

    for name in all_names:
        canonical = staff_roles.get(name)
        mismatches = []

        if name in orch_roles and canonical and orch_roles[name] != canonical:
            mismatches.append(f"orchestrator.py: \"{orch_roles[name]}\"")
        if name in char_roles and canonical and char_roles[name] != canonical:
            mismatches.append(f"characters.json: \"{char_roles[name]}\"")
        if name in guide_roles and canonical and guide_roles[name] != canonical:
            mismatches.append(f"character-guide.md: \"{guide_roles[name]}\"")

        if not canonical:
            print(f"  {YELLOW}MISS{RESET}  {name}: not on staff page")
            missing_count += 1
        elif mismatches:
            print(f"  {RED}FAIL{RESET}  {name}: canonical \"{canonical}\"")
            for mm in mismatches:
                print(f"         ≠ {mm}")
            inconsistent += 1
        else:
            consistent += 1

    print()
    print(f"  {BOLD}Summary{RESET}")
    print(f"  Agents checked:  {len(all_names)}")
    print(f"  {GREEN}Consistent:      {consistent}{RESET}")
    if inconsistent:
        print(f"  {RED}Inconsistent:    {inconsistent}{RESET}")
    if missing_count:
        print(f"  {YELLOW}Missing:         {missing_count}{RESET}")
    print()

    if inconsistent == 0 and missing_count == 0:
        print(f"  {GREEN}Role consistency: ALL CLEAR{RESET}")
    else:
        print(f"  {RED}Role consistency: {inconsistent} MISMATCH(ES) — reconcile against staff page{RESET}")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


def cmd_smoke():
    """Run a basic smoke test on key files and directories."""
    print(f"{WHITE}  S! SPEC — SMOKE TEST{RESET}")
    print(f"{DIM}  ─────────────────────────────────────────────────{RESET}")
    print()

    passed = 0
    failed = 0
    warned = 0

    def check(label, condition, warn=False):
        nonlocal passed, failed, warned
        if condition:
            print(f"  {GREEN}PASS{RESET}  {label}")
            passed += 1
        elif warn:
            print(f"  {YELLOW}WARN{RESET}  {label}")
            warned += 1
        else:
            print(f"  {RED}FAIL{RESET}  {label}")
            failed += 1

    # Key files exist
    print(f"  {BOLD}Key files{RESET}")
    key_files = [
        ("CLAUDE.md", False),
        ("_config.yml", False),
        ("flake.nix", False),
        ("index.md", False),
    ]
    for fname, is_warn in key_files:
        fpath = os.path.join(REPO_DIR, fname)
        exists = os.path.exists(fpath) and os.path.getsize(fpath) > 0
        check(f"{fname} exists and non-empty", exists, warn=is_warn)
    print()

    # Key directories populated
    print(f"  {BOLD}Key directories{RESET}")
    key_dirs = [
        ("_posts", 1),
        ("_layouts", 1),
        ("scripts", 1),
        ("scripts/agents", 1),
        ("scripts/prompts", 1),
        ("site", 1),
        ("games", 1),
        ("memory", 1),
    ]
    for dirname, min_files in key_dirs:
        dirpath = os.path.join(REPO_DIR, dirname)
        if os.path.isdir(dirpath):
            count = len([f for f in os.listdir(dirpath) if not f.startswith(".")])
            check(f"{dirname}/ has >={min_files} files (found {count})", count >= min_files)
        else:
            check(f"{dirname}/ exists", False)
    print()

    # Key scripts parse
    print(f"  {BOLD}Key scripts parse{RESET}")
    key_scripts = [
        "scripts/think.py",
        "scripts/route.py",
        "scripts/pipeline.py",
        "scripts/publish.py",
        "scripts/mirror.py",
    ]
    for script in key_scripts:
        spath = os.path.join(REPO_DIR, script)
        if os.path.exists(spath):
            ok, err = syntax_check_python(spath)
            if ok:
                check(f"{script} parses cleanly", True)
            else:
                check(f"{script} parses cleanly ({err})", False)
        else:
            check(f"{script} exists", False, warn=True)
    print()

    # Agent scripts parse
    print(f"  {BOLD}Agent scripts parse{RESET}")
    agents_dir = os.path.join(REPO_DIR, "scripts", "agents")
    if os.path.isdir(agents_dir):
        agent_files = [f for f in os.listdir(agents_dir) if f.endswith(".py")]
        for af in sorted(agent_files):
            afpath = os.path.join(agents_dir, af)
            ok, err = syntax_check_python(afpath)
            if ok:
                check(f"agents/{af}", True)
            else:
                check(f"agents/{af} ({err})", False)
    print()

    # Git health
    print(f"  {BOLD}Git health{RESET}")
    try:
        result = subprocess.run(
            ["git", "-C", REPO_DIR, "status", "--porcelain"],
            capture_output=True, text=True, timeout=10
        )
        dirty = len(result.stdout.strip().split("\n")) if result.stdout.strip() else 0
        check(f"Working tree ({dirty} uncommitted changes)", dirty == 0, warn=True)
    except Exception:
        check("Git status readable", False)
    print()

    # Summary
    total = passed + failed + warned
    print(f"  {BOLD}Smoke test summary{RESET}")
    print(f"  Total checks:  {total}")
    print(f"  {GREEN}Passed:        {passed}{RESET}")
    if warned:
        print(f"  {YELLOW}Warnings:      {warned}{RESET}")
    if failed:
        print(f"  {RED}Failed:        {failed}{RESET}")
    else:
        print(f"  {GREEN}Failed:        0{RESET}")
    print()

    if failed == 0:
        print(f"  {GREEN}Smoke test: ALL CLEAR{RESET}")
    else:
        print(f"  {RED}Smoke test: {failed} FAILURE(S) — investigate before shipping{RESET}")
    print()

    print(f"  -- Spec, Substrate QA")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="QA Engineer Agent (Spec) — local-only testing and verification for Substrate"
    )
    parser.add_argument(
        "command",
        choices=["status", "links", "scripts", "build", "audit", "smoke", "roles"],
        help="QA command to run",
    )
    args = parser.parse_args()

    cmds = {
        "status": cmd_status,
        "links": cmd_links,
        "scripts": cmd_scripts,
        "build": cmd_build,
        "audit": cmd_audit,
        "smoke": cmd_smoke,
        "roles": cmd_roles,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()
