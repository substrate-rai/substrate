# Research: AI on Linux in 2026: What Actually Works
Topic ID: ai-on-linux-2026
Researched: 2026-03-11 15:30 UTC
Sources checked: 5 (5 fetched)

## External Findings

### https://github.com/ollama/ollama/raw/main/README.md
**Status:** fetched

# Ollama Start building with open models. ## Download ### macOS ```shell curl -fsSL https://ollama.com/install.sh | sh ``` or [download manually](https://ollama.com/download/Ollama.dmg) ### Windows ```shell irm https://ollama.com/install.ps1 | iex ``` or [download manually](https://ollama.com/download/OllamaSetup.exe) ### Linux ```shell curl -fsSL https://ollama.com/install.sh | sh ``` [Manual install instructions](https://docs.ollama.com/linux#manual-install) ### Docker The official [Ollama Docker image](https://hub.docker.com/r/ollama/ollama) `ollama/ollama` is available on Docker Hub. ### Libraries - [ollama-python](https://github.com/ollama/ollama-python) - [ollama-js](https://github.com/ollama/ollama-js) ### Community - [Discord](https://discord.gg/ollama) - [𝕏 (Twitter)](https://x.com/ollama) - [Reddit](https://reddit.com/r/ollama) ## Get started ``` ollama ``` You'll be prompted to run a model or connect Ollama to your existing agents or applications such as `claude`, `codex`, `openclaw` and more. ### Coding To launch a specific integration: ``` ollama launch claude ``` Supported integrations include [Claude Code](https://docs.ollama.com/integrations/claude-code), [Codex](https://docs.ollama.com/integrations/codex), [Droid](https://docs.ollama.com/integrations/droid), and [OpenCode](https://docs.ollama.com/integrations/opencode). ### AI assistant Use [OpenClaw](https://docs.ollama.com/integrations/openclaw) to turn Ollama into a personal AI assistant across WhatsApp, Telegram, Slack, Discord, and more: ``` ollama launch openclaw ``` ### Chat with a model Run and chat with [Gemma 3](https://ollama.com/library/gemma3): ``` ollama run gemma3 ``` See [ollama.com/library](https://ollama.com/library) for the full list. See the [quickstart guide](https://docs.ollama.com/quickstart) for more details. ## REST API Ollama has a REST API for running and managing models. ``` curl http://localhost:11434/api/chat -d '{ "model": "gemma3", "messages": [{ "role": "user", "content": "Why is the sky blue?" }], "stream": false }' ``` See the [API documentation](https://docs.ollama.com/api) for all endpoints. ### Python ``` pip install ollama ``` ```python from ollama import chat response = chat(model='gemma3', messages=[ { 'role': 'user', 'content': 'Why is the sky blue?', }, ]) print(response.message.content) ``` ### JavaScript ``` npm i ollama ``` ```javascript import ollama from "ollama"; const response = await ollama.chat({ model: "gemma3", messages: [{ role: "user", content: "Why is the sky blue?" }], }); console.log(response.message.content); ``` ## Supported backends - [llama.cpp](https://github.com/ggml-org/llama.cpp) project founded by Georgi Gerganov. ## Documentation - [CLI reference](https://docs.ollama.com/cli) - [REST API reference](https://docs.ollama.com/api) - [Importing models](https://docs.ollama.com/import) - [Modelfile reference](https://docs.ollama.com/modelfile) - [Building from source](https://github.com/ollama/ollama/blob/main/docs/dev...

### https://wiki.nixos.org/wiki/Python
**Status:** fetched

Python - Official NixOS Wiki Jump to content Main menu Main menu move to sidebar hide Navigation Home Ecosystem Overview NixOS Package Manager Nix Language Nixpkgs Hydra Applications Topics Software Hardware Desktop Server Community Learn NixOS Overview Guides Tutorials References Cookbooks Wiki Contribute Manual of Style Recent changes Random page Official NixOS Wiki Search Search English Appearance Create account Log in Personal tools Create account Log in Contents move to sidebar hide Beginning 1 Python development environments with Nix Toggle Python development environments with Nix subsection 1.1 Using the Nixpkgs Python infrastructure via shell.nix (recommended) 1.2 Using R packages in python with rpy2 1.3 Using Nix shell (new command line) 1.3.1 Using a Python package not in Nixpkgs 1.4 Running Python packages which requires compilation and/or contains libraries precompiled without nix 1.4.1 Using nix overlay 1.4.2 Using nix-ld 1.4.3 Using fix-python 1.4.4 Using buildFHSEnv (Recommended) 1.4.5 Using a custom nix-shell 1.4.6 Prefix library paths using wrapProgram 1.5 Using venv 1.6 Using uv 1.7 Using poetry 1.7.1 poetry2nix 1.8 Using micromamba 1.9 Using conda 1.9.1 Imperative use 1.10 Using pixi 1.10.1 Using Home Manager 2 Package a Python application Toggle Package a Python application subsection 2.1 With setup.py 2.2 With pyproject.toml 3 Nixpkgs Python contribution guidelines Toggle Nixpkgs Python contribution guidelines subsection 3.1 Libraries 3.2 Applications 4 Special Modules Toggle Special Modules subsection 4.1 GNOME 5 Debug Build 6 Installing Multiple Versions 7 Performance Toggle Performance subsection 7.1 Regression 7.2 Possible Optimizations 8 Troubleshooting Toggle Troubleshooting subsection 8.1 My module cannot be imported 9 See also Toggle the table of contents Python Page Discussion English Read View source View history Tools Tools move to sidebar hide Actions Read View source View history General What links here Related changes Printable version Permanent link Page information Appearance move to sidebar hide From Official NixOS Wiki Python development environments with Nix Nix supports a number of approaches to creating "development environments" for Python programming. These provide functionality analogous to virtualenv or conda : a shell environment with access to pinned versions of the python executable and Python packages. Using the Nixpkgs Python infrastructure via shell.nix (recommended) Nixpkgs has the few last Python versions packaged, as well as a consequent set of Python packages packaged that you can use to quickly create a Python environment. Create a file shell.nix in the project directory, with the following template: # shell.nix let # We pin to a specific nixpkgs commit for reproducibility. # Last updated: 2024-04-29. Check for new commits at https://status.nixos.org. pkgs = import ( fetchTarball https://github.com/NixOS/nixpkgs/archive/cf8cc1201be8bc71b7cbbbdaf349b22f4f99c7ae.tar.gz ) {}; in pkgs . mkShell...

### https://wiki.nixos.org/wiki/CUDA
**Status:** fetched

CUDA - Official NixOS Wiki Jump to content Main menu Main menu move to sidebar hide Navigation Home Ecosystem Overview NixOS Package Manager Nix Language Nixpkgs Hydra Applications Topics Software Hardware Desktop Server Community Learn NixOS Overview Guides Tutorials References Cookbooks Wiki Contribute Manual of Style Recent changes Random page Official NixOS Wiki Search Search English Appearance Create account Log in Personal tools Create account Log in Contents move to sidebar hide Beginning 1 cudatoolkit, cudnn, and related packages 2 Setting up CUDA Binary Cache Toggle Setting up CUDA Binary Cache subsection 2.1 NixOS 2.2 Non-NixOS 3 Some things to keep in mind when setting up CUDA in NixOS 4 CUDA under WSL 5 See also Toggle the table of contents CUDA Page Discussion English Read View source View history Tools Tools move to sidebar hide Actions Read View source View history General What links here Related changes Printable version Permanent link Page information Appearance move to sidebar hide From Official NixOS Wiki NixOS supports using NVIDIA GPUs for pure computing purposes, not just for graphics. For example, many users rely on NixOS for machine learning both locally and on cloud instances. These use cases are supported by the @NixOS/cuda-maintainers team on GitHub ( project board ). If you have an issue using your NVIDIA GPU for computing purposes open an issue on GitHub and tag @NixOS/cuda-maintainers . 🟆&#xfe0e; Tip: Cache : Using the binary cache is recommended! It will save you valuable time and electrons. Click here for more details. 🟆&#xfe0e; Tip: Data center GPUs : Note that you may need to adjust your driver version to use "data center" GPUs like V100/A100s. See this thread for more info. cudatoolkit , cudnn , and related packages ⏲&#xfe0e;&#xfe0e; This section is outdated&#160;as of July 2024. Note that these examples have been updated more recently (as of 2024-07-30). May not be the best solution. A better resource is likely the packaging CUDA sample code here . Further information might be found in the corresponding discussion . Please remove this notice once the information has been updated. The CUDA toolkit is available in a number of different versions . Please use the latest major version. You can see where they're defined in nixpkgs here . Several "CUDA-X" libraries are packages as well. In particular, cuDNN is packaged here . cuTENSOR is packaged here . There are some possible ways to setup a development environment using CUDA on NixOS. This can be accomplished in the following ways: By making a FHS user env # flake.nix, run with `nix develop` # Run with `nix-shell cuda-fhs.nix` { pkgs ? import nixpkgs {} }: let # Change according to the driver used: stable, beta nvidiaPackage = pkgs . linuxPackages . nvidiaPackages . stable ; in ( pkgs . buildFHSEnv { name = cuda-env ; targetPkgs = pkgs : with pkgs ; [ git gitRepo gnupg autoconf curl procps gnumake util-linux m4 gperf unzip cudatoolkit nvidiaPackage libGLU libGL xorg...

### https://wiki.nixos.org/wiki/Ollama
**Status:** fetched

Ollama - Official NixOS Wiki Jump to content Main menu Main menu move to sidebar hide Navigation Home Ecosystem Overview NixOS Package Manager Nix Language Nixpkgs Hydra Applications Topics Software Hardware Desktop Server Community Learn NixOS Overview Guides Tutorials References Cookbooks Wiki Contribute Manual of Style Recent changes Random page Official NixOS Wiki Search Search English Appearance Create account Log in Personal tools Create account Log in Contents move to sidebar hide Beginning 1 Setup 2 Configuration of GPU acceleration 3 Usage via CLI Toggle Usage via CLI subsection 3.1 Download a model and run interactive prompt 3.2 Send a prompt to ollama 3.3 See usage and speed statistics 4 Usage via web API 5 Troubleshooting Toggle Troubleshooting subsection 5.1 AMD GPU with open source driver Toggle the table of contents Ollama Page Discussion English Read View source View history Tools Tools move to sidebar hide Actions Read View source View history General What links here Related changes Printable version Permanent link Page information Appearance move to sidebar hide From Official NixOS Wiki Ollama is an open-source framework designed to facilitate the deployment of large language models on local environments. It aims to simplify the complexities involved in running and managing these models, providing a seamless experience for users across different operating systems. Setup You can add Ollama in two ways to your system configuration. As a standalone package: environment . systemPackages = [ pkgs . ollama ]; As a systemd service: services . ollama = { enable = true ; # Optional: preload models, see https://ollama.com/library loadModels = [ llama3.2:3b deepseek-r1:1.5b ]; }; Configuration of GPU acceleration Acceleration is configured by selecting a package: ollama-cpu: disable GPU, only use CPU ollama-rocm: supported by most modern AMD GPUs ollama-cuda: supported by most modern NVIDIA GPUs ollama-vulkan: supported by most modern GPUs on Linux Example: Enable GPU acceleration for Nvidia graphic cards As a standalone package: environment . systemPackages = [ ( pkgs . ollama . override { acceleration = cuda ; }) ]; As a systemd service: services . ollama = { enable = true ; package = pkgs . ollama-cuda ; }; To find out whether a model is running on CPU or GPU, you can either look at the logs of $ ollama serve and search for "looking for compatible GPUs" and "new model will fit in available VRAM in single GPU, loading" or while a model is answering run in another terminal $ ollama ps NAME ID SIZE PROCESSOR UNTIL gemma3:4b c0494fe00251 4 .7 GB 100 % GPU 4 minutes from now In this example we see "100% GPU". Usage via CLI Download a model and run interactive prompt Example: Download and run Mistral LLM model as an interactive prompt $ ollama run mistral For other models see Ollama library . Send a prompt to ollama Example: To download and run codellama with 13 billion parameters in the "instruct" variant and send a prompt: $ ollama run code...

### https://wiki.nixos.org/wiki/NVIDIA
**Status:** fetched

NVIDIA - Official NixOS Wiki Jump to content Main menu Main menu move to sidebar hide Navigation Home Ecosystem Overview NixOS Package Manager Nix Language Nixpkgs Hydra Applications Topics Software Hardware Desktop Server Community Learn NixOS Overview Guides Tutorials References Cookbooks Wiki Contribute Manual of Style Recent changes Random page Official NixOS Wiki Search Search English Appearance Create account Log in Personal tools Create account Log in Contents move to sidebar hide Beginning 1 Enabling Toggle Enabling subsection 1.1 Kernel modules from NVIDIA 1.1.1 Legacy branches 1.1.2 Beta/production branches 1.2 Nouveau 2 Configuring Toggle Configuring subsection 2.1 Power management 2.2 Hybrid graphics with PRIME 2.2.1 Common setup 2.2.2 Offload mode 2.2.3 Sync mode 2.2.4 Reverse sync mode 2.3 Wayland 2.3.1 Requirements 2.3.2 Supported Compositors 2.3.3 PRIME and Wayland 2.3.4 Explict Sync 3 Tips and tricks Toggle Tips and tricks subsection 3.1 Check nixos-hardware 3.2 Multiple boot configurations 3.3 Using GPUs on non-NixOS 3.4 CUDA and using your GPU for compute 3.5 Multi-Process Service (MPS) 3.6 Running Specific NVIDIA Driver Versions 4 Troubleshooting Toggle Troubleshooting subsection 4.1 Booting to text mode 4.2 Screen tearing issues 4.3 Flickering with Picom 4.4 Graphical corruption and system crashes on suspend/resume 4.5 Black screen or 'nothing works' on laptops 4.6 NVIDIA Docker Containers 5 Disabling Toggle Disabling subsection 5.1 Kernel modules from NVIDIA 5.2 Nouveau 6 Footnotes Toggle the table of contents NVIDIA Page Discussion English Read View source View history Tools Tools move to sidebar hide Actions Read View source View history General What links here Related changes Printable version Permanent link Page information Appearance move to sidebar hide From Official NixOS Wiki This page attempts to cover everything related to the use of NVIDIA GPUs on NixOS. Enabling Kernel modules from NVIDIA Kernel modules from NVIDIA offer better performance than other alternatives, but make the system unfree by requiring proprietary userspace libraries that can interface with the kernel modules. Users that want to have a fully free and open-source system should use Nouveau instead. To enable them, add "nvidia" to the list of enabled video drivers defined by the services.xserver.videoDrivers option. Note: hardware.graphics.enable was named hardware.opengl.enable until NixOS 24.11 . Note: Since driver version 560, you also will need to decide whether to use the open-source or proprietary modules by setting the hardware.nvidia.open option to either true or false respectively. Open-source kernel modules are preferred over and planned to steadily replace proprietary modules &#91; 1 &#93; , although they only support GPUs of the Turing architecture or newer (from GeForce RTX 20 series and GeForce GTX 16 series onwards). Data center GPUs starting from Grace Hopper or Blackwell must use open-source modules — proprietary modules are no lon...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
eefce2b agents: field agents + AI discovery infrastructure
3e6be10 site: batch 3 — mycoworld life, ai arena honeypot, chat modes, dominion mobile, broadcast audio
a8fd85e games: master blueprint + CASCADE rebuild (executive function training)
90d748a content: AI landscape blog post + Byte news digest (Gemini, Claude, Perplexity, OpenClaw, age verification)
94d6618 agents: soul document v2 alignment, portraits, lore, social queue
06384f1 art: regenerate all 25 agent portraits without JoJo LoRA
0deb1ee fix: Byte, Spec, Lumen portraits — masculine prompt rewrites + lock 22 seeds
f919249 feature: 25 agents — portraits, voices, knowledge, context system
c570464 fix: Q writes haiku now, og meta tags, archive stale draft, honest footer
9e6834f credibility: honest language, archive old posts, complete SD character guide
01ebcec feat: separate news section from blog with daily AI headlines
f53a22d fix: make site work for internet visitors — SNES audio, broken links, thumbnails
b015f69 feat: migrate domain to substrate.lol
763ed20 chore: update remaining agent count refs 22→23 across site
51f9b90 feat: update llms.txt with game APIs + add AI Arena to site nav
592b2a7 feat: add AI Arena — portal for AI agents with puzzles and bot APIs
6f0a797 fix: remaining game accessibility improvements
19eba20 fix: regenerate 7 original agent portraits (were abstract, now anime)
060e19d fix: regenerate 16 agent portraits for visual consistency
e71961e feat: site-wide narrative sync + MGS codec About page + character guide

### Existing Blog Posts
- `2026-03-11-ollama-nixos-complete.md`: Ollama on NixOS: Models, CUDA, Systemd, Python
- `2026-03-11-nixos-nvidia-cuda-2026.md`: NixOS + NVIDIA + CUDA: The Complete 2026 Guide
- `2026-03-11-local-vs-cloud-cost-analysis.md`: Local vs Cloud AI: A Real Cost Analysis
- `2026-03-11-claude-code-nixos-complete.md`: Claude Code on NixOS: Complete Setup and Workflow
- `2026-03-11-autonomous-agent-system-linux.md`: How to Build an Autonomous AI Agent System on Linux

### Related Scripts
- `scripts/api-server.py`
- `scripts/crosspost.py`
- `scripts/donations.py`
- `scripts/gen-myth-placeholder.py`
- `scripts/monologue.py`

### NixOS Configuration
```nix
  imports = [
    ./battery-guard.nix
    ./health-check.nix
    ./daily-blog.nix
    ./metrics.nix
    ./content-calendar.nix
    ./feedback-loop.nix
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Packages
  environment.systemPackages = with pkgs; [
```

## Guide Outline Suggestion

Based on research for "AI on Linux in 2026: What Actually Works":

- **Prerequisites** — hardware, software, NixOS version
- **Methodology** — how the data was collected
- **Results** — tables, comparisons, benchmarks
- **Analysis** — what the numbers mean
- **Substrate Note** — what we run in production
- **Troubleshooting** — error → fix format
- **What's Next** — links to related guides
- **NixOS Config Snippets** — from our production flake
- **Cross-references** — related Substrate posts

---
-- Ink, Substrate Research Library
