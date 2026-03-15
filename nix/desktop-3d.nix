{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.electron ];

  systemd.user.services.substrate-desktop-3d = {
    description = "Substrate Desktop 3D (Electron)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/home/operator/substrate/scripts/desktop-3d";
      ExecStart = "${pkgs.electron}/bin/electron .";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=/home/operator"
        "DISPLAY=:0"
        "ELECTRON_DISABLE_GPU_SANDBOX=1"
      ];
    };
  };
}
