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
      ExecStart = "${pkgs.bash}/bin/bash -c 'export XAUTHORITY=$(ls /run/user/1000/xauth_* 2>/dev/null | head -1); exec ${pkgs.electron}/bin/electron .'";
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
