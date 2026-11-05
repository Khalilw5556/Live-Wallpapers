#!/usr/bin/env bash
# caelestia-wallpaper-live.sh — start live wallpaper via mpvpaper (reads slot sound preference automatically)
set -euo pipefail

WITH_SOUND_OVERRIDE=""
SLOT=""
declare -a NEW_ARGS=()

for arg in "$@"; do
    case "$arg" in
        --withsound|-withsound)
            WITH_SOUND_OVERRIDE="1"
            ;;
        --nosound|--mute|-nosound|-mute)
            WITH_SOUND_OVERRIDE="0"
            ;;
        --withsound-[1-9]|--withsound-10|-withsound-[1-9]|-withsound-10)
            WITH_SOUND_OVERRIDE="1"
            SLOT="${arg#*sound-}"
            ;;
        --[1-9]|--10|-[1-9]|-10)
            SLOT="${arg#*-}"
            SLOT="${SLOT#-}"
            ;;
        [1-9]|10)
            SLOT="$arg"
            ;;
        *)
            NEW_ARGS+=("$arg")
            ;;
    esac
done

if [[ ${#NEW_ARGS[@]} -gt 0 ]]; then
    set -- "${NEW_ARGS[@]}"
else
    set --
fi

LIVE_DIR="$HOME/.config/caelestia/Wallpapers/Live"
HELPER="$HOME/.local/bin/caelestia-wallpaper-helper.sh"
CACHE_FILE="$HOME/.cache/caelestia/live-wallpaper-path.txt"
SLOTS_DIR="$HOME/.config/caelestia/slots"

command -v mpvpaper >/dev/null 2>&1 || {
    notify-send -u critical "mpvpaper not installed" "Install: paru -S mpvpaper" 2>/dev/null || true
    echo "ERROR: mpvpaper not found" >&2; exit 1
}

if [[ "${1:-}" == "--stop" || "${1:-}" == "-stop" ]]; then
    pkill -f mpvpaper || true
    "$HELPER" on
    notify-send "Live wallpaper stopped" "" 2>/dev/null || true
    exit 0
fi

resolve_paired() {
    local static_path base base_noext candidate
    static_path=$(cat ~/.local/state/caelestia/wallpaper/path.txt 2>/dev/null || echo "")
    [[ -z "$static_path" ]] && static_path=$(readlink ~/.local/state/caelestia/wallpaper/current 2>/dev/null || echo "")
    [[ -z "$static_path" || ! -f "$static_path" ]] && return 1
    base=$(basename "$static_path")
    base_noext="${base%.*}"
    for ext in mp4 webm mkv mov gif; do
        candidate=$(find "$LIVE_DIR" -maxdepth 1 -iname "$base_noext.$ext" -type f 2>/dev/null | head -n1)
        [[ -n "$candidate" && -f "$candidate" ]] && { echo "$candidate"; return 0; }
    done
    candidate=$(find "$LIVE_DIR" -maxdepth 1 -type f -iname "$base_noext*" \
        \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.gif" \) 2>/dev/null | head -n1)
    [[ -n "$candidate" && -f "$candidate" ]] && { echo "$candidate"; return 0; }
    return 1
}

pick_random() {
    local candidates=()
    [[ -d "$LIVE_DIR" ]] || mkdir -p "$LIVE_DIR"
    mapfile -t candidates < <(find "$LIVE_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.gif" -o -iname "*.mkv" -o -iname "*.mov" \) 2>/dev/null)
    [[ ${#candidates[@]} -gt 0 ]] || {
        echo "ERROR: No video files in $LIVE_DIR" >&2; exit 1
    }
    printf "%s\n" "${candidates[@]}" | shuf -n1
}

TARGET=""
FINAL_SOUND=0

# 1. Play from saved slot
if [[ -n "$SLOT" ]]; then
    SLOT_FILE="$SLOTS_DIR/slot_${SLOT}.conf"
    if [[ ! -f "$SLOT_FILE" ]]; then
        echo "ERROR: Slot $SLOT is empty! Save a wallpaper first: wset <file> -$SLOT" >&2
        exit 1
    fi

    # Load saved configuration (LIVE_FILE, STATIC_FILE, WITH_SOUND)
    # shellcheck disable=SC1090
    source "$SLOT_FILE"
    TARGET="$LIVE_FILE"
    FINAL_SOUND="${WITH_SOUND:-0}"

    # Automatically sync Caelestia theme colors with selected wallpaper
    if [[ -f "${STATIC_FILE:-}" ]] && command -v caelestia >/dev/null 2>&1; then
        echo "[live] Syncing Caelestia theme: $STATIC_FILE" >&2
        caelestia wallpaper -f "$STATIC_FILE" 2>&1 | head -n 5 || true
    fi

# 2. Random selection
elif [[ "${1:-}" == "--random" || "${1:-}" == "-random" ]]; then
    TARGET=$(pick_random)

# 3. No arguments: Paired or last cached wallpaper
elif [[ $# -eq 0 ]]; then
    if PAIRED=$(resolve_paired); then
        TARGET="$PAIRED"
    else
        LAST=$(cat "$CACHE_FILE" 2>/dev/null || echo "")
        if [[ -n "$LAST" && -f "$LAST" ]]; then
            TARGET="$LAST"
        else
            TARGET=$(pick_random)
        fi
    fi
else
    TARGET="$1"
    [[ -f "$TARGET" ]] || { echo "ERROR: File not found: $TARGET" >&2; exit 1; }
fi

# Override saved sound preference if manually specified by user
if [[ "$WITH_SOUND_OVERRIDE" == "1" ]]; then
    FINAL_SOUND=1
elif [[ "$WITH_SOUND_OVERRIDE" == "0" ]]; then
    FINAL_SOUND=0
fi

# Stop any previous instance
"$HELPER" off
pkill -f mpvpaper || true
sleep 0.3

# Configure MPV options
if [[ "$FINAL_SOUND" -eq 1 ]]; then
    MPV_OPTS="loop hwdec=auto volume=100"
    SOUND_MSG="Sound ON"
else
    MPV_OPTS="loop hwdec=auto no-audio"
    SOUND_MSG="Muted"
fi

echo "Starting mpvpaper: $TARGET ($SOUND_MSG)"
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$TARGET" > "$CACHE_FILE"
rm -f /tmp/mpvpaper.log

nohup nice -n 10 mpvpaper -o "$MPV_OPTS" -p -a max ALL "$TARGET" >>/tmp/mpvpaper.log 2>&1 &
renice -n 10 -p $! >/dev/null 2>&1 || true

sleep 1
if pgrep -f mpvpaper >/dev/null; then
    notify-send "Live wallpaper active" "$(basename "$TARGET") ($SOUND_MSG)" 2>/dev/null || true
    echo "Active: $TARGET ($SOUND_MSG)"
else
    echo "mpvpaper failed, check /tmp/mpvpaper.log" >&2
    "$HELPER" on
    exit 1
fi