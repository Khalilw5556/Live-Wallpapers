#!/usr/bin/env bash
# caelestia-wallpaper-helper.sh — toggle Caelestia background.wallpaperEnabled
# Usage: helper.sh [on|off|status]
set -euo pipefail
CONFIG="$HOME/.config/caelestia/shell.json"

[[ -f "$CONFIG" ]] || echo '{}' > "$CONFIG"

if ! python3 -m json.tool "$CONFIG" >/dev/null 2>&1; then
    echo "shell.json is invalid, restoring backup" >&2
    cp -f "$HOME/shell.json.bak" "$CONFIG" 2>/dev/null || echo '{}' > "$CONFIG"
fi

case "${1:-status}" in
    on)
        python3 - << 'PY'
import json, pathlib
p = pathlib.Path.home() / ".config/caelestia/shell.json"
data = json.loads(p.read_text()) if p.exists() else {}
data.setdefault("background", {})["wallpaperEnabled"] = True
p.write_text(json.dumps(data, indent=4))
print("wallpaperEnabled -> true")
PY
        ;;
    off)
        python3 - << 'PY'
import json, pathlib
p = pathlib.Path.home() / ".config/caelestia/shell.json"
data = json.loads(p.read_text()) if p.exists() else {}
data.setdefault("background", {})["wallpaperEnabled"] = False
p.write_text(json.dumps(data, indent=4))
print("wallpaperEnabled -> false")
PY
        ;;
    status)
        python3 - << 'PY'
import json, pathlib
p = pathlib.Path.home() / ".config/caelestia/shell.json"
try:
    data = json.loads(p.read_text())
    print(f"wallpaperEnabled = {data.get('background', {}).get('wallpaperEnabled', True)}")
except Exception:
    print("unknown")
PY
        ;;
    *) echo "usage: $0 [on|off|status]" >&2; exit 1 ;;
esac
