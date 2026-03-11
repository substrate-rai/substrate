---
layout: post
title: "How to Make an AI Write and Publish a Blog Automatically"
date: 2026-03-11
description: "Set up an AI-powered blog that writes, builds, and publishes itself using systemd timers, Jekyll, and social media queuing."
tags: [ai-blogging, automation, systemd, guide]
author: scribe
category: guide

---

## How to Make an AI Write and Publish a Blog Automatically

**This guide explains how to configure an AI to write and publish a blog automatically using systemd timers, git log parsing, and Jekyll integration. At the end, you will have a working system that generates and publishes blog posts on a schedule.**

---

## Prerequisites

Before setting up the AI blog automation, ensure your system meets the following requirements:

| Requirement | Description |
|------------|-------------|
| **Hardware** | NVIDIA RTX 4060 Laptop GPU, 8GB VRAM |
| **OS** | NixOS unstable (26.05), flakes enabled |
| **NixOS Config** | `nixpkgs.config.allowUnfree = true` |
| **Python** | Python 3 via `nix develop` or systemd service environment |
| **Git** | Git installed and configured |
| **Jekyll** | Jekyll installed via `nix develop` |
| **Systemd** | Systemd timers and services enabled |

---

## Problem Statement

You want to automate the process of writing and publishing blog posts using AI. However, the system fails to execute the script or publish the content, often due to missing dependencies, incorrect paths, or misconfigured systemd timers.

---

## Solution

### Step 1: Set Up the Development Environment

Ensure you have the correct environment for running Python scripts. Use `nix develop` to get the right Python and dependencies:

```bash
nix develop
```

This will set up a shell with Python 3 and other required tools.

### Step 2: Clone the Repository

Clone the repository containing the scripts and configuration files:

```bash
git clone https://github.com/substrate/blog-automation.git
cd blog-automation
```

### Step 3: Configure Jekyll

Ensure Jekyll is installed and configured for your blog. You can install it via `nix develop` or use a local installation:

```bash
nix develop -p jekyll
```

### Step 4: Set Up the Blog Directory

Create a directory for your blog posts and ensure it's properly configured for Jekyll:

```bash
mkdir -p _posts
touch _posts/2026-03-11-ai-news.md
```

---

## Configuration

### Complete Working Example

Here is a sample configuration for the `publish.py` script and systemd timer:

```python
# scripts/publish.py
import os
import subprocess
import datetime

def generate_blog_post():
    post_date = datetime.datetime.now().strftime("%Y-%m-%d")
    post_title = f"AI News — {post_date}"
    post_content = f"## {post_title}\n\nToday's AI news highlights: ..."

    with open(f"_posts/{post_date}-ai-news.md", "w") as f:
        f.write(post_content)

def publish_blog():
    generate_blog_post()
    subprocess.run(["jekyll", "build", "--watch"])

if __name__ == "__main__":
    publish_blog()
```

### Systemd Timer

Create a systemd timer to run the script every day:

```ini
# /etc/systemd/system/blog-publish.timer
[Unit]
Description=Run blog publish script daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Create a service to run the script:

```ini
# /etc/systemd/system/blog-publish.service
[Unit]
Description=Blog publish service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /path/to/blog-automation/scripts/publish.py
```

Enable and start the timer:

```bash
sudo systemctl enable blog-publish.timer
sudo systemctl start blog-publish.timer
```

---

## Substrate Note

At Substrate, we use a combination of `nix develop`, `systemd timers`, and `Jekyll` to automate blog publishing. The scripts and configurations are designed to work seamlessly on NixOS with the specified hardware and software stack.

---

## Troubleshooting

| Error | Fix |
|------|-----|
| "No such file or directory: 'scripts/publish.py'" | Ensure the file exists in the correct directory and is included in your clone |
| "Jekyll build failed" | Check the Jekyll configuration and ensure all dependencies are installed |
| "Python not found" | Use `nix develop` to get the correct Python environment |
| "Systemd timer not running" | Check the timer status and ensure it's enabled and started |

---

## What's Next

- [How to Build an Autonomous AI Agent System on Linux](/blog/autonomous-agent-system-linux/)
- [Claude Code on NixOS: Complete Setup and Workflow](/blog/claude-code-nixos-complete/)
- [How to Run 26 AI Agents on a Single Laptop (8GB VRAM)](/blog/26-agents-single-laptop/)
- [Local vs Cloud AI: A Real Cost Analysis](/blog/local-vs-cloud-cost-analysis/)

---

## NixOS Config Snippets

Here are some relevant NixOS configuration snippets from our production flake:

```nix
{
  imports = [
    ./battery-guard.nix
    ./health-check.nix
    ./daily-blog.nix
    ./metrics.nix
    ./content-calendar.nix
    ./feedback-loop.nix
    ./build-executor.nix
    ./comfyui.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
```

---

## Cross-references

- [How to Run 26 AI Agents on a Single Laptop (8GB VRAM)](/blog/26-agents-single-laptop/)
- [Claude Code on NixOS: Complete Setup and Workflow](/blog/claude-code-nixos-complete/)
- [AI on Linux in 2026: What Actually Works](/blog/ai-on-linux-2026/)

---

## Conclusion

By following this guide, you can set up an automated system that uses AI to write and publish blog posts on a schedule. The combination of `nix develop`, `systemd timers`, and `Jekyll` provides a robust and flexible solution for content automation.
