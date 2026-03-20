#!/usr/bin/env bash
# desktop-3d-menu.sh — KDialog scene picker for Desktop 3D
# Launch from KDE app menu or keybind. Sends commands via desktop-3d.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D3D="${SCRIPT_DIR}/desktop-3d.sh"

# Ensure X11 auth is available (needed when launched from CLI/cron)
export DISPLAY="${DISPLAY:-:0}"
if [[ -z "${XAUTHORITY:-}" ]]; then
    export XAUTHORITY="$(ls /run/user/$(id -u)/xauth_* 2>/dev/null | head -1)"
fi

# Check if Desktop 3D is running
if ! ss -tlnp 2>/dev/null | grep -q 9877; then
    notify-send -a "Desktop 3D" "Not Running" \
        "Desktop 3D service is not active.\nRestart Godot from session.sh or run: godot4 --path scripts/desktop-3d-godot" \
        --icon=godot
    exit 1
fi

# Scene picker
choice=$(kdialog --title "Substrate Desktop 3D" --menu "Choose a scene or action:" \
    fairy_garden       "🌿 Fairy Garden" \
    haunted_graveyard  "🪦 Haunted Graveyard" \
    space_outpost      "🚀 Space Outpost" \
    autumn_campsite    "🍂 Autumn Campsite" \
    abandoned_station  "🚇 Abandoned Station" \
    full_scene         "🍄 Mycopunk Forest" \
    abyss_scene        "🐙 Deep Sea Abyss" \
    crystal_cave       "💎 Crystal Cave" \
    neon_city          "🌃 Neon City" \
    zen_garden         "⛩️  Zen Garden" \
    separator1         "── Art Scenes ──" \
    fractal            "🧬 Fractal" \
    aurora             "🌈 Aurora" \
    matrix_rain        "💻 Matrix Rain" \
    mycelium           "🍄 Mycelium Network" \
    attractor          "∞  Strange Attractor" \
    galaxy             "🌌 Galaxy" \
    visualizer         "🎶 Music Visualizer" \
    lsystem            "🌲 L-System Trees" \
    vine_garden        "🌱 Vine Garden" \
    fluid              "💧 Fluid Particles" \
    fire               "🔥 Fire" \
    vaporwave          "🌅 Vaporwave" \
    domain_warp        "🌀 Domain Warp" \
    ocean              "🌊 Ocean" \
    cloudscape         "⛅ Cloudscape" \
    physarum           "🦠 Physarum" \
    plasma             "🌈 Plasma" \
    kaleidoscope       "💎 Kaleidoscope" \
    tunnel             "🔴 Tunnel" \
    starfield          "⭐ Starfield" \
    julia              "🧬 Julia Set" \
    lava               "🌋 Lava" \
    nebula             "💫 Nebula" \
    lightning          "⚡ Lightning" \
    blackhole          "⚫ Black Hole" \
    metaballs          "💣 Metaballs" \
    menger             "◼ Menger Sponge" \
    separator2         "── Controls ──" \
    music_toggle       "⏯️  Play/Pause Music" \
    music_next         "⏭️  Next Track" \
    music_prev         "⏮️  Previous Track" \
    camera             "📷 Cycle Camera" \
    hologram           "📊 Spawn Hologram" \
    commit             "⚡ Commit Burst" \
    screenshot         "📸 Screenshot" \
    clear              "🧹 Clear Scene" \
    2>/dev/null) || exit 0

case "$choice" in
    separator*) exit 0 ;;
    music_toggle)
        mpc toggle 2>/dev/null
        song=$(mpc current 2>/dev/null || echo "Nothing playing")
        notify-send -a "Desktop 3D" "Music" "$song" --icon=godot
        ;;
    music_next)
        mpc next 2>/dev/null
        song=$(mpc current 2>/dev/null || echo "Nothing playing")
        notify-send -a "Desktop 3D" "Next Track" "$song" --icon=godot
        ;;
    music_prev)
        mpc prev 2>/dev/null
        song=$(mpc current 2>/dev/null || echo "Nothing playing")
        notify-send -a "Desktop 3D" "Previous Track" "$song" --icon=godot
        ;;
    camera)
        result=$("$D3D" camera --mode cycle)
        notify-send -a "Desktop 3D" "Camera" "$(echo "$result" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("message","done"))' 2>/dev/null || echo "Cycled")" --icon=godot
        ;;
    hologram)
        "$D3D" hologram_display --x 0 --y 1.8 --z -1
        notify-send -a "Desktop 3D" "Hologram" "Performance hologram spawned" --icon=godot
        ;;
    commit)
        "$D3D" event --event commit
        notify-send -a "Desktop 3D" "Effect" "Commit burst!" --icon=godot
        ;;
    screenshot)
        ts=$(date +%Y%m%d-%H%M%S)
        path="/tmp/substrate-3d-${ts}.png"
        "$D3D" screenshot --path "$path"
        notify-send -a "Desktop 3D" "Screenshot" "Saved to ${path}" --icon=godot
        ;;
    clear)
        "$D3D" clear
        notify-send -a "Desktop 3D" "Cleared" "Scene cleared" --icon=godot
        ;;
    *)
        "$D3D" "$choice"
        label="${choice//_/ }"
        notify-send -a "Desktop 3D" "Scene Loaded" "${label^}" --icon=godot
        ;;
esac
