{ config, pkgs, ... }:

let
  sensorsPython = pkgs.python3.withPackages (ps: [ ps.requests ]);
in {
  systemd.user.services.substrate-sensors = {
    description = "Substrate Sensor Daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${sensorsPython}/bin/python3 /home/operator/substrate/scripts/sensors/substrate_sensors.py";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = [
        "HOME=/home/operator"
      ];
    };
  };
}
