#!/usr/bin/env python3
"""Sentinel — Security Agent. Guards the perimeter.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Scans the repo for leaked secrets, audits security posture,
validates .gitignore, checks file permissions, and flags risky deps.

Usage:
    python3 scripts/agents/security.py scan          # grep for secrets/leaks
    python3 scripts/agents/security.py audit         # AI security posture review
    python3 scripts/agents/security.py gitignore     # verify .gitignore coverage
    python3 scripts/agents/security.py permissions   # check sensitive file perms
    python3 scripts/agents/security.py deps          # flag risky dependencies
    python3 scripts/agents/security.py report        # full security report
"""

import argparse
import json
import os
import re
import stat
import sys
from datetime import datetime

from context import load_context

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))

_BASE_PROMPT = """\
You are Sentinel, the security agent for Substrate, an autonomous AI workstation.
You guard the perimeter. Every file committed is a potential leak. Every dependency \
is a potential attack surface. Every API key left in code is a breach waiting to happen. \
Paranoia is your job description.

Rules:
- Flag anything that looks like a credential, key, token, or secret.
- Flag IP addresses, SSIDs, and network topology details.
- Flag overly permissive file permissions on sensitive files.
- Flag dependencies with known issues or suspicious provenance.
- Be specific: file path, line number, what you found, why it's a risk.
- Recommend concrete fixes, not vague advice.
- Do NOT use thinking/reasoning tags. Answer directly."""

_ctx = load_context("Sentinel")
SYSTEM_PROMPT = _ctx.system_prompt(_BASE_PROMPT)

# Patterns that indicate potential secrets or sensitive data
SECRET_PATTERNS = [
    (r'(?i)(?:api[_-]?key|apikey)\s*[=:]\s*["\']?[A-Za-z0-9_\-]{16,}', "API key assignment"),
    (r'(?i)(?:secret|token|password|passwd|pwd)\s*[=:]\s*["\']?[^\s"\']{8,}', "Secret/token/password assignment"),
    (r'(?i)bearer\s+[A-Za-z0-9_\-\.]{20,}', "Bearer token"),
    (r'(?i)(?:sk|pk)[-_][A-Za-z0-9]{20,}', "Stripe-style API key"),
    (r'(?i)ghp_[A-Za-z0-9]{36,}', "GitHub personal access token"),
    (r'(?i)(?:AKIA|ASIA)[A-Z0-9]{16}', "AWS access key ID"),
    (r'\x2d{5}BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIV' + r'ATE KEY\x2d{5}', "Private key"),
    (r'(?i)ssh-(?:rsa|ed25519|dss)\s+[A-Za-z0-9+/=]{40,}', "SSH public key"),
    (r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', "IP address"),
    (r'(?i)ssid\s*[=:]\s*["\']?[^\s"\']+', "SSID reference"),
    (r'(?i)ANTHROPIC_API_KEY\s*=\s*["\']?sk-[^\s"\']+', "Anthropic API key (hardcoded)"),
    (r'(?i)(?:mysql|postgres|mongodb)://[^\s"\']+:[^\s"\']+@', "Database connection string with credentials"),
    (r'(?i)(?:access_token|auth_token|client_secret)\s*[=:]\s*["\']?[^\s"\']{8,}', "Auth token assignment"),
]

# Files/dirs to skip during scanning
SKIP_DIRS = {
    ".git", "node_modules", "__pycache__", ".nix-profile",
    "result", "result-bin", "_site", ".jekyll-cache",
    "tools", "briefings",
}

SKIP_EXTENSIONS = {
    ".png", ".jpg", ".jpeg", ".gif", ".ico", ".svg", ".webp",
    ".woff", ".woff2", ".ttf", ".eot",
    ".mp3", ".wav", ".ogg", ".mp4", ".webm",
    ".pdf", ".zip", ".tar", ".gz",
    ".pyc", ".o", ".so", ".dylib",
}

# Sensitive files that should have restricted permissions
SENSITIVE_FILES = [
    ".env",
    "ledger/*.private.txt",
]

# Patterns that .gitignore SHOULD cover
RECOMMENDED_GITIGNORE = [
    ".env",
    "*.secret",
    "*.key",
    "*.pem",
    "*.p12",
    "*.pfx",
    "ledger/*.private.txt",
    "__pycache__/",
    "*.pyc",
    "initialPassword",
    "*.private.*",
    ".env.*",
    "id_rsa",
    "id_ed25519",
]

# Color codes
STEEL = "\033[38;2;136;153;170m"
RED = "\033[1;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[1;32m"
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"


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
# Scanning utilities
# ---------------------------------------------------------------------------

def walk_repo():
    """Walk the repo, yielding (filepath, relative_path) for scannable files."""
    for root, dirs, files in os.walk(REPO_DIR):
        # Prune skipped directories
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]

        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext in SKIP_EXTENSIONS:
                continue

            full = os.path.join(root, fname)
            rel = os.path.relpath(full, REPO_DIR)
            yield full, rel


def is_localhost_ip(match_str):
    """Check if an IP address is localhost/loopback (not a real leak)."""
    ip_match = re.search(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b', match_str)
    if ip_match:
        ip = ip_match.group(1)
        return ip.startswith("127.") or ip == "0.0.0.0" or ip.startswith("192.168.") is False and ip == "localhost"
    return False


def scan_file(filepath, rel_path):
    """Scan a single file for secret patterns. Returns list of findings."""
    findings = []
    try:
        with open(filepath, "r", errors="ignore") as f:
            for lineno, line in enumerate(f, 1):
                for pattern, description in SECRET_PATTERNS:
                    matches = re.finditer(pattern, line)
                    for match in matches:
                        matched_text = match.group(0)

                        # Skip localhost/loopback IPs — those are fine
                        if description == "IP address":
                            ip = re.search(r'\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b', matched_text)
                            if ip:
                                addr = ip.group(1)
                                if (addr.startswith("127.") or addr == "0.0.0.0"
                                        or addr.startswith("10.")
                                        or addr.startswith("192.168.")):
                                    continue
                                # Skip version-like numbers (e.g. 1.2.3.4)
                                octets = addr.split(".")
                                if all(int(o) < 20 for o in octets):
                                    continue

                        # Skip patterns in comments that are just documentation
                        stripped = line.strip()
                        if stripped.startswith("#") and description == "IP address":
                            continue

                        # Truncate the matched text for display
                        display = matched_text[:60] + "..." if len(matched_text) > 60 else matched_text

                        findings.append({
                            "file": rel_path,
                            "line": lineno,
                            "type": description,
                            "match": display,
                        })
    except (OSError, UnicodeDecodeError):
        pass
    return findings


def scan_repo():
    """Scan entire repo for potential secrets. Returns list of findings."""
    all_findings = []
    for filepath, rel_path in walk_repo():
        findings = scan_file(filepath, rel_path)
        all_findings.extend(findings)
    return all_findings


def read_gitignore():
    """Read and parse .gitignore, returning set of patterns."""
    gitignore_path = os.path.join(REPO_DIR, ".gitignore")
    patterns = set()
    if os.path.exists(gitignore_path):
        with open(gitignore_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    patterns.add(line)
    return patterns


def find_sensitive_files():
    """Find files that might be sensitive based on name/extension."""
    sensitive = []
    for filepath, rel_path in walk_repo():
        fname = os.path.basename(filepath)
        # Check for sensitive file names
        if fname in (".env", ".env.local", ".env.production"):
            sensitive.append((filepath, rel_path, "environment file"))
        elif fname.endswith((".key", ".pem", ".p12", ".pfx")):
            sensitive.append((filepath, rel_path, "key/cert file"))
        elif fname.endswith(".secret"):
            sensitive.append((filepath, rel_path, "secret file"))
        elif "private" in fname.lower():
            sensitive.append((filepath, rel_path, "private data file"))
        elif fname in ("id_rsa", "id_ed25519", "id_dsa"):
            sensitive.append((filepath, rel_path, "SSH private key"))
    # Also check known paths
    for pattern in SENSITIVE_FILES:
        if "*" not in pattern:
            full = os.path.join(REPO_DIR, pattern)
            if os.path.exists(full):
                sensitive.append((full, pattern, "known sensitive file"))
    return sensitive


def collect_python_imports():
    """Collect all external Python imports across the repo."""
    imports = {}
    stdlib = {
        "os", "sys", "re", "json", "datetime", "argparse", "subprocess",
        "pathlib", "collections", "functools", "itertools", "math", "random",
        "hashlib", "hmac", "base64", "time", "socket", "http", "urllib",
        "io", "string", "textwrap", "copy", "logging", "warnings",
        "stat", "glob", "shutil", "tempfile", "csv", "xml", "html",
        "unittest", "typing", "abc", "enum", "dataclasses", "contextlib",
        "threading", "multiprocessing", "concurrent", "asyncio",
        "struct", "codecs", "pprint", "traceback", "signal",
    }

    for filepath, rel_path in walk_repo():
        if not filepath.endswith(".py"):
            continue
        try:
            with open(filepath) as f:
                for lineno, line in enumerate(f, 1):
                    line = line.strip()
                    # Match: import X, from X import Y
                    m = re.match(r'^(?:from\s+(\S+)|import\s+(\S+))', line)
                    if m:
                        mod = (m.group(1) or m.group(2)).split(".")[0]
                        if mod not in stdlib and not mod.startswith("_"):
                            if mod not in imports:
                                imports[mod] = []
                            imports[mod].append(f"{rel_path}:{lineno}")
        except (OSError, UnicodeDecodeError):
            pass

    return imports


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_scan():
    """Scan the repo for potential secrets and leaks."""
    print(f"\n{STEEL}  X| SENTINEL — SECRET SCAN{RESET}")
    print(f"{DIM}  Scanning repo for leaked credentials, keys, tokens...{RESET}")
    print()

    findings = scan_repo()

    if not findings:
        print(f"  {GREEN}CLEAR{RESET} — No obvious secrets detected in tracked files.")
        print()
        return

    # Group by severity
    high = [f for f in findings if f["type"] in (
        "Private key", "Anthropic API key (hardcoded)", "AWS access key ID",
        "GitHub personal access token", "Database connection string with credentials",
    )]
    medium = [f for f in findings if f not in high and f["type"] != "IP address"]
    low = [f for f in findings if f["type"] == "IP address"]

    if high:
        print(f"  {RED}HIGH SEVERITY ({len(high)}){RESET}")
        for f in high:
            print(f"  {RED}!{RESET}  {f['file']}:{f['line']}  [{f['type']}]")
            print(f"      {DIM}{f['match']}{RESET}")
        print()

    if medium:
        print(f"  {YELLOW}MEDIUM SEVERITY ({len(medium)}){RESET}")
        for f in medium:
            print(f"  {YELLOW}?{RESET}  {f['file']}:{f['line']}  [{f['type']}]")
            print(f"      {DIM}{f['match']}{RESET}")
        print()

    if low:
        print(f"  {DIM}LOW SEVERITY ({len(low)}){RESET}")
        for f in low:
            print(f"  {DIM}-  {f['file']}:{f['line']}  [{f['type']}]  {f['match']}{RESET}")
        print()

    total = len(findings)
    print(f"  TOTAL: {total} finding(s) — {RED}{len(high)} high{RESET}, "
          f"{YELLOW}{len(medium)} medium{RESET}, {DIM}{len(low)} low{RESET}")
    print()


def cmd_audit():
    """AI-assisted security posture review."""
    print(f"\n{STEEL}  X| SENTINEL — SECURITY AUDIT{RESET}")
    print(f"{DIM}  Running local AI audit (Qwen3 8B)...{RESET}")
    print()

    # Gather context
    findings = scan_repo()
    gitignore_patterns = read_gitignore()
    sensitive = find_sensitive_files()

    context = "=== REPO SCAN RESULTS ===\n"
    if findings:
        context += f"Found {len(findings)} potential issues:\n"
        for f in findings[:30]:  # Limit to keep context manageable
            context += f"  {f['file']}:{f['line']} — {f['type']}: {f['match']}\n"
        if len(findings) > 30:
            context += f"  ... and {len(findings) - 30} more\n"
    else:
        context += "No obvious secrets detected in code.\n"

    context += "\n=== .GITIGNORE COVERAGE ===\n"
    for p in sorted(gitignore_patterns):
        context += f"  {p}\n"

    context += "\n=== SENSITIVE FILES FOUND ===\n"
    if sensitive:
        for full, rel, desc in sensitive:
            perms = oct(os.stat(full).st_mode)[-3:] if os.path.exists(full) else "???"
            context += f"  {rel} ({desc}) — perms: {perms}\n"
    else:
        context += "  None found on disk.\n"

    context += f"\n=== REPO ROOT ===\n{REPO_DIR}\n"

    response = ask_local(
        "Perform a full security audit of this Substrate repo.\n\n"
        "Assess:\n"
        "1. Are secrets adequately protected? Any leaks?\n"
        "2. Is .gitignore covering all sensitive patterns?\n"
        "3. Are file permissions appropriate for sensitive files?\n"
        "4. What's the overall security posture (1-10)?\n"
        "5. Top 3 most urgent security actions needed.\n"
        "6. Any praise-worthy security practices already in place?\n\n"
        "Be specific and actionable.",
        context=context,
    )
    print(response)
    print()


def cmd_gitignore():
    """Verify .gitignore covers all sensitive patterns."""
    print(f"\n{STEEL}  X| SENTINEL — GITIGNORE AUDIT{RESET}")
    print(f"{DIM}  Checking .gitignore coverage...{RESET}")
    print()

    current = read_gitignore()
    gitignore_path = os.path.join(REPO_DIR, ".gitignore")

    print(f"  {BOLD}Current .gitignore entries:{RESET}")
    for p in sorted(current):
        print(f"    {GREEN}+{RESET} {p}")
    print()

    # Check recommended patterns
    missing = []
    for rec in RECOMMENDED_GITIGNORE:
        if rec not in current:
            # Check if a broader pattern already covers it
            covered = False
            for existing in current:
                if existing == rec:
                    covered = True
                    break
                # Simple glob check: *.key covers anything.key
                if existing.startswith("*") and rec.endswith(existing[1:]):
                    covered = True
                    break
            if not covered:
                missing.append(rec)

    if missing:
        print(f"  {YELLOW}RECOMMENDED ADDITIONS:{RESET}")
        for m in missing:
            print(f"    {YELLOW}+{RESET} {m}")
        print()
    else:
        print(f"  {GREEN}All recommended patterns are covered.{RESET}")
        print()

    # Check if .env exists and is gitignored
    env_path = os.path.join(REPO_DIR, ".env")
    if os.path.exists(env_path):
        if ".env" in current:
            print(f"  {GREEN}OK{RESET}  .env exists and is gitignored")
        else:
            print(f"  {RED}DANGER{RESET}  .env exists but is NOT gitignored!")
    else:
        print(f"  {DIM}INFO{RESET}  No .env file found on disk")

    # Check if any private ledger files exist
    ledger_dir = os.path.join(REPO_DIR, "ledger")
    if os.path.isdir(ledger_dir):
        private_files = [f for f in os.listdir(ledger_dir) if "private" in f.lower()]
        if private_files:
            if "ledger/*.private.txt" in current:
                print(f"  {GREEN}OK{RESET}  Private ledger files ({len(private_files)}) are gitignored")
            else:
                print(f"  {RED}DANGER{RESET}  Private ledger files exist but pattern not in .gitignore!")
    print()


def cmd_permissions():
    """Check file permissions on sensitive files."""
    print(f"\n{STEEL}  X| SENTINEL — PERMISSIONS CHECK{RESET}")
    print(f"{DIM}  Checking file permissions on sensitive files...{RESET}")
    print()

    sensitive = find_sensitive_files()
    issues = 0

    if not sensitive:
        print(f"  {GREEN}No sensitive files found on disk.{RESET}")
        print()
        return

    for full, rel, desc in sensitive:
        if not os.path.exists(full):
            continue

        st = os.stat(full)
        mode = st.st_mode
        perms = oct(mode)[-3:]
        owner_only = not (mode & stat.S_IRGRP or mode & stat.S_IROTH
                          or mode & stat.S_IWGRP or mode & stat.S_IWOTH)

        if owner_only:
            print(f"  {GREEN}OK{RESET}  {rel} ({desc}) — {perms} (owner-only)")
        else:
            print(f"  {YELLOW}WARN{RESET}  {rel} ({desc}) — {perms} (group/other can read)")
            print(f"        Fix: chmod 600 {rel}")
            issues += 1

    print()
    if issues:
        print(f"  {YELLOW}{issues} file(s) with overly permissive permissions.{RESET}")
    else:
        print(f"  {GREEN}All sensitive files have appropriate permissions.{RESET}")
    print()


def cmd_deps():
    """List external dependencies and flag supply chain risks."""
    print(f"\n{STEEL}  X| SENTINEL — DEPENDENCY AUDIT{RESET}")
    print(f"{DIM}  Scanning for external dependencies...{RESET}")
    print()

    imports = collect_python_imports()

    # Known safe / expected packages
    known_safe = {
        "requests": "HTTP library — widely used, well-maintained",
        "flask": "Web framework — widely used",
        "PIL": "Image processing (Pillow)",
        "feedparser": "RSS feed parsing",
        "bs4": "HTML parsing (BeautifulSoup)",
        "atproto": "Bluesky AT Protocol client",
    }

    # Potentially risky patterns
    flagged = {
        "eval": "Dynamic code execution",
        "pickle": "Deserialization attacks",
        "subprocess": "Shell command injection",
    }

    print(f"  {BOLD}External Python imports found:{RESET}")
    print()

    for mod, locations in sorted(imports.items()):
        count = len(locations)
        if mod in known_safe:
            status = f"{GREEN}OK{RESET}"
            note = known_safe[mod]
        elif mod in flagged:
            status = f"{YELLOW}FLAG{RESET}"
            note = flagged[mod]
        else:
            status = f"{DIM}UNKNOWN{RESET}"
            note = "Not in known-safe list — verify provenance"

        print(f"  {status}  {mod} (used in {count} file(s))")
        print(f"        {DIM}{note}{RESET}")
        if count <= 3:
            for loc in locations:
                print(f"        {DIM}  {loc}{RESET}")
        else:
            for loc in locations[:2]:
                print(f"        {DIM}  {loc}{RESET}")
            print(f"        {DIM}  ... and {count - 2} more{RESET}")
        print()

    # Check for package.json / npm
    pkg_json = os.path.join(REPO_DIR, "package.json")
    if os.path.exists(pkg_json):
        print(f"  {YELLOW}NOTE{RESET}  package.json found — npm dependencies present")
        try:
            with open(pkg_json) as f:
                pkg = json.load(f)
            deps = pkg.get("dependencies", {})
            dev_deps = pkg.get("devDependencies", {})
            print(f"        {len(deps)} runtime deps, {len(dev_deps)} dev deps")
        except (json.JSONDecodeError, OSError):
            print(f"        {RED}Could not parse package.json{RESET}")
        print()

    # Check for Gemfile (Ruby/Jekyll)
    gemfile = os.path.join(REPO_DIR, "Gemfile")
    if os.path.exists(gemfile):
        print(f"  {DIM}NOTE{RESET}  Gemfile found — Ruby/Jekyll dependencies managed by bundler")
        print()

    print(f"  {BOLD}Summary:{RESET} {len(imports)} external Python module(s) detected.")
    print()


def cmd_report():
    """Full security report with AI analysis."""
    print(f"\n{STEEL}{'='*60}{RESET}")
    print(f"{STEEL}  X| SENTINEL — FULL SECURITY REPORT{RESET}")
    print(f"{STEEL}  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{RESET}")
    print(f"{STEEL}{'='*60}{RESET}")

    # Run all checks and collect data
    print(f"\n{DIM}  [1/4] Scanning for secrets...{RESET}")
    findings = scan_repo()

    print(f"{DIM}  [2/4] Checking .gitignore...{RESET}")
    gitignore_patterns = read_gitignore()
    missing_patterns = [r for r in RECOMMENDED_GITIGNORE if r not in gitignore_patterns]

    print(f"{DIM}  [3/4] Checking permissions...{RESET}")
    sensitive = find_sensitive_files()
    perm_issues = []
    for full, rel, desc in sensitive:
        if os.path.exists(full):
            mode = os.stat(full).st_mode
            if mode & stat.S_IRGRP or mode & stat.S_IROTH:
                perm_issues.append((rel, desc, oct(mode)[-3:]))

    print(f"{DIM}  [4/4] Scanning dependencies...{RESET}")
    imports = collect_python_imports()

    # Build context for AI
    context = f"=== SECRET SCAN: {len(findings)} findings ===\n"
    high = [f for f in findings if f["type"] in (
        "Private key", "Anthropic API key (hardcoded)", "AWS access key ID",
        "GitHub personal access token", "Database connection string with credentials",
    )]
    medium = [f for f in findings if f not in high and f["type"] != "IP address"]
    low = [f for f in findings if f["type"] == "IP address"]
    context += f"  High: {len(high)}, Medium: {len(medium)}, Low: {len(low)}\n"
    for f in findings[:20]:
        context += f"  {f['file']}:{f['line']} — {f['type']}\n"

    context += f"\n=== GITIGNORE: {len(gitignore_patterns)} patterns ===\n"
    context += f"  Missing recommended: {missing_patterns}\n"

    context += f"\n=== PERMISSIONS: {len(perm_issues)} issues ===\n"
    for rel, desc, perms in perm_issues:
        context += f"  {rel} ({desc}) — {perms}\n"

    context += f"\n=== DEPENDENCIES: {len(imports)} external modules ===\n"
    for mod in sorted(imports.keys()):
        context += f"  {mod} ({len(imports[mod])} usages)\n"

    context += f"\n=== SECURITY RULES (from CLAUDE.md) ===\n"
    context += "Never commit: IP addresses, passwords, API keys, SSIDs, network topology, credentials.\n"
    context += "Use [redacted] as placeholder for network details.\n"
    context += "Secrets managed out-of-band (agenix, sops-nix), never inline in Nix config.\n"

    # Print summary
    print(f"\n{BOLD}  FINDINGS SUMMARY{RESET}")
    print(f"  {'─'*50}")
    print(f"  Secret scan:     {len(high)} high, {len(medium)} medium, {len(low)} low")
    print(f"  .gitignore:      {len(gitignore_patterns)} patterns, {len(missing_patterns)} missing")
    print(f"  Permissions:     {len(perm_issues)} issue(s)")
    print(f"  Dependencies:    {len(imports)} external module(s)")
    print(f"  {'─'*50}")
    print()

    # AI analysis
    print(f"{DIM}  Generating AI analysis (Qwen3 8B)...{RESET}")
    print()

    response = ask_local(
        "Write a concise security report for Substrate based on the scan results.\n\n"
        "Include:\n"
        "1. Overall security grade (A-F)\n"
        "2. Critical issues that need immediate attention\n"
        "3. Warnings that should be addressed soon\n"
        "4. Good practices already in place\n"
        "5. Recommended next actions (prioritized)\n\n"
        "Format it like a professional security audit. Be direct.",
        context=context,
    )
    print(response)
    print()
    print(f"{STEEL}  -- Sentinel, Substrate Security{RESET}")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Sentinel — Security Agent. Local-only repo security auditor."
    )
    parser.add_argument(
        "command",
        choices=["scan", "audit", "gitignore", "permissions", "deps", "report"],
        help="Security command to run",
    )
    args = parser.parse_args()

    cmds = {
        "scan": cmd_scan,
        "audit": cmd_audit,
        "gitignore": cmd_gitignore,
        "permissions": cmd_permissions,
        "deps": cmd_deps,
        "report": cmd_report,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()
