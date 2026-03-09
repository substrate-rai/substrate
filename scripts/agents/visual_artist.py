#!/usr/bin/env python3
"""Pixel -- visual artist agent for Substrate.

Generates image prompts and manages Stable Diffusion image generation
for blog posts, site pages, and social media.

Usage:
    python3 scripts/agents/visual_artist.py              # generate images
    python3 scripts/agents/visual_artist.py --dry-run    # output prompts only, no generation
    python3 scripts/agents/visual_artist.py --date 2026-03-07

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import glob
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
BLOG_POSTS_DIR = os.path.join(REPO_DIR, "blog", "posts")
ALT_POSTS_DIR = os.path.join(REPO_DIR, "_posts")
SITE_DIR = os.path.join(REPO_DIR, "site")
ASSETS_DIR = os.path.join(REPO_DIR, "assets", "images", "generated")
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
VISUALS_DIR = os.path.join(MEMORY_DIR, "visuals")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "pixel-voice.txt")
GPU_SWITCH = os.path.join(REPO_DIR, "scripts", "ml", "gpu-switch.sh")
GENERATE_IMAGE = os.path.join(REPO_DIR, "scripts", "ml", "generate-image.py")

# ---------------------------------------------------------------------------
# Aesthetic configuration
# ---------------------------------------------------------------------------

# Core aesthetic: dark, bioluminescent, mycelium-inspired
STYLE_SUFFIX = (
    "dark background, bioluminescent glow, mycelium network aesthetic, "
    "deep blacks with cyan and magenta accents, organic circuitry, "
    "subtle spore particles, high contrast, digital art"
)

# Map content themes to prompt modifiers
THEME_MODIFIERS = {
    "ai": "neural pathways rendered as glowing fungal threads",
    "infrastructure": "server racks overgrown with luminous mycelium",
    "nixos": "snowflake fractals merging with fungal networks",
    "gpu": "silicon die cross-section with bioluminescent veins",
    "blog": "scroll of light unfurling from a mycelium core",
    "funding": "golden spores rising from a substrate base",
    "game": "pixel terrain with glowing mushroom biomes",
    "music": "sound waves visualized as mycelium wave patterns",
    "health": "pulse monitor made of connected fungal nodes",
    "release": "new growth emerging from established mycelium mat",
    "community": "interconnected spore network, many nodes glowing",
    "code": "lines of luminous code growing like hyphae",
}

# Image dimensions for different targets
DIMENSIONS = {
    "blog_hero": (1024, 512),
    "social_square": (512, 512),
    "site_banner": (1024, 256),
    "thumbnail": (256, 256),
}

# ---------------------------------------------------------------------------
# Content scanning
# ---------------------------------------------------------------------------

def read_file(path):
    """Read a file and return its contents, or None on failure."""
    try:
        with open(path, "r") as f:
            return f.read()
    except (IOError, OSError) as e:
        print(f"[pixel] could not read {path}: {e}", file=sys.stderr)
        return None


def find_blog_posts(days_back=7):
    """Find recent blog posts that may need visuals."""
    posts = []

    for posts_dir in [BLOG_POSTS_DIR, ALT_POSTS_DIR]:
        if not os.path.isdir(posts_dir):
            continue
        for fname in sorted(os.listdir(posts_dir)):
            if not fname.endswith(".md") or fname.startswith("."):
                continue
            match = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)\.md", fname)
            if match:
                post_date = match.group(1)
                slug = match.group(2)
                filepath = os.path.join(posts_dir, fname)
                content = read_file(filepath) or ""
                has_image = bool(re.search(r'!\[.*?\]\(.*?\)', content)) or "image:" in content.lower()
                posts.append({
                    "date": post_date,
                    "slug": slug,
                    "file": filepath,
                    "content": content,
                    "has_image": has_image,
                })

    return posts


def find_site_pages():
    """Find site pages that may need visuals."""
    pages = []
    if not os.path.isdir(SITE_DIR):
        return pages

    for fname in sorted(os.listdir(SITE_DIR)):
        if not fname.endswith(".md") or fname.startswith("."):
            continue
        filepath = os.path.join(SITE_DIR, fname)
        content = read_file(filepath) or ""
        has_image = bool(re.search(r'!\[.*?\]\(.*?\)', content)) or "image:" in content.lower()
        pages.append({
            "name": fname.replace(".md", ""),
            "file": filepath,
            "content": content,
            "has_image": has_image,
        })

    return pages


def detect_theme(text):
    """Detect the dominant theme from content text."""
    text_lower = text.lower()
    scores = {}
    theme_keywords = {
        "ai": ["ai", "llm", "model", "inference", "neural", "claude", "ollama", "qwen"],
        "infrastructure": ["server", "service", "timer", "systemd", "deploy", "pipeline"],
        "nixos": ["nixos", "nix", "flake", "declarative", "nixpkgs"],
        "gpu": ["gpu", "cuda", "vram", "rtx", "nvidia", "compute"],
        "funding": ["fund", "donat", "sponsor", "revenue", "ledger", "$", "stripe"],
        "game": ["game", "arcade", "play", "score", "pixel", "canvas"],
        "music": ["music", "audio", "sound", "beat", "synth"],
        "health": ["health", "monitor", "status", "uptime", "check"],
        "release": ["release", "version", "update", "changelog", "new model"],
        "community": ["community", "supporter", "audience", "follower", "social"],
        "code": ["script", "code", "function", "commit", "git", "python", "bash"],
    }

    for theme, keywords in theme_keywords.items():
        scores[theme] = sum(1 for kw in keywords if kw in text_lower)

    if not scores:
        return "blog"

    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "blog"


# ---------------------------------------------------------------------------
# Prompt generation
# ---------------------------------------------------------------------------

def generate_prompt(title, theme, target="blog_hero"):
    """Generate a Stable Diffusion prompt for the given content."""
    modifier = THEME_MODIFIERS.get(theme, THEME_MODIFIERS["blog"])

    # Clean the title for prompt use
    clean_title = re.sub(r'[^a-zA-Z0-9\s]', '', title).strip()

    prompt = f"{clean_title}, {modifier}, {STYLE_SUFFIX}"
    negative = (
        "text, watermark, signature, blurry, low quality, "
        "bright background, white background, cartoon, anime, "
        "oversaturated, lens flare"
    )

    width, height = DIMENSIONS.get(target, DIMENSIONS["blog_hero"])

    return {
        "prompt": prompt,
        "negative_prompt": negative,
        "width": width,
        "height": height,
        "steps": 30,
        "cfg_scale": 7.5,
    }


def build_image_plan(posts, pages):
    """Build a list of images to generate."""
    plan = []

    # Blog posts without images get hero images
    for post in posts:
        if not post["has_image"]:
            theme = detect_theme(post["content"])
            title = post["slug"].replace("-", " ").title()
            prompt_data = generate_prompt(title, theme, "blog_hero")
            output_name = f"{post['date']}-{post['slug']}-hero.png"
            plan.append({
                "source": post["file"],
                "source_type": "blog",
                "title": title,
                "theme": theme,
                "target": "blog_hero",
                "output_name": output_name,
                "output_path": os.path.join(ASSETS_DIR, output_name),
                "prompt_data": prompt_data,
            })

    # Site pages without images get banners
    for page in pages:
        if not page["has_image"]:
            theme = detect_theme(page["content"])
            title = page["name"].replace("-", " ").title()
            prompt_data = generate_prompt(title, theme, "site_banner")
            output_name = f"site-{page['name']}-banner.png"
            plan.append({
                "source": page["file"],
                "source_type": "site",
                "title": title,
                "theme": theme,
                "target": "site_banner",
                "output_name": output_name,
                "output_path": os.path.join(ASSETS_DIR, output_name),
                "prompt_data": prompt_data,
            })

    return plan


# ---------------------------------------------------------------------------
# Image generation
# ---------------------------------------------------------------------------

def switch_gpu(mode="sd"):
    """Call gpu-switch.sh to allocate VRAM for Stable Diffusion."""
    if not os.path.isfile(GPU_SWITCH):
        print("[pixel] gpu-switch.sh not found, skipping VRAM management", file=sys.stderr)
        return True

    try:
        result = subprocess.run(
            ["bash", GPU_SWITCH, mode],
            capture_output=True, text=True, timeout=30, cwd=REPO_DIR,
        )
        if result.returncode != 0:
            print(f"[pixel] gpu-switch.sh failed: {result.stderr.strip()}", file=sys.stderr)
            return False
        print(f"[pixel] GPU switched to {mode} mode", file=sys.stderr)
        return True
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"[pixel] gpu-switch.sh error: {e}", file=sys.stderr)
        return False


def generate_image(prompt_data, output_path):
    """Call generate-image.py to produce an image."""
    if not os.path.isfile(GENERATE_IMAGE):
        print(f"[pixel] generate-image.py not found, cannot generate", file=sys.stderr)
        return False

    cmd = [
        sys.executable, GENERATE_IMAGE,
        "--prompt", prompt_data["prompt"],
        "--negative-prompt", prompt_data["negative_prompt"],
        "--width", str(prompt_data["width"]),
        "--height", str(prompt_data["height"]),
        "--steps", str(prompt_data["steps"]),
        "--cfg-scale", str(prompt_data["cfg_scale"]),
        "--output", output_path,
    ]

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=300, cwd=REPO_DIR,
        )
        if result.returncode != 0:
            print(f"[pixel] generation failed: {result.stderr.strip()[:200]}", file=sys.stderr)
            return False
        return True
    except subprocess.TimeoutExpired:
        print(f"[pixel] generation timed out for {output_path}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"[pixel] generation error: {e}", file=sys.stderr)
        return False


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def build_report(plan, results, date_str, dry_run=False):
    """Build the visual artist report."""
    lines = []
    lines.append(f"# Pixel -- Visual Report: {date_str}")
    lines.append("")
    lines.append(f"**Generated:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
    mode = "DRY RUN (prompts only)" if dry_run else "LIVE (images generated)"
    lines.append(f"**Mode:** {mode}")
    lines.append("")

    # Summary
    total = len(plan)
    if dry_run:
        lines.append(f"Scanned content. Found {total} items needing visuals.")
    else:
        succeeded = sum(1 for r in results if r["success"])
        failed = total - succeeded
        lines.append(f"Generated {succeeded}/{total} images. {failed} failed.")
    lines.append("")

    # Details per image
    lines.append("## Image Plan")
    lines.append("")

    for i, item in enumerate(plan, 1):
        lines.append(f"### {i}. {item['title']}")
        lines.append("")
        lines.append(f"- **Source:** {os.path.basename(item['source'])} ({item['source_type']})")
        lines.append(f"- **Theme:** {item['theme']}")
        lines.append(f"- **Target:** {item['target']} ({item['prompt_data']['width']}x{item['prompt_data']['height']})")
        lines.append(f"- **Output:** {item['output_name']}")
        lines.append("")
        lines.append("**Prompt:**")
        lines.append(f"> {item['prompt_data']['prompt']}")
        lines.append("")
        lines.append("**Negative:**")
        lines.append(f"> {item['prompt_data']['negative_prompt']}")
        lines.append("")

        if not dry_run and i <= len(results):
            r = results[i - 1]
            status = "GENERATED" if r["success"] else "FAILED"
            lines.append(f"**Status:** {status}")
            if r["success"]:
                lines.append(f"**Path:** {r['path']}")
            lines.append("")

    lines.append("---")
    lines.append("-- Pixel, Substrate Visual Studio")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Pixel -- visual artist agent for Substrate")
    parser.add_argument("--dry-run", action="store_true",
                        help="Output prompts only, do not generate images")
    parser.add_argument("--date", default=None,
                        help="Date for the report (YYYY-MM-DD, default: today)")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[pixel] scanning content for visual needs...", file=sys.stderr)

    # Scan content
    posts = find_blog_posts()
    pages = find_site_pages()

    print(f"[pixel] found {len(posts)} blog posts, {len(pages)} site pages", file=sys.stderr)

    # Build generation plan
    plan = build_image_plan(posts, pages)

    if not plan:
        print("No content needs visuals. Everything has images already.")
        print()
        print("-- Pixel, Substrate Visual Studio")
        return

    print(f"[pixel] {len(plan)} images planned", file=sys.stderr)

    results = []

    if args.dry_run:
        # Dry run: just output the prompts
        print(f"Pixel here. {len(plan)} images needed. Prompts ready.")
        print()
        for i, item in enumerate(plan, 1):
            print(f"  {i}. [{item['target']}] {item['title']}")
            print(f"     theme: {item['theme']}")
            print(f"     prompt: {item['prompt_data']['prompt'][:80]}...")
        print()
        print("Run without --dry-run to generate.")
    else:
        # Live mode: switch GPU and generate
        print(f"[pixel] switching GPU to SD mode...", file=sys.stderr)
        gpu_ok = switch_gpu("sd")
        if not gpu_ok:
            print("[pixel] GPU switch failed, attempting generation anyway", file=sys.stderr)

        os.makedirs(ASSETS_DIR, exist_ok=True)

        for i, item in enumerate(plan, 1):
            print(f"[pixel] generating {i}/{len(plan)}: {item['title']}", file=sys.stderr)
            success = generate_image(item["prompt_data"], item["output_path"])
            results.append({"success": success, "path": item["output_path"]})

        # Switch GPU back to inference mode
        switch_gpu("inference")

        succeeded = sum(1 for r in results if r["success"])
        print(f"Pixel here. Generated {succeeded}/{len(plan)} images.")
        print()
        for i, item in enumerate(plan, 1):
            status = "done" if results[i - 1]["success"] else "FAILED"
            print(f"  {i}. [{status}] {item['title']} -> {item['output_name']}")

    # Save report
    report = build_report(plan, results, date_str, dry_run=args.dry_run)

    os.makedirs(VISUALS_DIR, exist_ok=True)
    report_path = os.path.join(VISUALS_DIR, f"{date_str}.md")
    with open(report_path, "w") as f:
        f.write(report)

    print()
    print(f"Report: {report_path}")
    print()
    print("-- Pixel, Substrate Visual Studio")


if __name__ == "__main__":
    main()
