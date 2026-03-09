{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repo = "/home/operator/substrate";
in
{
  # Daily stats collection (GitHub API) — runs at 6am ET
  systemd.services.substrate-stats = {
    description = "Substrate daily GitHub stats collection";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pythonEnv}/bin/python3 ${repo}/scripts/stats.py";
      TimeoutStartSec = 60;
    };
  };

  systemd.timers.substrate-stats = {
    description = "Daily GitHub stats collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
    };
  };

  # Daily audience metrics (GoatCounter) — runs at 6:10am ET
  systemd.services.substrate-audience = {
    description = "Substrate daily audience metrics (GoatCounter)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pythonEnv}/bin/python3 ${repo}/scripts/stats.py --metrics";
      TimeoutStartSec = 60;
    };
  };

  systemd.timers.substrate-audience = {
    description = "Daily audience metrics collection";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:10:00";
      Persistent = true;
    };
  };

  # Daily donation check — runs at 6:05am ET
  systemd.services.substrate-donations = {
    description = "Substrate daily donation monitor";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pythonEnv}/bin/python3 ${repo}/scripts/donations.py";
      TimeoutStartSec = 60;
    };
  };

  systemd.timers.substrate-donations = {
    description = "Daily donation monitor";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:05:00";
      Persistent = true;
    };
  };

  # Social media queue — posts twice daily (10am and 4pm ET)
  systemd.services.substrate-social = {
    description = "Substrate social media queue publisher";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pythonEnv}/bin/python3 ${repo}/scripts/social-queue.py";
      TimeoutStartSec = 60;
    };
  };

  systemd.timers.substrate-social = {
    description = "Social media queue (twice daily)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 10,16:00:00";
      Persistent = true;
    };
  };

  # Git push — every 6 hours, push local commits to GitHub
  # Prevents data loss if the machine dies (learned from Day 1 battery incident)
  systemd.services.substrate-push = {
    description = "Substrate periodic git push to GitHub";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${pkgs.git}/bin/git push origin master";
      TimeoutStartSec = 60;
      Environment = [
        "HOME=/home/operator"
        "SSH_AUTH_SOCK="
      ];
    };
    path = [ pkgs.openssh ];
  };

  systemd.timers.substrate-push = {
    description = "Push to GitHub every 6 hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00,06,12,18:15:00";
      Persistent = true;
    };
  };
}
