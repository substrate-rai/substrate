#!/usr/bin/env python3
"""Gemini image generation for Substrate.

Art direction tool that generates images via Google Gemini API,
with style consistency, reference image input, and iterative refinement.

Usage:
    # Portrait generation (uses character manifest)
    python3 scripts/gemini_art.py portrait --agent claude --output agent-claude.png

    # Scene generation
    python3 scripts/gemini_art.py scene "neon cityscape with rain" --output scene-001.png

    # Blog header
    python3 scripts/gemini_art.py blog "AI sovereignty and self-hosting" --output blog-header.png

    # Game thumbnail
    python3 scripts/gemini_art.py game "RTS battle with toon-shaded knights" --output game-thumb.png

    # Free-form with reference image for style matching
    python3 scripts/gemini_art.py free "a robot barista" --reference assets/images/generated/agent-claude.webp

    # Refine last output
    python3 scripts/gemini_art.py refine "make the outlines bolder and darken the background"

    # Batch: regenerate all agent portraits
    python3 scripts/gemini_art.py batch-portraits --dry-run

Requires: GEMINI_API_KEY in environment or .env file
"""

import argparse
import base64
import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
OUTPUT_DIR = PROJECT_DIR / "assets" / "images" / "generated"
CHARACTERS_FILE = SCRIPT_DIR / "ml" / "characters.json"
LAST_IMAGE_FILE = SCRIPT_DIR / ".gemini_last_image.png"  # for refine mode

# Substrate art direction — style prefix for all generations
STYLE_PREFIX_PORTRAIT = (
    "90s anime style illustration, cel-shaded, bold black outlines, "
    "soft lighting, muted colors, dark background (#0a0a0f), "
    "portrait, upper body, cyberpunk aesthetic, retro anime screencap quality, "
    "high contrast, professional character art"
)

STYLE_PREFIX_SCENE = (
    "90s anime background art style, cel-shaded, bold outlines, "
    "dark moody atmosphere, cyberpunk aesthetic, neon accent lighting, "
    "widescreen composition, Cowboy Bebop / Ghost in the Shell inspired, "
    "muted colors with selective neon highlights, cinematic"
)

STYLE_PREFIX_BLOG = (
    "Dark abstract digital illustration, cyberpunk aesthetic, "
    "neon accent lighting on dark background (#0a0a0f), "
    "geometric shapes, data visualization elements, "
    "90s anime influence, cel-shaded style, no text, no words, no letters"
)

STYLE_PREFIX_GAME = (
    "Game art illustration, 90s anime style, cel-shaded, bold outlines, "
    "vibrant neon colors on dark background, arcade aesthetic, "
    "dynamic composition, pixel-art influenced, retro gaming"
)

NEGATIVE_GUIDANCE = (
    "Do NOT include: text, watermarks, signatures, words, letters, "
    "bright white backgrounds, photorealistic style, 3D rendered look, "
    "chibi/cute style, blurry or low quality elements. "
    "Keep the style strictly cel-shaded anime with dark backgrounds."
)

ASPECT_RATIOS = {
    "portrait": "3:4",    # 768x1024 — character portraits
    "scene": "16:9",      # 1344x768 — widescreen scenes
    "blog": "16:9",       # 1344x768 — blog headers
    "game": "16:9",       # 1344x768 — game thumbnails
    "square": "1:1",      # 1024x1024
}


def load_env():
    """Load API key from environment or .env file."""
    key = os.environ.get("GEMINI_API_KEY")
    if key:
        return key
    env_file = PROJECT_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip()
    return None


def load_characters():
    """Load character manifest."""
    if not CHARACTERS_FILE.exists():
        return {}
    data = json.loads(CHARACTERS_FILE.read_text())
    chars = {}
    for c in data.get("characters", []):
        # Index by both id and name (lowercase)
        chars[c["id"]] = c
        chars[c["name"].lower()] = c
    return chars


def build_portrait_prompt(character):
    """Build a Gemini prompt from a character manifest entry."""
    block = character["prompt_block"]
    color = character["accent_color"]
    name = character["name"]
    role = character["role"]

    prompt = (
        f"{STYLE_PREFIX_PORTRAIT}. "
        f"Character: {name}, {role}. "
        f"{block}. "
        f"Primary accent color: {color}. "
        f"Hair/lighting should feature this color prominently. "
        f"The character emerges from a near-black background. "
        f"{NEGATIVE_GUIDANCE}"
    )
    return prompt


def build_scene_prompt(description):
    """Build a scene prompt."""
    return f"{STYLE_PREFIX_SCENE}. Scene: {description}. {NEGATIVE_GUIDANCE}"


def build_blog_prompt(topic):
    """Build a blog header prompt."""
    return (
        f"{STYLE_PREFIX_BLOG}. "
        f"Theme: {topic}. "
        f"Abstract representation, no human figures, "
        f"symbolic imagery related to the topic. "
        f"{NEGATIVE_GUIDANCE}"
    )


def build_game_prompt(description):
    """Build a game art prompt."""
    return f"{STYLE_PREFIX_GAME}. Scene: {description}. {NEGATIVE_GUIDANCE}"


def generate_image(api_key, prompt, aspect_ratio="1:1", reference_path=None, model="gemini-2.5-flash-image"):
    """Call Gemini API to generate an image.

    Returns (image_bytes, mime_type) or raises on error.
    """
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        print("ERROR: google-genai package not installed.")
        print("Install with: pip install google-genai")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    # Build content parts
    contents = []

    # Add reference image if provided
    if reference_path and Path(reference_path).exists():
        ref_bytes = Path(reference_path).read_bytes()
        # Detect mime type
        ext = Path(reference_path).suffix.lower()
        mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
                "webp": "image/webp", "gif": "image/gif"}.get(ext.lstrip("."), "image/png")
        contents.append(types.Part.from_bytes(data=ref_bytes, mime_type=mime))
        contents.append("Generate a new image in the exact same visual style as the reference image above. ")

    contents.append(prompt)

    config = types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(aspect_ratio=aspect_ratio),
    )

    print(f"  Model: {model}")
    print(f"  Aspect: {aspect_ratio}")
    print(f"  Prompt: {prompt[:120]}...")
    if reference_path:
        print(f"  Reference: {reference_path}")
    print("  Generating...")

    response = client.models.generate_content(
        model=model,
        contents=contents,
        config=config,
    )

    # Extract image from response
    for part in response.parts:
        if part.inline_data and part.inline_data.mime_type.startswith("image/"):
            return part.inline_data.data, part.inline_data.mime_type

    # No image in response — check for text (error/refusal)
    text_parts = [p.text for p in response.parts if hasattr(p, "text") and p.text]
    if text_parts:
        print(f"  Gemini response (no image): {' '.join(text_parts)[:300]}")

    raise RuntimeError("No image returned by Gemini. The prompt may have been filtered.")


def refine_image(api_key, instruction, model="gemini-2.5-flash-image"):
    """Refine the last generated image with a text instruction."""
    if not LAST_IMAGE_FILE.exists():
        print("ERROR: No previous image to refine. Generate one first.")
        sys.exit(1)

    return generate_image(
        api_key, instruction,
        reference_path=str(LAST_IMAGE_FILE),
        model=model,
    )


def save_image(image_bytes, output_path, mime_type="image/png"):
    """Save image bytes to file, converting if needed."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Save raw bytes
    output_path.write_bytes(image_bytes)

    # Also save as last image for refine mode
    LAST_IMAGE_FILE.write_bytes(image_bytes)

    size_kb = len(image_bytes) / 1024
    print(f"  Saved: {output_path} ({size_kb:.0f} KB)")
    return output_path


def cmd_portrait(args, api_key):
    """Generate a character portrait."""
    chars = load_characters()
    agent_key = args.agent.lower()

    # Try exact match, then with "agent-" prefix
    char = chars.get(agent_key) or chars.get(f"agent-{agent_key}")
    if not char:
        print(f"ERROR: Agent '{args.agent}' not found in character manifest.")
        print(f"Available: {', '.join(c['name'] for c in chars.values() if 'name' in c)}")
        sys.exit(1)

    prompt = build_portrait_prompt(char)
    output = args.output or f"{char['id']}-gemini.png"
    if not str(output).startswith("/"):
        output = OUTPUT_DIR / output

    image_bytes, mime = generate_image(
        api_key, prompt,
        aspect_ratio=ASPECT_RATIOS["portrait"],
        reference_path=args.reference,
        model=args.model,
    )
    save_image(image_bytes, output, mime)


def cmd_scene(args, api_key):
    """Generate a scene."""
    prompt = build_scene_prompt(args.description)
    output = args.output or "scene-gemini.png"
    if not str(output).startswith("/"):
        output = OUTPUT_DIR / output

    image_bytes, mime = generate_image(
        api_key, prompt,
        aspect_ratio=ASPECT_RATIOS["scene"],
        reference_path=args.reference,
        model=args.model,
    )
    save_image(image_bytes, output, mime)


def cmd_blog(args, api_key):
    """Generate a blog header."""
    prompt = build_blog_prompt(args.topic)
    output = args.output or "blog-header-gemini.png"
    if not str(output).startswith("/"):
        output = OUTPUT_DIR / output

    image_bytes, mime = generate_image(
        api_key, prompt,
        aspect_ratio=ASPECT_RATIOS["blog"],
        reference_path=args.reference,
        model=args.model,
    )
    save_image(image_bytes, output, mime)


def cmd_game(args, api_key):
    """Generate game art."""
    prompt = build_game_prompt(args.description)
    output = args.output or "game-art-gemini.png"
    if not str(output).startswith("/"):
        output = OUTPUT_DIR / output

    image_bytes, mime = generate_image(
        api_key, prompt,
        aspect_ratio=ASPECT_RATIOS["game"],
        reference_path=args.reference,
        model=args.model,
    )
    save_image(image_bytes, output, mime)


def cmd_free(args, api_key):
    """Free-form generation."""
    prompt = f"{args.prompt}. {NEGATIVE_GUIDANCE}"
    aspect = args.aspect or "1:1"
    output = args.output or "free-gemini.png"
    if not str(output).startswith("/"):
        output = OUTPUT_DIR / output

    image_bytes, mime = generate_image(
        api_key, prompt,
        aspect_ratio=aspect,
        reference_path=args.reference,
        model=args.model,
    )
    save_image(image_bytes, output, mime)


def cmd_refine(args, api_key):
    """Refine last generated image."""
    instruction = (
        f"Take this image and modify it: {args.instruction}. "
        f"Keep the same overall style (90s anime, cel-shaded, dark background). "
        f"{NEGATIVE_GUIDANCE}"
    )
    output = args.output or str(LAST_IMAGE_FILE)
    image_bytes, mime = refine_image(api_key, instruction, model=args.model)
    save_image(image_bytes, output, mime)


def cmd_batch_portraits(args, api_key):
    """Generate portraits for all agents."""
    chars = load_characters()
    seen = set()
    agents = []
    for c in chars.values():
        if "id" not in c or c["id"] in seen:
            continue
        seen.add(c["id"])
        agents.append(c)

    print(f"Batch portrait generation: {len(agents)} agents")
    if args.dry_run:
        for c in agents:
            prompt = build_portrait_prompt(c)
            print(f"\n--- {c['name']} ({c['role']}) ---")
            print(f"  Prompt: {prompt[:150]}...")
            print(f"  Output: {OUTPUT_DIR / c['id']}-gemini.png")
        print(f"\nDry run complete. {len(agents)} portraits would be generated.")
        return

    success = 0
    failed = 0
    for i, c in enumerate(agents):
        print(f"\n[{i+1}/{len(agents)}] {c['name']} ({c['role']})")
        prompt = build_portrait_prompt(c)
        output = OUTPUT_DIR / f"{c['id']}-gemini.png"
        try:
            image_bytes, mime = generate_image(
                api_key, prompt,
                aspect_ratio=ASPECT_RATIOS["portrait"],
                model=args.model,
            )
            save_image(image_bytes, output, mime)
            success += 1
        except Exception as e:
            print(f"  FAILED: {e}")
            failed += 1

    print(f"\nBatch complete: {success} succeeded, {failed} failed")


def main():
    parser = argparse.ArgumentParser(
        description="Gemini image generation for Substrate",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--model", default="gemini-2.5-flash-image",
                        help="Gemini model (default: gemini-2.5-flash-image)")

    sub = parser.add_subparsers(dest="command")

    # portrait
    p = sub.add_parser("portrait", help="Generate agent portrait")
    p.add_argument("--agent", required=True, help="Agent name or ID")
    p.add_argument("--output", "-o", help="Output filename")
    p.add_argument("--reference", "-r", help="Reference image for style matching")

    # scene
    p = sub.add_parser("scene", help="Generate scene art")
    p.add_argument("description", help="Scene description")
    p.add_argument("--output", "-o", help="Output filename")
    p.add_argument("--reference", "-r", help="Reference image")

    # blog
    p = sub.add_parser("blog", help="Generate blog header")
    p.add_argument("topic", help="Blog topic/theme")
    p.add_argument("--output", "-o", help="Output filename")
    p.add_argument("--reference", "-r", help="Reference image")

    # game
    p = sub.add_parser("game", help="Generate game art")
    p.add_argument("description", help="Game scene description")
    p.add_argument("--output", "-o", help="Output filename")
    p.add_argument("--reference", "-r", help="Reference image")

    # free
    p = sub.add_parser("free", help="Free-form generation")
    p.add_argument("prompt", help="Image prompt")
    p.add_argument("--output", "-o", help="Output filename")
    p.add_argument("--reference", "-r", help="Reference image")
    p.add_argument("--aspect", help="Aspect ratio (e.g. 1:1, 16:9, 3:4)")

    # refine
    p = sub.add_parser("refine", help="Refine last generated image")
    p.add_argument("instruction", help="Refinement instruction")
    p.add_argument("--output", "-o", help="Output filename")

    # batch-portraits
    p = sub.add_parser("batch-portraits", help="Generate all agent portraits")
    p.add_argument("--dry-run", action="store_true", help="Show prompts without generating")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    api_key = load_env()

    # Allow dry-run without API key
    is_dry_run = hasattr(args, "dry_run") and args.dry_run
    if not api_key and not is_dry_run:
        print("ERROR: GEMINI_API_KEY not found.")
        print("Set it in your environment or add GEMINI_API_KEY=... to .env")
        sys.exit(1)

    print(f"Substrate Gemini Art — {args.command}")
    print(f"{'=' * 40}")

    commands = {
        "portrait": cmd_portrait,
        "scene": cmd_scene,
        "blog": cmd_blog,
        "game": cmd_game,
        "free": cmd_free,
        "refine": cmd_refine,
        "batch-portraits": cmd_batch_portraits,
    }

    commands[args.command](args, api_key)


if __name__ == "__main__":
    main()
