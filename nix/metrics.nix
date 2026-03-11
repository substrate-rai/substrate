{ pkgs, ... }:

{
  # Daily metrics collection — GitHub stars, Bluesky followers, GoatCounter views.
  # Runs stats.py --all which produces a unified report at memory/metrics/YYYY-MM-DD.md.

  systemd.services.substrate-metrics = {
    description = "Substrate daily metrics collection";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pkgs.nix}/bin/nix develop /home/operator/substrate --command python3 /home/operator/substrate/scripts/stats.py --all";
      TimeoutStartSec = 120;
    };
  };

  systemd.timers.substrate-metrics = {
    description = "Run Substrate metrics collection daily";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "*-*-* 06:30:00";  # Daily at 6:30am ET (after mirror at 6am)
      Persistent = true;
      RandomizedDelaySec = 300;
    };
  };
}
