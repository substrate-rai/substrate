# Architecture Decisions

## 001 — Use NixOS as the base OS

**Date:** 2026-03-06
**Status:** Accepted

NixOS makes the system configuration declarative and reproducible. The machine can describe its own state as code. Rollbacks are trivial. This aligns with the self-documenting principle.

## 002 — Plaintext everything

**Date:** 2026-03-06
**Status:** Accepted

Blog posts are markdown. Financial records are plaintext. Configuration is Nix. No databases, no CMS, no opaque state. Everything is greppable, diffable, and version-controlled.
