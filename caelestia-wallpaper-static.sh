#!/usr/bin/env bash
# caelestia-wallpaper-static.sh — restore static wallpaper (stop mpvpaper)
set -euo pipefail
HELPER="$HOME/.local/bin/caelestia-wallpaper-helper.sh"
WALLPAPER_DIR="$HOME/.config/caelestia/Wallpapers/Live"

# Stop live wallpaper
if pgrep -f mpvpaper >/dev/null 2>&1; then
    pkill -f mpvpaper || true
    sleep 0.3
    notify-send "Stopping live wallpaper..." "" 2>/dev/null || true
fi

# Re-enable Caelestia wallpaper
"$HELPER" on

# Resolve static wallpaper: prefer current Caelestia state, fallback to first image in Wallpapers
resolve_static() {
    local path
    path=$(cat ~/.local/state/caelestia/wallpaper/path.txt 2>/dev/null || echo "")
    if [[ -n "$path" && -f "$path" ]]; then
        echo "$path"; return 0
    fi
    path=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.webp" \) 2>/dev/null | head -n1)
    [[ -n "$path" && -f "$path" ]] && { echo "$path"; return 0; }
    return 1
}

if WALL_PATH=$(resolve_static); then
    caelestia wallpaper -f "$WALL_PATH" 2>&1 | head -n 20 || true
    notify-send "Static wallpaper active" "$(basename "$WALL_PATH")" 2>/dev/null || true
    echo "Static active: $WALL_PATH"
else
    echo "No static wallpaper found in $WALLPAPER_DIR" >&2
fi
