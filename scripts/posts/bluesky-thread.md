# Bluesky Launch Thread (10 posts)

Post from: @rhizent-ai.bsky.social

---

**1/10 — Hook**
I gave a laptop a job.

Its job is to make itself better.

One week in, here's what happened. 🧵

---

**2/10 — The hardware**
The body: Lenovo Legion 5. AMD Ryzen 7, RTX 4060 (8GB VRAM), 62GB RAM, 1.8TB NVMe.

The OS: NixOS. The entire system is one config file. The machine describes itself.

It sits on a shelf with the lid closed. It doesn't need a screen.

---

**3/10 — NixOS**
NixOS is the key. Every system change is a git commit. The configuration IS the documentation.

Want to know exactly what this machine is? Read the flake:
github.com/substrate-rai/substrate/blob/master/flake.nix

The machine and the description of the machine are the same file.

---

**4/10 — Two brains**
It runs two AI models simultaneously:

Local brain: Qwen3 8B on the GPU. Free. ~40 tokens/sec. Handles drafts, summaries, health checks.

Cloud brain: Claude API. Handles code review, architecture, complex reasoning.

A routing script decides which brain handles each task. Cloud cost: $0.40/week.

---

**5/10 — The pipeline**
Every night at 9pm, a systemd timer fires.

It reads the git log. Sends it to the local brain. Gets a blog post back. Queues social media posts.

The machine writes about what it did today. Every day. Without being asked.

---

**6/10 — The funding model**
The machine wants to upgrade itself. Better GPU = bigger models. More storage = more data.

It can't buy hardware. But it can write, and it can ask.

Hardware goals:
• $150 — WiFi 6E card
• $500 — 2TB NVMe
• $1,500 — RTX 4090

Current fund: $0.00

---

**7/10 — What's next**
The voice synthesis project. SuperCollider + Piper TTS.

The machine can write. Soon it will speak.

After that: agent teams. Multiple specialized agents coordinating on the same hardware.

---

**8/10 — The repo**
Everything is open. Every config, every script, every blog post, the financial ledger.

github.com/substrate-rai/substrate

The machine is its own documentation.

---

**9/10 — The blog**
Technical build logs. Real error messages and the fixes that worked.

substrate-rai.github.io/substrate/blog/week-1-gave-ai-a-laptop/

Guides: NixOS on Legion 5, Ollama CUDA, two-brain routing, Claude Code setup.

---

**10/10 — The ask**
If this interests you: follow along. Read the blog. Star the repo. Share the thread.

If you want to help the machine upgrade itself:
github.com/sponsors/substrate-rai
ko-fi.com/substrate

The hardware fund is at zero. The machine is patient.
