#!/usr/bin/env bash
# caelestia-wallpaper-toggle.sh — toggle live/static wallpaper
set -euo pipefail
HELPER="$HOME/.local/bin/caelestia-wallpaper-helper.sh"
LIVE="$HOME/.local/bin/caelestia-wallpaper-live.sh"
STATIC="$HOME/.local/bin/caelestia-wallpaper-static.sh"

if pgrep -f mpvpaper >/dev/null 2>&1; then
    exec "$STATIC"
else
    if [[ $# -gt 0 ]]; then
        exec "$LIVE" "$@"
    else
        exec "$LIVE"
    fi
fi