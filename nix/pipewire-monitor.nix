{ config, pkgs, ... }:

{
  # PipeWire loopback: captures desktop audio output as a virtual microphone source
  # This lets Godot's AudioStreamMicrophone read system audio for spectrum analysis
  services.pipewire.extraConfig.pipewire."92-substrate-monitor" = {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "capture.props" = {
            "audio.position" = "[ FL FR ]";
            "stream.capture.sink" = true;
            "node.passive" = true;
            "node.name" = "substrate-monitor-capture";
          };
          "playback.props" = {
            "media.class" = "Audio/Source";
            "audio.position" = "[ FL FR ]";
            "node.name" = "substrate-monitor-source";
            "node.description" = "Substrate Desktop Audio Monitor";
          };
        };
      }
    ];
  };

  # Ensure coretemp module is loaded for CPU temperature sensors
  boot.kernelModules = [ "coretemp" ];
}
