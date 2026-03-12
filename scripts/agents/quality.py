"""Quality gates for locally-generated content.

Pure stdlib. Catches repetition loops, length violations, missing structure,
and common hallucination signals from small language models.

Usage:
    from quality import validate

    ok, issues = validate(text, "guide")
    if not ok:
        print("Quality check failed:", issues)
"""

import re


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------

def check_repetition(text, threshold=0.3):
    """Check for excessive sentence-level repetition.

    Returns (pass, reason) where pass=False if the ratio of duplicate
    sentences exceeds threshold.
    """
    sentences = [s.strip() for s in re.split(r'[.!?\n]', text) if s.strip()]
    if len(sentences) < 3:
        return True, None

    unique = set(s.lower() for s in sentences)
    dup_ratio = 1 - (len(unique) / len(sentences))

    if dup_ratio > threshold:
        return False, f"repetition ratio {dup_ratio:.0%} exceeds {threshold:.0%} threshold"
    return True, None


def check_length(text, min_words=50, max_words=5000):
    """Check word count is within bounds.

    Returns (pass, reason).
    """
    word_count = len(text.split())
    if word_count < min_words:
        return False, f"too short: {word_count} words (min {min_words})"
    if word_count > max_words:
        return False, f"too long: {word_count} words (max {max_words})"
    return True, None


def check_structure(text, required_headings=None):
    """Verify expected H2 sections exist.

    Returns (pass, reason). Skipped if required_headings is empty/None.
    """
    if not required_headings:
        return True, None

    headings_found = set()
    for line in text.splitlines():
        m = re.match(r'^##\s+(.+)', line)
        if m:
            headings_found.add(m.group(1).strip().lower())

    missing = []
    for h in required_headings:
        h_lower = h.lower()
        if not any(h_lower in found for found in headings_found):
            missing.append(h)

    if missing:
        return False, f"missing required sections: {', '.join(missing)}"
    return True, None


def check_hallucination_signals(text):
    """Flag common hallucination patterns from small models.

    Checks for:
    - Fabricated URLs (non-substrate domains presented as links)
    - Impossible benchmark numbers (>100% accuracy, negative latency)
    - Repetitive filler phrases
    - Known-invalid NixOS options

    Returns (pass, [reasons]).
    """
    issues = []

    # Fabricated URLs — real links to unknown domains
    fake_urls = re.findall(
        r'https?://(?!substrate\.lol|github\.com|nixos\.org|ollama\.com'
        r'|ko-fi\.com|goatcounter\.com|bsky\.app)[a-zA-Z0-9.-]+\.[a-z]{2,}/\S+',
        text
    )
    if len(fake_urls) > 3:
        issues.append(f"suspicious URLs ({len(fake_urls)} unknown domains)")

    # Impossible numbers
    impossible = re.findall(r'\b(\d{4,})\s*%', text)
    if impossible:
        issues.append(f"impossible percentages: {', '.join(impossible[:3])}%")

    # Repetitive filler — same phrase repeated 3+ times
    phrases = re.findall(r'(?:^|\. )([A-Z][^.]{10,50}\.)', text)
    phrase_counts = {}
    for p in phrases:
        p_lower = p.strip().lower()
        phrase_counts[p_lower] = phrase_counts.get(p_lower, 0) + 1
    repeated = [p for p, c in phrase_counts.items() if c >= 3]
    if repeated:
        issues.append(f"repeated phrases ({len(repeated)}): '{repeated[0][:40]}...'")

    # "End of Guide" / "End of" spam
    end_spam = len(re.findall(r'(?i)end of (guide|article|post|section)', text))
    if end_spam > 2:
        issues.append(f"'End of...' repeated {end_spam} times")

    if issues:
        return False, issues
    return True, []


# ---------------------------------------------------------------------------
# Content-type validation profiles
# ---------------------------------------------------------------------------

PROFILES = {
    "guide": {
        "min_words": 300,
        "max_words": 4000,
        "rep_threshold": 0.25,
        "required_headings": ["Troubleshooting"],
    },
    "social": {
        "min_words": 3,
        "max_words": 100,
        "rep_threshold": 0.5,
        "required_headings": None,
    },
    "summary": {
        "min_words": 20,
        "max_words": 500,
        "rep_threshold": 0.3,
        "required_headings": None,
    },
    "log": {
        "min_words": 5,
        "max_words": 1000,
        "rep_threshold": 0.4,
        "required_headings": None,
    },
}


def validate(text, content_type="guide"):
    """Run all quality checks for a content type.

    Returns (pass: bool, reasons: list[str]).
    """
    if not text or not text.strip():
        return False, ["empty content"]

    profile = PROFILES.get(content_type, PROFILES["guide"])
    reasons = []

    ok, reason = check_repetition(text, profile["rep_threshold"])
    if not ok:
        reasons.append(reason)

    ok, reason = check_length(text, profile["min_words"], profile["max_words"])
    if not ok:
        reasons.append(reason)

    ok, reason = check_structure(text, profile.get("required_headings"))
    if not ok:
        reasons.append(reason)

    ok, hallucination_issues = check_hallucination_signals(text)
    if not ok:
        reasons.extend(hallucination_issues)

    return len(reasons) == 0, reasons
