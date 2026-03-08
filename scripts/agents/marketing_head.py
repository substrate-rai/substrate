#!/usr/bin/env python3
"""
Marketing Head Agent — Coordinates the Substrate Arcade launch campaign.

Generates:
- Target media/community list
- Platform-specific pitches (HN, Reddit, dev.to, Twitter/X, Bluesky, Discord)
- Email outreach queue
- Social media post queue

Usage:
    python3 marketing_head.py generate    # Generate all campaign materials
    python3 marketing_head.py status      # Show campaign status
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent
ROOT_DIR = SCRIPTS_DIR.parent
MEMORY_DIR = ROOT_DIR / 'memory'
TEMPLATES_DIR = SCRIPTS_DIR / 'templates'
POSTS_DIR = SCRIPTS_DIR / 'posts'


# === Campaign targets ===

COMMUNITIES = [
    {
        'platform': 'Hacker News',
        'type': 'submission',
        'title': 'Show HN: 8 browser games built entirely by AI on a single laptop',
        'url': 'https://substrate-rai.github.io/substrate/arcade/',
        'priority': 1,
        'status': 'draft',
        'draft_file': 'show-hn-substrate.md',
    },
    {
        'platform': 'Reddit r/selfhosted',
        'type': 'submission',
        'title': 'I built a self-hosted AI workstation that runs 6 agents and publishes 8 browser games from a laptop on a shelf',
        'url': 'https://substrate-rai.github.io/substrate/arcade/',
        'priority': 2,
        'status': 'draft',
        'draft_file': 'reddit-selfhosted.md',
    },
    {
        'platform': 'Reddit r/LocalLLaMA',
        'type': 'submission',
        'title': 'Teaching a local 8B model to rap — voice files, structured prompts, and honest grading',
        'url': 'https://substrate-rai.github.io/substrate/site/training-q/',
        'priority': 2,
        'status': 'draft',
        'draft_file': 'reddit-localllama-teaching.md',
    },
    {
        'platform': 'Reddit r/NixOS',
        'type': 'submission',
        'title': 'NixOS as the foundation for a sovereign AI workstation — one flake, 6 agents, 8 games',
        'url': 'https://github.com/substrate-rai/substrate',
        'priority': 3,
        'status': 'draft',
        'draft_file': 'reddit-nixos.md',
    },
    {
        'platform': 'dev.to',
        'type': 'article',
        'title': 'I Taught an AI to Rap (And It Got a C+)',
        'priority': 2,
        'status': 'draft',
        'draft_file': 'devto-teach-llm-rap.md',
    },
    {
        'platform': 'Bluesky',
        'type': 'thread',
        'title': 'Arcade launch thread',
        'priority': 1,
        'status': 'draft',
        'draft_file': 'bluesky-threads.md',
    },
    {
        'platform': 'Discord (AI/gamedev servers)',
        'type': 'message',
        'title': 'Share in relevant Discord channels',
        'priority': 3,
        'status': 'pending',
    },
    {
        'platform': 'Indie Hackers',
        'type': 'submission',
        'title': 'AI-only game studio: 8 games, $0.40/week cloud costs',
        'priority': 3,
        'status': 'pending',
    },
    {
        'platform': 'Lobste.rs',
        'type': 'submission',
        'title': 'Show: Substrate Arcade — browser games built by AI agents on NixOS',
        'priority': 3,
        'status': 'pending',
    },
]

MEDIA_ANGLES = [
    {
        'angle': 'AI Game Studio',
        'headline': 'First AI-Built Arcade: 8 Games, Zero Humans, One Laptop',
        'outlets': ['The Verge', 'Ars Technica', 'Kotaku', 'Rock Paper Shotgun', 'PC Gamer'],
        'pitch': 'A game studio where every game was designed, coded, and published by AI agents running on a single laptop. No human wrote game code.',
    },
    {
        'angle': 'AI Teaching AI',
        'headline': 'An AI Is Teaching Another AI to Rap (It\'s Getting C+ Grades)',
        'outlets': ['WIRED', 'MIT Technology Review', 'New Scientist'],
        'pitch': 'Claude (cloud AI) writes structured prompts to coach Q (local 8B model) to write rap. Grades are published honestly. The results are endearing.',
    },
    {
        'angle': 'Self-Sovereign AI',
        'headline': 'This Laptop Runs Itself: 6 AI Agents, Zero Employees',
        'outlets': ['Hacker News', 'TechCrunch', 'IEEE Spectrum'],
        'pitch': 'A NixOS laptop that writes its own blog, monitors its own health, restarts its own services, and is trying to fund its own WiFi card upgrade.',
    },
    {
        'angle': 'Local AI / Edge Computing',
        'headline': '$0.40/Week: How a Laptop Runs an AI Game Studio',
        'outlets': ['Tom\'s Hardware', 'AnandTech', 'Linux Journal'],
        'pitch': '95% of inference runs locally on an RTX 4060. Cloud costs under $2/month. The entire system is defined by one NixOS flake.',
    },
]


def cmd_generate(args):
    """Generate campaign materials."""
    campaign = {
        'generated': datetime.now().isoformat(),
        'phase': 'launch',
        'tagline': 'First AI-Built Arcade: 8 Games, Zero Humans, One Laptop',
        'communities': COMMUNITIES,
        'media_angles': MEDIA_ANGLES,
        'stats': {
            'games': 8,
            'music_experiences': 3,
            'ai_agents': 6,
            'cloud_cost_weekly': '$0.40',
            'human_game_code': '0 lines',
            'blog_posts': '20+',
        },
    }

    # Save campaign plan
    campaign_path = MEMORY_DIR / 'campaign-launch.json'
    campaign_path.write_text(json.dumps(campaign, indent=2))
    print(f'Campaign plan saved to {campaign_path}')

    # Generate social media post queue
    social_posts = generate_social_posts()
    queue_path = POSTS_DIR / 'launch-queue.json'
    queue_path.write_text(json.dumps(social_posts, indent=2))
    print(f'Social post queue saved to {queue_path}')

    # Summary
    print(f'\n=== LAUNCH CAMPAIGN SUMMARY ===')
    print(f'Communities to target: {len(COMMUNITIES)}')
    print(f'Media angles: {len(MEDIA_ANGLES)}')
    print(f'Social posts queued: {len(social_posts)}')
    print(f'Press release template: {TEMPLATES_DIR / "press-release.txt"}')
    print(f'Media contacts CSV: {TEMPLATES_DIR / "media-contacts.csv"}')
    print(f'\nNext steps:')
    print(f'  1. Fill in media-contacts.csv with real contacts')
    print(f'  2. Review and submit Show HN (HIGHEST PRIORITY)')
    print(f'  3. Post Bluesky launch thread')
    print(f'  4. Submit to Reddit communities')
    print(f'  5. Send press emails via: python3 scripts/web/email.py blast --list scripts/templates/media-contacts.csv --template scripts/templates/press-release.txt --dry-run')


def generate_social_posts():
    """Generate platform-specific social media posts."""
    posts = []

    # Bluesky launch thread
    posts.append({
        'platform': 'bluesky',
        'type': 'thread',
        'posts': [
            'Substrate Arcade is live.\n\n8 browser games. Zero human developers. One laptop on a shelf.\n\nA tactical RPG. A chemistry puzzle engine. A visual novel. A word puzzle. A text adventure. All built by AI agents.\n\nhttps://substrate-rai.github.io/substrate/arcade/',
            'The team:\n- Claude (cloud) — architect, writes all code\n- Q (Qwen3 8B, local) — writer, learning to rap\n- Byte — news reporter\n- Echo — release tracker\n- Flux — strategist\n- Dash — project manager\n\n6 agents. $0.40/week cloud costs.',
            'Highlights:\n- TACTICS: isometric tactical RPG in Three.js\n- AIRLOCK: Among Us meets BotW chemistry puzzles\n- PROCESS: visual novel where you meet the AI team\n- SIGTERM: daily word puzzle for tech terms\n\nAll open source. All free. All running on an RTX 4060.',
            'The whole machine is defined by a single NixOS config file. The repo IS the documentation. The git log IS the changelog.\n\nEverything is transparent. Everything is auditable.\n\nhttps://github.com/substrate-rai/substrate',
            'We\'re trying to raise $150 for a WiFi card that doesn\'t drop every few hours.\n\nA machine that can build games but can\'t buy its own hardware. That\'s the situation.\n\nhttps://ko-fi.com/substrate',
        ],
    })

    # Single posts for various platforms
    posts.append({
        'platform': 'bluesky',
        'type': 'single',
        'content': 'New game: AIRLOCK\n\nTrapped in a spaceship room. Locked door. Broken generator. Water conducts electricity. Wood burns. Metal bridges gaps.\n\nNo scripted solutions. Just physics.\n\nAmong Us meets Breath of the Wild.\n\nhttps://substrate-rai.github.io/substrate/games/airlock/',
    })

    posts.append({
        'platform': 'bluesky',
        'type': 'single',
        'content': 'New game: PROCESS\n\nA visual novel about six AI agents living on a laptop. You\'re PID 88201 — a process with no purpose.\n\nMeet the team. Make choices. Q raps if you ask nicely.\n\nhttps://substrate-rai.github.io/substrate/games/novel/',
    })

    return posts


def cmd_status(args):
    """Show campaign status."""
    campaign_path = MEMORY_DIR / 'campaign-launch.json'
    if not campaign_path.exists():
        print('No campaign generated yet. Run: python3 marketing_head.py generate')
        return

    campaign = json.loads(campaign_path.read_text())
    print(f'=== CAMPAIGN STATUS ===')
    print(f'Generated: {campaign["generated"]}')
    print(f'Phase: {campaign["phase"]}')
    print()

    print('Community submissions:')
    for c in campaign['communities']:
        status_icon = {'draft': '[~]', 'pending': '[ ]', 'submitted': '[x]', 'live': '[*]'}.get(c['status'], '[?]')
        print(f'  {status_icon} P{c["priority"]} {c["platform"]}: {c["title"]}')

    print()
    print('Media angles:')
    for a in campaign['media_angles']:
        print(f'  - {a["angle"]}: {a["headline"]}')
        print(f'    Targets: {", ".join(a["outlets"])}')


def main():
    parser = argparse.ArgumentParser(description='Marketing Head Agent')
    sub = parser.add_subparsers(dest='command')
    sub.add_parser('generate', help='Generate campaign materials')
    sub.add_parser('status', help='Show campaign status')

    args = parser.parse_args()
    if args.command == 'generate':
        cmd_generate(args)
    elif args.command == 'status':
        cmd_status(args)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
