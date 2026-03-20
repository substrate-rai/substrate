#!/bin/sh
# Substrate desktop session services
# Replaces: systemd --user services bound to graphical-session.target
# Launch this from window manager autostart (e.g., i3 exec, or LightDM session script)

SUBSTRATE="/home/operator/substrate"

# Wait for display server
sleep 2

# --- Audio ---
# PipeWire (replaces PulseAudio, provides ALSA/PulseAudio/JACK compat)
gentoo-pipewire-launcher &

# PipeWire loopback: captures desktop audio for Godot spectrum analysis
# (replaces NixOS pipewire extraConfig "92-substrate-monitor")
sleep 1
pw-loopback \
    --capture-props='audio.position=[FL FR] stream.capture.sink=true node.passive=true node.name=substrate-monitor-capture' \
    --playback-props='media.class=Audio/Source audio.position=[FL FR] node.name=substrate-monitor-source node.description="Substrate Desktop Audio Monitor"' &

# MPD — music player daemon
mkdir -p /home/operator/.local/share/mpd/playlists /home/operator/Music
mpd --no-daemon /home/operator/.config/mpd/mpd.conf &

# --- 3D Desktop ---
# Godot live wallpaper (Forward+ Vulkan renderer)
godot4 --path "$SUBSTRATE/scripts/desktop-3d-godot" --rendering-driver vulkan &

# Sensor daemon — feeds CPU/GPU/weather/notifications to 3D scene
sleep 2
python3 "$SUBSTRATE/scripts/sensors/substrate_sensors.py" &

# Web control panel — http://localhost:9880
python3 "$SUBSTRATE/scripts/desktop-3d-web.py" &

# --- Chat UI ---
python3 "$SUBSTRATE/scripts/chat-ui.py" &
sleep 4
firefox http://127.0.0.1:8080 &

echo "Substrate desktop session started"
