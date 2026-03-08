{ config, pkgs, ... }:

let
  python = pkgs.python3;
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
      ExecStart = "${python}/bin/python3 ${repoDir}/scripts/mirror.py";
      Environment = "HOME=/home/operator";
    };
    path = with pkgs; [ git coreutils systemd util-linux ] ++ [ "/run/current-system/sw" ];
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
