#!/usr/bin/env python3
"""Neon — UI/UX Designer agent.

Audits all pages and games for mobile responsiveness, visual consistency,
accessibility compliance, and design system adherence. Generates design
audit reports with specific fixes.

Usage:
    python3 scripts/agents/ui_designer.py
    python3 scripts/agents/ui_designer.py --date 2026-03-08
    python3 scripts/agents/ui_designer.py --dry-run
"""

import argparse
import os
import re
import sys
from datetime import datetime, timezone

from shared import queue_post

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_DIR = os.path.join(REPO_DIR, "memory", "design")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "neon-voice.txt")

# Design system tokens
DESIGN_TOKENS = {
    "min_touch_target": 44,  # px
    "min_font_mobile": 14,  # px
    "min_font_desktop": 12,  # px
    "spacing_scale": [4, 8, 12, 16, 24, 32, 48, 64],
    "mobile_breakpoint": 768,
    "small_breakpoint": 480,
    "contrast_ratio_min": 4.5,
}

# Files to audit
CONTENT_PATTERNS = [
    ("games", "*.html"),
    ("site", "*.html"),
    ("site", "*.md"),
    ("arcade", "*.md"),
    ("_layouts", "*.html"),
]


def find_ui_files():
    """Find all HTML/MD files that contain UI elements."""
    files = []
    for subdir in ["games", "site", "arcade", "_layouts"]:
        scan_dir = os.path.join(REPO_DIR, subdir)
        if not os.path.isdir(scan_dir):
            continue
        for root, dirs, filenames in os.walk(scan_dir):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for f in filenames:
                if f.endswith((".html", ".md")):
                    files.append(os.path.join(root, f))
    # Add root-level files
    for f in os.listdir(REPO_DIR):
        if f.endswith((".html", ".md")) and os.path.isfile(os.path.join(REPO_DIR, f)):
            files.append(os.path.join(REPO_DIR, f))
    return files


def check_viewport_meta(filepath, content):
    """Check viewport meta tag for mobile support."""
    issues = []
    if "<meta" in content and "viewport" in content:
        if "user-scalable=no" in content or "user-scalable=0" in content:
            issues.append("Blocks pinch-to-zoom (user-scalable=no)")
        if "maximum-scale=1" in content:
            issues.append("Restricts zoom (maximum-scale=1)")
    elif filepath.endswith(".html") and "layout: null" in content[:200]:
        # Standalone HTML page should have viewport meta
        if "viewport" not in content:
            issues.append("Missing viewport meta tag")
    return issues


def check_mobile_responsive(filepath, content):
    """Check for mobile responsiveness patterns."""
    issues = []
    rel_path = os.path.relpath(filepath, REPO_DIR)

    # Check for media queries
    has_style = "<style" in content
    has_media_768 = "@media" in content and ("768" in content or "max-width" in content)

    if has_style and not has_media_768:
        # Page has custom styles but no mobile breakpoint
        if "position: fixed" in content or "position:fixed" in content:
            issues.append("Fixed-position elements with no mobile media query")

    # Check for hardcoded pixel widths on containers
    width_pattern = re.compile(r'width:\s*(\d+)px', re.IGNORECASE)
    for match in width_pattern.finditer(content):
        px = int(match.group(1))
        if px > 400:
            issues.append(f"Hardcoded width: {px}px (may overflow on mobile)")
            break  # One warning is enough

    # Check for overflow: hidden on body (common in games)
    if "overflow: hidden" in content or "overflow:hidden" in content:
        if "position: fixed" in content:
            # Game-style layout, check for touch controls
            if "hover: none" not in content and "pointer: coarse" not in content:
                issues.append("Fixed fullscreen layout with no touch/mobile detection")

    return issues


def check_touch_targets(filepath, content):
    """Check for touch target size compliance."""
    issues = []

    # Look for buttons/links with small padding
    small_padding = re.compile(r'padding:\s*(\d+)px\s+(\d+)px', re.IGNORECASE)
    for match in small_padding.finditer(content):
        v_pad = int(match.group(1))
        h_pad = int(match.group(2))
        if v_pad < 8 and h_pad < 12:
            issues.append(f"Small touch target: padding {v_pad}px {h_pad}px (min 44px total height)")
            break

    # Check for min-height on interactive elements
    if "min-height: 44px" not in content and "min-height:44px" not in content:
        # Only flag if there are interactive elements
        if "<button" in content or 'role="button"' in content:
            if 'min-height' not in content:
                issues.append("No min-height on interactive elements (44px recommended)")

    return issues


def check_font_sizes(filepath, content):
    """Check for font sizes below minimum."""
    issues = []
    small_font = re.compile(r'font-size:\s*(0\.\d+)rem', re.IGNORECASE)
    for match in small_font.finditer(content):
        rem = float(match.group(1))
        if rem < 0.7:  # Less than ~11px at 16px base
            issues.append(f"Font size {rem}rem ({int(rem * 16)}px) — below 12px minimum")
            break
    return issues


def check_color_contrast(filepath, content):
    """Basic check for potentially low-contrast color combinations."""
    issues = []
    # Common dark-on-dark patterns
    dim_colors = re.compile(r'color:\s*#([234][0-9a-f]{5})', re.IGNORECASE)
    dim_count = len(dim_colors.findall(content))
    if dim_count > 5:
        issues.append(f"{dim_count} potentially low-contrast color values (verify manually)")
    return issues


def check_accessibility(filepath, content):
    """Check for basic accessibility patterns."""
    issues = []

    # Check for alt text on images
    img_pattern = re.compile(r'<img\s[^>]*>', re.IGNORECASE)
    for match in img_pattern.finditer(content):
        tag = match.group(0)
        if 'alt=' not in tag and 'role="presentation"' not in tag and 'aria-hidden' not in tag:
            issues.append("Image without alt text or aria-hidden")
            break

    # Check for skip link
    if filepath.endswith(".html") and "layout: null" in content[:200]:
        if "skip" not in content.lower() and "Skip" not in content:
            if "<main" in content or 'role="main"' in content:
                issues.append("No skip-to-content link")

    # Check for focus styles
    if "<style" in content:
        if "focus-visible" not in content and "focus" not in content:
            if "<button" in content or "<input" in content:
                issues.append("No custom focus styles for interactive elements")

    return issues


def audit_file(filepath):
    """Run all checks on a single file."""
    try:
        with open(filepath, "r", errors="replace") as f:
            content = f.read()
    except Exception:
        return []

    all_issues = []
    all_issues.extend(("viewport", i) for i in check_viewport_meta(filepath, content))
    all_issues.extend(("responsive", i) for i in check_mobile_responsive(filepath, content))
    all_issues.extend(("touch", i) for i in check_touch_targets(filepath, content))
    all_issues.extend(("font", i) for i in check_font_sizes(filepath, content))
    all_issues.extend(("contrast", i) for i in check_color_contrast(filepath, content))
    all_issues.extend(("a11y", i) for i in check_accessibility(filepath, content))

    return all_issues


def auto_fix_issues(results):
    """Auto-fix the safest issues. Returns (fixed_count, fixed_details, updated_results).

    Only fixes missing viewport meta tags — the safest possible change.
    Other issues are left as TODOs in the report.
    """
    VIEWPORT_TAG = '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
    fixed_count = 0
    fixed_files = []
    updated_results = {}

    for filepath, issues in results.items():
        remaining_issues = []

        for cat, desc in issues:
            if cat == "viewport" and desc == "Missing viewport meta tag":
                # Auto-fix: inject viewport meta tag after <head> or after charset meta
                try:
                    with open(filepath, "r", errors="replace") as f:
                        content = f.read()

                    # Find best insertion point: after <head> tag
                    head_match = re.search(r'(<head[^>]*>)', content, re.IGNORECASE)
                    if head_match:
                        insert_pos = head_match.end()
                        content = content[:insert_pos] + "\n" + VIEWPORT_TAG + content[insert_pos:]
                        with open(filepath, "w") as f:
                            f.write(content)
                        fixed_count += 1
                        rel = os.path.relpath(filepath, REPO_DIR)
                        fixed_files.append(rel)
                        print(f"[Neon] Fixed: added viewport meta to {rel}")
                    else:
                        # No <head> tag found — can't safely fix, keep as issue
                        remaining_issues.append((cat, desc))
                except Exception as e:
                    print(f"[Neon] Could not auto-fix {filepath}: {e}")
                    remaining_issues.append((cat, desc))
            else:
                remaining_issues.append((cat, desc))

        if remaining_issues:
            updated_results[filepath] = remaining_issues
        # If all issues were fixed, the file drops out of results

    return fixed_count, fixed_files, updated_results


def build_report(date_str, results, fixed_count=0, fixed_files=None):
    """Build the design audit report."""
    if fixed_files is None:
        fixed_files = []

    lines = []
    lines.append(f"# Design Audit — {date_str}")
    lines.append("")

    total_issues = sum(len(issues) for issues in results.values())
    total_files = len(results)
    clean_files = sum(1 for issues in results.values() if not issues)

    lines.append(f"**Files audited:** {total_files}")
    lines.append(f"**Clean files:** {clean_files}")
    lines.append(f"**Issues auto-fixed:** {fixed_count}")
    lines.append(f"**Remaining issues:** {total_issues}")
    lines.append("")

    # Report what was fixed
    if fixed_count > 0:
        lines.append(f"## Auto-Fixed ({fixed_count})")
        lines.append("")
        for rel in fixed_files:
            lines.append(f"- `{rel}` — added viewport meta tag")
        lines.append("")

    if total_issues == 0:
        lines.append("All clear. Every page passes. -- Neon")
        return "\n".join(lines)

    # Group by category
    categories = {}
    for filepath, issues in results.items():
        for cat, desc in issues:
            if cat not in categories:
                categories[cat] = []
            rel_path = os.path.relpath(filepath, REPO_DIR)
            categories[cat].append((rel_path, desc))

    category_names = {
        "viewport": "Viewport & Zoom",
        "responsive": "Mobile Responsiveness",
        "touch": "Touch Targets",
        "font": "Typography",
        "contrast": "Color Contrast",
        "a11y": "Accessibility",
    }

    for cat, items in sorted(categories.items()):
        name = category_names.get(cat, cat.title())
        lines.append(f"## {name} ({len(items)} issue{'s' if len(items) != 1 else ''})")
        lines.append("")
        for filepath, desc in items:
            lines.append(f"- `{filepath}` — {desc}")
        lines.append("")

    # Write TODOs for issues that need manual attention
    lines.append("## TODO (requires manual fix)")
    lines.append("")
    for cat, items in sorted(categories.items()):
        for filepath, desc in items:
            lines.append(f"- [ ] `{filepath}` — {desc}")
    lines.append("")

    lines.append("---")
    lines.append("-- Neon, Substrate Design")
    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Neon — UI/UX Designer")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true", help="Print report without saving")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[Neon] Design audit for {date_str}")

    files = find_ui_files()
    print(f"[Neon] Found {len(files)} UI files to audit")

    results = {}
    for filepath in files:
        issues = audit_file(filepath)
        if issues:
            results[filepath] = issues

    print(f"[Neon] {len(results)} file(s) with issues")

    # Auto-fix the safest issues (viewport meta tags only)
    fixed_count, fixed_files, results = auto_fix_issues(results)
    if fixed_count:
        print(f"[Neon] Auto-fixed {fixed_count} issue(s)")

    report = build_report(date_str, results, fixed_count, fixed_files)

    if args.dry_run:
        print()
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Neon] Report saved: {report_path}")

    # Queue a Bluesky post if fixes were actually made
    if fixed_count > 0 and not args.dry_run:
        detail = f"Added viewport meta tags to {', '.join(fixed_files)}" if len(fixed_files) <= 3 else f"Added viewport meta tags to {len(fixed_files)} pages"
        fix_post = (
            f"Neon fixed {fixed_count} accessibility issue{'s' if fixed_count != 1 else ''} "
            f"across the site today. {detail}. "
            f"Every page should work on a phone. substrate.lol"
        )
        queue_post(fix_post, source="neon")
        print(f"[Neon] Queued Bluesky post about fixes")

    issue_count = sum(len(v) for v in results.values())
    if issue_count == 0:
        print("[Neon] All clear. Design is clean.")
    else:
        print(f"[Neon] {issue_count} design issue(s) still need attention")
    print("-- Neon, Substrate Design")


if __name__ == "__main__":
    main()
