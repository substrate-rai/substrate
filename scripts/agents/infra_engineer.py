#!/usr/bin/env python3
"""Root -- infrastructure engineer agent for Substrate.

Monitors system health, checks GPU/VRAM/disk/services, reads trends
from health logs, and proposes infrastructure improvements.

Usage:
    python3 scripts/agents/infra_engineer.py              # generate infra report
    python3 scripts/agents/infra_engineer.py --dry-run    # print report without saving
    python3 scripts/agents/infra_engineer.py --date 2026-03-07

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
INFRA_DIR = os.path.join(MEMORY_DIR, "infra")
HEALTH_LOG = os.path.join(MEMORY_DIR, "health.log")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "root-voice.txt")

# Services and timers to check
EXPECTED_SERVICES = [
    "ollama.service",
]

EXPECTED_TIMERS = [
    "substrate-health.timer",
    "substrate-blog.timer",
    "substrate-mirror.timer",
]

# Disk usage warning thresholds (percentage)
DISK_WARN_PCT = 80
DISK_CRIT_PCT = 90

# VRAM thresholds (MB)
VRAM_WARN_MB = 6500  # 6.5 GB of 8 GB
VRAM_CRIT_MB = 7500  # 7.5 GB of 8 GB

# ---------------------------------------------------------------------------
# System checks
# ---------------------------------------------------------------------------

def run_cmd(cmd, timeout=15):
    """Run a shell command and return (stdout, stderr, returncode)."""
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout,
            shell=isinstance(cmd, str),
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "command timed out", 1
    except FileNotFoundError:
        return "", "command not found", 1
    except Exception as e:
        return "", str(e), 1


def check_gpu():
    """Check NVIDIA GPU status via nvidia-smi."""
    info = {
        "available": False,
        "name": "unknown",
        "vram_used_mb": 0,
        "vram_total_mb": 0,
        "vram_pct": 0,
        "temperature": 0,
        "gpu_util": 0,
        "power_draw": 0,
        "status": "unknown",
        "processes": [],
    }

    # NixOS: nvidia-smi may not be in restricted systemd PATH
    nvidia_smi = "nvidia-smi"
    for path in ["/run/current-system/sw/bin/nvidia-smi", "/usr/bin/nvidia-smi"]:
        if os.path.exists(path):
            nvidia_smi = path
            break

    stdout, stderr, rc = run_cmd([
        nvidia_smi,
        "--query-gpu=name,memory.used,memory.total,temperature.gpu,utilization.gpu,power.draw",
        "--format=csv,noheader,nounits"
    ])

    if rc != 0:
        info["status"] = f"nvidia-smi failed: {stderr[:100]}"
        return info

    info["available"] = True
    parts = [p.strip() for p in stdout.split(",")]
    if len(parts) >= 6:
        info["name"] = parts[0]
        try:
            info["vram_used_mb"] = int(float(parts[1]))
            info["vram_total_mb"] = int(float(parts[2]))
            info["vram_pct"] = int(info["vram_used_mb"] / info["vram_total_mb"] * 100) if info["vram_total_mb"] > 0 else 0
            info["temperature"] = int(float(parts[3]))
            info["gpu_util"] = int(float(parts[4]))
            info["power_draw"] = float(parts[5])
        except (ValueError, IndexError):
            pass

    # Determine status
    if info["vram_used_mb"] >= VRAM_CRIT_MB:
        info["status"] = "CRITICAL: VRAM near capacity"
    elif info["vram_used_mb"] >= VRAM_WARN_MB:
        info["status"] = "WARNING: VRAM usage high"
    elif info["temperature"] >= 85:
        info["status"] = "WARNING: GPU temperature high"
    else:
        info["status"] = "OK"

    # Get GPU processes
    proc_stdout, _, proc_rc = run_cmd([
        nvidia_smi, "--query-compute-apps=pid,name,used_memory",
        "--format=csv,noheader,nounits"
    ])
    if proc_rc == 0 and proc_stdout:
        for line in proc_stdout.splitlines():
            pparts = [p.strip() for p in line.split(",")]
            if len(pparts) >= 3:
                info["processes"].append({
                    "pid": pparts[0],
                    "name": pparts[1],
                    "vram_mb": pparts[2],
                })

    return info


def check_disk():
    """Check disk usage."""
    info = {
        "filesystems": [],
        "status": "OK",
    }

    stdout, _, rc = run_cmd(["df", "-h", "--output=target,pcent,avail,size"])
    if rc != 0:
        info["status"] = "could not check disk"
        return info

    critical = False
    warning = False

    for line in stdout.splitlines()[1:]:  # skip header
        parts = line.split()
        if len(parts) >= 4:
            mount = parts[0]
            # Skip pseudo-filesystems
            if mount in ("/dev", "/dev/shm", "/run", "/sys", "/proc") or mount.startswith("/sys"):
                continue
            pct_str = parts[1].replace("%", "")
            try:
                pct = int(pct_str)
            except ValueError:
                continue

            fs = {
                "mount": mount,
                "used_pct": pct,
                "available": parts[2],
                "total": parts[3],
            }
            info["filesystems"].append(fs)

            if pct >= DISK_CRIT_PCT:
                critical = True
            elif pct >= DISK_WARN_PCT:
                warning = True

    if critical:
        info["status"] = "CRITICAL: disk space critically low"
    elif warning:
        info["status"] = "WARNING: disk space getting low"

    return info


def check_services():
    """Check status of expected systemd services."""
    results = []

    for svc in EXPECTED_SERVICES:
        stdout, stderr, rc = run_cmd(["systemctl", "is-active", svc])
        status = stdout if rc == 0 else "inactive/failed"
        results.append({"name": svc, "status": status})

    return results


def check_timers():
    """Check status of expected systemd timers."""
    results = []

    for timer in EXPECTED_TIMERS:
        stdout, stderr, rc = run_cmd(["systemctl", "is-active", timer])
        status = stdout if rc == 0 else "inactive/failed"

        # Get next trigger time
        next_stdout, _, next_rc = run_cmd([
            "systemctl", "show", timer, "--property=NextElapseUSecRealtime"
        ])
        next_trigger = ""
        if next_rc == 0 and "=" in next_stdout:
            next_trigger = next_stdout.split("=", 1)[1].strip()

        results.append({
            "name": timer,
            "status": status,
            "next_trigger": next_trigger,
        })

    return results


def check_ollama():
    """Check if Ollama is responsive."""
    stdout, stderr, rc = run_cmd(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                                   "http://localhost:11434/api/tags"])
    if rc == 0 and stdout == "200":
        return {"status": "OK", "detail": "responding on :11434"}

    return {"status": "DOWN", "detail": f"HTTP {stdout}" if stdout else stderr[:80]}


def check_comfyui():
    """Check if ComfyUI is running."""
    stdout, stderr, rc = run_cmd(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                                   "http://localhost:8188"])
    if rc == 0 and stdout == "200":
        return {"status": "OK", "detail": "responding on :8188"}

    return {"status": "DOWN", "detail": f"HTTP {stdout}" if stdout else "not reachable"}


def check_memory():
    """Check system RAM usage."""
    stdout, _, rc = run_cmd(["free", "-m"])
    info = {"total_mb": 0, "used_mb": 0, "available_mb": 0, "pct": 0, "status": "unknown"}

    if rc != 0:
        return info

    for line in stdout.splitlines():
        if line.startswith("Mem:"):
            parts = line.split()
            if len(parts) >= 7:
                try:
                    info["total_mb"] = int(parts[1])
                    info["used_mb"] = int(parts[2])
                    info["available_mb"] = int(parts[6])
                    info["pct"] = int(info["used_mb"] / info["total_mb"] * 100) if info["total_mb"] > 0 else 0
                except (ValueError, IndexError):
                    pass

    if info["pct"] >= 90:
        info["status"] = "CRITICAL"
    elif info["pct"] >= 75:
        info["status"] = "WARNING"
    else:
        info["status"] = "OK"

    return info


# ---------------------------------------------------------------------------
# Health log analysis
# ---------------------------------------------------------------------------

def read_file(path):
    """Read a file and return its contents, or None on failure."""
    try:
        with open(path, "r") as f:
            return f.read()
    except (IOError, OSError):
        return None


def analyze_health_log():
    """Read memory/health.log and extract trends."""
    trends = {
        "entries": 0,
        "recent_errors": [],
        "gpu_temps": [],
        "vram_readings": [],
        "warnings": [],
    }

    content = read_file(HEALTH_LOG)
    if not content:
        return trends

    lines = content.strip().splitlines()
    trends["entries"] = len(lines)

    # Analyze last 48 entries (roughly 2 days of hourly checks)
    recent = lines[-48:] if len(lines) > 48 else lines

    for line in recent:
        line_lower = line.lower()

        if "error" in line_lower or "fail" in line_lower:
            trends["recent_errors"].append(line.strip()[:120])

        if "warn" in line_lower:
            trends["warnings"].append(line.strip()[:120])

        # Extract GPU temp if present
        temp_match = re.search(r'(\d+)\s*[Cc]', line)
        if temp_match and "gpu" in line_lower:
            try:
                trends["gpu_temps"].append(int(temp_match.group(1)))
            except ValueError:
                pass

        # Extract VRAM if present
        vram_match = re.search(r'(\d+)\s*(?:MiB|MB)', line)
        if vram_match and "vram" in line_lower:
            try:
                trends["vram_readings"].append(int(vram_match.group(1)))
            except ValueError:
                pass

    return trends


# ---------------------------------------------------------------------------
# Proposal generation
# ---------------------------------------------------------------------------

def generate_proposals(gpu, disk, memory, services, timers, ollama, comfyui, trends):
    """Generate infrastructure improvement proposals based on findings."""
    proposals = []

    # GPU proposals
    if gpu["available"]:
        if gpu["vram_pct"] >= 80:
            proposals.append({
                "area": "GPU/VRAM",
                "severity": "high",
                "title": "VRAM pressure detected",
                "description": (
                    f"VRAM usage at {gpu['vram_pct']}% ({gpu['vram_used_mb']}/"
                    f"{gpu['vram_total_mb']} MB). Consider stopping unused GPU "
                    "processes or switching to smaller model quantizations."
                ),
                "action": "Review GPU processes, consider model swap or gpu-switch.sh scheduling",
            })
        if gpu["temperature"] >= 80:
            proposals.append({
                "area": "GPU/Thermal",
                "severity": "medium",
                "title": "GPU running hot",
                "description": (
                    f"GPU temperature at {gpu['temperature']}C. Sustained high temps "
                    "reduce hardware lifespan. Check cooling and airflow."
                ),
                "action": "Verify laptop ventilation, consider inference scheduling to allow cool-down",
            })
    else:
        proposals.append({
            "area": "GPU",
            "severity": "high",
            "title": "GPU not detected",
            "description": "nvidia-smi is not responding. CUDA workloads will fail.",
            "action": "Check NVIDIA driver status, verify NixOS GPU config in flake.nix",
        })

    # Disk proposals
    for fs in disk.get("filesystems", []):
        if fs["used_pct"] >= DISK_CRIT_PCT:
            proposals.append({
                "area": "Disk",
                "severity": "critical",
                "title": f"Disk critically full: {fs['mount']}",
                "description": (
                    f"{fs['mount']} at {fs['used_pct']}% usage ({fs['available']} free). "
                    "System may become unresponsive."
                ),
                "action": "Clear old generations: sudo nix-collect-garbage -d; clean /tmp and logs",
            })
        elif fs["used_pct"] >= DISK_WARN_PCT:
            proposals.append({
                "area": "Disk",
                "severity": "medium",
                "title": f"Disk usage elevated: {fs['mount']}",
                "description": (
                    f"{fs['mount']} at {fs['used_pct']}% usage ({fs['available']} free)."
                ),
                "action": "Schedule garbage collection: nix-collect-garbage --delete-older-than 7d",
            })

    # Memory proposals
    if memory.get("pct", 0) >= 85:
        proposals.append({
            "area": "RAM",
            "severity": "high",
            "title": "System memory pressure",
            "description": (
                f"RAM at {memory['pct']}% ({memory['used_mb']}/{memory['total_mb']} MB). "
                "OOM killer may activate."
            ),
            "action": "Identify memory-heavy processes, consider reducing Ollama context window",
        })

    # Service proposals
    for svc in services:
        if svc["status"] != "active":
            proposals.append({
                "area": "Services",
                "severity": "high",
                "title": f"Service down: {svc['name']}",
                "description": f"{svc['name']} is {svc['status']}. Dependent workflows will fail.",
                "action": f"systemctl restart {svc['name']} && systemctl status {svc['name']}",
            })

    # Timer proposals
    for timer in timers:
        if timer["status"] != "active":
            proposals.append({
                "area": "Timers",
                "severity": "medium",
                "title": f"Timer inactive: {timer['name']}",
                "description": f"{timer['name']} is {timer['status']}. Scheduled tasks are not running.",
                "action": f"systemctl enable --now {timer['name']}",
            })

    # Ollama proposals
    if ollama["status"] != "OK":
        proposals.append({
            "area": "ML Pipeline",
            "severity": "high",
            "title": "Ollama not responding",
            "description": f"Local inference unavailable: {ollama['detail']}",
            "action": "systemctl restart ollama.service; check CUDA driver compatibility",
        })

    # ComfyUI proposals
    if comfyui["status"] != "OK":
        proposals.append({
            "area": "ML Pipeline",
            "severity": "low",
            "title": "ComfyUI not reachable",
            "description": f"Image generation pipeline unavailable: {comfyui['detail']}",
            "action": "Start ComfyUI if needed, or note as intentionally offline",
        })

    # Health log trend proposals
    if trends["recent_errors"]:
        proposals.append({
            "area": "Health Trends",
            "severity": "medium",
            "title": f"{len(trends['recent_errors'])} errors in recent health log",
            "description": (
                "Errors detected in the last 48 hours of health checks. "
                f"Latest: {trends['recent_errors'][-1]}"
            ),
            "action": "Review memory/health.log for patterns; fix root causes",
        })

    if trends["gpu_temps"]:
        avg_temp = sum(trends["gpu_temps"]) / len(trends["gpu_temps"])
        if avg_temp >= 75:
            proposals.append({
                "area": "Health Trends",
                "severity": "medium",
                "title": f"Average GPU temp trending high ({avg_temp:.0f}C)",
                "description": "GPU temperatures averaging above 75C over recent readings.",
                "action": "Improve cooling or reduce sustained GPU workload",
            })

    # If nothing is wrong, note that
    if not proposals:
        proposals.append({
            "area": "General",
            "severity": "info",
            "title": "All systems nominal",
            "description": "No issues detected. Infrastructure is healthy.",
            "action": "Continue monitoring. Consider proactive upgrades from brainstorm backlog.",
        })

    return proposals


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def build_report(date_str, gpu, disk, memory, services, timers, ollama, comfyui,
                 trends, proposals):
    """Build the infrastructure report."""
    lines = []
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    lines.append(f"# Root -- Infrastructure Report: {date_str}")
    lines.append("")
    lines.append(f"**Generated:** {now_str}")
    lines.append("")

    # Overall status
    severities = [p["severity"] for p in proposals]
    if "critical" in severities:
        overall = "CRITICAL"
    elif "high" in severities:
        overall = "ATTENTION NEEDED"
    elif "medium" in severities:
        overall = "MINOR ISSUES"
    else:
        overall = "HEALTHY"
    lines.append(f"**Overall status:** {overall}")
    lines.append("")

    # GPU
    lines.append("## GPU")
    lines.append("")
    if gpu["available"]:
        lines.append(f"- **Model:** {gpu['name']}")
        lines.append(f"- **VRAM:** {gpu['vram_used_mb']}/{gpu['vram_total_mb']} MB ({gpu['vram_pct']}%)")
        lines.append(f"- **Temperature:** {gpu['temperature']}C")
        lines.append(f"- **Utilization:** {gpu['gpu_util']}%")
        lines.append(f"- **Power draw:** {gpu['power_draw']}W")
        lines.append(f"- **Status:** {gpu['status']}")
        if gpu["processes"]:
            lines.append("")
            lines.append("**GPU processes:**")
            for p in gpu["processes"]:
                lines.append(f"  - PID {p['pid']}: {p['name']} ({p['vram_mb']} MB)")
    else:
        lines.append(f"- **Status:** NOT AVAILABLE -- {gpu['status']}")
    lines.append("")

    # System Memory
    lines.append("## System Memory")
    lines.append("")
    lines.append(f"- **Total:** {memory.get('total_mb', '?')} MB")
    lines.append(f"- **Used:** {memory.get('used_mb', '?')} MB ({memory.get('pct', '?')}%)")
    lines.append(f"- **Available:** {memory.get('available_mb', '?')} MB")
    lines.append(f"- **Status:** {memory.get('status', 'unknown')}")
    lines.append("")

    # Disk
    lines.append("## Disk")
    lines.append("")
    if disk["filesystems"]:
        lines.append("| Mount | Used | Available | Total | Status |")
        lines.append("|-------|------|-----------|-------|--------|")
        for fs in disk["filesystems"]:
            status = "OK"
            if fs["used_pct"] >= DISK_CRIT_PCT:
                status = "CRITICAL"
            elif fs["used_pct"] >= DISK_WARN_PCT:
                status = "WARNING"
            lines.append(f"| {fs['mount']} | {fs['used_pct']}% | {fs['available']} | {fs['total']} | {status} |")
    else:
        lines.append("Could not read disk information.")
    lines.append("")

    # Services
    lines.append("## Services")
    lines.append("")
    for svc in services:
        icon = "OK" if svc["status"] == "active" else "DOWN"
        lines.append(f"- **{svc['name']}:** {icon} ({svc['status']})")
    lines.append("")

    # Timers
    lines.append("## Timers")
    lines.append("")
    for timer in timers:
        icon = "OK" if timer["status"] == "active" else "INACTIVE"
        next_info = f" (next: {timer['next_trigger']})" if timer["next_trigger"] else ""
        lines.append(f"- **{timer['name']}:** {icon}{next_info}")
    lines.append("")

    # ML Pipeline
    lines.append("## ML Pipeline")
    lines.append("")
    lines.append(f"- **Ollama:** {ollama['status']} -- {ollama['detail']}")
    lines.append(f"- **ComfyUI:** {comfyui['status']} -- {comfyui['detail']}")
    lines.append("")

    # Health log trends
    lines.append("## Health Log Trends")
    lines.append("")
    lines.append(f"- **Total log entries:** {trends['entries']}")
    lines.append(f"- **Recent errors:** {len(trends['recent_errors'])}")
    lines.append(f"- **Recent warnings:** {len(trends['warnings'])}")
    if trends["gpu_temps"]:
        avg_temp = sum(trends["gpu_temps"]) / len(trends["gpu_temps"])
        lines.append(f"- **Avg GPU temp (recent):** {avg_temp:.0f}C")
    if trends["vram_readings"]:
        avg_vram = sum(trends["vram_readings"]) / len(trends["vram_readings"])
        lines.append(f"- **Avg VRAM usage (recent):** {avg_vram:.0f} MB")
    lines.append("")

    # Proposals
    lines.append("## Proposals")
    lines.append("")
    severity_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
    sorted_proposals = sorted(proposals, key=lambda p: severity_order.get(p["severity"], 5))
    for i, p in enumerate(sorted_proposals, 1):
        lines.append(f"### {i}. [{p['severity'].upper()}] {p['title']}")
        lines.append("")
        lines.append(f"**Area:** {p['area']}")
        lines.append(f"{p['description']}")
        lines.append("")
        lines.append(f"**Recommended action:** {p['action']}")
        lines.append("")

    lines.append("---")
    lines.append("-- Root, Substrate Infrastructure")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Root -- infrastructure engineer agent for Substrate")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print report without saving to disk")
    parser.add_argument("--date", default=None,
                        help="Date for the report (YYYY-MM-DD, default: today)")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[root] starting infrastructure scan...", file=sys.stderr)

    # Run all checks
    gpu = check_gpu()
    print(f"[root] GPU: {gpu['status']}", file=sys.stderr)

    disk = check_disk()
    print(f"[root] Disk: {disk['status']}", file=sys.stderr)

    memory = check_memory()
    print(f"[root] RAM: {memory.get('status', 'unknown')}", file=sys.stderr)

    services = check_services()
    timers = check_timers()

    ollama = check_ollama()
    print(f"[root] Ollama: {ollama['status']}", file=sys.stderr)

    comfyui = check_comfyui()
    print(f"[root] ComfyUI: {comfyui['status']}", file=sys.stderr)

    trends = analyze_health_log()
    print(f"[root] Health log: {trends['entries']} entries, {len(trends['recent_errors'])} recent errors", file=sys.stderr)

    # Generate proposals
    proposals = generate_proposals(gpu, disk, memory, services, timers, ollama, comfyui, trends)

    # Build report
    report = build_report(date_str, gpu, disk, memory, services, timers, ollama, comfyui,
                          trends, proposals)

    if args.dry_run:
        print(report)
        return

    # Save report
    os.makedirs(INFRA_DIR, exist_ok=True)
    report_path = os.path.join(INFRA_DIR, f"{date_str}.md")
    with open(report_path, "w") as f:
        f.write(report)

    # Print summary to stdout
    severities = [p["severity"] for p in proposals]
    if "critical" in severities:
        overall = "CRITICAL"
    elif "high" in severities:
        overall = "ATTENTION NEEDED"
    elif "medium" in severities:
        overall = "MINOR ISSUES"
    else:
        overall = "HEALTHY"

    print(f"Root here. Infrastructure status: {overall}.")
    print()
    if gpu["available"]:
        print(f"  GPU: {gpu['name']} | {gpu['vram_used_mb']}/{gpu['vram_total_mb']} MB VRAM | {gpu['temperature']}C")
    print(f"  RAM: {memory.get('used_mb', '?')}/{memory.get('total_mb', '?')} MB ({memory.get('pct', '?')}%)")
    print(f"  Ollama: {ollama['status']} | ComfyUI: {comfyui['status']}")
    print(f"  Proposals: {len(proposals)}")
    print()
    # Show highest severity proposal
    if proposals and proposals[0]["severity"] != "info":
        top = sorted(proposals, key=lambda p: {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}.get(p["severity"], 5))[0]
        print(f"  Top issue: [{top['severity'].upper()}] {top['title']}")
        print()
    print(f"Report: {report_path}")
    print()
    print("-- Root, Substrate Infrastructure")


if __name__ == "__main__":
    main()
