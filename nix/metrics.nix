{ pkgs, ... }:

{
  # Weekly metrics collection — GitHub stars, Bluesky followers, repo stats.

  systemd.services.substrate-metrics = {
    description = "Substrate weekly metrics collection";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/metrics.sh";
    };
  };

  systemd.timers.substrate-metrics = {
    description = "Run Substrate metrics collection weekly";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "Sun *-*-* 20:00:00";  # Sunday 8pm ET
      Persistent = true;
      RandomizedDelaySec = 300;
    };
  };
}
