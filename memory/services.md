# Services State

Last verified: 2026-03-20

## Active Services (OpenRC)

### Ollama
- **Status:** active (OpenRC + supervise-daemon with healthcheck)
- **Package:** manual install from official binary (no stable Portage ebuild)
- **Models loaded:** qwen3:8b
- **Config:** `/etc/init.d/ollama` + `/etc/conf.d/ollama`
- **API endpoint:** http://localhost:11434
- **Local wrapper:** scripts/think.py (streams via Ollama API)

### OpenSSH
- **Status:** enabled (rc-update add sshd default)

### NetworkManager
- **Status:** managing wifi (wlo1)
- **Current connection:** [redacted]

### Battery Guard
- **Status:** active (OpenRC + supervise-daemon)
- **Config:** `/etc/init.d/substrate-battery-guard` + `/etc/conf.d/substrate-battery-guard`

### NVIDIA Persistence
- **Status:** active (from nvidia-drivers ebuild USE=persistenced)

## Gentoo Configuration

- **Profile:** desktop/amd64
- **Init system:** OpenRC
- **Scheduler:** fcron (22 jobs, see `gentoo/fcrontab`)
- **Filesystem:** BTRFS with snapper snapshots
- **Kernel:** gentoo-kernel-bin (prebuilt)
- **GPU:** nvidia-drivers (proprietary, dist-kernel)
- **Binary packages:** enabled via official binhost

## Installed Packages

See `gentoo/sets/substrate` for the full package set.
Core: vim, git, curl, wget, htop, nvtop, tmux, fish, pciutils, usbutils, linux-firmware
