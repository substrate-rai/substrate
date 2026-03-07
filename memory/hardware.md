# Hardware Profile

## Machine

- **Model:** Lenovo Legion 5 (laptop)
- **CPU:** AMD Ryzen 7 7735HS with Radeon Graphics (8 cores)
- **RAM:** 62 GB DDR5
- **GPU:** NVIDIA GeForce RTX 4060 Laptop GPU, 8188 MiB VRAM
- **Storage:** 1.8 TB NVMe (nvme0n1), LUKS encrypted (cryptroot), ext4 root
- **Boot:** systemd-boot, EFI, 512 MB boot partition (FAT32)
- **Kernel:** 6.6.94

## Networking

- **Wifi:** MediaTek MT7922 (wlo1) — working via NetworkManager
- **Ethernet:** enp4s0 — available but not currently connected
- **Current IP:** 192.168.1.206/24 (wifi, DHCP)

## GPU Details

- **Driver:** NVIDIA 565.77 (stable, open kernel module)
- **CUDA:** Enabled, used by Ollama
- **Modesetting:** Enabled
- **hardware.graphics.enable:** true

## Disk Layout

```
nvme0n1 (1.8T)
├─ nvme0n1p1 (512M) → /boot (vfat)
└─ nvme0n1p2 (1.8T) → LUKS → cryptroot → / (ext4)
```

No swap configured.

## CPU Features

- Architecture: x86_64
- KVM-AMD kernel module loaded
- AMD microcode updates enabled
