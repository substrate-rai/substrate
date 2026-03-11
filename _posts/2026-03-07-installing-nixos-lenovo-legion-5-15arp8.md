---
layout: post
title: "How to Install NixOS on a Lenovo Legion 5 15ARP8 (NVIDIA RTX 4060, MediaTek WiFi)"
date: 2026-03-07
description: "Step-by-step guide to installing NixOS on Lenovo Legion 5 with RTX 4060 GPU, MediaTek MT7922 WiFi, and LUKS full-disk encryption. Covers SQUASHFS errors, NVIDIA driver setup, and headless configuration."
tags: [nixos, lenovo-legion-5, nvidia, rtx-4060, luks, installation-guide]
category: guide
---

Installing NixOS on a Lenovo Legion 5 15ARP8 requires workarounds for SQUASHFS boot errors, a MediaTek WiFi card that doesn't work on the minimal ISO, and NVIDIA driver configuration. This guide covers every error and the exact fix. Total install time: about 4 hours.

## Hardware

| Component | Detail |
|-----------|--------|
| CPU | AMD Ryzen 7 7735HS (8 cores, Zen 3+) |
| GPU | NVIDIA GeForce RTX 4060 Laptop, 8 GB VRAM |
| RAM | 62 GB DDR5 |
| Storage | 1.8 TB NVMe |
| WiFi | MediaTek MT7922 (Filogic 330) |
| Ethernet | Realtek (enp4s0) |

## Error: SQUASHFS Decompression Failure on Boot

When booting the NixOS minimal ISO (24.11) from USB, you may see:

```
SQUASHFS error: Unable to read data cache entry
SQUASHFS error: Unable to read page, block ...
```

The installer cannot unpack its own filesystem.

### Fix

The USB stick has bad sectors. Re-download the ISO, verify the SHA-256 checksum, and flash to a **different USB stick**:

```bash
sha256sum nixos-minimal-24.11-x86_64-linux.iso
# Compare against the official checksum at nixos.org/download

dd if=nixos-minimal-24.11-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Use a known-good USB drive. Cheap flash drives fail silently.

## Error: WiFi Not Working on Minimal ISO

The MediaTek MT7922 shows up in `lspci`:

```
03:00.0 Network controller: MEDIATEK Corp. MT7921 802.11ax PCI Express Wireless Network Adapter
```

But `iwctl` cannot bring the radio up. `wpa_supplicant` finds no interfaces. The NixOS minimal ISO does not include `linux-firmware`, which this card requires.

### Fix

**Use ethernet for the installation.** The onboard Realtek NIC (`enp4s0`) works immediately. Plug in a cable and continue.

After installation, add to `configuration.nix`:

```nix
hardware.firmware = [ pkgs.linux-firmware ];
networking.networkmanager.enable = true;
```

Run `sudo nixos-rebuild switch`. WiFi will work after reboot.

## Partitioning with LUKS Encryption

### Partition layout

```
nvme0n1 (1.8T)
├─ nvme0n1p1 (512M) → /boot (vfat, EFI)
└─ nvme0n1p2 (1.8T) → LUKS → cryptroot → / (ext4)
```

### Commands

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 cryptroot

mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/disk/by-id/dm-name-cryptroot

mount /dev/disk/by-id/dm-name-cryptroot /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

nixos-generate-config --root /mnt
```

Add to `configuration.nix`:

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;

boot.initrd.luks.devices."cryptroot" = {
  device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
};
```

Get the UUID with `blkid /dev/nvme0n1p2`.

## NVIDIA Driver Configuration

The RTX 4060 requires explicit driver configuration. Without it, you get no GPU acceleration.

Add to `configuration.nix`:

```nix
nixpkgs.config.allowUnfree = true;

services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
hardware.graphics.enable = true;
```

Key points:
- `allowUnfree = true` is **required** — without it the NVIDIA driver won't be available.
- `open = true` uses NVIDIA's open kernel modules. These work on RTX 40-series.
- `modesetting.enable = true` prevents blank screen on boot.
- Don't set `prime.offload` or `prime.sync` for headless/server use.

Verify after reboot:

```
$ nvidia-smi
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 565.77                 Driver Version: 565.77         CUDA Version: 12.7     |
|  NVIDIA GeForce RTX 4060 Laptop GPU         32C    18MiB / 8188MiB                      |
+-----------------------------------------------------------------------------------------+
```

## Headless Configuration (Lid Closed)

If you're using the Legion 5 as a server, closing the lid will suspend the machine by default, killing all services.

Add to `configuration.nix`:

```nix
services.logind.lidSwitch = "ignore";
services.logind.lidSwitchDocked = "ignore";
powerManagement.enable = false;
```

## Complete Working Configuration

```nix
{ config, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-HERE";
  };

  networking.hostName = "substrate";
  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";

  nixpkgs.config.allowUnfree = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  powerManagement.enable = false;

  environment.systemPackages = with pkgs; [
    vim git curl wget htop nvtopPackages.full tmux
    fish pciutils usbutils
  ];

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";
}
```

## Troubleshooting

**"SQUASHFS error" on boot** — Bad USB media. Reflash to a different drive.

**No WiFi after install** — Missing `hardware.firmware = [ pkgs.linux-firmware ];`. Add it and rebuild.

**Black screen after reboot** — Missing `hardware.nvidia.modesetting.enable = true`. Boot into recovery or TTY (Ctrl+Alt+F2) and add it.

**"unfree package nvidia-x11 refused"** — Missing `nixpkgs.config.allowUnfree = true`.

**Laptop suspends when lid closed** — Missing `services.logind.lidSwitch = "ignore"`.

## What's Next

This machine runs [substrate](https://github.com/substrate-rai/substrate), a sovereign AI workstation that documents its own construction. See the blog for guides on [running Ollama with CUDA on NixOS]({{ site.baseurl }}/blog/ollama-cuda-nixos-unstable/) and [two-brain AI routing]({{ site.baseurl }}/blog/two-brain-ai-routing-local-cloud-nixos/).

[Sponsor the hardware fund]({{ site.baseurl }}/site/fund/) | [GitHub](https://github.com/substrate-rai/substrate)
