#!/usr/bin/env python3
"""Local RAG — semantic search over Substrate's markdown files.

Embeds blog posts, memory files, and docs using nomic-embed-text,
stores vectors in a JSON index, and retrieves relevant chunks by
cosine similarity.

Usage:
    python3 scripts/agents/rag.py --query "how does the radio work"
    python3 scripts/agents/rag.py --reindex
    python3 scripts/agents/rag.py --query "battery guard" --top 5

Dependencies: stdlib + ollama_client.py
Embedding model: nomic-embed-text (137M params, ~300MB VRAM)
"""

import argparse
import json
import math
import os
import sys
import time

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))

sys.path.insert(0, SCRIPT_DIR)
from ollama_client import OLLAMA_URL, OllamaError

import urllib.request
import urllib.error

INDEX_PATH = os.path.join(REPO_DIR, "memory", "rag-index.json")
EMBED_MODEL = "nomic-embed-text"
CHUNK_SIZE = 500  # characters per chunk
CHUNK_OVERLAP = 100

# Directories to index
INDEX_DIRS = [
    os.path.join(REPO_DIR, "_posts"),
    os.path.join(REPO_DIR, "memory"),
    os.path.join(REPO_DIR, "docs"),
    os.path.join(REPO_DIR, "blog"),
]

# Skip patterns
SKIP_PATTERNS = ["rag-index.json", "health.log", ".gitignore", "node_modules"]


def chunk_text(text, size=CHUNK_SIZE, overlap=CHUNK_OVERLAP):
    """Split text into overlapping chunks."""
    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start = end - overlap
    return chunks


def embed(texts, model=EMBED_MODEL, timeout=60):
    """Get embeddings for a list of texts from Ollama.

    Uses /api/embed endpoint. Returns list of embedding vectors.
    """
    payload = json.dumps({
        "model": model,
        "input": texts,
    }).encode("utf-8")

    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/embed",
        data=payload,
        headers={"Content-Type": "application/json"},
    )

    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        body = json.loads(resp.read().decode("utf-8"))
        return body.get("embeddings", [])
    except urllib.error.HTTPError as e:
        raise OllamaError(f"Embed HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        raise OllamaError(f"Embed unreachable: {e.reason}")
    except OSError as e:
        raise OllamaError(f"Embed connection error: {e}")


def cosine_similarity(a, b):
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def find_markdown_files():
    """Find all .md files in indexed directories."""
    files = []
    for dir_path in INDEX_DIRS:
        if not os.path.isdir(dir_path):
            continue
        for root, dirs, filenames in os.walk(dir_path):
            # Skip hidden dirs
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for fname in filenames:
                if not fname.endswith(".md"):
                    continue
                if any(skip in fname for skip in SKIP_PATTERNS):
                    continue
                full_path = os.path.join(root, fname)
                rel_path = os.path.relpath(full_path, REPO_DIR)
                files.append((rel_path, full_path))
    return files


def build_index(verbose=True):
    """Build or rebuild the RAG index over all markdown files."""
    files = find_markdown_files()
    if verbose:
        print(f"Found {len(files)} markdown files to index")

    index = {"chunks": [], "built_at": time.strftime("%Y-%m-%dT%H:%M:%S")}

    # Process in batches to avoid overwhelming the embedding API
    batch_size = 10
    all_chunks = []

    for rel_path, full_path in files:
        try:
            with open(full_path, "r", errors="replace") as f:
                text = f.read()
        except IOError:
            continue

        chunks = chunk_text(text)
        for i, chunk in enumerate(chunks):
            all_chunks.append({
                "file": rel_path,
                "chunk_index": i,
                "text": chunk,
            })

    if verbose:
        print(f"Created {len(all_chunks)} chunks, embedding...")

    # Embed in batches
    for i in range(0, len(all_chunks), batch_size):
        batch = all_chunks[i:i + batch_size]
        texts = [c["text"] for c in batch]
        try:
            embeddings = embed(texts)
        except OllamaError as e:
            print(f"  embed batch {i // batch_size} failed: {e}", file=sys.stderr)
            continue

        for chunk, embedding in zip(batch, embeddings):
            chunk["embedding"] = embedding
            index["chunks"].append(chunk)

        if verbose:
            done = min(i + batch_size, len(all_chunks))
            print(f"  embedded {done}/{len(all_chunks)} chunks")

    # Save index
    os.makedirs(os.path.dirname(INDEX_PATH), exist_ok=True)
    with open(INDEX_PATH, "w") as f:
        json.dump(index, f)

    if verbose:
        size_mb = os.path.getsize(INDEX_PATH) / (1024 * 1024)
        print(f"Index saved: {INDEX_PATH} ({size_mb:.1f} MB, {len(index['chunks'])} chunks)")

    return index


def load_index():
    """Load the RAG index from disk."""
    if not os.path.isfile(INDEX_PATH):
        return None
    try:
        with open(INDEX_PATH) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def search(query, top_k=3, index=None):
    """Search the RAG index for chunks relevant to a query.

    Args:
        query: Search query string
        top_k: Number of results to return
        index: Pre-loaded index (loads from disk if None)

    Returns:
        List of {"file": str, "text": str, "score": float} dicts
    """
    if index is None:
        index = load_index()
    if index is None:
        raise OllamaError("No RAG index found. Run with --reindex first.")

    # Embed the query
    query_embeddings = embed([query])
    if not query_embeddings:
        raise OllamaError("Failed to embed query")
    query_vec = query_embeddings[0]

    # Score all chunks
    scored = []
    for chunk in index["chunks"]:
        if "embedding" not in chunk:
            continue
        score = cosine_similarity(query_vec, chunk["embedding"])
        scored.append({
            "file": chunk["file"],
            "text": chunk["text"],
            "score": score,
            "chunk_index": chunk.get("chunk_index", 0),
        })

    # Sort by score descending
    scored.sort(key=lambda x: x["score"], reverse=True)

    # Deduplicate by file (keep highest scoring chunk per file)
    seen_files = set()
    results = []
    for item in scored:
        if item["file"] not in seen_files:
            seen_files.add(item["file"])
            results.append(item)
        if len(results) >= top_k:
            break

    return results


def main():
    parser = argparse.ArgumentParser(description="Local RAG search over Substrate docs")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--reindex", action="store_true", help="Rebuild the index")
    parser.add_argument("--top", "-k", type=int, default=3, help="Number of results (default: 3)")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output as JSON")
    args = parser.parse_args()

    if args.reindex:
        build_index()
        if not args.query:
            return

    if not args.query:
        parser.error("Provide --query or --reindex")

    try:
        results = search(args.query, top_k=args.top)
    except OllamaError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    if args.as_json:
        # Remove embeddings from output
        for r in results:
            r.pop("embedding", None)
        print(json.dumps(results, indent=2))
    else:
        for i, r in enumerate(results, 1):
            score_pct = r["score"] * 100
            print(f"\n{'─' * 60}")
            print(f"  #{i}  {r['file']}  (relevance: {score_pct:.1f}%)")
            print(f"{'─' * 60}")
            # Show first 200 chars of chunk
            preview = r["text"][:200].replace("\n", " ")
            print(f"  {preview}...")


if __name__ == "__main__":
    main()
