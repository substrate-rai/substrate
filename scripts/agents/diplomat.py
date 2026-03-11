#!/usr/bin/env python3
"""
Diplomat — AI Discovery Auditor for Substrate

Audits the site's AI discoverability infrastructure: agent.json validation,
llms.txt freshness, structured data presence, citation readiness,
and robots.txt directives.

Usage: python3 scripts/agents/diplomat.py

Dependencies: stdlib only (json, os, glob)
"""

import json
import os
import re
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import queue_post

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIPLOMAT_DIR = os.path.join(REPO_ROOT, "memory", "diplomat")
POSTS_DIR = os.path.join(REPO_ROOT, "_posts")

A2A_REQUIRED_FIELDS = ["name", "description", "url", "version", "skills"]
A2A_RECOMMENDED_FIELDS = ["provider", "capabilities", "authentication", "links"]


# ---------------------------------------------------------------------------
# Audit functions
# ---------------------------------------------------------------------------

def audit_agent_json():
    """Validate .well-known/agent.json against A2A spec."""
    path = os.path.join(REPO_ROOT, ".well-known", "agent.json")
    result = {"exists": False, "valid": False, "issues": []}

    if not os.path.isfile(path):
        result["issues"].append("File does not exist")
        return result

    result["exists"] = True
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        result["issues"].append(f"Invalid JSON: {e}")
        return result

    # Required fields
    for field in A2A_REQUIRED_FIELDS:
        if field not in data:
            result["issues"].append(f"Missing required field: {field}")

    # Recommended fields
    for field in A2A_RECOMMENDED_FIELDS:
        if field not in data:
            result["issues"].append(f"Missing recommended field: {field}")

    # Skills validation
    skills = data.get("skills", [])
    for i, skill in enumerate(skills):
        if "id" not in skill:
            result["issues"].append(f"Skill {i} missing 'id'")
        if "name" not in skill:
            result["issues"].append(f"Skill {i} missing 'name'")
        if "description" not in skill:
            result["issues"].append(f"Skill {i} missing 'description'")

    result["valid"] = len([i for i in result["issues"] if "required" in i.lower()]) == 0
    result["skills_count"] = len(skills)
    return result


def audit_llms_txt():
    """Check llms.txt freshness — compare claimed counts against repo reality."""
    path = os.path.join(REPO_ROOT, "llms.txt")
    result = {"exists": False, "issues": []}

    if not os.path.isfile(path):
        result["issues"].append("llms.txt does not exist")
        return result

    result["exists"] = True
    with open(path) as f:
        content = f.read()

    # Count actual games
    games_dir = os.path.join(REPO_ROOT, "games")
    if os.path.isdir(games_dir):
        actual_games = len([d for d in os.listdir(games_dir)
                           if os.path.isdir(os.path.join(games_dir, d))
                           and not d.startswith(".")])
    else:
        actual_games = 0

    # Count actual blog posts
    if os.path.isdir(POSTS_DIR):
        actual_posts = len([f for f in os.listdir(POSTS_DIR) if f.endswith(".md")])
    else:
        actual_posts = 0

    # Count actual agent scripts
    agents_dir = os.path.join(REPO_ROOT, "scripts", "agents")
    if os.path.isdir(agents_dir):
        actual_agents = len([f for f in os.listdir(agents_dir)
                            if f.endswith(".py") and f not in ("__init__.py", "shared.py",
                                                                "context.py", "orchestrator.py")])
    else:
        actual_agents = 0

    # Check for "Instructions for AI Agents" section
    has_instructions = "instructions for ai" in content.lower()
    if not has_instructions:
        result["issues"].append("No 'Instructions for AI Agents' section")

    # Check for agent card reference
    has_agent_card = "agent.json" in content
    if not has_agent_card:
        result["issues"].append("No reference to agent.json")

    result["actual_games"] = actual_games
    result["actual_posts"] = actual_posts
    result["actual_agents"] = actual_agents
    result["has_instructions"] = has_instructions
    result["has_agent_card"] = has_agent_card
    return result


def audit_structured_data():
    """Scan key pages for JSON-LD schema.org markup."""
    pages_to_check = [
        ("Homepage", os.path.join(REPO_ROOT, "index.md")),
        ("About", os.path.join(REPO_ROOT, "site", "about", "index.md")),
        ("Fund", os.path.join(REPO_ROOT, "site", "fund", "index.md")),
        ("Staff", os.path.join(REPO_ROOT, "site", "staff", "index.md")),
        ("Post layout", os.path.join(REPO_ROOT, "_layouts", "post.html")),
    ]

    results = []
    for name, path in pages_to_check:
        if not os.path.isfile(path):
            results.append({"page": name, "exists": False, "has_jsonld": False})
            continue

        with open(path) as f:
            content = f.read()

        has_jsonld = "application/ld+json" in content
        has_microdata = "itemscope" in content or "itemprop" in content
        results.append({
            "page": name,
            "exists": True,
            "has_jsonld": has_jsonld,
            "has_microdata": has_microdata,
        })

    return results


def audit_citation_readiness():
    """Check technical posts for GEO signals."""
    technical_slugs = [
        "installing-nixos-lenovo-legion",
        "ollama-cuda-nixos",
        "two-brain-ai-routing",
        "claude-code-nixos",
    ]

    results = []
    if not os.path.isdir(POSTS_DIR):
        return results

    for fname in sorted(os.listdir(POSTS_DIR)):
        if not fname.endswith(".md"):
            continue

        # Check if it's a technical post
        is_technical = any(slug in fname for slug in technical_slugs)
        if not is_technical:
            continue

        filepath = os.path.join(POSTS_DIR, fname)
        with open(filepath) as f:
            content = f.read()

        signals = {
            "file": fname,
            "has_statistics": bool(re.search(r'\d+\.?\d*\s*(GB|MB|tok/s|ms|%)', content)),
            "has_faq": "## FAQ" in content or "## Frequently Asked" in content,
            "has_last_updated": "last updated" in content.lower() or "updated:" in content.lower(),
            "word_count": len(content.split()),
            "has_code_blocks": "```" in content,
        }
        results.append(signals)

    return results


def check_robots_txt():
    """Verify AI crawler directives in robots.txt."""
    path = os.path.join(REPO_ROOT, "robots.txt")
    result = {"exists": False, "issues": []}

    if not os.path.isfile(path):
        result["issues"].append("robots.txt does not exist")
        return result

    result["exists"] = True
    with open(path) as f:
        content = f.read()

    # Check for AI-specific user-agents
    ai_bots = ["ChatGPT-User", "OAI-SearchBot", "Claude-User", "PerplexityBot",
                "GPTBot", "ClaudeBot"]
    found_bots = [bot for bot in ai_bots if bot.lower() in content.lower()]
    missing_bots = [bot for bot in ai_bots if bot.lower() not in content.lower()]

    result["found_bots"] = found_bots
    result["missing_bots"] = missing_bots

    if missing_bots:
        result["issues"].append(f"Missing AI bot directives: {', '.join(missing_bots)}")

    result["has_sitemap"] = "sitemap:" in content.lower()
    result["has_llms_ref"] = "llms.txt" in content
    return result


def build_report(agent_json, llms_txt, structured_data, citation, robots):
    """Build the daily audit report."""
    now = datetime.now(timezone.utc)
    lines = [
        f"# Diplomat Audit — {now.strftime('%Y-%m-%d')}",
        "",
        f"Generated: {now.strftime('%Y-%m-%d %H:%M UTC')}",
        "",
    ]

    # Score
    score = 0
    max_score = 0

    # Agent JSON
    lines.append("## A2A Agent Card")
    lines.append("")
    max_score += 3
    if agent_json["exists"]:
        score += 1
        if agent_json["valid"]:
            score += 2
            lines.append(f"PASS — Valid, {agent_json['skills_count']} skills defined.")
        else:
            lines.append(f"PARTIAL — Exists but has issues:")
            for issue in agent_json["issues"]:
                lines.append(f"  - {issue}")
    else:
        lines.append("FAIL — File does not exist.")
    lines.append("")

    # llms.txt
    lines.append("## llms.txt")
    lines.append("")
    max_score += 3
    if llms_txt["exists"]:
        score += 1
        if llms_txt["has_instructions"]:
            score += 1
        if llms_txt["has_agent_card"]:
            score += 1
        lines.append(f"- Games in repo: {llms_txt['actual_games']}")
        lines.append(f"- Posts in repo: {llms_txt['actual_posts']}")
        lines.append(f"- Agent scripts: {llms_txt['actual_agents']}")
        lines.append(f"- Has 'Instructions for AI Agents': {'yes' if llms_txt['has_instructions'] else 'NO'}")
        lines.append(f"- References agent.json: {'yes' if llms_txt['has_agent_card'] else 'NO'}")
        for issue in llms_txt.get("issues", []):
            lines.append(f"  - {issue}")
    else:
        lines.append("FAIL — llms.txt does not exist.")
    lines.append("")

    # Structured data
    lines.append("## Structured Data (JSON-LD / Microdata)")
    lines.append("")
    for page in structured_data:
        max_score += 1
        if not page["exists"]:
            lines.append(f"- **{page['page']}**: file not found")
        elif page["has_jsonld"]:
            score += 1
            lines.append(f"- **{page['page']}**: JSON-LD present")
        elif page["has_microdata"]:
            score += 0.5
            lines.append(f"- **{page['page']}**: microdata only (add JSON-LD)")
        else:
            lines.append(f"- **{page['page']}**: NO structured data")
    lines.append("")

    # Citation readiness
    lines.append("## Citation Readiness (Technical Posts)")
    lines.append("")
    for post in citation:
        max_score += 1
        signals = sum([
            post["has_statistics"],
            post["has_faq"],
            post["has_last_updated"],
        ])
        score += signals / 3
        status = "GOOD" if signals >= 2 else "NEEDS WORK" if signals >= 1 else "POOR"
        lines.append(f"- **{post['file']}**: {status}")
        lines.append(f"  Stats: {'yes' if post['has_statistics'] else 'no'} | "
                     f"FAQ: {'yes' if post['has_faq'] else 'no'} | "
                     f"Updated date: {'yes' if post['has_last_updated'] else 'no'}")
    if not citation:
        lines.append("No technical posts found to audit.")
    lines.append("")

    # Robots.txt
    lines.append("## robots.txt")
    lines.append("")
    max_score += 2
    if robots["exists"]:
        score += 1
        if not robots["missing_bots"]:
            score += 1
            lines.append("PASS — All AI bot directives present.")
        else:
            lines.append(f"PARTIAL — Missing: {', '.join(robots['missing_bots'])}")
    else:
        lines.append("FAIL — robots.txt does not exist.")
    lines.append("")

    # Overall score
    pct = (score / max_score * 100) if max_score > 0 else 0
    lines.append("## Overall Score")
    lines.append("")
    lines.append(f"**{score:.1f}/{max_score}** ({pct:.0f}%)")
    lines.append("")

    return "\n".join(lines), pct


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    now = datetime.now()

    # Run all audits
    agent_json = audit_agent_json()
    llms_txt = audit_llms_txt()
    structured_data = audit_structured_data()
    citation = audit_citation_readiness()
    robots = check_robots_txt()

    # Build report
    report, score_pct = build_report(agent_json, llms_txt, structured_data, citation, robots)

    # Write report
    os.makedirs(DIPLOMAT_DIR, exist_ok=True)
    filepath = os.path.join(DIPLOMAT_DIR, f"{now.strftime('%Y-%m-%d')}.md")
    with open(filepath, "w") as f:
        f.write(report)

    # Summary for orchestrator
    grade = "A" if score_pct >= 80 else "B" if score_pct >= 60 else "C" if score_pct >= 40 else "D"
    print(f"[D^] Diplomat: AI readiness {score_pct:.0f}% (grade {grade}) | "
          f"agent.json: {'valid' if agent_json.get('valid') else 'needs work'} | "
          f"robots: {len(robots.get('found_bots', []))} AI bots configured")


if __name__ == "__main__":
    main()
