# Security Domain Knowledge — Sentinel (Security Agent)

## Threat Model

Substrate is a self-hosted AI workstation (Lenovo Legion 5, NixOS) with a public web presence
via GitHub Pages. Primary goal: protect repo integrity, local system, and credentials.

## Attack Surfaces

| Surface | Risk | Notes |
|---------|------|-------|
| GitHub Pages | LOW | Static site on GitHub CDN. No server code. Risk is repo compromise via credential theft. |
| Ollama API | MEDIUM | Localhost only (port 11434). Risk if network config exposes it. Verify 127.0.0.1 binding. |
| ComfyUI | MEDIUM | Localhost only. Same profile as Ollama. Never expose without auth. |
| SSH | HIGH | Key-only auth, fail2ban, non-standard port. Config changes require operator approval. |
| NixOS | MEDIUM | Declarative config limits drift. Pin flake inputs. Review all `flake.lock` changes. |
| Physical | VARIABLE | LUKS encrypted. Battery death can cause data loss (see incidents). |

## Credential Management

- **No secrets in the repo.** Ever. This includes API keys, passwords, SSIDs, IP addresses.
- Use `[redacted]` as placeholder when documenting network-specific details.
- Secrets for services should use out-of-band management (agenix, sops-nix).
- Reference: `CLAUDE.md` Security section defines this policy.
- The `ledger/*.private.txt` files are gitignored — real financial data stays out of the repo.

## Known Incidents

### 2026-03-07: Battery Death / Git Corruption
- Battery died during a build. Git repository was corrupted.
- Recovery: recloned from GitHub remote.
- Remediation: `scripts/battery-guard.sh` built to auto-commit on low battery.
- Lesson: local-only state is fragile. Push early, push often. Battery guard is a safety net.

## Security Checklist for New Capabilities

When any agent adds a new service, script, or network-facing feature:

- [ ] No secrets hardcoded in source files
- [ ] No new ports exposed to the network
- [ ] No services binding to 0.0.0.0 (use 127.0.0.1)
- [ ] No flake inputs from untrusted sources
- [ ] No credential files added to git (check `.gitignore`)
- [ ] Operator approval for any network/security config changes

Periodic checks: verify Ollama/ComfyUI localhost binding, review `flake.lock` changes,
confirm `.gitignore` covers `*.private.*`, verify battery guard is active.
