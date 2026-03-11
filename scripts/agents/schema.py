"""Agent report schema for structured handoffs.

Typed dataclass schemas so agents produce machine-readable output
alongside their markdown reports. Executive reads JSON first, falls
back to markdown regex.

Usage:
    from schema import AgentReport, Finding, save_report, load_report

    report = AgentReport(
        agent="Root",
        timestamp="2026-03-11T12:00:00",
        status="ok",
        summary="All systems nominal",
        findings=[Finding(severity="info", detail="Disk 42% used", area="infra")],
    )
    save_report(report, "memory/infra/2026-03-11.json")
"""

import json
import os
from dataclasses import dataclass, field, asdict
from typing import List, Optional

# Import atomic_write if available, fall back to regular write
try:
    from atomicwrite import atomic_write as _atomic_write
except ImportError:
    _atomic_write = None


@dataclass
class Finding:
    severity: str       # "critical" | "high" | "medium" | "low" | "info"
    detail: str
    area: str
    file: Optional[str] = None
    action: Optional[str] = None


@dataclass
class AgentReport:
    agent: str
    timestamp: str
    status: str         # "ok" | "warning" | "error"
    summary: str
    findings: List[Finding] = field(default_factory=list)
    duration_ms: int = 0
    metadata: dict = field(default_factory=dict)


def save_report(report, path):
    """Save an AgentReport as JSON. Uses atomic write if available."""
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    content = json.dumps(asdict(report), indent=2) + "\n"

    if _atomic_write:
        _atomic_write(path, content)
    else:
        with open(path, "w") as f:
            f.write(content)


def load_report(path):
    """Load an AgentReport from a JSON file."""
    with open(path) as f:
        data = json.loads(f.read())

    findings = [Finding(**f) for f in data.pop("findings", [])]
    return AgentReport(**data, findings=findings)
