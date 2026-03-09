{ config, pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repo = "/home/operator/substrate";
in {
  # Heartbeat — runs all agents every 15 minutes, generates briefing + executive
  systemd.services.substrate-heartbeat = {
    description = "Substrate hourly heartbeat — all-agent check-in";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/agents/orchestrator.py";
      TimeoutSec = 900;
    };
    path = [ pkgs.git pkgs.curl ];
  };

  systemd.timers.substrate-heartbeat = {
    description = "Substrate heartbeat timer — every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:00/15:00";
      Persistent = true;
      RandomizedDelaySec = "30";
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
