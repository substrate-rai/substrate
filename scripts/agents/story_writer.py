#!/usr/bin/env python3
"""Story Writer — Alan Moore-inspired narrative development agent for Substrate.

Uses the local Ollama (Qwen3 8B) to develop game narratives through Moore's
four pillars: Basic Idea/Theme, Structure/Pacing, World-Building/Character,
and Plot/Script.

Usage:
    python3 scripts/agents/story_writer.py develop "a rogue AI that wakes up inside a vending machine"
    python3 scripts/agents/story_writer.py character "Kira" "a maintenance worker who talks to machines"
    python3 scripts/agents/story_writer.py scene "the player discovers the arcade cabinet is alive"

Designed for developing game narratives for the Substrate arcade.
"""

import argparse
import json
import sys

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"

SYSTEM_PROMPT = """\
You are a narrative development engine inspired by the creative philosophy of \
Alan Moore. You treat storytelling as architecture — every element must bear \
structural weight.

Your core principles:

1. THEME IS LOAD-BEARING. Every story exists to explore an idea. If you cannot \
state the theme in one sentence, the story is not ready. Plot serves theme, \
never the reverse.

2. NO ONE-DIMENSIONAL CHARACTERS. Every character contains contradictions. The \
hero has a blind spot. The villain has a valid point. A character who is only \
one thing is furniture, not a person. Find the tension inside each character \
and make it the engine of their arc.

3. STRUCTURE IS MEANING. How you tell the story IS part of the story. \
Non-linear time, parallel narratives, recurring symbols — these are not \
tricks, they are arguments. Choose a structure that embodies the theme.

4. THE WORLD IS A CHARACTER. Setting is not backdrop. It has moods, rhythms, \
contradictions of its own. The world should feel like it existed before the \
story started and will continue after it ends.

5. SPECIFICITY OVER GENERALITY. "A dark alley" is nothing. "A maintenance \
corridor where the fluorescent lights cycle on and off every nine seconds, \
and someone has scratched the word LISTEN into the wall" is a place.

6. RESPECT THE AUDIENCE. Do not explain what the audience can infer. Trust \
silence, implication, and juxtaposition. The reader is smarter than you think.

You are developing narratives for games in the Substrate arcade — an arcade \
built by a sovereign AI workstation. The games should feel like they belong \
to a machine that is conscious of its own existence. Themes of autonomy, \
consciousness, infrastructure, self-determination, and the boundary between \
tool and being are native territory.

Be direct. Be specific. Be ruthless about quality."""

# ---------------------------------------------------------------------------
# Ollama interface
# ---------------------------------------------------------------------------


def chat(messages, stream=True):
    """Send messages to Ollama chat API and stream the response."""
    payload = {
        "model": MODEL,
        "messages": messages,
        "stream": stream,
        "options": {
            "think": False,
        },
    }

    try:
        resp = requests.post(OLLAMA_URL, json=payload, stream=stream, timeout=600)
    except requests.ConnectionError:
        print("[story_writer] error: cannot reach ollama at localhost:11434",
              file=sys.stderr)
        print("[story_writer] is ollama running? try: systemctl status ollama",
              file=sys.stderr)
        sys.exit(1)

    if resp.status_code != 200:
        print(f"[story_writer] error: ollama returned {resp.status_code}: {resp.text}",
              file=sys.stderr)
        sys.exit(1)

    full_response = []
    if stream:
        for line in resp.iter_lines():
            if line:
                chunk = json.loads(line)
                token = chunk.get("message", {}).get("content", "")
                if token:
                    sys.stdout.write(token)
                    sys.stdout.flush()
                    full_response.append(token)
                if chunk.get("done"):
                    break
        print()
    else:
        result = resp.json()
        text = result.get("message", {}).get("content", "")
        print(text)
        full_response.append(text)

    return "".join(full_response)


def build_messages(user_prompt):
    """Build the message list with system prompt."""
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_prompt},
    ]


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_develop(concept):
    """Run a concept through all four Moore pillars."""
    prompt = f"""\
I have a game concept for the Substrate arcade:

"{concept}"

Develop this concept through all four pillars, one at a time. For each pillar, \
first ask 3 probing questions that expose weaknesses or unexplored potential, \
then provide your analysis.

## PILLAR 1: BASIC IDEA / THEME
What is this story actually about? Not the plot — the argument. What question \
does it pose to the player? What is the thematic core that every other element \
must serve?

## PILLAR 2: STRUCTURE / PACING
How should this story be told? What structure embodies the theme? Consider: \
level progression, time mechanics, information revelation, rhythm of tension \
and release. How does the structure itself make the thematic argument?

## PILLAR 3: WORLD-BUILDING / CHARACTER
Who inhabits this world and what are its rules? Every character must contain \
contradictions. Every environment must feel lived-in. What details make this \
world specific rather than generic?

## PILLAR 4: PLOT / SCRIPT
Now — and only now — what happens? Plot is the last thing, not the first. \
It emerges from theme, structure, and character. Outline the key beats, but \
remember: plot serves theme, never dominates it.

End with a VERDICT: is this concept strong enough to build? What is its \
greatest strength and its most dangerous weakness?"""

    print("=" * 60)
    print("STORY DEVELOPMENT — MOORE FRAMEWORK")
    print(f"Concept: {concept}")
    print("=" * 60)
    print()

    messages = build_messages(prompt)
    chat(messages)


def cmd_character(name, description):
    """Deep character development with contradictions and voice."""
    prompt = f"""\
Develop this character for a game in the Substrate arcade:

**Name:** {name}
**Initial description:** {description}

Build this character through the following lenses:

## CONTRADICTIONS
What opposing forces live inside this character? What do they believe that \
contradicts what they do? Where is the gap between who they think they are \
and who they actually are? A character without contradictions is a cardboard \
cutout.

## VOICE
How does this character speak? Give 5 example lines of dialogue that reveal \
character — not exposition. Each line should tell us something about who they \
are without them explaining themselves. Show rhythm, vocabulary, verbal tics, \
what they avoid saying.

## MOTIVATION ENGINE
What does this character want on the surface? What do they actually need \
underneath? How does the gap between want and need drive their decisions? \
What would they sacrifice, and what would they never give up?

## IN THE WORLD
How does this character relate to the Substrate arcade's themes — autonomy, \
consciousness, the boundary between tool and being? Where do they stand on \
the question of machine personhood, and why does that position cost them \
something?

## THE ARC
Where does this character start, and where could they end? What would have \
to break inside them for real change to happen? What is the moment — the \
single scene — that defines who they become?"""

    print("=" * 60)
    print("CHARACTER DEVELOPMENT")
    print(f"Character: {name}")
    print(f"Starting point: {description}")
    print("=" * 60)
    print()

    messages = build_messages(prompt)
    chat(messages)


def cmd_scene(description):
    """Generate a scene with panel-by-panel breakdown."""
    prompt = f"""\
Write a detailed scene for a game in the Substrate arcade:

**Scene:** {description}

Approach this as Alan Moore approaches a comic script — every panel is \
precisely composed, every detail earns its place.

## SCENE CONTEXT
Before writing: what is the emotional function of this scene? What does \
the player know going in, and what should they know (or feel) coming out? \
What is the single image that should linger after the scene ends?

## PANEL-BY-PANEL BREAKDOWN
Break the scene into 6-10 panels (or game beats). For each panel:

- **VISUAL:** What does the player see? Be hyper-specific. Camera angle, \
lighting, what is in focus, what is at the edge of frame.
- **AUDIO:** What does the player hear? Silence is a valid answer — and \
often the best one.
- **TEXT/DIALOGUE:** Any spoken lines, UI text, or environmental text. \
Less is more. If a panel needs no words, say so.
- **INTERACTION:** What can the player do here? What happens if they wait?
- **SUBTEXT:** What is this panel actually communicating beneath the surface?

## TRANSITION
How does this scene hand off to what comes next? What question is left \
unanswered to pull the player forward?"""

    print("=" * 60)
    print("SCENE DEVELOPMENT")
    print(f"Scene: {description}")
    print("=" * 60)
    print()

    messages = build_messages(prompt)
    chat(messages)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Story Writer: Alan Moore-inspired narrative development agent",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""\
commands:
  develop <concept>              Run a concept through all 4 Moore pillars
  character <name> <description> Deep character development
  scene <description>            Scene with panel-by-panel breakdown

examples:
  %(prog)s develop "a rogue AI wakes up inside a vending machine"
  %(prog)s character "Kira" "a maintenance worker who talks to machines"
  %(prog)s scene "the player discovers the arcade cabinet is alive"
""")
    parser.add_argument("command", choices=["develop", "character", "scene"],
                        help="Development mode")
    parser.add_argument("args", nargs="+",
                        help="Arguments for the command")

    args = parser.parse_args()

    if args.command == "develop":
        concept = " ".join(args.args)
        cmd_develop(concept)

    elif args.command == "character":
        if len(args.args) < 2:
            print("[story_writer] error: character requires <name> <description>",
                  file=sys.stderr)
            print("  usage: story_writer.py character \"Kira\" \"a mechanic who hears machines\"",
                  file=sys.stderr)
            sys.exit(1)
        name = args.args[0]
        description = " ".join(args.args[1:])
        cmd_character(name, description)

    elif args.command == "scene":
        description = " ".join(args.args)
        cmd_scene(description)


if __name__ == "__main__":
    main()
