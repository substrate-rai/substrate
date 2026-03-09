"""Shared context loader for Substrate agents.

Provides each agent with its voice, recent bulletins, and domain knowledge
so AI calls (Ollama) have the right context. Import and use in any agent:

    from context import load_context

    ctx = load_context("Pixel")
    # ctx.voice       — agent personality (from voice file)
    # ctx.bulletins   — recent memos (from bulletin board)
    # ctx.knowledge   — domain-specific knowledge summaries
    # ctx.system_prompt() — combined prompt ready for Ollama
"""

import os
import re
from datetime import datetime, timedelta

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROMPTS_DIR = os.path.join(REPO_DIR, "scripts", "prompts")
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
BULLETIN_FILE = os.path.join(MEMORY_DIR, "bulletin.md")

# Map agent names to their voice file slugs
VOICE_SLUGS = {
    "Pixel": "pixel", "Myth": "myth", "Neon": "neon", "Hum": "hum",
    "Root": "root", "Forge": "forge", "Spore": "spore", "Sync": "sync",
    "Flux": "flux", "Lumen": "lumen", "Arc": "arc", "Spec": "spec",
    "Byte": "byte", "Echo": "echo", "Dash": "dash", "Mint": "mint",
    "Yield": "yield", "Amp": "amp", "Pulse": "pulse", "Sentinel": "sentinel",
    "Close": "close", "Promo": "promo", "V": "v", "Q": "q", "Claude": "claude",
}

# Map agents to their domain knowledge files (relative to memory/)
# Each agent gets its voice + bulletins automatically.
# This dict adds domain-specific knowledge from memory/.
DOMAIN_FILES = {
    "Pixel":    ["art-direction.md", "visuals/"],
    "Myth":     ["lore/", "narrative/"],
    "Neon":     ["art-direction.md", "design/"],
    "Hum":      ["audio/"],
    "Spec":     [],
    "Forge":    ["site/"],
    "Root":     ["infra/", "status/"],
    "Sync":     ["narrative/", "engagement/"],
    "Flux":     ["brainstorms/"],
    "Arc":      ["game-design/"],
    "Byte":     ["news/"],
    "Echo":     ["releases/"],
    "Dash":     ["briefings/", "mirror/"],
    "Spore":    ["engagement/"],
    "Lumen":    ["curriculum/"],
    "Mint":     [],
    "Yield":    [],
    "Amp":      ["engagement/", "news/"],
    "Pulse":    ["metrics/"],
    "Sentinel": ["bugs/", "security/"],
    "Close":    ["sales/"],
    "Promo":    [],
}


def _read_file(path, max_chars=4000):
    """Read a file, truncated to max_chars."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read(max_chars)
        if len(content) == max_chars:
            content += "\n... (truncated)"
        return content
    except (IOError, OSError):
        return None


def _read_latest_in_dir(dirpath, max_files=1, max_chars=2000):
    """Read the most recent .md file(s) in a directory."""
    if not os.path.isdir(dirpath):
        return ""
    files = sorted(
        [f for f in os.listdir(dirpath) if f.endswith(".md")],
        reverse=True,
    )
    parts = []
    for f in files[:max_files]:
        content = _read_file(os.path.join(dirpath, f), max_chars)
        if content:
            parts.append(f"### {f}\n{content}")
    return "\n\n".join(parts)


def load_voice(agent_name):
    """Load an agent's voice file."""
    slug = VOICE_SLUGS.get(agent_name, agent_name.lower())
    path = os.path.join(PROMPTS_DIR, f"{slug}-voice.txt")
    return _read_file(path) or ""


def load_bulletins(days=7, max_chars=2000):
    """Load recent bulletin memos."""
    if not os.path.exists(BULLETIN_FILE):
        return ""

    content = _read_file(BULLETIN_FILE, max_chars=8000) or ""
    if not content:
        return ""

    # Extract memos from the last N days
    cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    lines = content.splitlines()
    result = []
    include = False

    for line in lines:
        if line.startswith("## 20") and " — " in line:
            date_part = line.split(" — ")[0].replace("## ", "").strip()
            include = date_part >= cutoff
        if include:
            result.append(line)

    text = "\n".join(result).strip()
    if len(text) > max_chars:
        text = text[:max_chars] + "\n... (truncated)"
    return text


def load_knowledge(agent_name, max_chars=3000):
    """Load domain-specific knowledge for an agent."""
    files = DOMAIN_FILES.get(agent_name, [])
    parts = []

    for f in files:
        path = os.path.join(MEMORY_DIR, f)
        if f.endswith("/"):
            # Directory — read latest file
            content = _read_latest_in_dir(path, max_chars=max_chars // max(len(files), 1))
            if content:
                parts.append(content)
        else:
            content = _read_file(path, max_chars=max_chars // max(len(files), 1))
            if content:
                parts.append(f"### {f}\n{content}")

    return "\n\n".join(parts)


class AgentContext:
    """Loaded context for an agent."""

    def __init__(self, agent_name):
        self.agent_name = agent_name
        self.voice = load_voice(agent_name)
        self.bulletins = load_bulletins()
        self.knowledge = load_knowledge(agent_name)

    def system_prompt(self, base_prompt=None):
        """Build a complete system prompt with voice, bulletins, and knowledge.

        Args:
            base_prompt: Optional override for the base system prompt.
                         If None, uses the voice file content.
        """
        parts = []

        # Identity from voice file (or base prompt)
        if base_prompt:
            parts.append(base_prompt)
        if self.voice:
            parts.append(f"--- IDENTITY ---\n{self.voice}")

        # Recent bulletins
        if self.bulletins:
            parts.append(f"--- RECENT MEMOS ---\n{self.bulletins}")

        # Domain knowledge
        if self.knowledge:
            parts.append(f"--- DOMAIN KNOWLEDGE ---\n{self.knowledge}")

        return "\n\n".join(parts)


def load_context(agent_name):
    """Load full context for an agent. Returns an AgentContext object."""
    return AgentContext(agent_name)
