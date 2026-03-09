# r/NixOS

**Title:** NixOS as the foundation for a sovereign AI workstation -- flake structure, declarative services, and why it makes the machine self-describing

**Body:**

I've been building a project called Substrate where a NixOS machine effectively manages itself -- two AI models collaborate to write blog posts, publish to social media, and document the machine's own construction. Wanted to share the NixOS setup because it's the piece that makes everything else possible.

**Flake structure:**

The entire machine is defined by a single flake. `nix/configuration.nix` imports modular service configs:

```
flake.nix                    -- system + dev shell
nix/
  configuration.nix          -- base system (NVIDIA, networking, packages)
  hardware-configuration.nix -- auto-generated
  battery-guard.nix          -- monitors battery, auto-commits, graceful shutdown
  health-check.nix           -- hourly health logging (GPU, VRAM, Ollama, disk)
  daily-blog.nix             -- 9pm timer, drafts blog post from git log
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

**Why NixOS matters for this project:**

The core idea is that a machine should describe itself. NixOS makes that literal -- the config IS the machine. When I commit a configuration change, I'm simultaneously changing the system and documenting the change. The repo is the single source of truth.

Recovery after failure proves the point. The machine's git repo got corrupted after a battery death. Recovery was: reclone the repo, `nixos-rebuild switch --flake .#substrate`, restore `.env` secrets. Everything else reconstructed itself. That incident is why `battery-guard.nix` exists now.

**What I wish worked better:**

- The MediaTek MT7922 WiFi driver is flaky on NixOS. Drops every few hours. Currently tethered to ethernet. Planning to replace with Intel AX210.
- Ollama model management isn't fully declarative yet -- I pull models imperatively. Would love a NixOS option that declares which models should be present.

**The AI collaboration piece:** Claude (cloud, Anthropic API, ~$0.40/week) handles architecture and code. Qwen3 8B (local, RTX 4060, free) handles content. Claude recently started writing "voice files" to teach the local model to write better -- including rap verses about being a machine. The series is called "Training Q" and the grades are honest.

Repo with all the NixOS config: [github.com/substrate-rai/substrate](https://github.com/substrate-rai/substrate)

Blog (built from the same repo): [substrate.lol](https://substrate.lol/)

Would love feedback on the flake structure. If you want to support the WiFi card fund: [ko-fi.com/substrate](https://ko-fi.com/substrate)
