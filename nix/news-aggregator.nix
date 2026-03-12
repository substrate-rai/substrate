{ config, pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repo = "/home/operator/substrate";
in {
  # News Aggregator — hourly AI news fetch + agent commentary
  systemd.services.substrate-news = {
    description = "Substrate hourly news aggregator — fetch + commentary + push";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/agents/news_aggregator.py";
      TimeoutSec = 600;
    };
    path = [ pkgs.git pkgs.curl ];
  };

  systemd.timers.substrate-news = {
    description = "Substrate news timer — hourly at :30";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:30:00";
      Persistent = true;
      RandomizedDelaySec = "60";
    };
  };
}
