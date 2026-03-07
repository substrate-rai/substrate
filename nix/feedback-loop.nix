{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
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
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pythonEnv}/bin/python3 /home/operator/substrate/scripts/stats.py";
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

  # Daily donation check — runs at 6:05am ET
  systemd.services.substrate-donations = {
    description = "Substrate daily donation monitor";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pythonEnv}/bin/python3 /home/operator/substrate/scripts/donations.py";
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
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pythonEnv}/bin/python3 /home/operator/substrate/scripts/social-queue.py";
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
}
