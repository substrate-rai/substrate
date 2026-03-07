#!/usr/bin/env python3
"""Fetch and extract readable content from any URL. Stdlib only.

Usage:
    python3 scripts/web/fetch.py https://example.com
    python3 scripts/web/fetch.py https://example.com --raw          # raw HTML
    python3 scripts/web/fetch.py https://example.com --links        # extract links
    python3 scripts/web/fetch.py https://example.com --summarize    # summarize via local brain
    echo "https://example.com" | python3 scripts/web/fetch.py -     # read URL from stdin
"""

import argparse
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request
from html.parser import HTMLParser


# ---------------------------------------------------------------------------
# HTML → text extraction
# ---------------------------------------------------------------------------

class TextExtractor(HTMLParser):
    """Extract readable text from HTML, stripping tags and scripts."""

    SKIP_TAGS = {"script", "style", "noscript", "svg", "path", "head"}

    def __init__(self):
        super().__init__()
        self.pieces = []
        self.skip_depth = 0
        self.links = []
        self.current_href = None
        self.title = ""
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        if tag in self.SKIP_TAGS:
            self.skip_depth += 1
        if tag == "title":
            self.in_title = True
        if tag == "a" and "href" in attrs_dict:
            self.current_href = attrs_dict["href"]
        if tag in ("p", "br", "div", "h1", "h2", "h3", "h4", "h5", "h6",
                    "li", "tr", "blockquote", "pre", "article", "section"):
            self.pieces.append("\n")
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self.pieces.append("#" * int(tag[1]) + " ")

    def handle_endtag(self, tag):
        if tag in self.SKIP_TAGS:
            self.skip_depth = max(0, self.skip_depth - 1)
        if tag == "title":
            self.in_title = False
        if tag == "a" and self.current_href:
            self.current_href = None
        if tag in ("p", "div", "article", "section", "blockquote", "pre",
                    "h1", "h2", "h3", "h4", "h5", "h6"):
            self.pieces.append("\n")

    def handle_data(self, data):
        if self.in_title:
            self.title = data.strip()
        if self.skip_depth > 0:
            return
        text = data.strip()
        if text:
            self.pieces.append(text)
            if self.current_href:
                self.links.append((text, self.current_href))

    def get_text(self):
        raw = " ".join(self.pieces)
        # Collapse whitespace
        raw = re.sub(r"[ \t]+", " ", raw)
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        return raw.strip()

    def get_links(self):
        return self.links


# ---------------------------------------------------------------------------
# HTTP fetch
# ---------------------------------------------------------------------------

USER_AGENT = "Substrate/1.0 (sovereign AI workstation; +https://substrate-rai.github.io/substrate/)"

def fetch_url(url, timeout=15):
    """Fetch URL content. Returns (html_content, final_url, status_code)."""
    req = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read().decode(charset, errors="replace")
            return body, resp.url, resp.status
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace") if e.fp else ""
        return body, url, e.code
    except urllib.error.URLError as e:
        print(f"error: {e.reason}", file=sys.stderr)
        sys.exit(1)


def extract(html_content):
    """Extract text and metadata from HTML."""
    parser = TextExtractor()
    parser.feed(html_content)
    return {
        "title": parser.title,
        "text": parser.get_text(),
        "links": parser.get_links(),
    }


# ---------------------------------------------------------------------------
# Local brain summarization (optional)
# ---------------------------------------------------------------------------

def summarize_local(text, max_chars=4000):
    """Summarize text via Ollama local brain."""
    truncated = text[:max_chars]
    payload = json.dumps({
        "model": "qwen3:8b",
        "prompt": f"Summarize this web page content in 3-5 bullet points. Be concise.\n\n{truncated}",
        "stream": False,
        "options": {"temperature": 0.3},
    }).encode("utf-8")

    req = urllib.request.Request(
        "http://localhost:11434/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("response", "").strip()
    except Exception as e:
        return f"(summarization failed: {e})"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Fetch and extract web content")
    parser.add_argument("url", help="URL to fetch (or - for stdin)")
    parser.add_argument("--raw", action="store_true", help="Output raw HTML")
    parser.add_argument("--links", action="store_true", help="Extract and list links")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output as JSON")
    parser.add_argument("--summarize", action="store_true", help="Summarize via local brain")
    parser.add_argument("--max-length", type=int, default=0, help="Truncate output to N chars")
    parser.add_argument("--timeout", type=int, default=15, help="HTTP timeout in seconds")
    args = parser.parse_args()

    # Read URL
    url = args.url
    if url == "-":
        url = sys.stdin.readline().strip()
    if not url.startswith("http"):
        url = "https://" + url

    # Fetch
    html_content, final_url, status = fetch_url(url, timeout=args.timeout)

    if status >= 400:
        print(f"error: HTTP {status} for {url}", file=sys.stderr)
        sys.exit(1)

    # Raw mode
    if args.raw:
        print(html_content)
        return

    # Extract
    result = extract(html_content)

    # Summarize
    if args.summarize:
        result["summary"] = summarize_local(result["text"])

    # Truncate
    if args.max_length > 0:
        result["text"] = result["text"][:args.max_length]

    # Output
    if args.as_json:
        output = {
            "url": final_url,
            "title": result["title"],
            "text": result["text"],
        }
        if args.links:
            output["links"] = [{"text": t, "href": h} for t, h in result["links"]]
        if args.summarize:
            output["summary"] = result.get("summary", "")
        print(json.dumps(output, indent=2))
    elif args.links:
        print(f"# {result['title']}\n# {final_url}\n")
        for text, href in result["links"]:
            print(f"  {text}: {href}")
    else:
        if result["title"]:
            print(f"# {result['title']}")
        print(f"# {final_url}\n")
        print(result["text"])
        if args.summarize and result.get("summary"):
            print(f"\n---\n## Summary\n{result['summary']}")


if __name__ == "__main__":
    main()
