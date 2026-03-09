{ config, pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repoDir = "/home/operator/substrate";
in
{
  systemd.services.substrate-mirror = {
    description = "Substrate mirror — daily self-assessment";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      Group = "users";
      WorkingDirectory = repoDir;
      ExecStart = "${pythonEnv}/bin/python3 ${repoDir}/scripts/mirror.py";
      Environment = "HOME=/home/operator";
    };
    path = with pkgs; [ git coreutils systemd util-linux ];
  };

  systemd.timers.substrate-mirror = {
    description = "Run Substrate mirror daily at 6am ET";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
