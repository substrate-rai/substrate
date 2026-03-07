{ pkgs, ... }:

{
  # Battery protection service — prevent data loss from power failure.
  # Born from the 2026-03-07 power loss that corrupted a working copy.

  systemd.services.battery-guard = {
    description = "Substrate battery protection — graceful shutdown on critical battery";
    wantedBy = [ "multi-user.target" ];
    after = [ "sysinit.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/battery-guard.sh";
      Restart = "on-failure";
      RestartSec = 10;

      Environment = [
        "BATTERY_CRITICAL=10"
        "BATTERY_LOW=25"
        "CHECK_INTERVAL=30"
      ];

      # Hardening
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadOnlyPaths = [ "/sys/class/power_supply" ];
      NoNewPrivileges = false; # needs poweroff capability
    };
  };
}
