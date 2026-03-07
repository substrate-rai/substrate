{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
{
  # Daily blog pipeline — drafts a build log from the day's git activity.
  # Runs at 9pm ET. Posts are marked draft for operator review.

  systemd.services.substrate-blog = {
    description = "Substrate daily blog draft pipeline";
    after = [ "network.target" "ollama.service" ];

    path = with pkgs; [ git coreutils ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = "/home/operator/substrate";
      ExecStart = "${pythonEnv}/bin/python3 /home/operator/substrate/scripts/pipeline.py";
      TimeoutStartSec = 300;  # local inference can be slow
    };
  };

  systemd.timers.substrate-blog = {
    description = "Run Substrate blog pipeline daily at 9pm";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";  # 9pm (system timezone is America/New_York)
      Persistent = true;  # run if missed
    };
  };
}
