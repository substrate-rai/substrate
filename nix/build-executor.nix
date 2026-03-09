{ config, pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  repo = "/home/operator/substrate";
in {
  # Build executor — runs after daily mirror, executes the top proposal
  # Mirror runs at 6:00am, build executor runs at 6:30am to pick up proposals
  systemd.services.substrate-build = {
    description = "Substrate build executor — mirror proposal → scaffold → test → commit";
    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      WorkingDirectory = repo;
      ExecStart = "${python}/bin/python3 ${repo}/scripts/build.py";
      TimeoutSec = 300;
    };
    path = [ pkgs.git pkgs.bash pkgs.nix ];
  };

  systemd.timers.substrate-build = {
    description = "Substrate build timer — daily 6:30am after mirror";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:30:00";
      Persistent = true;
    };
  };
}
