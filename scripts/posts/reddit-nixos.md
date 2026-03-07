# r/NixOS

**Title:** Full NixOS flake for an AI workstation: Ollama CUDA, systemd timers, battery guard, headless laptop config

**Body:**

Sharing my NixOS flake for an AI workstation running on a Lenovo Legion 5 (RTX 4060, AMD Ryzen 7). The machine runs headless with the lid closed, serves local AI inference, and manages itself via automated systemd timers.

**The flake structure:**

```
flake.nix                    — system + dev shell
nix/
  configuration.nix          — base system (NVIDIA, networking, packages)
  hardware-configuration.nix — auto-generated
  battery-guard.nix          — monitors battery, auto-commits, graceful shutdown
  health-check.nix           — hourly health logging (GPU, VRAM, Ollama, disk)
  daily-blog.nix             — 9pm timer, drafts blog post from git log
```

**Key config decisions:**

1. **Ollama with CUDA on unstable:** The `services.ollama.acceleration` option was removed in unstable. You need `package = pkgs.ollama-cuda` now.

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-cuda;
};
```

2. **Headless laptop:** Three lines to keep it running with the lid closed:

```nix
services.logind.lidSwitch = "ignore";
services.logind.lidSwitchDocked = "ignore";
powerManagement.enable = false;
```

3. **Python in systemd services:** NixOS doesn't put python3 in PATH. For services that need it:

```nix
let pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in {
  systemd.services.my-service = {
    serviceConfig.ExecStart = "${pythonEnv}/bin/python3 /path/to/script.py";
  };
}
```

4. **NVIDIA open kernel modules:** Working well on RTX 4060:

```nix
hardware.nvidia = {
  modesetting.enable = true;
  open = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
```

5. **LUKS with systemd-boot:** Full disk encryption, EFI boot.

**Services running 24/7:**

- Ollama (CUDA, qwen3:8b loaded)
- Battery guard (auto-commit at 25%, shutdown at 10%)
- Health timer (hourly GPU/VRAM/disk logging)
- Blog timer (daily 9pm, local inference → blog post)

**The whole repo is the config.** NixOS configuration, scripts, blog, financial ledger — all in one git repo. The machine is its own documentation.

https://github.com/substrate-rai/substrate

Detailed blog posts covering the NixOS install on Legion 5 (SQUASHFS errors, WiFi issues, NVIDIA setup) and Ollama CUDA setup on the blog: https://substrate-rai.github.io/substrate

Full week 1 writeup: https://substrate-rai.github.io/substrate/blog/week-1-gave-ai-a-laptop/

Would love feedback on the flake structure. First time building something this integrated with NixOS modules.
