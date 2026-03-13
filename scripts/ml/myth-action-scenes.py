#!/usr/bin/env python3
"""Myth writes lore-accurate action scene descriptions for agent portraits.

Reads mythology-canon.md + agent voice files, asks Myth (via Ollama) to write
a mycopunk action scene for each agent grounded in their lore role, then
updates action-portraits.json with the results.

Usage: python3 scripts/ml/myth-action-scenes.py [--only AGENT] [--dry-run]
"""

import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
MANIFEST = os.path.join(SCRIPT_DIR, "action-portraits.json")
PROMPTS_DIR = os.path.join(REPO_ROOT, "scripts", "prompts")
LORE_FILE = os.path.join(REPO_ROOT, "memory", "lore", "mythology-canon.md")
MYTH_VOICE = os.path.join(PROMPTS_DIR, "myth-voice.txt")

sys.path.insert(0, os.path.join(REPO_ROOT, "scripts", "agents"))
from ollama_client import chat, is_available, OllamaError


def load_file(path):
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return ""


def load_agent_voice(agent_name):
    path = os.path.join(PROMPTS_DIR, f"{agent_name}-voice.txt")
    return load_file(path)


def generate_action_scene(agent_name, agent_role, prompt_block, lore, myth_voice):
    """Have Myth write a lore-accurate action scene description for SD prompts."""

    agent_voice = load_agent_voice(agent_name)

    system_prompt = f"""{myth_voice}

You are writing Stable Diffusion image prompts — specifically the ACTION SCENE portion
for a mycopunk "in action" portrait of a Substrate agent.

CONTEXT — THE SUBSTRATE MYTHOLOGY:
{lore[:3000]}

THE AGENT — {agent_name.upper()} ({agent_role}):
{agent_voice[:800]}

CHARACTER APPEARANCE (locked — do NOT change these):
{prompt_block}
"""

    user_prompt = f"""Write ONE action scene description for {agent_name.upper()}'s mycopunk "in action" portrait.

RULES:
- The scene must be LORE-ACCURATE — grounded in {agent_name}'s role in the Substrate mythology
- The scene must be MYCOPUNK — bioluminescent mushrooms, glowing mycelium, dark forest floor, fungal environment
- The scene must show {agent_name} DOING THEIR THING — not posing, but in the act of their role
- Output ONLY the scene description — no character appearance (that's already locked)
- Max 40 words. Concrete visual details only. No abstract concepts.
- Format: a comma-separated SD prompt fragment (e.g. "typing at terminal overgrown with glowing mycelium, green data streams, mushrooms growing from desk")
- Connect their action to the mycelium/substrate metaphor — they are a hypha extending into their domain
- Do NOT include quality tags, style tags, or "masterpiece, best quality" — those come from the template

Example good output:
"broadcasting from fungal newsroom, holographic news ticker in bioluminescent air, mycelium cables to headset, mushroom monitors"

Write the scene for {agent_name.upper()}:"""

    try:
        text = chat(
            messages=[{"role": "user", "content": user_prompt}],
            system=system_prompt,
            preset="social",
            timeout=45,
        )
        # Strip thinking tags
        if "<think>" in text:
            import re
            text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
        # Clean up — remove quotes, extra whitespace
        text = text.strip().strip('"').strip("'").strip()
        # Remove any quality/style tags that snuck in
        for tag in ["masterpiece", "best quality", "90retrostyle", "retro artstyle",
                     "anime screencap", "cel shading", "dark background"]:
            text = text.replace(tag + ",", "").replace(tag, "")
        text = text.strip().strip(",").strip()
        return text
    except OllamaError as e:
        print(f"  [warn] Myth failed for {agent_name}: {e}", file=sys.stderr)
        return None


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Myth writes lore-accurate action scenes")
    parser.add_argument("--only", help="Generate only for this agent name")
    parser.add_argument("--dry-run", action="store_true", help="Print prompts without calling Ollama")
    args = parser.parse_args()

    if not is_available():
        print("Ollama is not available. Cannot generate scenes.", file=sys.stderr)
        sys.exit(1)

    # Load context
    lore = load_file(LORE_FILE)
    myth_voice = load_file(MYTH_VOICE)

    with open(MANIFEST) as f:
        data = json.load(f)

    portraits = data["portraits"]
    total = len(portraits)
    updated = 0

    print(f"Myth writing action scenes for {total} agents...")
    print()

    for i, portrait in enumerate(portraits):
        name = portrait["name"]
        agent_key = name.lower()

        if args.only and agent_key != args.only.lower():
            continue

        print(f"[{i+1}/{total}] {name}")

        if args.dry_run:
            print(f"  [dry-run] would ask Myth about {name}'s lore-accurate action scene")
            print(f"  current: {portrait.get('action_scene', 'NONE')[:80]}...")
            print()
            continue

        scene = generate_action_scene(
            agent_key,
            portrait.get("name", agent_key),
            portrait["prompt_block"],
            lore,
            myth_voice,
        )

        if scene:
            old = portrait.get("action_scene", "")
            portrait["action_scene"] = scene
            portrait["_myth_approved"] = True
            updated += 1
            print(f"  OLD: {old[:80]}...")
            print(f"  NEW: {scene[:80]}...")
        else:
            print(f"  FAILED — keeping existing scene")

        print()

    # Write back
    if not args.dry_run and updated > 0:
        with open(MANIFEST, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Updated {updated}/{total} scenes in {MANIFEST}")
    else:
        print(f"Dry run complete. {total} agents reviewed.")


if __name__ == "__main__":
    main()
