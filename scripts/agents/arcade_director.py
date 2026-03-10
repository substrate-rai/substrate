#!/usr/bin/env python3
"""Arc — Arcade Director agent.

Tests actual game playability: HTML validity, JS syntax, mobile readiness,
asset integrity, link health, and size budgets. Not just file existence.

Usage:
    python3 scripts/agents/arcade_director.py status
    python3 scripts/agents/arcade_director.py audit
    python3 scripts/agents/arcade_director.py smoke
    python3 scripts/agents/arcade_director.py report [--date 2026-03-08]
    python3 scripts/agents/arcade_director.py report --dry-run
"""

import argparse
import os
import re
import sys
from datetime import datetime, timezone
from html.parser import HTMLParser

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAMES_DIR = os.path.join(REPO_DIR, "games")
ARCADE_DIR = os.path.join(REPO_DIR, "arcade")
REPORT_DIR = os.path.join(REPO_DIR, "memory", "arcade")
ASSETS_JS_DIR = os.path.join(REPO_DIR, "assets", "js")
ASSETS_IMG_DIR = os.path.join(REPO_DIR, "assets", "images", "generated")

# (dir_slug, display_name, genre)
KNOWN_GAMES = [
    ("puzzle", "SIGTERM", "Word puzzle"),
    ("adventure", "SUBPROCESS", "Text adventure"),
    ("mycelium", "MYCELIUM", "3D simulation"),
    ("chemistry", "SYNTHESIS", "Sandbox"),
    ("tactics", "TACTICS", "Tactical RPG"),
    ("novel", "PROCESS", "Visual novel"),
    ("airlock", "AIRLOCK", "Physics puzzle"),
    ("cascade", "CASCADE", "Quick decisions"),
    ("objection", "OBJECTION!", "Courtroom drama"),
    ("cypher", "V_CYPHER", "Visual novel"),
    ("bootloader", "BOOTLOADER", "Sandbox"),
    ("brigade", "BRIGADE", "Recruitment VN"),
    ("radio", "RADIO", "Music player"),
    ("album", "ALBUM", "Creative tool"),
    ("myco", "MYCOWORLD", "Educational VN"),
    ("signal", "SIGNAL", "Deduction game"),
    ("snatcher", "SEEKER", "Kojima tribute"),
    ("dragonforce", "DRAGONFORCE", "Army battle"),
    ("warcraft", "DOMINION", "RTS"),
    ("deckbuilder", "STACK OVERFLOW", "Deckbuilder"),
    ("idle", "SUBSTRATE GROWTH", "Idle clicker"),
    ("runner", "PIPELINE", "Endless runner"),
    ("vocal-lab", "VOCAL LAB", "Audio synthesis"),
    ("card", "PITCH CARD", "Landing page"),
]

SIZE_BUDGET_KB = 200


# ---------------------------------------------------------------------------
# HTML Validator
# ---------------------------------------------------------------------------

class HTMLValidator(HTMLParser):
    """Lightweight HTML structure checker."""

    VOID_ELEMENTS = frozenset([
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ])

    def __init__(self):
        super().__init__()
        self.errors = []
        self.tag_stack = []
        self.has_doctype = False
        self.has_html = False
        self.has_head = False
        self.has_body = False
        self.has_title = False
        self.title_text = ""
        self._in_title = False

    def handle_decl(self, decl):
        if decl.lower().startswith("doctype"):
            self.has_doctype = True

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag == "html":
            self.has_html = True
        elif tag == "head":
            self.has_head = True
        elif tag == "body":
            self.has_body = True
        elif tag == "title":
            self.has_title = True
            self._in_title = True

        if tag not in self.VOID_ELEMENTS:
            self.tag_stack.append((tag, self.getpos()))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "title":
            self._in_title = False

        if tag in self.VOID_ELEMENTS:
            return

        # Walk the stack looking for a match
        for i in range(len(self.tag_stack) - 1, -1, -1):
            if self.tag_stack[i][0] == tag:
                # Check for anything left unclosed between
                unclosed = self.tag_stack[i + 1:]
                for utag, upos in unclosed:
                    self.errors.append(
                        f"unclosed <{utag}> at line {upos[0]}"
                    )
                self.tag_stack = self.tag_stack[:i]
                return

        self.errors.append(
            f"unexpected </{tag}> at line {self.getpos()[0]}"
        )

    def handle_data(self, data):
        if self._in_title:
            self.title_text += data

    def finish(self):
        """Call after feeding all data. Reports remaining unclosed tags."""
        for tag, pos in self.tag_stack:
            self.errors.append(f"unclosed <{tag}> at line {pos[0]}")


def validate_html(content, uses_jekyll_layout=False):
    """Parse HTML content and return list of issues."""
    issues = []
    validator = HTMLValidator()

    try:
        validator.feed(content)
        validator.finish()
    except Exception as e:
        issues.append(f"HTML parse error: {e}")
        return issues

    # Jekyll layout files inherit DOCTYPE/html/head/body from the layout
    if not uses_jekyll_layout:
        if not validator.has_doctype:
            issues.append("missing <!DOCTYPE html>")
        if not validator.has_html:
            issues.append("missing <html> tag")
        if not validator.has_head:
            issues.append("missing <head> tag")
        if not validator.has_title:
            issues.append("missing <title> tag")
    else:
        # Jekyll layout pages get <title> from frontmatter `title:` field
        has_fm_title = bool(re.search(r"^title:", content[:500], re.MULTILINE))
        if not validator.has_title and not has_fm_title:
            issues.append("missing <title> (not in HTML or frontmatter)")

    # Report structural errors (unclosed/mismatched tags)
    # Filter out noise: some are benign in practice (e.g. <br> variants)
    for err in validator.errors:
        issues.append(f"html: {err}")

    return issues


# ---------------------------------------------------------------------------
# JavaScript Syntax Checker
# ---------------------------------------------------------------------------

# Patterns that indicate likely JS syntax errors (conservative — low
# false-positive rate matters more than catching everything)
JS_ERROR_PATTERNS = [
    (r"\bfuncion\b", "typo: 'funcion' (should be 'function')"),
    (r"\bretrun\b", "typo: 'retrun' (should be 'return')"),
    (r"\bvra\s", "typo: 'vra' (should be 'var')"),
    (r"\bconts\s", "typo: 'conts' (should be 'const')"),
]


def check_js_syntax(script_content, label="inline"):
    """Basic JS syntax checks on a script block.

    Uses bracket-balance counting with comment/string/regex awareness.
    Intentionally conservative — a false positive here marks a working
    game as 'degraded', which is worse than missing a real bug.
    """
    issues = []

    # Bracket balance with comment/string/template-literal/regex tracking
    openers = {"(": ")", "[": "]", "{": "}"}
    closers = {v: k for k, v in openers.items()}
    stack = []
    i = 0
    n = len(script_content)

    while i < n:
        ch = script_content[i]

        # --- Line comment ---
        if ch == "/" and i + 1 < n and script_content[i + 1] == "/":
            # Skip to end of line
            j = script_content.find("\n", i)
            i = j + 1 if j != -1 else n
            continue

        # --- Block comment ---
        if ch == "/" and i + 1 < n and script_content[i + 1] == "*":
            j = script_content.find("*/", i + 2)
            i = j + 2 if j != -1 else n
            continue

        # --- Template literal (backtick) — can span lines, contain ${} ---
        if ch == "`":
            i += 1
            depth = 0
            while i < n:
                c = script_content[i]
                if c == "\\" and i + 1 < n:
                    i += 2
                    continue
                if c == "$" and i + 1 < n and script_content[i + 1] == "{":
                    depth += 1
                    i += 2
                    continue
                if c == "}" and depth > 0:
                    depth -= 1
                    i += 1
                    continue
                if c == "`" and depth == 0:
                    i += 1
                    break
                i += 1
            continue

        # --- Single/double quoted string (consume until matching close) ---
        if ch in ("'", '"'):
            quote = ch
            i += 1
            while i < n:
                c = script_content[i]
                if c == "\\" and i + 1 < n:
                    i += 2  # skip escaped char
                    continue
                if c == quote:
                    i += 1
                    break
                if c == "\n":
                    # Newline in a non-template string — could be an HTML
                    # attribute value spanning lines. Too noisy to flag.
                    i += 1
                    break
                i += 1
            continue

        # --- Regex literal (heuristic: / after certain tokens) ---
        if ch == "/":
            # Quick heuristic: if the previous non-whitespace char is one
            # of = ( , ; ! & | ? : { [ ~ ^ % + - or start of input, treat
            # as regex. Otherwise treat as division operator.
            prev = script_content[:i].rstrip()
            if prev and prev[-1] in "=(!,;|&?:{[~^%+-><" or not prev:
                i += 1
                while i < n:
                    c = script_content[i]
                    if c == "\\" and i + 1 < n:
                        i += 2
                        continue
                    if c == "/":
                        i += 1
                        # Skip flags like /gi
                        while i < n and script_content[i].isalpha():
                            i += 1
                        break
                    if c == "\n":
                        i += 1
                        break
                    i += 1
                continue

        # --- Brackets ---
        if ch in openers:
            stack.append(ch)
        elif ch in closers:
            if not stack:
                issues.append(f"js ({label}): unexpected '{ch}' with no matching opener")
            elif stack[-1] != closers[ch]:
                issues.append(
                    f"js ({label}): mismatched bracket — expected "
                    f"'{openers[stack[-1]]}' but got '{ch}'"
                )
            else:
                stack.pop()

        i += 1

    if stack:
        unclosed = "".join(stack)
        issues.append(f"js ({label}): {len(stack)} unclosed bracket(s): {unclosed}")

    # Pattern checks (simple regexes on raw source)
    for pattern, msg in JS_ERROR_PATTERNS:
        try:
            if re.search(pattern, script_content):
                issues.append(f"js ({label}): {msg}")
        except re.error:
            pass

    return issues


def extract_and_check_scripts(html_content):
    """Extract all <script> blocks from HTML and check each."""
    issues = []
    # Find all inline script blocks (skip external src= scripts)
    script_pattern = re.compile(
        r"<script(?:\s[^>]*)?>(.+?)</script>",
        re.DOTALL | re.IGNORECASE,
    )
    blocks = script_pattern.findall(html_content)
    for idx, block in enumerate(blocks):
        block = block.strip()
        if not block:
            continue
        label = f"block-{idx + 1}"
        issues.extend(check_js_syntax(block, label))
    return issues


# ---------------------------------------------------------------------------
# Mobile Readiness Checker
# ---------------------------------------------------------------------------

def check_mobile_readiness(html_content, uses_jekyll_layout=False):
    """Check for mobile-friendly patterns.

    Games using a Jekyll layout (e.g. layout: default) inherit viewport
    and other meta tags from the layout template, so we skip those checks.
    """
    issues = []

    # Viewport meta tag (skip if layout provides it)
    if not uses_jekyll_layout:
        viewport_match = re.search(
            r'<meta\s+name=["\']viewport["\'][^>]*content=["\']([^"\']+)["\']',
            html_content, re.IGNORECASE,
        )
        if not viewport_match:
            # Also try content before name (some files reverse the order)
            viewport_match = re.search(
                r'<meta\s+content=["\']([^"\']+)["\'][^>]*name=["\']viewport["\']',
                html_content, re.IGNORECASE,
            )

        if not viewport_match:
            issues.append("mobile: no viewport meta tag")
        else:
            vp = viewport_match.group(1)
            if "width=device-width" not in vp:
                issues.append("mobile: viewport missing width=device-width")
            if "initial-scale" not in vp:
                issues.append("mobile: viewport missing initial-scale")

    # touch-action CSS (game-specific, not from layout)
    if "touch-action" not in html_content:
        issues.append("mobile: no touch-action CSS (may have scroll/zoom issues)")

    # safe-area-inset (game-specific — games need their own padding)
    if "safe-area-inset" not in html_content and not uses_jekyll_layout:
        issues.append("mobile: no safe-area-inset usage (notch devices may clip)")

    # Minimum touch target sizes (44px is the guideline)
    has_min_height = bool(re.search(r"min-height\s*:\s*4[0-9]px", html_content))
    has_min_width = bool(re.search(r"min-width\s*:\s*4[0-9]px", html_content))
    if not has_min_height and not has_min_width:
        issues.append("mobile: no min-height/min-width for touch targets (buttons may be too small)")

    return issues


# ---------------------------------------------------------------------------
# Asset Integrity Checker
# ---------------------------------------------------------------------------

def check_asset_integrity(html_content, game_dir):
    """Check that referenced local scripts and assets exist."""
    issues = []

    # Find src= references that use site.baseurl (Jekyll pattern)
    jekyll_srcs = re.findall(
        r'src=["\'](?:\{\{[^}]*\}\})?/assets/js/([^"\']+)["\']',
        html_content,
    )
    for js_file in jekyll_srcs:
        full_path = os.path.join(ASSETS_JS_DIR, js_file)
        if not os.path.isfile(full_path):
            issues.append(f"asset: missing /assets/js/{js_file}")

    # Find local relative src= references (not http, not {{ }}, not data:)
    local_srcs = re.findall(
        r'src=["\'](?!https?://)(?!\{\{)(?!data:)([^"\']+)["\']',
        html_content,
    )
    for src in local_srcs:
        # Skip absolute paths handled above
        if src.startswith("/assets/"):
            continue
        # Check relative to game directory
        src_path = os.path.join(game_dir, src)
        if not os.path.isfile(src_path):
            # Could be a build artifact or dynamic — soft warning
            issues.append(f"asset: possibly missing local file '{src}'")

    # Find CSS url() references to local files
    css_urls = re.findall(
        r"url\(['\"]?(?!https?://)(?!data:)([^'\")]+)['\"]?\)",
        html_content,
    )
    for url in css_urls:
        if url.startswith("/assets/"):
            path = os.path.join(REPO_DIR, url.lstrip("/"))
            if not os.path.isfile(path):
                issues.append(f"asset: missing CSS reference '{url}'")

    return issues


# ---------------------------------------------------------------------------
# Link Checker
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Playability Checker (NEW — checks what players actually experience)
# ---------------------------------------------------------------------------

def check_playability(html_content, slug):
    """Check if a player can actually figure out how to play this game.

    This is what Arc SHOULD have been checking from the start:
    not bracket balance, but whether a human can start playing.
    """
    issues = []

    # 1. Does the game have visible instructions or a tutorial?
    has_how_to = bool(re.search(
        r'how\s+to\s+play|instructions|tutorial|controls|help',
        html_content, re.IGNORECASE
    ))
    has_placeholder_text = bool(re.search(
        r'placeholder\s*=\s*["\'][^"\']*(?:type|try|enter|command)',
        html_content, re.IGNORECASE
    ))
    has_visible_controls = bool(re.search(
        r'(?:WASD|arrow\s*keys|click|tap|swipe|drag)',
        html_content, re.IGNORECASE
    ))
    if not has_how_to and not has_placeholder_text and not has_visible_controls:
        issues.append("playability: no visible instructions — new player won't know what to do")

    # 2. Does the game have a start/play button or auto-start?
    has_start = bool(re.search(
        r'(?:start|play|begin|new\s+game|launch)',
        html_content, re.IGNORECASE
    ))
    if not has_start:
        issues.append("playability: no start/play button found")

    # 3. Does it have any win/lose/score condition?
    has_win_condition = bool(re.search(
        r'(?:win|lose|score|points|game\s*over|victory|defeat|complete|streak|level)',
        html_content, re.IGNORECASE
    ))
    if not has_win_condition:
        issues.append("playability: no win/lose/score condition found — is this a game or a demo?")

    # 4. Does it have touch event handlers (not just CSS touch-action)?
    has_touch_handlers = bool(re.search(
        r'(?:touchstart|touchend|touchmove|ontouchstart|pointer(?:down|up|move))',
        html_content, re.IGNORECASE
    ))
    has_click_handlers = bool(re.search(
        r'(?:addEventListener\s*\(\s*["\']click|onclick|\.click\s*\()',
        html_content, re.IGNORECASE
    ))
    if not has_touch_handlers and not has_click_handlers:
        issues.append("playability: no click/touch event handlers found — game may not be interactive")

    # 5. Does canvas-based game have any visible UI overlay?
    has_canvas = bool(re.search(r'<canvas', html_content, re.IGNORECASE))
    if has_canvas:
        has_ui_overlay = bool(re.search(
            r'(?:position\s*:\s*(?:absolute|fixed).*?(?:z-index|pointer-events))',
            html_content, re.DOTALL | re.IGNORECASE
        ))
        has_hud = bool(re.search(
            r'(?:hud|overlay|ui-panel|controls|toolbar|sidebar)',
            html_content, re.IGNORECASE
        ))
        if not has_ui_overlay and not has_hud:
            issues.append("playability: canvas game with no visible UI overlay — player has no feedback")

    return issues


def check_internal_links(html_content, slug):
    """Check that internal links between games reference valid targets."""
    issues = []

    # Find href= to /games/XXX/ paths
    game_links = re.findall(
        r'href=["\'](?:\{\{[^}]*\}\})?/games/([^"\'#?]+)',
        html_content,
    )
    for link in game_links:
        link = link.strip("/")
        # Allow known subdirectories like puzzle/versus
        top_slug = link.split("/")[0]
        target_dir = os.path.join(GAMES_DIR, link)
        target_index = os.path.join(target_dir, "index.html")
        # Also check if the top-level game dir exists
        top_dir = os.path.join(GAMES_DIR, top_slug)
        if not os.path.isdir(top_dir):
            issues.append(f"link: /games/{link}/ -> game directory not found")
        elif not os.path.isfile(target_index) and not os.path.isdir(target_dir):
            issues.append(f"link: /games/{link}/ -> no index.html at target")

    return issues


# ---------------------------------------------------------------------------
# Size Audit
# ---------------------------------------------------------------------------

def audit_size(game_dir):
    """Return total size in KB and per-file breakdown for large files."""
    total_bytes = 0
    large_files = []

    for root, dirs, files in os.walk(game_dir):
        for f in files:
            fpath = os.path.join(root, f)
            try:
                size = os.path.getsize(fpath)
                total_bytes += size
                if size > 50 * 1024:  # flag individual files > 50KB
                    rel = os.path.relpath(fpath, game_dir)
                    large_files.append((rel, size // 1024))
            except OSError:
                pass

    return total_bytes // 1024, large_files


# ---------------------------------------------------------------------------
# Full Game Scan
# ---------------------------------------------------------------------------

def scan_game(slug, title, genre):
    """Run all checks on a single game. Returns a result dict."""
    game_dir = os.path.join(GAMES_DIR, slug)

    result = {
        "slug": slug,
        "title": title,
        "genre": genre,
        "exists": os.path.isdir(game_dir),
        "has_index": False,
        "size_kb": 0,
        "large_files": [],
        "file_count": 0,
        "issues": [],      # all issues found
        "checks": {         # per-category pass/fail
            "html": None,
            "js": None,
            "mobile": None,
            "play": None,
            "assets": None,
            "links": None,
            "size": None,
        },
        "status": "unknown",
    }

    if not result["exists"]:
        result["issues"].append("CRITICAL: game directory missing")
        result["status"] = "missing"
        for k in result["checks"]:
            result["checks"][k] = "skip"
        return result

    index_path = os.path.join(game_dir, "index.html")
    result["has_index"] = os.path.isfile(index_path)

    if not result["has_index"]:
        result["issues"].append("CRITICAL: no index.html")
        result["status"] = "broken"
        for k in result["checks"]:
            result["checks"][k] = "skip"
        return result

    # Count files
    for root, dirs, files in os.walk(game_dir):
        result["file_count"] += len(files)

    # Read index.html
    try:
        with open(index_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except Exception as e:
        result["issues"].append(f"CRITICAL: cannot read index.html: {e}")
        result["status"] = "broken"
        return result

    # Detect if this file uses a Jekyll layout (not layout: null)
    fm_match = re.match(r"^---\s*\n(.*?)\n---", content[:1000], re.DOTALL)
    uses_jekyll_layout = False
    if fm_match:
        fm = fm_match.group(1)
        layout_match = re.search(r"^layout:\s*(.+)$", fm, re.MULTILINE)
        if layout_match:
            layout_val = layout_match.group(1).strip().strip("'\"")
            uses_jekyll_layout = layout_val != "null" and layout_val != ""

    # 1. HTML Validity
    html_issues = validate_html(content, uses_jekyll_layout)
    result["issues"].extend(html_issues)
    result["checks"]["html"] = "pass" if not html_issues else "fail"

    # 2. JavaScript Syntax
    js_issues = extract_and_check_scripts(content)
    result["issues"].extend(js_issues)
    result["checks"]["js"] = "pass" if not js_issues else "fail"

    # 3. Mobile Readiness
    mobile_issues = check_mobile_readiness(content, uses_jekyll_layout)
    result["issues"].extend(mobile_issues)
    result["checks"]["mobile"] = "pass" if not mobile_issues else "fail"

    # 4. Playability (the check that actually matters)
    play_issues = check_playability(content, slug)
    result["issues"].extend(play_issues)
    result["checks"]["play"] = "pass" if not play_issues else "fail"

    # 5. Asset Integrity
    asset_issues = check_asset_integrity(content, game_dir)
    result["issues"].extend(asset_issues)
    result["checks"]["assets"] = "pass" if not asset_issues else "fail"

    # 6. Link Check
    link_issues = check_internal_links(content, slug)
    result["issues"].extend(link_issues)
    result["checks"]["links"] = "pass" if not link_issues else "fail"

    # 7. Size Audit
    size_kb, large_files = audit_size(game_dir)
    result["size_kb"] = size_kb
    result["large_files"] = large_files
    size_issues = []
    if size_kb > SIZE_BUDGET_KB:
        size_issues.append(f"size: {size_kb}KB exceeds {SIZE_BUDGET_KB}KB budget")
    result["issues"].extend(size_issues)
    result["checks"]["size"] = "pass" if not size_issues else "warn"

    # Determine overall status
    critical = [i for i in result["issues"] if i.startswith("CRITICAL")]
    errors = [i for i in result["issues"]
              if i.startswith("html:") or i.startswith("js (") or i.startswith("asset:")]
    play_fails = [i for i in result["issues"] if i.startswith("playability:")]
    warnings = [i for i in result["issues"]
                if i.startswith("mobile:") or i.startswith("size:") or i.startswith("link:")]

    if critical:
        result["status"] = "broken"
    elif errors:
        result["status"] = "degraded"
    elif warnings:
        result["status"] = "playable"
    else:
        result["status"] = "healthy"

    return result


def scan_all_games():
    """Scan every known game and detect unknown directories."""
    results = []
    for slug, title, genre in KNOWN_GAMES:
        results.append(scan_game(slug, title, genre))

    # Detect unknown game directories
    known_slugs = {s for s, _, _ in KNOWN_GAMES}
    skip_dirs = {"shared"}
    try:
        for entry in os.listdir(GAMES_DIR):
            full = os.path.join(GAMES_DIR, entry)
            if os.path.isdir(full) and entry not in known_slugs and entry not in skip_dirs:
                results.append({
                    "slug": entry,
                    "title": f"UNKNOWN ({entry})",
                    "genre": "?",
                    "exists": True,
                    "has_index": os.path.isfile(os.path.join(full, "index.html")),
                    "size_kb": 0,
                    "large_files": [],
                    "file_count": 0,
                    "issues": [f"game directory '{entry}' not in KNOWN_GAMES registry"],
                    "checks": {k: "skip" for k in ["html", "js", "mobile", "assets", "links", "size"]},
                    "status": "unregistered",
                })
    except OSError:
        pass

    return results


def check_arcade_portal():
    """Check the arcade index page for valid game links."""
    issues = []
    arcade_index = os.path.join(ARCADE_DIR, "index.md")
    if not os.path.isfile(arcade_index):
        arcade_index = os.path.join(ARCADE_DIR, "index.html")
    if not os.path.isfile(arcade_index):
        return {"exists": False, "game_links": 0, "issues": ["no arcade index page"]}

    try:
        with open(arcade_index, "r") as f:
            content = f.read()
    except Exception as e:
        return {"exists": False, "game_links": 0, "issues": [str(e)]}

    # Check links point to existing games
    game_links = re.findall(r'/games/([^/"\'#?\s]+)', content)
    unique_links = set(game_links)
    valid = 0
    for link in unique_links:
        target = os.path.join(GAMES_DIR, link)
        if os.path.isdir(target):
            valid += 1
        else:
            issues.append(f"arcade portal links to /games/{link}/ which does not exist")

    return {"exists": True, "game_links": len(unique_links), "valid": valid, "issues": issues}


# ---------------------------------------------------------------------------
# Output Formatting
# ---------------------------------------------------------------------------

STATUS_ICONS = {
    "healthy":      "[OK]",
    "playable":     "[~~]",
    "degraded":     "[!!]",
    "broken":       "[XX]",
    "missing":      "[--]",
    "unregistered": "[??]",
    "unknown":      "[??]",
}


def fmt_status(status):
    return STATUS_ICONS.get(status, "[??]")


def print_status(results):
    """Quick inventory: one line per game with health indicator."""
    print(f"[Arc] Arcade Status — {len(results)} titles scanned")
    print()

    counts = {"healthy": 0, "playable": 0, "degraded": 0, "broken": 0, "missing": 0}
    for r in results:
        icon = fmt_status(r["status"])
        size = f"{r['size_kb']}KB" if r["size_kb"] else "---"
        checks = r["checks"]
        check_str = " ".join(
            f"{k}:{'ok' if v == 'pass' else v}" if v else f"{k}:--"
            for k, v in checks.items()
        )
        print(f"  {icon} {r['title']:<20} {r['status']:<12} {size:>7}  {check_str}")
        if r["status"] in counts:
            counts[r["status"]] += 1

    print()
    print(f"  healthy={counts['healthy']}  playable={counts['playable']}  "
          f"degraded={counts['degraded']}  broken={counts['broken']}  missing={counts['missing']}")
    print()
    print("-- Arc, Substrate Arcade")


def print_audit(results):
    """Detailed audit: all checks, all issues, per game."""
    print(f"[Arc] Full Arcade Audit — {len(results)} titles")
    print("=" * 72)

    for r in results:
        icon = fmt_status(r["status"])
        print(f"\n{icon} {r['title']} ({r['slug']}/) — {r['status'].upper()}")
        print(f"   genre: {r['genre']}  files: {r['file_count']}  size: {r['size_kb']}KB")

        checks = r["checks"]
        check_line = "   checks: " + "  ".join(
            f"{k}={'PASS' if v == 'pass' else v.upper()}" if v else f"{k}=N/A"
            for k, v in checks.items()
        )
        print(check_line)

        if r["large_files"]:
            print("   large files:")
            for fname, fsize in r["large_files"]:
                print(f"     {fname}: {fsize}KB")

        if r["issues"]:
            print(f"   issues ({len(r['issues'])}):")
            for issue in r["issues"]:
                print(f"     - {issue}")
        else:
            print("   issues: none")

    # Arcade portal
    portal = check_arcade_portal()
    print(f"\n{'=' * 72}")
    print(f"ARCADE PORTAL")
    if portal["exists"]:
        print(f"   links: {portal['game_links']} game targets ({portal.get('valid', 0)} valid)")
        for issue in portal["issues"]:
            print(f"   - {issue}")
    else:
        print("   WARNING: no arcade portal index page found")

    print()
    print("-- Arc, Substrate Arcade")


def print_smoke(results):
    """Failures only. If clean, say so."""
    failures = [r for r in results if r["status"] in ("broken", "degraded", "missing")]
    warnings = [r for r in results if r["status"] == "playable" and r["issues"]]
    portal = check_arcade_portal()

    if not failures and not warnings and not portal["issues"]:
        print(f"[Arc] Smoke test PASSED — all {len(results)} titles clean.")
        print("-- Arc, Substrate Arcade")
        return

    print(f"[Arc] Smoke test — {len(failures)} failures, {len(warnings)} warnings")
    print()

    for r in failures:
        icon = fmt_status(r["status"])
        print(f"  {icon} {r['title']} ({r['slug']}/) — {r['status'].upper()}")
        for issue in r["issues"]:
            print(f"       {issue}")

    if warnings:
        print()
        for r in warnings:
            icon = fmt_status(r["status"])
            print(f"  {icon} {r['title']} ({r['slug']}/) — WARNINGS:")
            for issue in r["issues"]:
                print(f"       {issue}")

    if portal["issues"]:
        print()
        print("  ARCADE PORTAL:")
        for issue in portal["issues"]:
            print(f"       {issue}")

    print()
    print("-- Arc, Substrate Arcade")


def build_report(date_str, results):
    """Build a full markdown report for archiving."""
    lines = []
    lines.append(f"# Arcade Audit Report — {date_str}")
    lines.append("")

    # Summary
    total = len(results)
    by_status = {}
    for r in results:
        by_status.setdefault(r["status"], []).append(r["title"])

    lines.append(f"**Games scanned:** {total}")
    status_summary = ", ".join(
        f"{s}: {len(titles)}" for s, titles in sorted(by_status.items())
    )
    lines.append(f"**Status:** {status_summary}")
    lines.append("")

    # Per-game
    lines.append("## Game-by-Game")
    lines.append("")

    for r in results:
        icon = fmt_status(r["status"])
        lines.append(f"### {icon} {r['title']} (`{r['slug']}/`)")
        lines.append(f"- **Status:** {r['status']}")
        lines.append(f"- **Genre:** {r['genre']}")
        lines.append(f"- **Files:** {r['file_count']}  |  **Size:** {r['size_kb']}KB")

        checks = r["checks"]
        check_str = " | ".join(
            f"{k}: {'PASS' if v == 'pass' else v.upper()}" if v else f"{k}: N/A"
            for k, v in checks.items()
        )
        lines.append(f"- **Checks:** {check_str}")

        if r["large_files"]:
            lines.append("- **Large files:**")
            for fname, fsize in r["large_files"]:
                lines.append(f"  - {fname}: {fsize}KB")

        if r["issues"]:
            lines.append(f"- **Issues ({len(r['issues'])}):**")
            for issue in r["issues"]:
                lines.append(f"  - {issue}")
        else:
            lines.append("- **Issues:** none")
        lines.append("")

    # Portal
    portal = check_arcade_portal()
    lines.append("## Arcade Portal")
    if portal["exists"]:
        lines.append(f"- Links to {portal['game_links']} game targets ({portal.get('valid', 0)} valid)")
        for issue in portal["issues"]:
            lines.append(f"- {issue}")
    else:
        lines.append("- **WARNING:** no arcade index page found")
    lines.append("")

    # Action items
    broken = [r["title"] for r in results if r["status"] in ("broken", "missing")]
    degraded = [r["title"] for r in results if r["status"] == "degraded"]
    over_budget = [f"{r['title']} ({r['size_kb']}KB)" for r in results if r["size_kb"] > SIZE_BUDGET_KB]

    if broken or degraded or over_budget:
        lines.append("## Action Items")
        lines.append("")
        if broken:
            lines.append(f"**Fix immediately:** {', '.join(broken)}")
        if degraded:
            lines.append(f"**Investigate:** {', '.join(degraded)}")
        if over_budget:
            lines.append(f"**Over {SIZE_BUDGET_KB}KB budget:** {', '.join(over_budget)}")
        lines.append("")

    lines.append("---")
    lines.append("-- Arc, Substrate Arcade")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Arc — Arcade Director (A^ red #cc4444)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "commands:\n"
            "  status   quick inventory with health indicators\n"
            "  audit    deep audit of all games\n"
            "  smoke    run all checks, report failures only\n"
            "  report   full report (saved to memory/arcade/)\n"
        ),
    )
    parser.add_argument("command", nargs="?", default="status",
                        choices=["status", "audit", "smoke", "report"],
                        help="what to do (default: status)")
    parser.add_argument("--date", default=None, help="override date (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print report to stdout instead of saving")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    results = scan_all_games()

    if args.command == "status":
        print_status(results)

    elif args.command == "audit":
        print_audit(results)

    elif args.command == "smoke":
        print_smoke(results)

    elif args.command == "report":
        report = build_report(date_str, results)
        if args.dry_run:
            print(report)
        else:
            os.makedirs(REPORT_DIR, exist_ok=True)
            report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
            with open(report_path, "w") as f:
                f.write(report)
            print(f"[Arc] Report saved: {report_path}")
            # Also print summary
            print_status(results)

    # Exit code: non-zero if anything is broken
    broken = [r for r in results if r["status"] in ("broken", "missing")]
    sys.exit(1 if broken else 0)


if __name__ == "__main__":
    main()
