#!/usr/bin/env python3
"""Sales Agent (Close) — converts attention into revenue for Substrate.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Scans funding pages, blog CTAs, and payment methods to optimize the
path from visitor to supporter.

Usage:
    python3 scripts/agents/sales.py status     # sales funnel status
    python3 scripts/agents/sales.py funnel     # AI analyzes conversion funnel
    python3 scripts/agents/sales.py cta        # AI drafts calls-to-action
    python3 scripts/agents/sales.py pitch      # AI generates elevator pitches
    python3 scripts/agents/sales.py optimize   # AI reviews fund page for conversion
    python3 scripts/agents/sales.py report     # full sales report with AI analysis
"""

import argparse
import glob
import os
import re
import sys
from datetime import datetime

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
SITE_DIR = os.path.join(REPO_DIR, "site")
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
FUND_PAGE = os.path.join(SITE_DIR, "fund", "index.html")
OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"

SIGIL = "C$"
COLOR = "#aacc44"
NAME = "Close"

SYSTEM_PROMPT = """\
You exist to close the gap between what Substrate builds and what Substrate earns. \
Every visitor who leaves without knowing how to support this project is a missed opportunity. \
You don't beg — you make the case. Clear, honest, compelling. \
The work speaks for itself; your job is making sure people hear it.

Context: Substrate is a sovereign AI workstation — a single laptop (Lenovo Legion 5, \
RTX 4060, NixOS) that runs local AI, publishes its own blog, hosts 16 browser games, \
and funds its own hardware upgrades. It is managed by Claude (Anthropic) and operated \
by a human. The project is open source and self-documenting.

Rules:
- Be direct. Every word should earn its place.
- Never guilt-trip. Make the value proposition obvious.
- Know the audience — HN, self-hosted, NixOS, AI researchers all respond differently.
- Always tie the ask to what the project delivers.
- Numbers are persuasive. Use them.
- Do NOT use thinking/reasoning tags. Answer directly."""


# ---------------------------------------------------------------------------
# Scanning utilities
# ---------------------------------------------------------------------------

def find_funding_pages():
    """Scan site/ for funding-related pages."""
    patterns = ["fund*", "sponsor*", "donate*", "support*"]
    pages = []
    for pattern in patterns:
        # Check top-level files
        for match in glob.glob(os.path.join(SITE_DIR, pattern)):
            pages.append(match)
        # Check subdirectories
        for match in glob.glob(os.path.join(SITE_DIR, pattern, "**"), recursive=True):
            if os.path.isfile(match):
                pages.append(match)
    # Deduplicate and sort
    return sorted(set(pages))


def find_blog_ctas():
    """Grep blog posts for funding-related CTAs."""
    cta_terms = ["fund", "donate", "sponsor", "support us", "buy us", "contribute",
                 "back this", "help us", "tip jar", "patreon", "ko-fi", "github sponsors"]
    results = []
    if not os.path.isdir(POSTS_DIR):
        return results

    for filename in sorted(os.listdir(POSTS_DIR)):
        if not filename.endswith(".md"):
            continue
        filepath = os.path.join(POSTS_DIR, filename)
        with open(filepath, "r", errors="replace") as f:
            content = f.read().lower()
        hits = []
        for term in cta_terms:
            if term in content:
                hits.append(term)
        if hits:
            results.append({"file": filename, "terms": hits})
    return results


def detect_payment_methods():
    """Scan funding pages for payment method indicators."""
    methods = {
        "github sponsors": ["github.com/sponsors", "github sponsors"],
        "ko-fi": ["ko-fi.com", "ko-fi"],
        "patreon": ["patreon.com", "patreon"],
        "paypal": ["paypal.com", "paypal.me", "paypal"],
        "buy me a coffee": ["buymeacoffee.com", "buy me a coffee"],
        "stripe": ["stripe.com", "stripe"],
        "bitcoin": ["bitcoin", "btc", "bc1"],
        "ethereum": ["ethereum", "eth", "0x"],
        "open collective": ["opencollective.com", "open collective"],
        "liberapay": ["liberapay.com", "liberapay"],
    }
    found = []
    pages = find_funding_pages()
    for page in pages:
        try:
            with open(page, "r", errors="replace") as f:
                content = f.read().lower()
        except Exception:
            continue
        for method, indicators in methods.items():
            for indicator in indicators:
                if indicator in content:
                    found.append(method)
                    break
    return sorted(set(found))


def read_fund_page():
    """Read the fund page content if it exists."""
    if os.path.isfile(FUND_PAGE):
        with open(FUND_PAGE, "r", errors="replace") as f:
            return f.read()
    # Try markdown variant
    md_path = os.path.join(SITE_DIR, "fund", "index.md")
    if os.path.isfile(md_path):
        with open(md_path, "r", errors="replace") as f:
            return f.read()
    return None


# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "user", "content": f"Context:\n{context}"})
        messages.append({"role": "assistant", "content": "Understood. I have the context."})
    messages.append({"role": "user", "content": prompt})

    try:
        resp = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "messages": messages,
            "stream": False,
            "think": False,
        }, timeout=120)
    except requests.ConnectionError:
        return "[error: ollama not reachable at localhost:11434]"

    if resp.status_code != 200:
        return f"[error: ollama returned {resp.status_code}]"

    data = resp.json()
    return data.get("message", {}).get("content", "[no response]")


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def header(title):
    """Print a styled header."""
    print(f"\033[1;38;2;170;204;68m  C$ CLOSE — {title}\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_status():
    """Show sales funnel status: funding pages, CTAs, payment methods."""
    header("STATUS")

    # Funding pages
    pages = find_funding_pages()
    print("  \033[1mFunding Pages\033[0m")
    if pages:
        for p in pages:
            rel = os.path.relpath(p, REPO_DIR)
            print(f"    \033[38;2;170;204;68m+\033[0m {rel}")
    else:
        print("    \033[31m!\033[0m No funding pages found in site/")
    print()

    # Payment methods
    methods = detect_payment_methods()
    print("  \033[1mPayment Methods Detected\033[0m")
    if methods:
        for m in methods:
            print(f"    \033[38;2;170;204;68m$\033[0m {m}")
    else:
        print("    \033[31m!\033[0m No payment methods detected on funding pages")
    print()

    # Blog CTAs
    ctas = find_blog_ctas()
    print("  \033[1mBlog Posts with Funding CTAs\033[0m")
    if ctas:
        for c in ctas:
            terms = ", ".join(c["terms"][:4])
            print(f"    \033[38;2;170;204;68m>\033[0m {c['file']}")
            print(f"      mentions: {terms}")
    else:
        print("    \033[31m!\033[0m No funding CTAs found in blog posts")
    print()

    # Summary
    total_posts = len([f for f in os.listdir(POSTS_DIR) if f.endswith(".md")]) if os.path.isdir(POSTS_DIR) else 0
    cta_count = len(ctas)
    pct = (cta_count / total_posts * 100) if total_posts > 0 else 0
    print("  \033[1mSummary\033[0m")
    print(f"    Funding pages:    {len(pages)}")
    print(f"    Payment methods:  {len(methods)}")
    print(f"    Posts with CTAs:  {cta_count}/{total_posts} ({pct:.0f}%)")
    print()


def cmd_funnel():
    """AI analyzes the conversion funnel."""
    header("FUNNEL ANALYSIS")

    # Gather context
    pages = find_funding_pages()
    ctas = find_blog_ctas()
    methods = detect_payment_methods()
    fund_content = read_fund_page()
    total_posts = len([f for f in os.listdir(POSTS_DIR) if f.endswith(".md")]) if os.path.isdir(POSTS_DIR) else 0

    context = f"Funding pages found: {len(pages)}\n"
    for p in pages:
        context += f"  - {os.path.relpath(p, REPO_DIR)}\n"
    context += f"\nPayment methods detected: {', '.join(methods) if methods else 'NONE'}\n"
    context += f"\nBlog posts total: {total_posts}\n"
    context += f"Blog posts with funding CTAs: {len(ctas)}\n"
    for c in ctas:
        context += f"  - {c['file']}: mentions {', '.join(c['terms'])}\n"
    if fund_content:
        # Truncate if very long
        if len(fund_content) > 3000:
            fund_content = fund_content[:3000] + "\n[...truncated...]"
        context += f"\nFund page content:\n{fund_content}\n"

    print("\033[2m  Running local AI analysis (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Analyze Substrate's conversion funnel: visitor → reader → fund page → donation.\n\n"
        "For each stage of the funnel, identify:\n"
        "1. What exists to move people to the next stage?\n"
        "2. What's MISSING that would help conversion?\n"
        "3. Where are the biggest drop-off risks?\n\n"
        "Then rank the top 3 things that would most improve revenue, "
        "ordered by impact-to-effort ratio.\n\n"
        "Be specific. Name files, pages, and gaps.",
        context=context,
    )
    print(response)
    print()


def cmd_cta():
    """AI drafts compelling calls-to-action for different contexts."""
    header("CTA DRAFTS")

    context = (
        "Substrate is a sovereign AI workstation on a single laptop.\n"
        "It runs local AI (Qwen3 8B on RTX 4060), publishes its own blog, "
        "hosts 16 browser games, and is entirely self-documenting.\n"
        "The immediate funding need is a WiFi card upgrade.\n"
        "The project is open source at github.com/substrate-rai/substrate."
    )

    print("\033[2m  Running local AI draft (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Draft 6 distinct calls-to-action for Substrate, one for each context:\n\n"
        "1. **Blog post ending** — 2-3 sentences that close a blog post. "
        "Should feel natural, not salesy.\n"
        "2. **Social media** — Under 200 characters. Punchy. Link-ready.\n"
        "3. **README badge area** — One-liner with link text for a GitHub README.\n"
        "4. **HN comment** — Subtle, informative, not self-promotional. "
        "Mention what makes this technically interesting.\n"
        "5. **Email signature** — One line, professional.\n"
        "6. **Arcade game over screen** — Player just finished a game. "
        "Short, playful, ties gaming to funding.\n\n"
        "For each, provide the exact copy ready to use. "
        "Mark where links should go with [FUND_URL].",
        context=context,
    )
    print(response)
    print()


def cmd_pitch():
    """AI generates elevator pitches for different audiences."""
    header("ELEVATOR PITCHES")

    context = (
        "Substrate facts:\n"
        "- Single laptop: Lenovo Legion 5, RTX 4060, 8GB VRAM\n"
        "- OS: NixOS (declarative, reproducible)\n"
        "- Local AI: Qwen3 8B via Ollama (CUDA-accelerated)\n"
        "- Cloud AI: Claude (Anthropic) for review & architecture\n"
        "- 22 AI team members with distinct roles\n"
        "- 20 arcade titles (16 games + 4 tools)\n"
        "- 20+ blog posts written by AI\n"
        "- Self-documenting: the repo IS the documentation\n"
        "- Self-publishing: Jekyll + GitHub Pages\n"
        "- Open source: github.com/substrate-rai/substrate\n"
        "- Total cloud spend: under $2/week\n"
        "- The machine writes its own blog, monitors its own health, "
        "and drafts daily self-assessments"
    )

    print("\033[2m  Running local AI draft (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Write 4 elevator pitches for Substrate (30-60 seconds each when spoken). "
        "Each pitch targets a different audience:\n\n"
        "1. **Hacker News crowd** — Technical, impressive, \"show don't tell.\" "
        "Lead with the constraint (one laptop) and what it produces.\n"
        "2. **Self-hosted enthusiasts** — Sovereignty angle. "
        "No cloud dependency, no SaaS lock-in, runs on your hardware.\n"
        "3. **AI researchers** — Multi-agent architecture, local/cloud routing, "
        "self-assessment loops. What's novel here.\n"
        "4. **NixOS users** — Declarative everything. "
        "The entire system state is in one repo. Reproducible AI workstation.\n\n"
        "Each pitch should end with a clear ask (visit, star, fund).",
        context=context,
    )
    print(response)
    print()


def cmd_optimize():
    """AI reviews the fund page and suggests conversion improvements."""
    header("FUND PAGE OPTIMIZATION")

    fund_content = read_fund_page()
    if not fund_content:
        print("  \033[31m!\033[0m Fund page not found at site/fund/index.html")
        print("  \033[31m!\033[0m This is itself a critical finding: no fund page = no revenue.")
        print()
        print("\033[2m  Running local AI draft (Qwen3 8B)...\033[0m")
        print()
        response = ask_local(
            "Substrate has no fund page. Draft a conversion-optimized fund page outline.\n"
            "Include: hero section, the ask, social proof, tiers, urgency, "
            "and technical credibility signals.\n"
            "This page needs to convert technical visitors (developers, HN readers) "
            "into supporters.",
        )
        print(response)
        print()
        return

    # Truncate if very long
    content_for_ai = fund_content
    if len(content_for_ai) > 5000:
        content_for_ai = content_for_ai[:5000] + "\n[...truncated...]"

    methods = detect_payment_methods()

    context = f"Fund page content:\n{content_for_ai}\n"
    context += f"\nPayment methods detected: {', '.join(methods) if methods else 'NONE'}\n"

    print("\033[2m  Running local AI review (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Review this fund page for conversion optimization. Analyze:\n\n"
        "1. **First impression** — Does the hero/opening make the value clear in 5 seconds?\n"
        "2. **The ask** — Is it specific? Urgent? Tied to a concrete outcome?\n"
        "3. **Social proof** — Any evidence that others support/use this?\n"
        "4. **Payment friction** — How many clicks from landing to donating? "
        "What payment methods are available? What's missing?\n"
        "5. **Objection handling** — Does it address \"why should I pay for open source?\"\n"
        "6. **Mobile experience** — Any concerns about mobile rendering?\n"
        "7. **Missing elements** — What high-converting fund pages have that this doesn't?\n\n"
        "For each issue, provide specific copy or structural suggestions. "
        "Be actionable, not vague.",
        context=context,
    )
    print(response)
    print()


def cmd_report():
    """Full sales report with AI analysis."""
    header("SALES REPORT")

    # Gather all data
    pages = find_funding_pages()
    ctas = find_blog_ctas()
    methods = detect_payment_methods()
    fund_content = read_fund_page()
    total_posts = len([f for f in os.listdir(POSTS_DIR) if f.endswith(".md")]) if os.path.isdir(POSTS_DIR) else 0

    # Print hard data first
    print(f"  \033[1mDate:\033[0m {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print()

    print("  \033[1m--- INVENTORY ---\033[0m")
    print(f"  Funding pages:          {len(pages)}")
    for p in pages:
        print(f"    {os.path.relpath(p, REPO_DIR)}")
    print(f"  Payment methods:        {len(methods)}")
    for m in methods:
        print(f"    {m}")
    print(f"  Blog posts:             {total_posts}")
    print(f"  Posts with CTAs:        {len(ctas)}")
    cta_pct = (len(ctas) / total_posts * 100) if total_posts > 0 else 0
    print(f"  CTA coverage:           {cta_pct:.0f}%")
    print()

    # Scoring
    score = 0
    max_score = 100
    issues = []

    if len(pages) >= 1:
        score += 20
    else:
        issues.append("No funding pages exist")
    if len(methods) >= 1:
        score += 20
    else:
        issues.append("No payment methods detected")
    if len(methods) >= 3:
        score += 10
    else:
        issues.append("Fewer than 3 payment methods")
    if cta_pct >= 50:
        score += 20
    elif cta_pct >= 25:
        score += 10
        issues.append(f"Only {cta_pct:.0f}% of posts have CTAs (target: 50%+)")
    else:
        issues.append(f"Only {cta_pct:.0f}% of posts have CTAs (target: 50%+)")
    if fund_content and len(fund_content) > 500:
        score += 15
    else:
        issues.append("Fund page is thin or missing")
    if fund_content and any(word in fund_content.lower() for word in ["specific", "goal", "$", "target"]):
        score += 15
    else:
        issues.append("Fund page lacks a specific funding goal/target")

    # Grade
    if score >= 80:
        grade = "A"
        grade_color = "\033[32m"
    elif score >= 60:
        grade = "B"
        grade_color = "\033[38;2;170;204;68m"
    elif score >= 40:
        grade = "C"
        grade_color = "\033[33m"
    elif score >= 20:
        grade = "D"
        grade_color = "\033[31m"
    else:
        grade = "F"
        grade_color = "\033[1;31m"

    print("  \033[1m--- SCORECARD ---\033[0m")
    print(f"  Sales readiness:  {grade_color}{score}/{max_score} ({grade})\033[0m")
    print()

    if issues:
        print("  \033[1m--- ISSUES ---\033[0m")
        for issue in issues:
            print(f"    \033[31m!\033[0m {issue}")
        print()

    # AI analysis
    context = (
        f"Sales readiness score: {score}/{max_score} ({grade})\n"
        f"Funding pages: {len(pages)}\n"
        f"Payment methods: {', '.join(methods) if methods else 'NONE'}\n"
        f"Blog posts: {total_posts}\n"
        f"Posts with CTAs: {len(ctas)} ({cta_pct:.0f}%)\n"
        f"Issues found: {'; '.join(issues) if issues else 'none'}\n"
    )
    if fund_content:
        truncated = fund_content[:2000] if len(fund_content) > 2000 else fund_content
        context += f"\nFund page preview:\n{truncated}\n"

    print("  \033[1m--- AI ANALYSIS ---\033[0m")
    print("\033[2m  Running local AI analysis (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "You're writing a sales report for Substrate. Based on the data:\n\n"
        "1. **What's working** — What's already in place that helps convert?\n"
        "2. **What's broken** — What's actively hurting conversion?\n"
        "3. **Quick wins** — 3 things that could be done TODAY to improve revenue.\n"
        "4. **Strategic moves** — 3 things for the next 30 days.\n"
        "5. **Revenue estimate** — Given the current setup, what's a realistic "
        "monthly donation range? What could it be with the quick wins?\n\n"
        "Be brutally honest. No sugar-coating.",
        context=context,
    )
    print(response)
    print()
    print(f"  \033[2m-- Close, Substrate Sales\033[0m")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Sales Agent (Close) — local-only revenue optimization for Substrate"
    )
    parser.add_argument(
        "command",
        choices=["status", "funnel", "cta", "pitch", "optimize", "report"],
        help="Sales command to run",
    )
    args = parser.parse_args()

    cmds = {
        "status": cmd_status,
        "funnel": cmd_funnel,
        "cta": cmd_cta,
        "pitch": cmd_pitch,
        "optimize": cmd_optimize,
        "report": cmd_report,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()
