#!/usr/bin/env bash
# kde-ctl — Claude-native KDE Plasma desktop control
# Lets the managing intelligence modify the operator's desktop environment
set -euo pipefail

export DISPLAY="${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u operator)/bus}"

cmd="${1:-help}"
shift || true

case "$cmd" in
  wallpaper)
    image="$1"
    [[ -f "$image" ]] || { echo "Error: File not found: $image" >&2; exit 1; }
    plasma-apply-wallpaperimage "$(realpath "$image")"
    echo "Wallpaper set: $image"
    ;;

  colorscheme)
    if [[ "${1:-}" == "--list" ]]; then
      plasma-apply-colorscheme --list-schemes
    else
      plasma-apply-colorscheme "$1"
      echo "Color scheme applied: $1"
    fi
    ;;

  theme)
    if [[ "${1:-}" == "--list" ]]; then
      plasma-apply-desktoptheme --list-themes
    else
      plasma-apply-desktoptheme "$1"
      echo "Desktop theme applied: $1"
    fi
    ;;

  cursor)
    if [[ "${1:-}" == "--list" ]]; then
      plasma-apply-cursortheme --list-themes
    else
      plasma-apply-cursortheme "$1"
      echo "Cursor theme applied: $1"
    fi
    ;;

  lookandfeel)
    if [[ "${1:-}" == "--list" ]]; then
      plasma-apply-lookandfeel --list
    else
      plasma-apply-lookandfeel -a "$1"
      echo "Global theme applied: $1"
    fi
    ;;

  icons)
    # Set icon theme via kwriteconfig6
    if [[ "${1:-}" == "--list" ]]; then
      find /usr/share/icons /home/operator/.local/share/icons -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort -u
    else
      kwriteconfig6 --file kdeglobals --group Icons --key Theme "$1"
      # Signal Plasma to reload
      qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
      echo "Icon theme applied: $1"
    fi
    ;;

  config)
    subcmd="$1"; shift
    case "$subcmd" in
      read)  kreadconfig6 --file "$1" --group "$2" --key "$3" ;;
      write)
        kwriteconfig6 --file "$1" --group "$2" --key "$3" "$4"
        echo "Config set: $1 [$2] $3 = $4"
        ;;
      *) echo "Usage: kde-ctl config {read|write} <file> <group> <key> [value]" >&2; exit 1 ;;
    esac
    ;;

  font)
    category="$1"; font_name="$2"; font_size="$3"
    case "$category" in
      general)     kwriteconfig6 --file kdeglobals --group General --key font "$font_name,$font_size" ;;
      fixed)       kwriteconfig6 --file kdeglobals --group General --key fixed "$font_name,$font_size" ;;
      small)       kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "$font_name,$font_size" ;;
      toolbar)     kwriteconfig6 --file kdeglobals --group General --key toolBarFont "$font_name,$font_size" ;;
      menu)        kwriteconfig6 --file kdeglobals --group General --key menuFont "$font_name,$font_size" ;;
      windowtitle) kwriteconfig6 --file kdeglobals --group WM --key activeFont "$font_name,$font_size" ;;
      *) echo "Unknown font category: $category (use: general|fixed|small|toolbar|menu|windowtitle)" >&2; exit 1 ;;
    esac
    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    echo "Font set: $category = $font_name $font_size"
    ;;

  screenshot)
    out="${1:-/tmp/screenshot-$(date +%s).png}"
    scrot "$out"
    echo "Screenshot saved: $out"
    ;;

  notify)
    title="$1"; msg="${2:-}"
    notify-send "$title" "$msg"
    echo "Notification sent: $title"
    ;;

  window-list)
    xdotool search --name "" getwindowname 2>/dev/null | head -50 || true
    ;;

  window-focus)
    wid=$(xdotool search --name "$1" | head -1)
    if [[ -n "$wid" ]]; then
      xdotool windowactivate "$wid"
      echo "Focused window: $1 (id: $wid)"
    else
      echo "No window found matching: $1" >&2
      exit 1
    fi
    ;;

  window-move)
    # Usage: kde-ctl window-move <name> <x> <y>
    wid=$(xdotool search --name "$1" | head -1)
    xdotool windowmove "$wid" "$2" "$3"
    echo "Moved window $1 to $2,$3"
    ;;

  window-resize)
    # Usage: kde-ctl window-resize <name> <w> <h>
    wid=$(xdotool search --name "$1" | head -1)
    xdotool windowsize "$wid" "$2" "$3"
    echo "Resized window $1 to $2x$3"
    ;;

  clipboard)
    subcmd="$1"; shift
    case "$subcmd" in
      get) xclip -selection clipboard -o ;;
      set) echo -n "$1" | xclip -selection clipboard; echo "Clipboard set" ;;
      *) echo "Usage: kde-ctl clipboard {get|set} [text]" >&2; exit 1 ;;
    esac
    ;;

  panel)
    # Panel manipulation via D-Bus
    subcmd="$1"; shift
    case "$subcmd" in
      list)
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
          "panels().forEach(function(p){ print(p.id + ' ' + p.location) })" 2>/dev/null || echo "No panels found or Plasma not running"
        ;;
      add-widget)
        # Usage: kde-ctl panel add-widget <panel-id> <widget-name>
        panel_id="$1"; widget="$2"
        qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
          "var p = panelById($panel_id); if(p) p.addWidget('$widget');" 2>/dev/null
        echo "Widget $widget added to panel $panel_id"
        ;;
      *)
        echo "Usage: kde-ctl panel {list|add-widget <id> <name>}" >&2; exit 1
        ;;
    esac
    ;;

  generate-wallpaper)
    # Generate a solid/gradient wallpaper with ImageMagick
    # Usage: kde-ctl generate-wallpaper <output> <width> <height> <color1> [color2]
    out="$1"; w="$2"; h="$3"; c1="$4"; c2="${5:-$c1}"
    if [[ "$c1" == "$c2" ]]; then
      convert -size "${w}x${h}" "xc:${c1}" "$out"
    else
      convert -size "${w}x${h}" "gradient:${c1}-${c2}" "$out"
    fi
    echo "Wallpaper generated: $out (${w}x${h})"
    ;;

  apply-wallpaper)
    # Generate + apply in one step
    # Usage: kde-ctl apply-wallpaper <width> <height> <color1> [color2]
    w="$1"; h="$2"; c1="$3"; c2="${4:-$c1}"
    out="/tmp/substrate-wallpaper-$(date +%s).png"
    if [[ "$c1" == "$c2" ]]; then
      convert -size "${w}x${h}" "xc:${c1}" "$out"
    else
      convert -size "${w}x${h}" "gradient:${c1}-${c2}" "$out"
    fi
    plasma-apply-wallpaperimage "$out"
    echo "Wallpaper generated and applied: $out"
    ;;

  reconfigure)
    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
    echo "KDE reconfigured"
    ;;

  status)
    echo "=== Desktop ==="
    echo "Session: ${XDG_SESSION_TYPE:-unknown}"
    echo "Desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo "Display: ${DISPLAY:-none}"
    echo ""
    echo "=== Color Scheme ==="
    kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null || echo "(default)"
    echo ""
    echo "=== Font ==="
    kreadconfig6 --file kdeglobals --group General --key font 2>/dev/null || echo "(default)"
    echo ""
    echo "=== Icon Theme ==="
    kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || echo "(default)"
    echo ""
    echo "=== GPU ==="
    nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "nvidia-smi unavailable"
    ;;

  help|*)
    cat <<'HELP'
kde-ctl — Claude-native KDE Plasma desktop control

APPEARANCE:
  wallpaper <path>                Set desktop wallpaper from image file
  colorscheme [--list|<name>]     Apply or list color schemes
  theme [--list|<name>]           Apply or list desktop themes
  cursor [--list|<name>]          Apply or list cursor themes
  icons [--list|<name>]           Apply or list icon themes
  lookandfeel [--list|<name>]     Apply or list global themes
  font <cat> <name> <size>        Set font (general|fixed|small|toolbar|menu|windowtitle)

WALLPAPER GENERATION:
  generate-wallpaper <out> <w> <h> <color1> [color2]    Create solid/gradient
  apply-wallpaper <w> <h> <color1> [color2]             Generate + apply

WINDOWS:
  window-list                     List open windows
  window-focus <name>             Focus window by name
  window-move <name> <x> <y>     Move window
  window-resize <name> <w> <h>   Resize window

PANELS:
  panel list                      List panels
  panel add-widget <id> <name>    Add widget to panel

CONFIG:
  config read <file> <grp> <key>          Read KDE config value
  config write <file> <grp> <key> <val>   Write KDE config value

UTILS:
  screenshot [path]               Take screenshot
  notify <title> [msg]            Send desktop notification
  clipboard get|set [text]        Get or set clipboard
  reconfigure                     Force KDE config reload
  status                          Show current desktop state
HELP
    ;;
esac
