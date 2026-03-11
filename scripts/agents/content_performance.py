#!/usr/bin/env python3
"""Content Performance Tracker for Substrate.

Parses all blog posts, correlates with GoatCounter metrics and social queue
engagement, and generates a ranked performance report.

Works with zero external data — falls back to internal signals (word count,
tag popularity, post frequency, category, author).

Usage:
    python3 scripts/agents/content_performance.py          # generate report
    python3 scripts/agents/content_performance.py --json    # JSON output
"""

import glob
import json
import os
import re
from collections import Counter
from datetime import datetime

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
METRICS_DIR = os.path.join(REPO_DIR, "memory", "metrics")
QUEUE_FILE = os.path.join(REPO_DIR, "scripts", "posts", "queue.jsonl")
OUTPUT_DIR = os.path.join(REPO_DIR, "memory", "content-performance")

# ---------------------------------------------------------------------------
# Blog post parsing
# ---------------------------------------------------------------------------

def parse_all_posts():
    """Parse every blog post in _posts/ and extract metadata."""
    posts = []
    for path in sorted(glob.glob(os.path.join(POSTS_DIR, "*.md"))):
        meta = _parse_post(path)
        if meta:
            posts.append(meta)
    return posts


def _parse_post(path):
    """Extract metadata from a single post file."""
    filename = os.path.basename(path)
    match = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)\.md$", filename)
    if not match:
        return None

    date_str = match.group(1)
    slug = match.group(2)

    meta = {
        "date": date_str,
        "slug": slug,
        "title": slug.replace("-", " ").title(),
        "author": "unknown",
        "category": "log",
        "tags": [],
        "series": None,
        "word_count": 0,
        "description": "",
        "draft": False,
        "layout": "post",
        "path": path,
    }

    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except (IOError, OSError):
        return meta

    # Split front matter
    parts = content.split("---", 2)
    if len(parts) >= 3:
        front = parts[1]
        body = parts[2]
    else:
        front = ""
        body = content

    meta["word_count"] = len(body.split())

    # Parse YAML-ish front matter (no PyYAML dependency)
    for line in front.splitlines():
        line = line.strip()
        if line.startswith("title:"):
            meta["title"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("author:"):
            meta["author"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("category:"):
            meta["category"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("layout:"):
            meta["layout"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("series:"):
            meta["series"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("description:"):
            meta["description"] = line.split(":", 1)[1].strip().strip("\"'")
        elif line.startswith("draft:"):
            val = line.split(":", 1)[1].strip().lower()
            meta["draft"] = val in ("true", "yes")
        elif line.startswith("published:"):
            val = line.split(":", 1)[1].strip().lower()
            if val == "false":
                meta["draft"] = True
        elif line.startswith("tags:"):
            raw = line.split(":", 1)[1].strip()
            # Handle [tag1, tag2] or tag1, tag2
            raw = raw.strip("[]")
            meta["tags"] = [t.strip().strip("\"'") for t in raw.split(",") if t.strip()]

    return meta


# ---------------------------------------------------------------------------
# GoatCounter metrics (from memory/metrics/*.md)
# ---------------------------------------------------------------------------

def load_goatcounter_metrics():
    """Load page-level traffic data from the latest metrics file.

    Returns dict: {page_path: {"views": int, "unique": int}} or empty dict.
    Also returns totals: {"total_views": int, "unique_visitors": int, "date": str}.
    """
    if not os.path.isdir(METRICS_DIR):
        return {}, {}

    files = sorted(glob.glob(os.path.join(METRICS_DIR, "????-??-??.md")))
    if not files:
        return {}, {}

    latest = files[-1]
    date = os.path.basename(latest).replace(".md", "")

    try:
        with open(latest, encoding="utf-8", errors="replace") as f:
            content = f.read()
    except (IOError, OSError):
        return {}, {}

    totals = {"date": date}
    pages = {}

    for line in content.splitlines():
        line = line.strip()
        if line.startswith("- **Total views:**"):
            try:
                totals["total_views"] = int(line.split("**")[2].strip().replace(",", ""))
            except (ValueError, IndexError):
                pass
        elif line.startswith("- **Unique visitors:**"):
            try:
                totals["unique_visitors"] = int(line.split("**")[2].strip().replace(",", ""))
            except (ValueError, IndexError):
                pass

    # Parse the top pages table (markdown table format)
    in_table = False
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("| Page"):
            in_table = True
            continue
        if in_table and line.startswith("|---"):
            continue
        if in_table and line.startswith("|"):
            cols = [c.strip() for c in line.split("|")]
            # cols[0] is empty (leading |), cols[1]=page, cols[2]=views, cols[3]=unique
            if len(cols) >= 4:
                page = cols[1].strip()
                try:
                    views = int(cols[2].strip().replace(",", ""))
                    unique = int(cols[3].strip().replace(",", ""))
                    pages[page] = {"views": views, "unique": unique}
                except (ValueError, IndexError):
                    pass
        elif in_table and not line.startswith("|"):
            in_table = False

    return pages, totals


# ---------------------------------------------------------------------------
# Social queue engagement
# ---------------------------------------------------------------------------

def load_social_engagement():
    """Analyze social queue for engagement signals.

    Returns per-slug stats: how many social posts mention each blog slug,
    and how many were sent vs pending.
    """
    if not os.path.exists(QUEUE_FILE):
        return {}

    slug_stats = {}  # slug -> {"mentions": int, "sent": int, "pending": int}

    try:
        with open(QUEUE_FILE, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                text = entry.get("text", "").lower()
                status = entry.get("status", "pending")

                # Check if this post references a blog URL
                # Patterns: substrate.lol/blog/SLUG/ or just keyword match
                url_match = re.findall(r"substrate\.lol/blog/([a-z0-9-]+)", text)
                for slug in url_match:
                    if slug not in slug_stats:
                        slug_stats[slug] = {"mentions": 0, "sent": 0, "pending": 0}
                    slug_stats[slug]["mentions"] += 1
                    if status == "sent":
                        slug_stats[slug]["sent"] += 1
                    else:
                        slug_stats[slug]["pending"] += 1

    except (IOError, OSError):
        pass

    return slug_stats


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def compute_scores(posts, page_traffic, social_engagement):
    """Score each post on multiple dimensions and compute a composite rank.

    Scoring factors (each 0-10, weighted):
      - traffic_score:   GoatCounter views (if available)     weight: 3
      - social_score:    social queue mentions/sent            weight: 2
      - length_score:    word count (longer guides score more) weight: 1
      - recency_score:   how recent the post is                weight: 1
      - tag_score:       uses popular tags                     weight: 1
      - category_bonus:  guides get a boost                    weight: 1

    Returns list of post dicts with scores, sorted by composite descending.
    """
    today = datetime.now()

    # Pre-compute global stats for relative scoring
    all_word_counts = [p["word_count"] for p in posts if p["word_count"] > 0]
    max_words = max(all_word_counts) if all_word_counts else 1

    # Tag frequency across all posts
    tag_counter = Counter()
    for p in posts:
        tag_counter.update(p["tags"])

    # Max social mentions
    max_mentions = max((s["mentions"] for s in social_engagement.values()), default=1)

    # Max page views
    max_views = 1
    for pdata in page_traffic.values():
        if pdata.get("views", 0) > max_views:
            max_views = pdata["views"]

    scored = []
    for post in posts:
        slug = post["slug"]

        # Traffic score (0-10)
        traffic = 0
        # Check various URL patterns that GoatCounter might use
        for page_key, pdata in page_traffic.items():
            if slug in page_key:
                traffic = pdata.get("views", 0)
                break
        traffic_score = min(10, (traffic / max_views) * 10) if max_views > 0 else 0

        # Social score (0-10)
        social = social_engagement.get(slug, {})
        mentions = social.get("mentions", 0)
        sent = social.get("sent", 0)
        social_raw = mentions + sent  # sent posts count double (they got published)
        social_score = min(10, (social_raw / max(max_mentions, 1)) * 10)

        # Length score (0-10): longer, in-depth posts score higher
        wc = post["word_count"]
        length_score = min(10, (wc / max_words) * 10) if max_words > 0 else 0

        # Recency score (0-10): newer posts score higher
        try:
            post_date = datetime.strptime(post["date"], "%Y-%m-%d")
            days_ago = (today - post_date).days
            recency_score = max(0, 10 - days_ago)  # loses 1 point per day
        except ValueError:
            recency_score = 0

        # Tag popularity score (0-10)
        if post["tags"]:
            avg_tag_freq = sum(tag_counter[t] for t in post["tags"]) / len(post["tags"])
            max_tag_freq = max(tag_counter.values()) if tag_counter else 1
            tag_score = min(10, (avg_tag_freq / max_tag_freq) * 10)
        else:
            tag_score = 0

        # Category bonus
        cat = post.get("category", "")
        category_bonus = 0
        if cat == "guide":
            category_bonus = 8  # guides have evergreen value
        elif cat == "news":
            category_bonus = 4  # news is timely but fades
        elif cat == "discussion":
            category_bonus = 5  # discussions drive engagement
        else:
            category_bonus = 2  # project logs are niche

        # Composite score (weighted)
        composite = (
            traffic_score * 3.0
            + social_score * 2.0
            + length_score * 1.0
            + recency_score * 1.0
            + tag_score * 1.0
            + category_bonus * 1.0
        ) / 9.0  # normalize to 0-10

        post_scored = dict(post)
        post_scored["scores"] = {
            "traffic": round(traffic_score, 1),
            "social": round(social_score, 1),
            "length": round(length_score, 1),
            "recency": round(recency_score, 1),
            "tags": round(tag_score, 1),
            "category": round(category_bonus, 1),
            "composite": round(composite, 1),
        }
        scored.append(post_scored)

    scored.sort(key=lambda p: p["scores"]["composite"], reverse=True)
    return scored


# ---------------------------------------------------------------------------
# Aggregation & insights
# ---------------------------------------------------------------------------

def compute_insights(scored_posts):
    """Derive insights from scored posts.

    Returns a dict with:
      - top_categories: ranked categories by avg composite score
      - top_tags: most-used tags and their avg score
      - top_authors: authors ranked by avg score
      - publish_frequency: posts per day over the date range
      - recommendations: actionable suggestions
    """
    # Category performance
    cat_scores = {}
    for p in scored_posts:
        cat = p.get("category", "log")
        if cat not in cat_scores:
            cat_scores[cat] = []
        cat_scores[cat].append(p["scores"]["composite"])

    top_categories = []
    for cat, scores in sorted(cat_scores.items(), key=lambda x: -(sum(x[1]) / len(x[1]))):
        top_categories.append({
            "category": cat,
            "count": len(scores),
            "avg_score": round(sum(scores) / len(scores), 1),
        })

    # Tag performance
    tag_scores = {}
    for p in scored_posts:
        for tag in p.get("tags", []):
            if tag not in tag_scores:
                tag_scores[tag] = []
            tag_scores[tag].append(p["scores"]["composite"])

    top_tags = []
    for tag, scores in sorted(tag_scores.items(), key=lambda x: -(sum(x[1]) / len(x[1]))):
        top_tags.append({
            "tag": tag,
            "count": len(scores),
            "avg_score": round(sum(scores) / len(scores), 1),
        })

    # Author performance
    author_scores = {}
    for p in scored_posts:
        author = p.get("author", "unknown")
        if author not in author_scores:
            author_scores[author] = []
        author_scores[author].append(p["scores"]["composite"])

    top_authors = []
    for author, scores in sorted(author_scores.items(), key=lambda x: -(sum(x[1]) / len(x[1]))):
        top_authors.append({
            "author": author,
            "count": len(scores),
            "avg_score": round(sum(scores) / len(scores), 1),
        })

    # Publish frequency
    dates = [p["date"] for p in scored_posts]
    if len(dates) >= 2:
        try:
            first = datetime.strptime(min(dates), "%Y-%m-%d")
            last = datetime.strptime(max(dates), "%Y-%m-%d")
            span_days = max((last - first).days, 1)
            posts_per_day = round(len(dates) / span_days, 1)
        except ValueError:
            span_days = 0
            posts_per_day = 0
    else:
        span_days = 0
        posts_per_day = 0

    # Recommendations
    recommendations = []

    guide_count = sum(1 for p in scored_posts if p.get("category") == "guide")
    total = len(scored_posts)
    if total > 0 and guide_count / total < 0.3:
        recommendations.append(
            "Guides score highest on average. Increase guide output "
            f"(currently {guide_count}/{total} posts = {round(guide_count/total*100)}%)."
        )

    draft_count = sum(1 for p in scored_posts if p.get("draft"))
    if draft_count > 0:
        recommendations.append(
            f"{draft_count} posts are still drafts. Review and publish them "
            "to increase indexed content."
        )

    no_tags = sum(1 for p in scored_posts if not p.get("tags"))
    if no_tags > 0:
        recommendations.append(
            f"{no_tags} posts have no tags. Add tags to improve discoverability."
        )

    # Find best-performing tag clusters
    if top_tags:
        best_tag = top_tags[0]
        recommendations.append(
            f"Best-performing tag: '{best_tag['tag']}' (avg score {best_tag['avg_score']}, "
            f"{best_tag['count']} posts). Write more content with this tag."
        )

    social_posts = sum(1 for p in scored_posts if p["scores"]["social"] > 0)
    if social_posts < total * 0.5:
        recommendations.append(
            f"Only {social_posts}/{total} posts have social queue presence. "
            "Queue social posts for more blog entries."
        )

    return {
        "top_categories": top_categories,
        "top_tags": top_tags[:15],  # top 15 tags
        "top_authors": top_authors,
        "publish_frequency": {
            "total_posts": total,
            "span_days": span_days,
            "posts_per_day": posts_per_day,
        },
        "draft_count": draft_count,
        "recommendations": recommendations,
    }


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def generate_report(scored_posts, insights, traffic_totals):
    """Generate a markdown performance report."""
    today = datetime.now().strftime("%Y-%m-%d")
    lines = []

    lines.append(f"# Content Performance Report — {today}")
    lines.append("")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    # Summary
    lines.append("## Summary")
    lines.append("")
    freq = insights["publish_frequency"]
    lines.append(f"- **Total posts:** {freq['total_posts']}")
    lines.append(f"- **Date range:** {freq['span_days']} days")
    lines.append(f"- **Publish rate:** {freq['posts_per_day']} posts/day")
    lines.append(f"- **Drafts:** {insights['draft_count']}")
    if traffic_totals.get("total_views") is not None:
        lines.append(f"- **Site views (latest):** {traffic_totals.get('total_views', 'N/A')}")
        lines.append(f"- **Unique visitors (latest):** {traffic_totals.get('unique_visitors', 'N/A')}")
    else:
        lines.append("- **Site views:** No GoatCounter data available")
    lines.append("")

    # Top 10 posts
    lines.append("## Top Posts (by composite score)")
    lines.append("")
    lines.append("| Rank | Score | Title | Category | Author | Words | Date |")
    lines.append("|-----:|------:|-------|----------|--------|------:|------|")
    for i, p in enumerate(scored_posts[:15], 1):
        s = p["scores"]["composite"]
        title = p["title"][:50] + ("..." if len(p["title"]) > 50 else "")
        lines.append(
            f"| {i} | {s} | {title} | {p.get('category', '-')} | "
            f"{p.get('author', '-')} | {p['word_count']:,} | {p['date']} |"
        )
    lines.append("")

    # Score breakdown for top 5
    lines.append("## Score Breakdown (top 5)")
    lines.append("")
    lines.append("| Title | Traffic | Social | Length | Recency | Tags | Category |")
    lines.append("|-------|--------:|-------:|-------:|--------:|-----:|---------:|")
    for p in scored_posts[:5]:
        s = p["scores"]
        title = p["title"][:40] + ("..." if len(p["title"]) > 40 else "")
        lines.append(
            f"| {title} | {s['traffic']} | {s['social']} | "
            f"{s['length']} | {s['recency']} | {s['tags']} | {s['category']} |"
        )
    lines.append("")

    # Category performance
    lines.append("## Category Performance")
    lines.append("")
    lines.append("| Category | Posts | Avg Score |")
    lines.append("|----------|------:|----------:|")
    for cat in insights["top_categories"]:
        lines.append(f"| {cat['category']} | {cat['count']} | {cat['avg_score']} |")
    lines.append("")

    # Tag performance (top 10)
    lines.append("## Top Tags")
    lines.append("")
    lines.append("| Tag | Posts | Avg Score |")
    lines.append("|-----|------:|----------:|")
    for tag in insights["top_tags"][:10]:
        lines.append(f"| {tag['tag']} | {tag['count']} | {tag['avg_score']} |")
    lines.append("")

    # Author performance
    lines.append("## Author Performance")
    lines.append("")
    lines.append("| Author | Posts | Avg Score |")
    lines.append("|--------|------:|----------:|")
    for a in insights["top_authors"]:
        lines.append(f"| {a['author']} | {a['count']} | {a['avg_score']} |")
    lines.append("")

    # Recommendations
    lines.append("## Recommendations")
    lines.append("")
    for i, rec in enumerate(insights["recommendations"], 1):
        lines.append(f"{i}. {rec}")
    if not insights["recommendations"]:
        lines.append("No recommendations at this time.")
    lines.append("")

    # Bottom 5 (improvement opportunities)
    if len(scored_posts) > 5:
        lines.append("## Improvement Opportunities (lowest scoring)")
        lines.append("")
        for p in scored_posts[-5:]:
            s = p["scores"]["composite"]
            lines.append(f"- **{p['title']}** (score: {s}) — {p['date']}, {p['word_count']} words")
        lines.append("")

    return "\n".join(lines)


def run_performance_analysis(json_output=False):
    """Main entry point: parse, score, report.

    Returns the report as a string and saves to memory/content-performance/.
    """
    # Gather data
    posts = parse_all_posts()
    if not posts:
        msg = "No blog posts found in _posts/."
        if json_output:
            return json.dumps({"error": msg})
        return msg

    page_traffic, traffic_totals = load_goatcounter_metrics()
    social_engagement = load_social_engagement()

    # Score and rank
    scored = compute_scores(posts, page_traffic, social_engagement)
    insights = compute_insights(scored)

    if json_output:
        return json.dumps({
            "date": datetime.now().strftime("%Y-%m-%d"),
            "posts": [
                {
                    "title": p["title"],
                    "slug": p["slug"],
                    "date": p["date"],
                    "author": p["author"],
                    "category": p.get("category", ""),
                    "tags": p.get("tags", []),
                    "word_count": p["word_count"],
                    "scores": p["scores"],
                }
                for p in scored
            ],
            "insights": insights,
            "traffic_totals": traffic_totals,
        }, indent=2)

    # Generate markdown report
    report = generate_report(scored, insights, traffic_totals)

    # Save to file
    today = datetime.now().strftime("%Y-%m-%d")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{today}.md")
    with open(output_path, "w") as f:
        f.write(report)

    return report, output_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    import sys
    json_output = "--json" in sys.argv

    result = run_performance_analysis(json_output=json_output)

    if json_output:
        print(result)
    else:
        report, output_path = result
        print(report)
        print(f"\nSaved to: {output_path}")


if __name__ == "__main__":
    main()
