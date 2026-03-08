{ config, pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repo = "/home/operator/substrate";
in {
  # Hourly heartbeat — runs all 22 agents, generates briefing
  systemd.services.substrate-heartbeat = {
    description = "Substrate hourly heartbeat — all-agent check-in";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/agents/orchestrator.py --quick";
      TimeoutSec = 600;
    };
    path = [ pkgs.git pkgs.curl ];
  };

  systemd.timers.substrate-heartbeat = {
    description = "Substrate heartbeat timer — hourly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:00:00";
      Persistent = true;
      RandomizedDelaySec = "60";
    };
  };

  # Weekly retro — Sundays at 6am
  systemd.services.substrate-retro = {
    description = "Substrate weekly retrospective";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/agents/orchestrator.py --retro";
      TimeoutSec = 300;
    };
    path = [ pkgs.git ];
  };

  systemd.timers.substrate-retro = {
    description = "Substrate retro timer — weekly Sunday 6am";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 06:00:00";
      Persistent = true;
    };
  };
}
