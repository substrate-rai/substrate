{ config, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.godot_4 ];

  systemd.user.services.substrate-desktop-3d-godot = {
    description = "Substrate Desktop 3D (Godot)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.godot_4}/bin/godot4 --path /home/operator/substrate/scripts/desktop-3d-godot --rendering-driver opengl3";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=/home/operator"
        "DISPLAY=:0"
      ];
    };
  };
}
