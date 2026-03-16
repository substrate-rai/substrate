{ config, pkgs, ... }:

let
  repo = "/home/operator/substrate";
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
in {
  # Autopush — commit and push data changes hourly
  # Runs at :45 (after news aggregator at :30 has time to finish)
  # Triggers GitHub Pages rebuild via push event in rebuild.yml

  systemd.services.substrate-autopush = {
    description = "Substrate hourly auto-commit and push";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ git openssh coreutils bash python util-linux ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pkgs.bash}/bin/bash ${repo}/scripts/autopush.sh";
      TimeoutSec = 120;
    };
  };

  systemd.timers.substrate-autopush = {
    description = "Push data updates to GitHub hourly at :45";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:45:00";
      Persistent = true;
      RandomizedDelaySec = "60";
    };
  };
}
