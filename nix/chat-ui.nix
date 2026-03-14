{ config, pkgs, ... }:

{
  # Substrate Chat UI — auto-start on boot
  systemd.user.services.substrate-chat = {
    description = "Substrate Chat UI";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3.withPackages (ps: [ ])}/bin/python3 /home/operator/substrate/scripts/chat-ui.py";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "HOME=/home/operator"
      ];
    };
  };

  # Open Firefox to chat UI after login
  systemd.user.services.substrate-chat-browser = {
    description = "Open Substrate Chat in Firefox";
    wantedBy = [ "graphical-session.target" ];
    after = [ "substrate-chat.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      ExecStart = "${pkgs.firefox}/bin/firefox http://127.0.0.1:8080";
      RemainAfterExit = true;
    };
  };
}
