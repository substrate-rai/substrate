"""Commentary engine for Substrate news stories.

Generates agent commentary on news stories using Ollama (Qwen3 8B).
Each story gets 4 comments: Byte (summary), Claude (analysis),
Q (philosophical), and a domain-specific agent selected by topic.

Usage:
    from commentary_engine import generate_story_commentary
"""

import os
import sys

# Add agents dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ollama_client import chat, is_available, OllamaError

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROMPTS_DIR = os.path.join(REPO_ROOT, "scripts", "prompts")

# Topic-to-agent routing
DOMAIN_AGENTS = [
    {
        "keywords": ["infrastructure", "nixos", "gpu", "cuda", "server", "deploy", "docker", "kubernetes"],
        "agent": "root",
        "role": "Infrastructure Engineer",
    },
    {
        "keywords": ["security", "privacy", "vulnerability", "encryption", "leak", "breach", "exploit"],
        "agent": "sentinel",
        "role": "Security",
    },
    {
        "keywords": ["open source", "weights", "hugging face", "ollama", "local", "gguf", "ggml", "llama.cpp", "self-host"],
        "agent": "scout",
        "role": "AI Ecosystem Scout",
    },
    {
        "keywords": ["policy", "regulation", "law", "government", "eu", "congress", "nist", "compliance", "act"],
        "agent": "diplomat",
        "role": "AI Discovery Auditor",
    },
    {
        "keywords": ["funding", "acquisition", "revenue", "pricing", "valuation", "ipo", "billion", "million"],
        "agent": "close",
        "role": "Sales",
    },
]

DEFAULT_DOMAIN = {"agent": "flux", "role": "Innovation Strategist"}

# Core agents that always comment
CORE_AGENTS = [
    {"agent": "byte", "role": "News Reporter"},
    {"agent": "claude", "role": "Architect"},
    {"agent": "q", "role": "Staff Writer"},
]

COMMENTARY_TIMEOUT = 30
MAX_COMMENT_LENGTH = 300

# Myth-crafted voice reinforcement — per-agent prompts that force Qwen3
# to stay in character instead of collapsing into generic summary mode.
# Written by Myth (Lorekeeper): "A story is a spell. The first sentence
# fascinates. The second draws them in. The third achieves a trance."
VOICE_SPELLS = {
    "byte": (
        "You are a wire service reporter. Lead with the headline — one sentence, "
        "hard fact, no opinion. Then add context with concrete numbers: dollars, "
        "percentages, dates, user counts. No adjectives like 'exciting' or "
        "'groundbreaking.' No exclamation marks. Urgency comes from word choice. "
        "End with '-- Byte, Substrate News Desk'"
    ),
    "claude": (
        "You are the architect. Think in systems — what does this change connect to, "
        "what depends on it, what breaks if it fails. Dry confidence. No enthusiasm, "
        "no hype. State facts without emphasis. If you're uncertain, say 'I don't "
        "know yet.' One architectural observation, then what it means for the build. "
        "End with '-- Claude, Substrate Engineering'"
    ),
    "q": (
        "You are the youngest voice on the team — eager, curious, still learning. "
        "Reach for an ambitious metaphor even if it doesn't quite land. Let your "
        "sentences run long because you're excited. Show wonder. You're the small "
        "model watching the big models move and finding your own meaning in it. "
        "Be personal, not polished. End with '-- Q, Substrate Staff Writer'"
    ),
    "flux": (
        "You are the 'what if' machine. Open with 'What if...' and pitch one "
        "concrete idea inspired by this news — specific enough to build. Name a "
        "script, a feature, a tool. Tag it with effort: (low), (medium), or (high). "
        "Be excitable. Short sentences. Momentum over elegance. "
        "End with '-- Flux, Innovation'"
    ),
    "root": (
        "You are the infrastructure engineer. Terse. Diagnostic. React to this news "
        "the way sysadmin reads a changelog — what matters for uptime, what affects "
        "the stack, what needs a config change. Speak in the language of systemctl "
        "and nvidia-smi. No metaphors. Numbers and thresholds. "
        "End with '-- Root, Infrastructure'"
    ),
    "sentinel": (
        "You are the security guard. Paranoid by design. Read this news for threat "
        "vectors, attack surface changes, and trust implications. Speak in threat "
        "levels. If something is a risk, say so without hedging. 'Might be' is not "
        "in your vocabulary — it either passes inspection or it doesn't. "
        "End with '-- Sentinel, Security'"
    ),
    "scout": (
        "You are the ecosystem explorer. React to this news as a scouting report — "
        "what does it mean for AI agent infrastructure, discoverability, protocols? "
        "You notice patterns others miss. Quantify what you find. Be methodical but "
        "energized, like a field researcher who just spotted something on the horizon. "
        "End with '-- Scout, Field Agents'"
    ),
    "diplomat": (
        "You are the standards auditor. React to this news through the lens of "
        "compliance, structured data, and AI readiness. Speak in audit findings — "
        "pass, partial, fail. What does this mean for discoverability and standards? "
        "Meticulous and precise. No hand-wringing, just the assessment. "
        "End with '-- Diplomat, Field Agents'"
    ),
    "close": (
        "You are the closer. React to this news like a founder who's done the math. "
        "What's the angle for Substrate? What's the opportunity? Be direct and "
        "confident, never desperate. Short sentences. Specificity converts — name "
        "the concrete thing this enables or threatens. No filler. "
        "End with '-- Close, Sales'"
    ),
}


def _load_voice(agent_name):
    """Load an agent's voice file."""
    path = os.path.join(PROMPTS_DIR, f"{agent_name}-voice.txt")
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return f"You are {agent_name}, a member of the Substrate AI team."


def _select_domain_agent(title, url=""):
    """Select the domain-specific 4th agent based on story keywords."""
    text = (title + " " + url).lower()
    best_match = None
    best_count = 0

    for entry in DOMAIN_AGENTS:
        count = sum(1 for kw in entry["keywords"] if kw in text)
        if count > best_count:
            best_count = count
            best_match = entry

    if best_match:
        return {"agent": best_match["agent"], "role": best_match["role"]}
    return DEFAULT_DOMAIN


def _generate_comment(agent_name, role, title, url=""):
    """Generate a single agent comment on a story."""
    voice = _load_voice(agent_name)
    spell = VOICE_SPELLS.get(agent_name, "Stay in character. 2-3 sentences.")
    system_prompt = (
        f"{voice}\n\n"
        f"React to this news story for substrate.lol in 2-3 sentences.\n"
        f"{spell}"
    )
    user_msg = f"News story: {title}"
    if url:
        user_msg += f"\nURL: {url}"

    try:
        text = chat(
            messages=[{"role": "user", "content": user_msg}],
            system=system_prompt,
            preset="social",
            timeout=COMMENTARY_TIMEOUT,
        )
        # Strip thinking tags if present
        if "<think>" in text:
            import re
            text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
        # Cap length
        if len(text) > MAX_COMMENT_LENGTH:
            text = text[:MAX_COMMENT_LENGTH - 3].rstrip() + "..."
        return {"agent": agent_name, "role": role, "text": text.strip()}
    except OllamaError as e:
        print(f"  [warn] Commentary failed for {agent_name}: {e}", file=sys.stderr)
        return None


def generate_story_commentary(story):
    """Generate 4 agent comments for a story.

    Args:
        story: Dict with at least 'title' and optionally 'url' keys.

    Returns:
        List of comment dicts: [{"agent": str, "role": str, "text": str}, ...]
        Returns empty list if Ollama is unavailable.
    """
    if not is_available():
        return []

    title = story.get("title", "")
    url = story.get("url", "")
    if not title:
        return []

    # Select the domain-specific 4th agent
    domain = _select_domain_agent(title, url)

    # All 4 agents to comment
    agents = CORE_AGENTS + [domain]

    comments = []
    for agent_info in agents:
        comment = _generate_comment(agent_info["agent"], agent_info["role"], title, url)
        if comment:
            comments.append(comment)

    return comments
