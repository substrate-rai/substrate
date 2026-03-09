{ config, pkgs, ... }:

{
  # Hourly health check — logs GPU temp, VRAM, Ollama status, disk usage.

  systemd.services.substrate-health = {
    description = "Substrate hourly health check";
    after = [ "network.target" "ollama.service" ];

    path = with pkgs; [
      curl python3 git coreutils
      # nvidia-smi lives in the driver package — expose it
      config.boot.kernelPackages.nvidiaPackages.stable.bin
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "operator";
      ExecStart = "${pkgs.bash}/bin/bash /home/operator/substrate/scripts/health-check.sh";
    };
  };

  systemd.timers.substrate-health = {
    description = "Run Substrate health check every hour";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = 60;
    };
  };
}
