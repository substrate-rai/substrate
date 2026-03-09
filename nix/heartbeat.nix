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

  # Q's monologue — daily 7am, reads latest briefing, posts haiku to Bluesky
  systemd.services.substrate-monologue = {
    description = "Q's daily haiku monologue — briefing → haiku → Bluesky queue";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/monologue.py";
      TimeoutSec = 120;
    };
    path = [ pkgs.git ];
  };

  systemd.timers.substrate-monologue = {
    description = "Q's monologue timer — daily 7am after mirror";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 07:00:00";
      Persistent = true;
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
