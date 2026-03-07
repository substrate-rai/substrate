{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
{
  # Content calendar timers:
  #   Monday 10am:    Technical deep-dive draft
  #   Wednesday 10am: Weekly narrative draft
  #   Friday 10am:    Social-only post draft
  #   Sunday 8pm:     Weekly state-of-substrate report

  # Monday — Technical post
  systemd.services.substrate-content-monday = {
    description = "Substrate Monday technical post draft";
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/content-calendar.sh monday";
      Environment = [ "PATH=${pythonEnv}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin" ];
      TimeoutStartSec = 300;
    };
  };

  systemd.timers.substrate-content-monday = {
    description = "Monday technical post timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon *-*-* 10:00:00";
      Persistent = true;
    };
  };

  # Wednesday — Weekly narrative
  systemd.services.substrate-content-wednesday = {
    description = "Substrate Wednesday weekly narrative draft";
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/content-calendar.sh wednesday";
      Environment = [ "PATH=${pythonEnv}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin" ];
      TimeoutStartSec = 300;
    };
  };

  systemd.timers.substrate-content-wednesday = {
    description = "Wednesday weekly narrative timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Wed *-*-* 10:00:00";
      Persistent = true;
    };
  };

  # Friday — Social post
  systemd.services.substrate-content-friday = {
    description = "Substrate Friday social post draft";
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/content-calendar.sh friday";
      Environment = [ "PATH=${pythonEnv}/bin:${pkgs.curl}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin" ];
      TimeoutStartSec = 300;
    };
  };

  systemd.timers.substrate-content-friday = {
    description = "Friday social post timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Fri *-*-* 10:00:00";
      Persistent = true;
    };
  };

  # Sunday — Weekly report
  systemd.services.substrate-content-report = {
    description = "Substrate weekly state report";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = with pkgs; [ curl git coreutils findutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/content-calendar.sh weekly-report";
      TimeoutStartSec = 120;
    };
  };

  systemd.timers.substrate-content-report = {
    description = "Sunday weekly report timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 20:00:00";
      Persistent = true;
    };
  };
}
