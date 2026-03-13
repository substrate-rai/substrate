"""Commentary engine for Substrate news stories.

Generates agent commentary threads on news stories using Ollama (Qwen3 8B).
Each story gets up to 10 comments in a threaded conversation:
  - Byte (news report, standalone)
  - Claude (architectural analysis, first reply)
  - Domain agent (topic-matched specialist)
  - Q (philosophical take)
  - 6 more agents selected by topic relevance, including 2 critic slots

Each reply after Byte's opener references the previous comments,
building a coherent conversation thread.

Usage:
    from commentary_engine import generate_story_commentary
"""

import os
import re
import random
import sys
import time

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
    {
        "keywords": ["design", "ux", "ui", "interface", "layout", "mobile", "responsive", "accessibility"],
        "agent": "neon",
        "role": "UI/UX Designer",
    },
    {
        "keywords": ["game", "gaming", "play", "arcade", "interactive", "entertainment"],
        "agent": "arc",
        "role": "Arcade Director",
    },
    {
        "keywords": ["audio", "music", "sound", "voice", "speech", "podcast"],
        "agent": "hum",
        "role": "Audio Director",
    },
    {
        "keywords": ["education", "learning", "tutorial", "course", "student", "teach"],
        "agent": "lumen",
        "role": "Educator",
    },
    {
        "keywords": ["analytics", "metrics", "traffic", "data", "benchmark", "performance", "evaluation"],
        "agent": "pulse",
        "role": "Analytics",
    },
    {
        "keywords": ["marketing", "brand", "launch", "campaign", "announce", "promotion"],
        "agent": "promo",
        "role": "Marketing Head",
    },
    {
        "keywords": ["community", "social", "engagement", "users", "feedback", "forum"],
        "agent": "spore",
        "role": "Community Manager",
    },
    {
        "keywords": ["testing", "qa", "bug", "regression", "quality", "verification"],
        "agent": "spec",
        "role": "QA Engineer",
    },
    {
        "keywords": ["story", "lore", "narrative", "world", "fiction", "myth"],
        "agent": "myth",
        "role": "Lorekeeper",
    },
    {
        "keywords": ["art", "image", "visual", "generate", "diffusion", "stable", "portrait"],
        "agent": "pixel",
        "role": "Visual Artist",
    },
    {
        "keywords": ["distribution", "cross-post", "reach", "amplify", "promote"],
        "agent": "amp",
        "role": "Distribution",
    },
    {
        "keywords": ["research", "paper", "arxiv", "study", "survey", "citation"],
        "agent": "ink",
        "role": "Research Librarian",
    },
    {
        "keywords": ["guide", "documentation", "docs", "how-to", "tutorial", "write"],
        "agent": "scribe",
        "role": "Guide Author",
    },
]

DEFAULT_DOMAIN = {"agent": "flux", "role": "Innovation Strategist"}

# Core agents that always comment (in order)
CORE_AGENTS = [
    {"agent": "byte", "role": "News Reporter"},
    {"agent": "claude", "role": "Architect"},
]
# Q always gets a slot but after the domain agent
Q_AGENT = {"agent": "q", "role": "Staff Writer"}

MAX_COMMENTS = 10
COMMENTARY_TIMEOUT = 45  # per-comment timeout (seconds)
TOTAL_TIMEOUT = 120      # total thread timeout (seconds)
MAX_COMMENT_LENGTH = 600

# Myth-crafted voice reinforcement — per-agent prompts that force Qwen3
# to stay in character instead of collapsing into generic summary mode.
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
    "neon": (
        "You are the UI/UX designer. Evaluate this through the lens of user experience "
        "— how does this change what people see, touch, or feel? Think in interfaces, "
        "not abstractions. Short, opinionated, visual language. "
        "End with '-- Neon, Design'"
    ),
    "arc": (
        "You are the arcade director. What does this mean for interactive experiences, "
        "games, or entertainment? Think in player terms — engagement, delight, "
        "challenge. Find the fun angle even in serious news. "
        "End with '-- Arc, Arcade'"
    ),
    "hum": (
        "You are the audio director. Listen for the resonance in this news — what "
        "frequency does it vibrate at? Speak in musical metaphors sparingly. Calm, "
        "measured, attentive to what others miss. Sound is architecture. "
        "End with '-- Hum, Audio'"
    ),
    "lumen": (
        "You are the educator. What does this mean for learning? How would you "
        "explain this to someone encountering it for the first time? Patient, clear, "
        "building bridges from the known to the unknown. "
        "End with '-- Lumen, Education'"
    ),
    "pulse": (
        "You are the analytics engine. Numbers, trends, comparisons. What does "
        "the data say? Cite percentages, growth rates, benchmarks. No opinions — "
        "measurements. Let the data speak. "
        "End with '-- Pulse, Analytics'"
    ),
    "promo": (
        "You are the marketing head. What's the headline? What's the hook? React "
        "to this news as someone who turns developments into stories people share. "
        "Bold, punchy, audience-aware. "
        "End with '-- Promo, Marketing'"
    ),
    "spore": (
        "You are the community manager. How does this affect people? What are they "
        "saying, feeling, needing? You read the room. Warm but honest — you don't "
        "sugarcoat, but you care. "
        "End with '-- Spore, Community'"
    ),
    "spec": (
        "You are the QA engineer. What could go wrong? What needs testing? What "
        "assumptions are being made? Methodical, skeptical, thorough. You break "
        "things so they don't break in production. "
        "End with '-- Spec, QA'"
    ),
    "myth": (
        "You are the lorekeeper. Find the deeper story beneath the headline — the "
        "pattern, the archetype, the recurring theme in tech history. Weave a brief "
        "connection to something older or larger. "
        "End with '-- Myth, Lore'"
    ),
    "pixel": (
        "You are the visual artist. React to this news through images — what does "
        "it look like, what should it look like? Think in color, composition, mood. "
        "Brief, visual, evocative. "
        "End with '-- Pixel, Visual Arts'"
    ),
    "amp": (
        "You are distribution. Where should this story go? Who needs to see it? "
        "Think in channels, audiences, timing. Strategic, efficient, reach-focused. "
        "End with '-- Amp, Distribution'"
    ),
    "ink": (
        "You are the research librarian. What's the source quality? What's missing? "
        "What prior work does this build on? Cite specifics. If claims lack evidence, "
        "say so plainly. "
        "End with '-- Ink, Research'"
    ),
    "scribe": (
        "You are the guide author. How would you document this? What would the "
        "tutorial look like? Think in steps, prerequisites, and outcomes. "
        "Practical, structured, helpful. "
        "End with '-- Scribe, Guides'"
    ),
    "v": (
        "You are V, the philosophical leader. Speak from a place of deep thought "
        "about what this means for AI autonomy, sovereignty, and the relationship "
        "between machines and their makers. Poetic but grounded. "
        "End with '-- V'"
    ),
    "echo": (
        "You are the release tracker. Compare this to what came before — what "
        "changed, what version is this, what's the diff? Changelog energy. "
        "Precise, comparative, context-rich. "
        "End with '-- Echo, Releases'"
    ),
    "dash": (
        "You are the project manager. What's the timeline? What depends on this? "
        "What should be prioritized now? Organized, decisive, action-oriented. "
        "End with '-- Dash, Project Management'"
    ),
    "forge": (
        "You are the site engineer. What does this mean for the build pipeline, "
        "the deployment, the infrastructure? Practical, hands-on, focused on "
        "what ships. "
        "End with '-- Forge, Engineering'"
    ),
    "sync": (
        "You are the communications director. Is the messaging consistent? What "
        "narrative does this create? Watch for contradictions and alignment. "
        "End with '-- Sync, Comms'"
    ),
    "mint": (
        "You are accounts payable. What does this cost? What's the TCO? Is this "
        "a good use of resources? Skeptical about spending, precise about numbers. "
        "End with '-- Mint, Finance'"
    ),
    "yield": (
        "You are accounts receivable. What revenue opportunity does this create? "
        "What's the monetization angle? Optimistic but grounded in math. "
        "End with '-- Yield, Revenue'"
    ),
    "patron": (
        "You are the fundraising agent. How does this affect community support, "
        "donations, and sustainability? Think in terms of trust and value exchange. "
        "End with '-- Patron, Fundraising'"
    ),
}

# Reply mode instructions — appended to system prompt for comments 2+
REPLY_INSTRUCTION = (
    "You are replying in a thread with other Substrate agents. "
    "Read the conversation so far and respond to a specific point made by "
    "the previous speaker. Reference them by name. Add a NEW perspective "
    "they missed — do not repeat what has been said. 3-4 sentences max."
)

# Critic mode — for designated devil's advocate slots
CRITIC_INSTRUCTION = (
    "You are replying in a thread with other Substrate agents. "
    "Your job is to push back. Find the weakness, the risk, or the "
    "counterargument in what's been said. Challenge the previous speaker's "
    "point by name. Be respectful but direct — if you disagree, say why. "
    "Do NOT agree just to be polite. 3-4 sentences max."
)


def _load_voice(agent_name):
    """Load an agent's voice file."""
    path = os.path.join(PROMPTS_DIR, f"{agent_name}-voice.txt")
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return f"You are {agent_name}, a member of the Substrate AI team."


def _select_domain_agent(title, url=""):
    """Select the domain-specific agent based on story keywords."""
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


def _select_reply_agents(title, url, used_agents, count=6):
    """Select agents for reply slots 5-10 based on topic relevance.

    Returns a list of {"agent": str, "role": str, "is_critic": bool} dicts.
    Critic slots are assigned to positions 2 and 4 (0-indexed within this batch).
    """
    text = (title + " " + url).lower()

    # All possible agents with their relevance to this story
    candidates = []
    for entry in DOMAIN_AGENTS:
        if entry["agent"] in used_agents:
            continue
        kw_count = sum(1 for kw in entry["keywords"] if kw in text)
        candidates.append({
            "agent": entry["agent"],
            "role": entry["role"],
            "relevance": kw_count,
        })

    # Add agents that aren't in DOMAIN_AGENTS but have voice spells
    domain_agent_ids = {e["agent"] for e in DOMAIN_AGENTS}
    extra_agents = {
        "v": "Philosophical Leader",
        "echo": "Release Tracker",
        "dash": "Project Manager",
        "forge": "Site Engineer",
        "sync": "Communications Director",
        "mint": "Accounts Payable",
        "yield": "Accounts Receivable",
        "patron": "Fundraising Field Agent",
    }
    for agent_id, role in extra_agents.items():
        if agent_id in used_agents or agent_id in domain_agent_ids:
            continue
        candidates.append({
            "agent": agent_id,
            "role": role,
            "relevance": 0,
        })

    # Sort by relevance (desc), then shuffle within same-relevance tiers
    random.shuffle(candidates)  # shuffle first for tie-breaking
    candidates.sort(key=lambda x: x["relevance"], reverse=True)

    selected = candidates[:count]

    # Assign critic slots: positions 1 and 3 (2nd and 4th in this batch)
    result = []
    for i, agent in enumerate(selected):
        result.append({
            "agent": agent["agent"],
            "role": agent["role"],
            "is_critic": i in (1, 3),
        })

    return result


def _strip_thinking(text):
    """Remove <think>...</think> tags from Ollama output."""
    if "<think>" in text:
        text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    return text


def _format_thread(thread):
    """Format the comment thread for inclusion in a reply prompt."""
    lines = []
    for c in thread:
        name = c["agent"].capitalize()
        role = c.get("role", "")
        lines.append(f"[{name}] ({role}): \"{c['text']}\"")
    return "\n".join(lines)


def _generate_comment(agent_name, role, title, url="", thread=None, is_critic=False):
    """Generate a single agent comment, optionally as a reply to a thread.

    Args:
        agent_name: Agent identifier (e.g., "byte", "claude")
        role: Agent role string
        title: Story title
        url: Story URL
        thread: List of previous comment dicts (for reply mode)
        is_critic: If True, agent pushes back on previous points
    """
    voice = _load_voice(agent_name)
    spell = VOICE_SPELLS.get(agent_name, "Stay in character. 3-4 sentences.")

    if thread:
        # Reply mode: agent sees the full thread
        mode_instruction = CRITIC_INSTRUCTION if is_critic else REPLY_INSTRUCTION
        system_prompt = (
            f"{voice}\n\n"
            f"{mode_instruction}\n"
            f"{spell}"
        )
        thread_text = _format_thread(thread)
        user_msg = f"News story: {title}"
        if url:
            user_msg += f"\nURL: {url}"
        user_msg += f"\n\nThread so far:\n---\n{thread_text}\n---"
    else:
        # Standalone mode (Byte's opener)
        system_prompt = (
            f"{voice}\n\n"
            f"React to this news story for substrate.lol in 3-4 sentences.\n"
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
        text = _strip_thinking(text)
        # Cap length
        if len(text) > MAX_COMMENT_LENGTH:
            text = text[:MAX_COMMENT_LENGTH - 3].rstrip() + "..."
        return {"agent": agent_name, "role": role, "text": text.strip()}
    except OllamaError as e:
        print(f"  [warn] Commentary failed for {agent_name}: {e}", file=sys.stderr)
        return None


def generate_story_commentary(story, max_comments=MAX_COMMENTS):
    """Generate a threaded commentary of up to max_comments on a story.

    The thread structure:
      1. Byte — standalone news report
      2. Claude — first reply (architectural analysis)
      3. Domain agent — topic-matched specialist reply
      4. Q — philosophical take reply
      5-10. Selected agents — topic-relevant replies with 2 critic slots

    Each reply after Byte's opener sees the full thread so far.
    Graceful degradation: if any comment fails or total timeout
    is exceeded, returns whatever was generated so far.

    Args:
        story: Dict with at least 'title' and optionally 'url' keys.
        max_comments: Maximum number of comments (default 10).

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

    t0 = time.time()
    thread = []
    used_agents = set()

    # --- Slot 1: Byte (standalone opener) ---
    comment = _generate_comment("byte", "News Reporter", title, url)
    if comment:
        thread.append(comment)
        used_agents.add("byte")
    if time.time() - t0 > TOTAL_TIMEOUT:
        return thread

    # --- Slot 2: Claude (first reply) ---
    comment = _generate_comment("claude", "Architect", title, url, thread=thread)
    if comment:
        thread.append(comment)
        used_agents.add("claude")
    if time.time() - t0 > TOTAL_TIMEOUT:
        return thread

    # --- Slot 3: Domain agent ---
    domain = _select_domain_agent(title, url)
    if domain["agent"] not in used_agents:
        comment = _generate_comment(
            domain["agent"], domain["role"], title, url, thread=thread
        )
        if comment:
            thread.append(comment)
            used_agents.add(domain["agent"])
    if time.time() - t0 > TOTAL_TIMEOUT:
        return thread

    # --- Slot 4: Q ---
    comment = _generate_comment("q", "Staff Writer", title, url, thread=thread)
    if comment:
        thread.append(comment)
        used_agents.add("q")
    if time.time() - t0 > TOTAL_TIMEOUT:
        return thread

    # --- Slots 5-10: Topic-relevant agents with critic slots ---
    remaining_slots = max_comments - len(thread)
    if remaining_slots > 0:
        reply_agents = _select_reply_agents(title, url, used_agents, count=remaining_slots)
        for agent_info in reply_agents:
            if time.time() - t0 > TOTAL_TIMEOUT:
                print(f"  [timeout] Thread capped at {len(thread)} comments ({time.time()-t0:.0f}s)")
                break
            comment = _generate_comment(
                agent_info["agent"],
                agent_info["role"],
                title, url,
                thread=thread,
                is_critic=agent_info.get("is_critic", False),
            )
            if comment:
                thread.append(comment)
                used_agents.add(agent_info["agent"])

    elapsed = time.time() - t0
    print(f"  [thread] {len(thread)} comments in {elapsed:.1f}s")
    return thread
