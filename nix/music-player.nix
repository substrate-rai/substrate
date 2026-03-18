{ config, pkgs, ... }:

let
  mpdConf = pkgs.writeText "mpd.conf" ''
    music_directory     "/home/operator/Music"
    db_file             "/home/operator/.local/share/mpd/database"
    state_file          "/home/operator/.local/share/mpd/state"
    sticker_file        "/home/operator/.local/share/mpd/sticker.sql"
    playlist_directory  "/home/operator/.local/share/mpd/playlists"

    bind_to_address     "127.0.0.1"
    port                "6600"
    log_level           "default"

    audio_output {
      type    "pulse"
      name    "Substrate Music"
    }
  '';
in {
  environment.systemPackages = with pkgs; [
    mpd       # daemon
    mpc       # CLI client
    ncmpcpp   # TUI client
  ];

  systemd.user.services.substrate-mpd = {
    description = "Substrate Music Player Daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "pipewire.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /home/operator/.local/share/mpd/playlists /home/operator/Music";
      ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon ${mpdConf}";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [ "HOME=/home/operator" ];
    };
  };
}
