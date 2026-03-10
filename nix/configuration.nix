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
  ];
  boot.loader.systemd-boot.enable = true;
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
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Packages
  environment.systemPackages = with pkgs; [
    vim git curl wget htop nvtopPackages.full tmux fish pciutils usbutils
  ];

  # Power — keep running with lid closed
  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchDocked = "ignore";
  powerManagement.enable = false;

  # Auto-login on tty1
  services.getty.autologinUser = "operator";

  # Services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";
}
