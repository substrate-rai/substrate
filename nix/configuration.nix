{ config, pkgs, ... }:

{
  imports = [
    ./battery-guard.nix
    ./health-check.nix
    ./daily-blog.nix
    ./metrics.nix
    ./content-calendar.nix
    ./feedback-loop.nix
    ./mirror.nix
    ./heartbeat.nix
    ./build-executor.nix
    ./comfyui.nix
    ./news-aggregator.nix
    ./autopush.nix
    ./monitoring.nix
    ./chat-ui.nix
    ./desktop-3d.nix
    ./desktop-3d-godot.nix
    ./pipewire-monitor.nix
    ./substrate-sensors.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-uuid/63a9d542-ce50-42db-b67c-576a345f118c";
  };

  networking.hostName = "substrate";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  users.users.operator = {
    isNormalUser = true;
    description = "substrate operator";
    extraGroups = [ "networkmanager" "wheel" "video" "render" ];
  };

  nixpkgs.config.allowUnfree = true;

  # GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Desktop environment — KDE Plasma 6 on X11 (not Wayland — NVIDIA stability)
  services.xserver.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "plasmax11";
  services.displayManager.autoLogin = {
    enable = true;
    user = "operator";
  };

  # Packages
  environment.systemPackages = with pkgs; [
    vim git curl wget htop nvtopPackages.full tmux fish pciutils usbutils
    # Desktop
    kitty firefox
    # Claude-native desktop control tools
    libnotify         # notify-send for desktop notifications
    imagemagick       # wallpaper generation / image manipulation
    scrot             # screenshots
    xdotool           # window manipulation
    xclip             # clipboard access
    # 3D modeling
    blender           # headless 3D modeling, rendering, format conversion
  ];

  # Power — keep running with lid closed
  services.logind.settings.Login.HandleLidSwitch = "ignore";
  services.logind.settings.Login.HandleLidSwitchDocked = "ignore";
  powerManagement.enable = false;

  # Disable screensaver / screen blanking / DPMS
  services.xserver.serverFlagsSection = ''
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;  # TEMPORARY — re-disable after adding SSH key
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Brute force protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };

  # Compressed swap in RAM — prevents OOM kills
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  # SSD maintenance
  services.fstrim.enable = true;

  # Disk health monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.mail.enable = false;
  };

  # Thermal management
  # Plasma enables power-profiles-daemon by default — conflicts with auto-cpufreq
  services.power-profiles-daemon.enable = false;

  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = { governor = "performance"; };
      battery = { governor = "powersave"; };
    };
  };
  services.thermald.enable = true;

  # Ollama — CUDA-accelerated local inference
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    environmentVariables = {
      OLLAMA_KEEP_ALIVE = "-1";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_MAX_LOADED_MODELS = "2";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  # Ollama sandboxing + OOM protection
  systemd.services.ollama = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 5;
      OOMScoreAdjust = -500;
      MemoryMax = "12G";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/ollama" ];
    };
    unitConfig = {
      StartLimitBurst = 5;
      StartLimitIntervalSec = 300;
    };
  };

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "24.11";
}
