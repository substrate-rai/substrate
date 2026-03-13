#!/usr/bin/env python3
"""News Aggregator — Hourly AI news for substrate.lol homepage.

Fetches headlines from HN + 20 RSS feeds, scores and ranks them,
generates agent commentary on the top 10 via Ollama, writes
_data/news.json, and commits + pushes for GitHub Pages rebuild.

Usage: python3 scripts/agents/news_aggregator.py
"""

import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone, timedelta

# Add agents dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared_news import fetch_all_sources, score_and_rank, signal_score, SOURCE_TIER
from commentary_engine import generate_story_commentary
from ollama_client import is_available

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_DIR = os.path.join(REPO_ROOT, "_data")

COMMENTARY_LIMIT = 10  # Top N stories get commentary
OUTPUT_LIMIT = 60       # Total stories in news.json (increased for ticker + retention)
NEWS_DIR = os.path.join(REPO_ROOT, "news")
STORY_RETAIN_DAYS = 14  # Keep stories in the feed for this many days

# Time-decay parameters
HALF_LIFE_PRIMARY = 18   # hours — primary sources (Anthropic, OpenAI, Google) decay slower
HALF_LIFE_EXTERNAL = 12  # hours — external press
HALF_LIFE_HN = 8         # hours — HN stories decay fastest
SIGNAL_FLOOR = 0.15      # minimum decay for signal stories (keeps them visible ~2 weeks)


def _time_decay(age_hours, half_life, is_signal=False):
    """Exponential time-decay. Returns a multiplier between 0 and 1.

    Signal stories have a minimum floor to keep them visible for weeks.
    """
    decay = math.exp(-math.log(2) * age_hours / half_life)
    if is_signal:
        return max(decay, SIGNAL_FLOOR)
    return decay


def _get_half_life(source):
    """Get the appropriate half-life for a source."""
    if source in ("Anthropic", "Claude Code", "OpenAI", "Google DeepMind", "Google AI"):
        return HALF_LIFE_PRIMARY
    if source == "HN":
        return HALF_LIFE_HN
    return HALF_LIFE_EXTERNAL


def _load_previous_stories():
    """Load stories from the existing news.json for retention/merging.

    Returns a dict of {title: story_entry} for deduplication and merging.
    """
    path = os.path.join(DATA_DIR, "news.json")
    if not os.path.exists(path):
        return {}

    try:
        with open(path) as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        return {}

    now = datetime.now(timezone.utc)
    retained = {}
    for story in data.get("stories", []):
        title = story.get("title", "")
        if not title:
            continue

        # Calculate age from published_at or the file's updated timestamp
        pub = story.get("published_at", data.get("updated", ""))
        age_hours = 0
        if pub:
            try:
                pub_dt = datetime.fromisoformat(pub.replace("Z", "+00:00"))
                age_hours = (now - pub_dt).total_seconds() / 3600
            except (ValueError, TypeError):
                age_hours = 24  # default to 1 day if unparsable

        # Drop stories older than retention window
        if age_hours > STORY_RETAIN_DAYS * 24:
            continue

        story["_age_hours"] = age_hours
        retained[title] = story

    return retained


def _consolidate_claude_code(stories):
    """Merge multiple Claude Code changelog entries into one summary article.

    Returns (consolidated_story_or_None, remaining_stories).
    """
    cc_stories = [s for s in stories if s.get("_source") == "Claude Code"]
    other_stories = [s for s in stories if s.get("_source") != "Claude Code"]

    if not cc_stories:
        return None, stories

    # Build a single summary from all changelog entries
    versions = []
    for s in cc_stories:
        title = s.get("title", "")
        versions.append(title)

    if len(versions) == 1:
        summary_title = versions[0]
    else:
        summary_title = f"Claude Code Updates: {len(versions)} releases this week"

    consolidated = {
        "title": summary_title,
        "url": cc_stories[0].get("url", ""),
        "_source": "Claude Code",
        "_relevance": max(s.get("_relevance", 0) for s in cc_stories),
        "_signal": max(s.get("_signal", 0) for s in cc_stories),
        "_versions": versions,  # Keep individual titles for commentary context
    }

    return consolidated, other_stories


def build_news_json(stories, commentary_limit=COMMENTARY_LIMIT):
    """Build the news.json data structure with optional commentary.

    Merges new stories with retained stories from the previous run,
    applies time-decay scoring, and generates commentary threads
    for the top stories that don't already have commentary.
    """

    # Load previous stories for retention
    previous = _load_previous_stories()
    print(f"  [retain] {len(previous)} stories from previous run")

    # Consolidate Claude Code entries into one summary article
    cc_article, stories = _consolidate_claude_code(stories)

    now = datetime.now(timezone.utc)
    entries = []
    seen = set()
    signal_count = 0
    commentary_count = 0

    # Insert Claude Code consolidated article
    all_stories = list(stories)
    if cc_article:
        all_stories.append(cc_article)

    # Build new entries from fetched stories
    for story in all_stories:
        title = story.get("title", "Untitled")
        if title in seen:
            continue
        seen.add(title)

        source = story.get("_source", "HN")
        is_signal = story.get("_signal", 0) > 3
        if is_signal:
            signal_count += 1

        # Calculate age and time-decay score
        pub_date = story.get("pub_date", "")
        age_hours = 0
        if pub_date:
            try:
                pub_dt = datetime.fromisoformat(pub_date.replace("Z", "+00:00"))
                age_hours = max(0, (now - pub_dt).total_seconds() / 3600)
            except (ValueError, TypeError):
                age_hours = 0

        # If no pub_date, check if story exists in previous run and use its age
        # (prevents dateless stories from ranking #1 forever)
        if not pub_date and title in previous:
            prev_pub = previous[title].get("published_at", "")
            if prev_pub:
                try:
                    pub_dt = datetime.fromisoformat(prev_pub.replace("Z", "+00:00"))
                    age_hours = max(0, (now - pub_dt).total_seconds() / 3600)
                    pub_date = prev_pub  # preserve the timestamp
                except (ValueError, TypeError):
                    pass

        # If still no date, stamp it as "now" so it decays on future runs
        if not pub_date:
            pub_date = now.isoformat()

        half_life = _get_half_life(source)
        decay = _time_decay(age_hours, half_life, is_signal)
        relevance = story.get("_relevance", 0)
        hn_score = story.get("score", 0)
        tier = SOURCE_TIER.get(source, 10)

        # Combined score: (tier + relevance + log boost from HN) * time decay
        combined = (tier + relevance + 0.1 * math.log(1 + hn_score)) * decay

        entry = {
            "title": title,
            "url": story.get("url", ""),
            "source": source,
            "signal": is_signal,
            "relevance": relevance,
            "_combined": combined,
            "_age_hours": age_hours,
        }

        if pub_date:
            entry["published_at"] = pub_date

        if story.get("_versions"):
            entry["versions"] = story["_versions"]

        # HN-specific fields
        hn_id = story.get("id", "")
        if hn_id:
            entry["hn_url"] = f"https://news.ycombinator.com/item?id={hn_id}"
        if hn_score:
            entry["points"] = hn_score
        comments = story.get("descendants", 0)
        if comments:
            entry["comments"] = comments

        # Carry over existing commentary from previous run
        # Re-generate if old format (< 10 comments) to upgrade to threaded commentary
        if title in previous and "commentary" in previous[title]:
            prev_commentary = previous[title]["commentary"]
            if len(prev_commentary) >= 10:
                entry["commentary"] = prev_commentary
            # else: drop old commentary so it gets regenerated with threaded format
            # Also carry over story_url if it existed
            if "story_url" in previous[title]:
                entry["story_url"] = previous[title]["story_url"]

        entries.append(entry)

    # Merge in retained stories that weren't re-fetched this run
    for title, prev_story in previous.items():
        if title in seen:
            continue
        seen.add(title)

        age_hours = prev_story.get("_age_hours", 24)
        source = prev_story.get("source", "HN")
        is_signal = prev_story.get("signal", False)
        half_life = _get_half_life(source)
        decay = _time_decay(age_hours, half_life, is_signal)
        relevance = prev_story.get("relevance", 0)
        hn_score = prev_story.get("points", 0) or 0
        tier = SOURCE_TIER.get(source, 10)
        combined = (tier + relevance + 0.1 * math.log(1 + hn_score)) * decay

        if is_signal:
            signal_count += 1

        # Drop old-format commentary (< 10 comments) so it gets regenerated
        if "commentary" in prev_story and len(prev_story["commentary"]) < 10:
            del prev_story["commentary"]

        prev_story["_combined"] = combined
        entries.append(prev_story)

    # Sort by combined score (time-decay weighted)
    entries.sort(key=lambda x: x.get("_combined", 0), reverse=True)

    # Generate commentary for top stories that don't have it yet
    for entry in entries[:OUTPUT_LIMIT]:
        if "commentary" in entry:
            continue
        if commentary_count >= commentary_limit:
            break
        if not is_available():
            break
        print(f"  Generating commentary for: {entry['title'][:60]}...")
        commentary = generate_story_commentary(entry)
        if commentary:
            entry["commentary"] = commentary
        commentary_count += 1

    # Trim to output limit and clean internal fields
    final_entries = []
    for entry in entries[:OUTPUT_LIMIT]:
        entry.pop("_combined", None)
        entry.pop("_age_hours", None)
        final_entries.append(entry)

    return {
        "updated": now.isoformat(),
        "date": now.strftime("%Y-%m-%d"),
        "total": len(final_entries),
        "signal_count": signal_count,
        "stories": final_entries,
    }


def _slugify(title):
    """Convert title to URL-safe slug."""
    slug = title.lower().strip()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'[\s-]+', '-', slug)
    return slug[:80].rstrip('-')


def _find_related_posts(title, posts_dir):
    """Find blog posts related to a story title by keyword overlap."""
    related = []
    keywords = set(re.findall(r'[a-z]+', title.lower()))
    # Remove common words
    keywords -= {'the', 'a', 'an', 'and', 'or', 'in', 'on', 'to', 'for', 'of',
                 'is', 'are', 'was', 'with', 'from', 'by', 'at', 'its', 'new',
                 'how', 'what', 'why', 'this', 'that', 'has', 'have', 'can'}
    if not keywords:
        return related

    try:
        for fname in os.listdir(posts_dir):
            if not fname.endswith('.md'):
                continue
            # Extract title from filename: YYYY-MM-DD-title.md
            parts = fname[11:-3]  # strip date and .md
            post_words = set(re.findall(r'[a-z]+', parts.lower()))
            overlap = keywords & post_words
            if len(overlap) >= 2:
                # Read frontmatter for actual title
                fpath = os.path.join(posts_dir, fname)
                post_title = parts.replace('-', ' ').title()
                try:
                    with open(fpath) as f:
                        for line in f:
                            if line.startswith('title:'):
                                post_title = line.split(':', 1)[1].strip().strip('"').strip("'")
                                break
                            if line.strip() == '---' and post_title != parts.replace('-', ' ').title():
                                break
                except Exception:
                    pass
                # Build URL from filename
                date_str = fname[:10]
                slug = fname[11:-3]
                y, m, d = date_str.split('-')
                url = f"/{y}/{m}/{d}/{slug}/"
                related.append({"title": post_title, "url": url, "score": len(overlap)})
    except Exception:
        pass

    related.sort(key=lambda x: x["score"], reverse=True)
    return [{"title": r["title"], "url": r["url"]} for r in related[:3]]


def generate_story_pages(data):
    """Generate individual story pages for stories with commentary."""
    date_str = data.get("date", datetime.now(timezone.utc).strftime("%Y-%m-%d"))
    day_dir = os.path.join(NEWS_DIR, date_str)
    os.makedirs(day_dir, exist_ok=True)

    posts_dir = os.path.join(REPO_ROOT, "_posts")
    generated = []

    for story in data.get("stories", []):
        if "commentary" not in story:
            continue

        slug = _slugify(story["title"])
        if not slug:
            continue

        story_dir = os.path.join(day_dir, slug)
        os.makedirs(story_dir, exist_ok=True)

        # Find related blog posts
        related = _find_related_posts(story["title"], posts_dir)

        # Build commentary YAML
        commentary_yaml = ""
        for c in story["commentary"]:
            agent = c.get("agent", "byte")
            role = c.get("role", "")
            text = c.get("text", "").replace('"', '\\"')
            commentary_yaml += f'  - agent: "{agent}"\n'
            if role:
                commentary_yaml += f'    role: "{role}"\n'
            commentary_yaml += f'    text: "{text}"\n'

        # Build related posts YAML
        related_yaml = ""
        for rp in related:
            rp_title = rp["title"].replace('"', '\\"')
            related_yaml += f'  - title: "{rp_title}"\n'
            related_yaml += f'    url: "{rp["url"]}"\n'

        # Build description from first commentary
        desc = story["commentary"][0]["text"][:155].replace('"', '\\"') if story["commentary"] else story["title"]

        # Escape title for YAML
        yaml_title = story["title"].replace('"', '\\"')

        permalink = f"/news/{date_str}/{slug}/"

        frontmatter = f"""---
layout: story
title: "{yaml_title}"
date: {date_str}
description: "{desc}"
source: "{story.get('source', 'HN')}"
source_url: "{story.get('url', '')}"
signal: {str(story.get('signal', False)).lower()}
permalink: "{permalink}"
commentary:
{commentary_yaml}"""

        if related_yaml:
            frontmatter += f"related_posts:\n{related_yaml}"

        frontmatter += "---\n"

        index_path = os.path.join(story_dir, "index.md")
        with open(index_path, "w") as f:
            f.write(frontmatter)

        # Add story_url to the news.json entry for homepage linking
        story["story_url"] = permalink
        generated.append(slug)

    print(f"  [stories] Generated {len(generated)} story pages in {day_dir}")
    return generated


def cleanup_old_story_pages():
    """Remove story page directories older than STORY_RETAIN_DAYS."""
    if not os.path.isdir(NEWS_DIR):
        return
    cutoff = (datetime.now(timezone.utc) - timedelta(days=STORY_RETAIN_DAYS)).strftime("%Y-%m-%d")
    removed = 0
    for name in os.listdir(NEWS_DIR):
        full = os.path.join(NEWS_DIR, name)
        if os.path.isdir(full) and re.match(r'\d{4}-\d{2}-\d{2}$', name) and name < cutoff:
            shutil.rmtree(full)
            removed += 1
    if removed:
        print(f"  [cleanup] Removed {removed} old story page directories")


def write_news_json(data):
    """Write news data to _data/news.json."""
    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, "news.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  [data] Wrote {data['total']} stories to {path}")
    return path


def git_commit_and_push():
    """Commit and push _data/news.json and news/ story pages."""
    news_path = os.path.join(DATA_DIR, "news.json")
    try:
        subprocess.run(
            ["git", "add", news_path, NEWS_DIR],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        result = subprocess.run(
            ["git", "diff", "--cached", "--quiet"],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        if result.returncode == 0:
            print("  [git] No changes to commit.")
            return
        subprocess.run(
            ["git", "commit", "-m", "data: hourly news update"],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        subprocess.run(
            ["git", "push"],
            cwd=REPO_ROOT, capture_output=True, timeout=30,
        )
        print("  [git] Committed and pushed news update.")
    except Exception as e:
        print(f"  [warn] Git operation failed: {e}", file=sys.stderr)


def main():
    print(f"News Aggregator starting at {datetime.now(timezone.utc).isoformat()}")
    print()

    # 1. Fetch from all sources
    stories = fetch_all_sources()
    if not stories:
        print("No stories fetched. Exiting.", file=sys.stderr)
        sys.exit(1)

    # 2. Score and rank
    ranked = score_and_rank(stories)
    print(f"\nFetched {len(ranked)} relevant stories.")

    # 3. Build news.json (merge with retained stories, apply time-decay,
    #    generate threaded commentary if Ollama available)
    if is_available():
        print(f"\nOllama available. Generating threaded commentary (up to 10 agents) for top {COMMENTARY_LIMIT} stories...")
    else:
        print("\nOllama unavailable. Outputting headlines only.")

    data = build_news_json(ranked)

    # 4. Generate individual story pages (before writing json so story_url is included)
    generate_story_pages(data)

    # 5. Clean up old story pages (>7 days)
    cleanup_old_story_pages()

    # 6. Write output
    write_news_json(data)

    # 7. Commit and push
    git_commit_and_push()

    print(f"\nDone. {data['total']} stories, {data['signal_count']} signal.")
    print(f"Commentary: {sum(1 for s in data['stories'] if 'commentary' in s)} stories with agent comments.")


if __name__ == "__main__":
    main()
