#!/usr/bin/env python3
"""Generate header images for blog posts using Stable Diffusion.

Scans _posts/ for posts without a header_image in front matter, generates
a dark-themed tech/cyber image from the post title, saves it, and updates
the front matter.

Usage:
    nix develop .#ml --command python3 scripts/ml/blog-images.py --dry-run
    nix develop .#ml --command python3 scripts/ml/blog-images.py --post 2026-03-06-day-0-substrate-is-alive.md
    nix develop .#ml --command python3 scripts/ml/blog-images.py
"""

import argparse
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "shared"))
from ollama import unload_models

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
POSTS_DIR = REPO_ROOT / "_posts"
IMAGES_DIR = REPO_ROOT / "assets" / "images" / "blog"
SITE_IMAGE_PREFIX = "/assets/images/blog"


def parse_front_matter(text):
    """Parse YAML front matter from a markdown file.

    Returns (front_matter_str, body_str, front_matter_dict).
    front_matter_dict is a simple key-value parse (not full YAML).
    """
    match = re.match(r"^---\n(.*?)\n---\n?(.*)", text, re.DOTALL)
    if not match:
        return None, text, {}
    fm_str = match.group(1)
    body = match.group(2)
    # Simple key-value extraction (handles quoted values)
    fm_dict = {}
    for line in fm_str.splitlines():
        kv = re.match(r'^(\w[\w_]*):\s*(.*)', line)
        if kv:
            key = kv.group(1)
            val = kv.group(2).strip().strip('"').strip("'")
            fm_dict[key] = val
    return fm_str, body, fm_dict


def slug_from_filename(filename):
    """Extract slug from a Jekyll post filename like 2026-03-06-day-0-substrate-is-alive.md."""
    name = Path(filename).stem
    # Strip leading date (YYYY-MM-DD-)
    match = re.match(r'^\d{4}-\d{2}-\d{2}-(.*)', name)
    return match.group(1) if match else name


def build_prompt(title, body_text):
    """Generate a Stable Diffusion prompt from the post title and content.

    Uses a template-based approach: dark theme, tech/cyber aesthetic, no text.
    """
    # Extract key terms from the title (strip quotes, punctuation, filler words)
    clean_title = re.sub(r'["\':—\-\(\)\[\],\.]', ' ', title)
    clean_title = re.sub(r'\s+', ' ', clean_title).strip()

    # Remove common filler/stop words to get thematic keywords
    stop_words = {
        'a', 'an', 'the', 'is', 'are', 'was', 'were', 'how', 'to', 'on',
        'in', 'of', 'for', 'and', 'or', 'its', 'it', 'we', 'our', 'i',
        'my', 'you', 'your', 'this', 'that', 'with', 'from', 'by', 'what',
        'when', 'where', 'why', 'do', 'does', 'did', 'has', 'have', 'had',
        'not', 'no', 'but', 'if', 'then', 'so', 'too', 'also', 'just',
        'than', 'very', 'can', 'will', 'about', 'up', 'out', 'all',
        'day', 'complete', 'guide', 'episode',
    }
    # Strip remaining punctuation from individual words
    keywords = []
    for w in clean_title.lower().split():
        w = re.sub(r'[^a-z0-9]', '', w)
        if w and w not in stop_words and len(w) > 2:
            keywords.append(w)
    keyword_str = ", ".join(keywords[:6])

    # Template: dark tech/cyber aesthetic, no text in image
    prompt = (
        f"dark futuristic technology illustration, {keyword_str}, "
        "neon glow, circuit board patterns, cyberpunk aesthetic, "
        "abstract digital art, deep dark background, moody lighting, "
        "no text, no letters, no words, no watermark"
    )
    return prompt


def find_posts_needing_images(single_post=None):
    """Find blog posts that don't have a header_image in front matter.

    Returns list of (filename, title, slug, body_text).
    """
    results = []

    if single_post:
        files = [POSTS_DIR / single_post]
    else:
        files = sorted(POSTS_DIR.glob("*.md"))

    for filepath in files:
        if not filepath.exists():
            print(f"warning: {filepath} does not exist, skipping", file=sys.stderr)
            continue

        text = filepath.read_text(encoding="utf-8")
        fm_str, body, fm_dict = parse_front_matter(text)

        if fm_str is None:
            print(f"warning: {filepath.name} has no front matter, skipping", file=sys.stderr)
            continue

        if "header_image" in fm_dict and fm_dict["header_image"]:
            continue

        title = fm_dict.get("title", filepath.stem)
        slug = slug_from_filename(filepath.name)
        results.append((filepath.name, title, slug, body))

    return results


def update_front_matter(filename, image_path):
    """Add header_image to a post's front matter."""
    filepath = POSTS_DIR / filename
    text = filepath.read_text(encoding="utf-8")

    # Insert header_image before the closing ---
    # Find the second --- which closes front matter
    lines = text.split("\n")
    new_lines = []
    fm_open = False
    inserted = False
    for line in lines:
        if line.strip() == "---" and not fm_open:
            fm_open = True
            new_lines.append(line)
        elif line.strip() == "---" and fm_open and not inserted:
            new_lines.append(f"header_image: \"{image_path}\"")
            new_lines.append(line)
            inserted = True
        else:
            new_lines.append(line)

    filepath.write_text("\n".join(new_lines), encoding="utf-8")
    print(f"  updated front matter: {filename}")


def generate_image(prompt, output_path, seed=None):
    """Generate an image using diffusers (SDXL Turbo)."""
    import torch
    from diffusers import StableDiffusionXLPipeline

    if not torch.cuda.is_available():
        print("error: CUDA not available", file=sys.stderr)
        sys.exit(1)

    print(f"  gpu: {torch.cuda.get_device_name(0)}")
    print(f"  vram free: {torch.cuda.mem_get_info()[0] / 1024**3:.1f} GB")

    model_id = "stabilityai/sdxl-turbo"
    pipe = StableDiffusionXLPipeline.from_pretrained(
        model_id, torch_dtype=torch.float16, variant="fp16"
    )
    pipe = pipe.to("cuda")
    pipe.enable_attention_slicing()

    generator = torch.Generator("cuda").manual_seed(seed) if seed else None

    result = pipe(
        prompt=prompt,
        num_inference_steps=4,
        guidance_scale=0.0,
        width=512,
        height=512,
        generator=generator,
    )

    image = result.images[0]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)
    print(f"  saved: {output_path}")

    # Clean up VRAM
    del pipe
    torch.cuda.empty_cache()


def unload_ollama_models():
    """Ask Ollama to unload all models to free VRAM."""
    try:
        unloaded = unload_models()
        if not unloaded:
            print("ollama: no models loaded, VRAM is free")
        for name in unloaded:
            print(f"ollama: unloaded {name}")
    except Exception as e:
        print(f"ollama: could not reach ({e}), assuming VRAM is free")


def main():
    parser = argparse.ArgumentParser(
        description="Generate header images for blog posts using Stable Diffusion"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be generated without doing it"
    )
    parser.add_argument(
        "--post", metavar="FILENAME",
        help="Generate for a single post (e.g. 2026-03-06-day-0-substrate-is-alive.md)"
    )
    parser.add_argument(
        "--seed", type=int, default=None,
        help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--no-unload", action="store_true",
        help="Skip unloading Ollama models before generation"
    )
    args = parser.parse_args()

    posts = find_posts_needing_images(single_post=args.post)

    if not posts:
        print("All posts already have header images. Nothing to do.")
        return

    print(f"Found {len(posts)} post(s) needing header images:\n")

    for filename, title, slug, body in posts:
        prompt = build_prompt(title, body)
        image_rel = f"{SITE_IMAGE_PREFIX}/{slug}.png"
        image_abs = IMAGES_DIR / f"{slug}.png"

        print(f"  [{filename}]")
        print(f"  title:  {title}")
        print(f"  slug:   {slug}")
        print(f"  prompt: {prompt}")
        print(f"  output: {image_abs}")
        print(f"  front matter: header_image: \"{image_rel}\"")
        print()

    if args.dry_run:
        print("Dry run complete. No images generated.")
        return

    # Unload Ollama to free VRAM
    if not args.no_unload:
        unload_ollama_models()

    print("Generating images...\n")

    for i, (filename, title, slug, body) in enumerate(posts):
        prompt = build_prompt(title, body)
        image_rel = f"{SITE_IMAGE_PREFIX}/{slug}.png"
        image_abs = IMAGES_DIR / f"{slug}.png"

        print(f"[{i+1}/{len(posts)}] {filename}")
        print(f"  prompt: {prompt}")

        generate_image(prompt, image_abs, seed=args.seed)
        update_front_matter(filename, image_rel)
        print()

    print(f"Done. Generated {len(posts)} image(s).")


if __name__ == "__main__":
    main()
