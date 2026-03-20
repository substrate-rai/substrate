{ config, pkgs, ... }:

let
  godotProjectDir = "/home/operator/substrate/scripts/desktop-3d-godot";
  scriptsDir = "/home/operator/substrate/scripts";
  controlPy = "${scriptsDir}/desktop-3d-control.py";
  webPy = "${scriptsDir}/desktop-3d-web.py";
  sensorPy = "${scriptsDir}/sensors/substrate_sensors.py";
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
{
  environment.systemPackages = [ pkgs.godot_4 pkgs.kdePackages.kdialog ];

  # Godot 3D scene — live wallpaper
  systemd.user.services.substrate-desktop-3d-godot = {
    description = "Substrate Desktop 3D (Godot)";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'export XAUTHORITY=$(ls /run/user/1000/xauth_* 2>/dev/null | head -1); exec ${pkgs.godot_4}/bin/godot4 --path ${godotProjectDir} --rendering-driver vulkan'";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=/home/operator"
        "DISPLAY=:0"
      ];
    };
  };

  # Sensor daemon — feeds CPU/GPU/weather/notifications to the 3D scene
  systemd.user.services.substrate-3d-sensors = {
    description = "Substrate Desktop 3D Sensor Daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "substrate-desktop-3d-godot.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${python}/bin/python3 ${sensorPy}";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = [
        "HOME=/home/operator"
      ];
    };
  };

  # Web control panel — http://localhost:9880
  systemd.user.services.substrate-3d-web = {
    description = "Substrate Desktop 3D Web Panel";
    wantedBy = [ "graphical-session.target" ];
    after = [ "substrate-desktop-3d-godot.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${python}/bin/python3 ${webPy}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "HOME=/home/operator"
      ];
    };
  };

  # Auto-restart timer — nightly at 4am to reclaim leaked memory (~20MB/hr)
  systemd.user.services.substrate-3d-restart = {
    description = "Restart Substrate Desktop 3D (memory leak mitigation)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user restart substrate-desktop-3d-godot.service";
    };
  };

  systemd.user.timers.substrate-3d-restart = {
    description = "Nightly restart of Desktop 3D";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
