#!/usr/bin/env python3
"""Forge — Site Engineer agent.

Scans all HTML/MD files for broken internal links, checks _config.yml health,
audits asset sizes, and generates a site health report.

Usage:
    python3 scripts/agents/site_engineer.py
    python3 scripts/agents/site_engineer.py --date 2026-03-08
    python3 scripts/agents/site_engineer.py --dry-run
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_DIR = os.path.join(REPO_DIR, "memory", "site")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "forge-voice.txt")

# Directories to scan for content files
CONTENT_DIRS = [
    "",          # repo root (index.md, etc.)
    "_posts",
    "_layouts",
    "blog",
    "site",
    "arcade",
    "games",
]

# Asset directories to audit
ASSET_DIRS = [
    "assets",
]

# Large file threshold in bytes (1MB)
LARGE_FILE_THRESHOLD = 1024 * 1024


def find_content_files():
    """Find all HTML and Markdown files in the repo."""
    content_files = []
    for subdir in CONTENT_DIRS:
        scan_dir = os.path.join(REPO_DIR, subdir) if subdir else REPO_DIR
        if not os.path.isdir(scan_dir):
            continue
        for root, dirs, files in os.walk(scan_dir):
            # Skip hidden dirs, node_modules, vendor, _site, .git
            dirs[:] = [
                d for d in dirs
                if not d.startswith(".")
                and d not in ("node_modules", "vendor", "_site", "__pycache__")
            ]
            # If scanning repo root, don't recurse into known subdirs
            if not subdir:
                dirs[:] = []
            for f in files:
                if f.endswith((".html", ".md", ".markdown")):
                    content_files.append(os.path.join(root, f))
    return content_files


def extract_internal_links(filepath):
    """Extract internal links from an HTML or Markdown file."""
    links = []
    try:
        with open(filepath, "r", errors="replace") as f:
            content = f.read()
    except Exception:
        return links

    # Match href="..." and src="..." attributes
    href_pattern = re.compile(r'(?:href|src)=["\']([^"\']+)["\']', re.IGNORECASE)
    # Match markdown links [text](url)
    md_pattern = re.compile(r'\[[^\]]*\]\(([^)]+)\)')

    for match in href_pattern.finditer(content):
        url = match.group(1)
        links.append(url)
    for match in md_pattern.finditer(content):
        url = match.group(1)
        links.append(url)

    return links


def is_internal_link(url):
    """Check if a URL is an internal link (not external, not anchor-only, not template)."""
    if not url:
        return False
    # Skip external URLs
    if url.startswith(("http://", "https://", "//", "mailto:", "tel:")):
        return False
    # Skip pure anchors
    if url.startswith("#"):
        return False
    # Skip Liquid/Jekyll template tags
    if "{{" in url or "{%" in url:
        return False
    # Skip data URIs
    if url.startswith("data:"):
        return False
    # Skip javascript
    if url.startswith("javascript:"):
        return False
    # Skip JS variable references parsed as links (e.g., "audioCtx.currentTime, dur")
    if " " in url or "," in url or "." in url.split("/")[0]:
        return False
    return True


def resolve_link(url, source_file):
    """Try to resolve an internal link to a file in the repo."""
    # Strip anchors and query strings
    clean_url = url.split("#")[0].split("?")[0]
    if not clean_url:
        return True  # anchor-only after stripping

    # Handle absolute paths (start with /)
    if clean_url.startswith("/"):
        target = os.path.join(REPO_DIR, clean_url.lstrip("/"))
    else:
        # Relative to the source file's directory
        source_dir = os.path.dirname(source_file)
        target = os.path.join(source_dir, clean_url)

    target = os.path.normpath(target)

    # Check if file exists directly
    if os.path.exists(target):
        return True

    # Jekyll resolves /path/ to /path/index.html or /path/index.md
    if clean_url.endswith("/"):
        for index_name in ("index.html", "index.md"):
            if os.path.exists(os.path.join(target, index_name)):
                return True

    # Try adding common extensions
    for ext in (".html", ".md", "/index.html", "/index.md"):
        if os.path.exists(target + ext):
            return True

    return False


def check_links(content_files):
    """Check all internal links across content files."""
    broken_links = []
    total_links = 0

    for filepath in content_files:
        links = extract_internal_links(filepath)
        for url in links:
            if not is_internal_link(url):
                continue
            total_links += 1
            if not resolve_link(url, filepath):
                rel_path = os.path.relpath(filepath, REPO_DIR)
                broken_links.append((rel_path, url))

    return total_links, broken_links


def check_config():
    """Check _config.yml for basic issues."""
    config_path = os.path.join(REPO_DIR, "_config.yml")
    issues = []

    if not os.path.isfile(config_path):
        issues.append("_config.yml not found")
        return issues

    try:
        with open(config_path, "r") as f:
            content = f.read()

        # Check for required fields
        required_fields = ["title", "url", "baseurl"]
        for field in required_fields:
            if f"{field}:" not in content:
                issues.append(f"missing field: {field}")

        # Check for empty file
        if len(content.strip()) == 0:
            issues.append("_config.yml is empty")

        # Check for tab characters (YAML should use spaces)
        if "\t" in content:
            issues.append("_config.yml contains tabs (use spaces for YAML)")

        # Check file size
        size = len(content)
        if size > 10000:
            issues.append(f"_config.yml is {size} bytes (unusually large)")

    except Exception as e:
        issues.append(f"error reading _config.yml: {e}")

    return issues


def audit_assets():
    """Audit asset directories for large files."""
    large_files = []
    total_assets = 0
    total_size = 0

    for subdir in ASSET_DIRS:
        asset_dir = os.path.join(REPO_DIR, subdir)
        if not os.path.isdir(asset_dir):
            continue
        for root, dirs, files in os.walk(asset_dir):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for f in files:
                fpath = os.path.join(root, f)
                total_assets += 1
                try:
                    size = os.path.getsize(fpath)
                    total_size += size
                    if size > LARGE_FILE_THRESHOLD:
                        rel_path = os.path.relpath(fpath, REPO_DIR)
                        large_files.append((rel_path, size))
                except OSError:
                    pass

    return total_assets, total_size, large_files


def count_site_structure():
    """Count pages, posts, games, and layouts."""
    counts = {
        "pages": 0,
        "posts": 0,
        "games": 0,
        "layouts": 0,
    }

    # Count posts
    posts_dir = os.path.join(REPO_DIR, "_posts")
    if os.path.isdir(posts_dir):
        for f in os.listdir(posts_dir):
            if f.endswith((".md", ".markdown", ".html")):
                counts["posts"] += 1

    # Count games
    games_dir = os.path.join(REPO_DIR, "games")
    if os.path.isdir(games_dir):
        for d in os.listdir(games_dir):
            if os.path.isdir(os.path.join(games_dir, d)) and not d.startswith("."):
                counts["games"] += 1

    # Count layouts
    layouts_dir = os.path.join(REPO_DIR, "_layouts")
    if os.path.isdir(layouts_dir):
        for f in os.listdir(layouts_dir):
            if f.endswith(".html"):
                counts["layouts"] += 1

    # Count top-level pages and site/ pages
    for scan_dir in [REPO_DIR, os.path.join(REPO_DIR, "site")]:
        if not os.path.isdir(scan_dir):
            continue
        for f in os.listdir(scan_dir):
            fpath = os.path.join(scan_dir, f)
            if os.path.isfile(fpath) and f.endswith((".md", ".html")):
                if f not in ("_config.yml",):
                    counts["pages"] += 1

    return counts


def check_layouts():
    """Check that layouts referenced in content files exist."""
    layouts_dir = os.path.join(REPO_DIR, "_layouts")
    available_layouts = set()
    if os.path.isdir(layouts_dir):
        for f in os.listdir(layouts_dir):
            if f.endswith(".html"):
                available_layouts.add(f.replace(".html", ""))

    missing_layouts = []
    layout_pattern = re.compile(r"^layout:\s*(\S+)", re.MULTILINE)

    content_files = find_content_files()
    for filepath in content_files:
        try:
            with open(filepath, "r", errors="replace") as f:
                # Only check front matter (first 50 lines)
                head = ""
                for i, line in enumerate(f):
                    if i > 50:
                        break
                    head += line
        except Exception:
            continue

        match = layout_pattern.search(head)
        if match:
            layout_name = match.group(1).strip().strip('"').strip("'")
            # null/none/nil/empty = valid Jekyll directive meaning "no layout"
            if layout_name.lower() in ("null", "none", "nil", ""):
                continue
            if layout_name not in available_layouts:
                rel_path = os.path.relpath(filepath, REPO_DIR)
                missing_layouts.append((rel_path, layout_name))

    return missing_layouts


def check_images(content_files):
    """Check that local image references in content files resolve to existing files."""
    missing_images = []
    total_refs = 0

    # Patterns for image references
    src_pattern = re.compile(r'src=["\']([^"\']+)["\']', re.IGNORECASE)
    css_url_pattern = re.compile(r'url\(["\']?([^"\')\s]+)["\']?\)', re.IGNORECASE)
    image_exts = (".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico", ".avif", ".bmp")

    for filepath in content_files:
        try:
            with open(filepath, "r", errors="replace") as f:
                content = f.read()
        except Exception:
            continue

        refs = []
        for match in src_pattern.finditer(content):
            refs.append(match.group(1))
        for match in css_url_pattern.finditer(content):
            refs.append(match.group(1))

        for ref in refs:
            # Only check image file references
            ref_lower = ref.lower().split("?")[0].split("#")[0]
            if not any(ref_lower.endswith(ext) for ext in image_exts):
                continue
            # Skip external URLs
            if ref.startswith(("http://", "https://", "//")):
                continue
            # Skip data URIs
            if ref.startswith("data:"):
                continue
            # Skip Liquid/Jekyll template variables
            if "{{" in ref or "{%" in ref:
                continue

            total_refs += 1

            # Resolve the reference to a file on disk
            clean_ref = ref.split("?")[0].split("#")[0]
            if clean_ref.startswith("/"):
                target = os.path.join(REPO_DIR, clean_ref.lstrip("/"))
            else:
                source_dir = os.path.dirname(filepath)
                target = os.path.join(source_dir, clean_ref)

            target = os.path.normpath(target)
            if not os.path.isfile(target):
                rel_source = os.path.relpath(filepath, REPO_DIR)
                missing_images.append((rel_source, ref))

    return total_refs, missing_images


def check_meta_tags(content_files):
    """Check pages for essential meta tags (title, description, og:title).

    Skips standalone HTML pages that use layout:null/none/nil (games, tools).
    """
    missing_meta = []
    no_layout_values = {"null", "none", "nil", ""}
    layout_pattern = re.compile(r"^layout:\s*(\S+)", re.MULTILINE)
    # Skip non-web files that don't need meta tags
    skip_filenames = {"README.md", "CLAUDE.md", "SUPPORTERS.md", "LICENSE", "CHANGELOG.md"}

    for filepath in content_files:
        if os.path.basename(filepath) in skip_filenames:
            continue
        try:
            with open(filepath, "r", errors="replace") as f:
                content = f.read()
        except Exception:
            continue

        # Check front matter for layout: null/none/nil — skip those files
        # Front matter is between leading --- lines
        fm_match = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
        if fm_match:
            fm = fm_match.group(1)
            layout_match = layout_pattern.search(fm)
            if layout_match:
                layout_val = layout_match.group(1).strip().strip('"').strip("'")
                if layout_val.lower() in no_layout_values:
                    continue

        rel_path = os.path.relpath(filepath, REPO_DIR)
        page_issues = []

        # For markdown files, title can come from front matter "title:" field
        has_title = False
        if fm_match:
            fm = fm_match.group(1)
            if re.search(r"^title:", fm, re.MULTILINE):
                has_title = True
        if not has_title and "<title" in content.lower():
            has_title = True
        if not has_title:
            page_issues.append("title")

        # Check for meta description — front matter "description:" or <meta name="description">
        has_desc = False
        if fm_match:
            fm = fm_match.group(1)
            if re.search(r"^description:", fm, re.MULTILINE):
                has_desc = True
        if not has_desc and re.search(r'<meta\s[^>]*name=["\']description["\']', content, re.IGNORECASE):
            has_desc = True
        if not has_desc:
            page_issues.append("description")

        # Check for og:title — front matter "title:" counts if layout injects it,
        # but explicitly check for og:title meta tag
        has_og = False
        if re.search(r'<meta\s[^>]*property=["\']og:title["\']', content, re.IGNORECASE):
            has_og = True
        # Front matter title + layout would inject og:title, so also count front matter title
        if fm_match:
            fm = fm_match.group(1)
            if re.search(r"^title:", fm, re.MULTILINE):
                has_og = True
        if not has_og:
            page_issues.append("og:title")

        if page_issues:
            missing_meta.append((rel_path, page_issues))

    return missing_meta


# ---------------------------------------------------------------------------
# Auto-fix: safe remediation actions
# ---------------------------------------------------------------------------

# Only fix files in these directories
SAFE_FIX_DIRS = ["_posts", "site"]


def _is_safe_to_fix(filepath):
    """Check if a file is in a safe-to-fix directory."""
    rel = os.path.relpath(filepath, REPO_DIR)
    return any(rel.startswith(d + os.sep) or rel.startswith(d + "/") for d in SAFE_FIX_DIRS)


def fix_missing_descriptions(missing_meta):
    """Add missing description fields to frontmatter in safe directories.

    Only modifies _posts/ and site/ markdown files. Generates description
    from the title field if present.

    Returns list of (filepath, action) tuples for files that were fixed.
    """
    fixed = []

    for rel_path, missing_tags in missing_meta:
        if "description" not in missing_tags:
            continue

        filepath = os.path.join(REPO_DIR, rel_path)
        if not _is_safe_to_fix(filepath):
            continue
        if not filepath.endswith((".md", ".markdown")):
            continue

        try:
            with open(filepath, "r") as f:
                content = f.read()
        except (IOError, OSError):
            continue

        # Parse frontmatter
        fm_match = re.match(r"^(---\s*\n)(.*?)(\n---)", content, re.DOTALL)
        if not fm_match:
            continue

        fm_open = fm_match.group(1)
        fm_body = fm_match.group(2)
        fm_close = fm_match.group(3)
        rest = content[fm_match.end():]

        # Skip if description already exists
        if re.search(r"^description:", fm_body, re.MULTILINE):
            continue

        # Generate description from title
        title_match = re.search(r'^title:\s*["\']?(.+?)["\']?\s*$', fm_body, re.MULTILINE)
        if title_match:
            title = title_match.group(1).strip()
            desc = title
        else:
            desc = os.path.splitext(os.path.basename(rel_path))[0].replace("-", " ").title()

        # Insert description after title line (or at end of frontmatter)
        if title_match:
            insert_after = title_match.group(0)
            new_fm_body = fm_body.replace(
                insert_after,
                f'{insert_after}\ndescription: "{desc}"',
                1,
            )
        else:
            new_fm_body = fm_body + f'\ndescription: "{desc}"'

        new_content = fm_open + new_fm_body + fm_close + rest

        with open(filepath, "w") as f:
            f.write(new_content)
        fixed.append((rel_path, f"added description: \"{desc}\""))

    return fixed


def fix_broken_internal_links(broken_links, content_files):
    """Attempt to fix broken internal links by finding the correct path.

    Only fixes links in _posts/ and site/ files. Only rewrites when a unique
    match is found (e.g., /old-path/ → /new-path/ based on filename match).

    Returns list of (filepath, old_url, new_url) tuples for fixed links.
    """
    fixed = []

    # Build a map of filenames → relative paths for resolution
    filename_map = {}
    for fpath in content_files:
        basename = os.path.basename(fpath)
        name_no_ext = os.path.splitext(basename)[0]
        rel = os.path.relpath(fpath, REPO_DIR)
        if name_no_ext not in filename_map:
            filename_map[name_no_ext] = []
        filename_map[name_no_ext].append("/" + rel)

    for source_rel, broken_url in broken_links:
        source_path = os.path.join(REPO_DIR, source_rel)
        if not _is_safe_to_fix(source_path):
            continue

        # Try to match the broken URL's filename to an existing file
        clean_url = broken_url.strip("/").split("#")[0].split("?")[0]
        url_basename = os.path.basename(clean_url)
        url_name = os.path.splitext(url_basename)[0] if url_basename else clean_url.split("/")[-1]

        if not url_name or url_name not in filename_map:
            continue

        candidates = filename_map[url_name]
        if len(candidates) != 1:
            continue  # Ambiguous — skip

        new_url = candidates[0]
        # Don't "fix" if it's the same path
        if new_url.rstrip("/") == broken_url.rstrip("/"):
            continue

        try:
            with open(source_path, "r") as f:
                content = f.read()

            new_content = content.replace(broken_url, new_url)
            if new_content != content:
                with open(source_path, "w") as f:
                    f.write(new_content)
                fixed.append((source_rel, broken_url, new_url))
        except (IOError, OSError):
            continue

    return fixed


def build_report(date_str, total_links, broken_links, config_issues,
                 total_assets, total_asset_size, large_files, counts,
                 missing_layouts, total_image_refs, missing_images,
                 missing_meta):
    """Build the site health report."""
    lines = []
    lines.append(f"# Site Health Report — {date_str}")
    lines.append("")

    # Overall status
    issue_count = (len(broken_links) + len(config_issues) + len(large_files)
                   + len(missing_layouts) + len(missing_images) + len(missing_meta))
    if issue_count == 0:
        lines.append("**Status:** 200 OK — all systems nominal")
    else:
        lines.append(f"**Status:** {issue_count} issue(s) detected")
    lines.append("")

    # Site structure
    lines.append("## Site Structure")
    lines.append("")
    lines.append(f"- **Pages:** {counts['pages']}")
    lines.append(f"- **Posts:** {counts['posts']}")
    lines.append(f"- **Games:** {counts['games']}")
    lines.append(f"- **Layouts:** {counts['layouts']}")
    lines.append(f"- **Total assets:** {total_assets} ({total_asset_size // 1024}KB)")
    lines.append("")

    # Link check
    lines.append("## Link Check")
    lines.append("")
    lines.append(f"- **Internal links scanned:** {total_links}")
    lines.append(f"- **Broken links:** {len(broken_links)}")
    if broken_links:
        lines.append("")
        for source, url in broken_links:
            lines.append(f"  - 404 `{url}` in `{source}`")
    else:
        lines.append("- All links resolve. 200 OK.")
    lines.append("")

    # Config check
    lines.append("## Config Health")
    lines.append("")
    if config_issues:
        for issue in config_issues:
            lines.append(f"- **WARNING:** {issue}")
    else:
        lines.append("- _config.yml: 200 OK")
    lines.append("")

    # Layout check
    lines.append("## Layout Integrity")
    lines.append("")
    if missing_layouts:
        for source, layout in missing_layouts:
            lines.append(f"- **404** layout `{layout}` referenced in `{source}`")
    else:
        lines.append("- All referenced layouts exist. 200 OK.")
    lines.append("")

    # Image references
    lines.append("## Image References")
    lines.append("")
    lines.append(f"- **Local image references scanned:** {total_image_refs}")
    lines.append(f"- **Missing images:** {len(missing_images)}")
    if missing_images:
        lines.append("")
        for source, ref in missing_images:
            lines.append(f"  - 404 `{ref}` in `{source}`")
    else:
        lines.append("- All image references resolve. 200 OK.")
    lines.append("")

    # Meta tags
    lines.append("## Meta Tags")
    lines.append("")
    if missing_meta:
        lines.append(f"- **{len(missing_meta)} page(s) with missing meta tags:**")
        lines.append("")
        for source, tags in missing_meta:
            lines.append(f"  - `{source}` — missing: {', '.join(tags)}")
    else:
        lines.append("- All pages have title, description, and og:title. 200 OK.")
    lines.append("")

    # Asset audit
    lines.append("## Asset Audit")
    lines.append("")
    if large_files:
        lines.append(f"- **{len(large_files)} file(s) over 1MB:**")
        for fpath, size in sorted(large_files, key=lambda x: -x[1]):
            size_mb = size / (1024 * 1024)
            lines.append(f"  - `{fpath}` ({size_mb:.1f}MB)")
    else:
        lines.append("- No oversized assets. All files under 1MB.")
    lines.append("")

    # Summary
    lines.append("---")
    lines.append("-- Forge, Substrate Site Engineering")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Forge — Site Engineer")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print report without saving"
    )
    parser.add_argument(
        "--fix", action="store_true",
        help="Auto-fix safe issues (missing descriptions, broken links in _posts/ and site/)"
    )
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Read blackboard for cross-agent context
    try:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from mycelium import blackboard_read, blackboard_write
        blackboard_context = blackboard_read(agent="Forge", limit=5)
    except ImportError:
        blackboard_read = None
        blackboard_write = None
        blackboard_context = []

    print(f"[Forge] Site health scan for {date_str}")

    # Find content files
    content_files = find_content_files()
    print(f"[Forge] Found {len(content_files)} content files")

    # Check internal links
    print("[Forge] Checking internal links...")
    total_links, broken_links = check_links(content_files)
    if broken_links:
        print(f"[Forge] 404 — {len(broken_links)} broken link(s) found")
    else:
        print(f"[Forge] 200 OK — {total_links} links checked, all resolve")

    # Check _config.yml
    print("[Forge] Checking _config.yml...")
    config_issues = check_config()
    if config_issues:
        for issue in config_issues:
            print(f"[Forge] WARNING: {issue}")
    else:
        print("[Forge] _config.yml: 200 OK")

    # Check layouts
    print("[Forge] Checking layout references...")
    missing_layouts = check_layouts()
    if missing_layouts:
        print(f"[Forge] 404 — {len(missing_layouts)} missing layout(s)")
    else:
        print("[Forge] Layouts: 200 OK")

    # Check image references
    print("[Forge] Checking image references...")
    total_image_refs, missing_images = check_images(content_files)
    if missing_images:
        print(f"[Forge] 404 — {len(missing_images)} missing image(s)")
    else:
        print(f"[Forge] Images: {total_image_refs} references checked, all resolve")

    # Check meta tags
    print("[Forge] Checking meta tags...")
    missing_meta = check_meta_tags(content_files)
    if missing_meta:
        print(f"[Forge] WARNING: {len(missing_meta)} page(s) missing meta tags")
    else:
        print("[Forge] Meta tags: 200 OK")

    # Audit assets
    print("[Forge] Auditing assets...")
    total_assets, total_asset_size, large_files = audit_assets()
    if large_files:
        print(f"[Forge] WARNING: {len(large_files)} file(s) over 1MB")
    else:
        print(f"[Forge] Assets: {total_assets} files, {total_asset_size // 1024}KB total")

    # Count site structure
    counts = count_site_structure()
    print(f"[Forge] Structure: {counts['pages']} pages, {counts['posts']} posts, {counts['games']} games")

    # Auto-fix if requested
    fix_actions = []
    if args.fix:
        print("[Forge] Auto-fix mode: attempting safe remediations...")

        # Fix missing descriptions
        desc_fixes = fix_missing_descriptions(missing_meta)
        for rel_path, action in desc_fixes:
            print(f"[Forge] FIXED {rel_path}: {action}")
            fix_actions.append(f"Fixed `{rel_path}`: {action}")

        # Fix broken links
        link_fixes = fix_broken_internal_links(broken_links, content_files)
        for rel_path, old_url, new_url in link_fixes:
            print(f"[Forge] FIXED {rel_path}: {old_url} → {new_url}")
            fix_actions.append(f"Fixed `{rel_path}`: `{old_url}` → `{new_url}`")

        if fix_actions:
            # Re-run checks after fixes to get updated counts
            total_links, broken_links = check_links(content_files)
            missing_meta = check_meta_tags(content_files)

            # Commit fixes
            try:
                subprocess.run(
                    ["git", "add", "_posts/", "site/"],
                    cwd=REPO_DIR, capture_output=True, timeout=10,
                )
                status = subprocess.run(
                    ["git", "diff", "--cached", "--quiet"],
                    cwd=REPO_DIR, timeout=10,
                )
                if status.returncode != 0:
                    msg = f"site: auto-fix {len(fix_actions)} issue(s)"
                    subprocess.run(
                        ["git", "commit", "-m", msg],
                        cwd=REPO_DIR, capture_output=True, timeout=10,
                    )
                    print(f"[Forge] Committed: {msg}")
            except Exception as e:
                print(f"[Forge] Commit failed: {e}", file=sys.stderr)
        else:
            print("[Forge] No auto-fixable issues found")

    # Build report
    report = build_report(
        date_str, total_links, broken_links, config_issues,
        total_assets, total_asset_size, large_files, counts,
        missing_layouts, total_image_refs, missing_images,
        missing_meta,
    )

    # Append fix actions to report
    if fix_actions:
        report += "\n## Auto-Fix Actions\n\n"
        for action in fix_actions:
            report += f"- {action}\n"
        report += "\n"

    if args.dry_run:
        print()
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Forge] Report saved: {report_path}")

    # Summary
    issue_count = (len(broken_links) + len(config_issues) + len(large_files)
                   + len(missing_layouts) + len(missing_images) + len(missing_meta))
    if issue_count == 0:
        print("[Forge] 200 OK — site is healthy")
        overall = "HEALTHY"
    else:
        print(f"[Forge] {issue_count} issue(s) need attention")
        overall = "ATTENTION NEEDED" if issue_count > 5 else "MINOR ISSUES"
    print("-- Forge, Substrate Site Engineering")

    # Write fix actions to blackboard so downstream agents know
    if fix_actions and blackboard_write:
        try:
            blackboard_write("Forge", "action", {
                "action": f"auto-fixed {len(fix_actions)} issue(s)",
                "success": True,
                "fixes": fix_actions[:10],
            }, ttl_hours=2)
        except Exception:
            pass

    # Structured JSON output for executive consumption (last line of stdout)
    findings = []
    for source, url in broken_links:
        findings.append({"type": "broken_link", "severity": "medium",
                         "title": f"404 {url} in {source}"})
    for source, tags in missing_meta:
        findings.append({"type": "missing_meta", "severity": "low",
                         "title": f"{source} missing: {', '.join(tags)}"})
    for source, ref in missing_images:
        findings.append({"type": "missing_image", "severity": "medium",
                         "title": f"404 image {ref} in {source}"})
    for issue in config_issues:
        findings.append({"type": "config_issue", "severity": "medium",
                         "title": issue})
    structured = {
        "agent": "Forge",
        "status": overall,
        "findings": findings,
        "actions_taken": [{"action": a, "success": True} for a in fix_actions],
    }
    print(json.dumps(structured))


if __name__ == "__main__":
    main()
