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
    system_prompt = (
        f"{voice}\n\n"
        f"Comment on this news story for substrate.lol. "
        f"2-3 sentences max. Stay in character."
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
