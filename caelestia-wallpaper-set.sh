#!/usr/bin/env bash
# caelestia-wallpaper-set.sh — ONLY save wallpapers to slots (1-10) with/without sound preference.
# Does NOT launch mpvpaper.
set -euo pipefail

VERBOSE="${VERBOSE:-1}"
LIVE_DIR="$HOME/.config/caelestia/Wallpapers/Live"
STATIC_DIR="$HOME/.config/caelestia/Wallpapers/Live"
SLOTS_DIR="$HOME/.config/caelestia/slots"
mkdir -p "$LIVE_DIR" "$STATIC_DIR" "$SLOTS_DIR"

WITH_SOUND=0
SLOT=""
INPUT=""
CUSTOM_NAME=""

log() { [[ "$VERBOSE" == "1" ]] && echo "[wset] $*" >&2 || true; }
err() { echo "[wset] ERROR: $*" >&2; }
notify() { notify-send "$1" "$2" 2>/dev/null || true; }

usage() {
    cat <<'EOF'
Usage:
  wset <video> [-1..--10] [--withsound] [--withsound-1..--withsound-10] [--name <name>]

Examples:
  wset ~/Downloads/anime.mp4 --withsound-1   # Save to slot 1 with sound enabled
  wset ~/Downloads/anime.mp4 -1             # Save to slot 1 without sound
  wset ~/Videos/loop.webm --withsound -2     # Save to slot 2 with sound
EOF
}

# Allow optional "set" keyword if passed from an alias
if [[ $# -gt 0 && "${1:-}" == "set" ]]; then
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --withsound-[1-9]|--withsound-10|-withsound-[1-9]|-withsound-10)
            WITH_SOUND=1
            SLOT="${1#*sound-}"
            shift
            ;;
        --withsound|-withsound)
            WITH_SOUND=1
            shift
            ;;
        --[1-9]|--10|-[1-9]|-10)
            SLOT="${1#*-}"
            SLOT="${SLOT#-}"
            shift
            ;;
        --name)
            CUSTOM_NAME="$2"; shift 2
            ;;
        -h|--help)
            usage; exit 0
            ;;
        --verbose) VERBOSE=1; shift ;;
        --quiet) VERBOSE=0; shift ;;
        *)
            if [[ -z "$INPUT" ]]; then
                INPUT="$1"
            elif [[ "$1" =~ ^([1-9]|10)$ && -z "$SLOT" ]]; then
                SLOT="$1"
            else
                err "Unknown argument: $1"; usage; exit 1
            fi
            shift
            ;;
    esac
done

[[ -n "$INPUT" ]] || { err "No file provided"; usage; exit 1; }
[[ -f "$INPUT" ]] || { err "File not found: $INPUT"; exit 1; }

ext="${INPUT##*.}"
ext_lc=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
[[ "$ext_lc" =~ ^(mp4|webm|mkv|mov|gif)$ ]] || err "Warning: extension .$ext_lc may be unsupported"

command -v ffmpeg >/dev/null 2>&1 || { err "ffmpeg not found"; exit 1; }

# Naming
orig_base=$(basename "$INPUT")
orig_base_noext="${orig_base%.*}"

if [[ -n "$CUSTOM_NAME" ]]; then
    base="$CUSTOM_NAME"
elif [[ -n "$SLOT" ]]; then
    clean_name=$(echo "$orig_base_noext" | tr ' ' '-' | tr -cd 'a-zA-Z0-9._-')
    base="slot_${SLOT}_${clean_name}"
else
    base=$(echo "$orig_base_noext" | tr ' ' '-' | tr -cd 'a-zA-Z0-9._-')
    [[ -n "$base" ]] || base="wallpaper"
fi

# Avoid overwriting unrelated wallpapers if not using a specific slot
if [[ -z "$SLOT" ]]; then
    suffix=""; cnt=0
    while [[ -e "$LIVE_DIR/$base$suffix.$ext_lc" || -e "$STATIC_DIR/$base$suffix.jpg" ]]; do
        cnt=$((cnt + 1))
        suffix="_$cnt"
        [[ $cnt -le 50 ]] || { err "Too many duplicates"; exit 1; }
    done
    [[ -n "$suffix" ]] && base="${base}${suffix}"
fi

live_dst="$LIVE_DIR/$base.$ext_lc"
static_dst="$STATIC_DIR/$base.jpg"

log "Saving video to: $live_dst"
cp -f "$INPUT" "$live_dst"
[[ -f "$live_dst" ]] || { err "Failed to copy video"; exit 1; }

# Extract frame for color palette extraction
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT" 2>/dev/null || echo "0")
[[ "$duration" == "N/A" || -z "$duration" ]] && duration="0"
seek=$(python3 -c "d=float('$duration'); s=max(0.5, d*0.25) if d>0 else 0.5; print(f'{s:.2f}')" 2>/dev/null || echo "0.50")

log "Extracting frame..."
set +e
ffmpeg -y -hide_banner -loglevel error -ss "$seek" -i "$INPUT" -vframes 1 -q:v 2 \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease" -frames:v 1 "$static_dst" 2>&1
ff_status=$?
set -e

if [[ $ff_status -ne 0 || ! -s "$static_dst" ]]; then
    ffmpeg -y -hide_banner -loglevel error -i "$INPUT" -vframes 1 -q:v 2 "$static_dst" 2>/dev/null || true
fi

[[ -s "$static_dst" ]] || { err "Failed to extract frame from video"; exit 1; }

# Save slot configuration file
if [[ -n "$SLOT" ]]; then
    cat <<EOF > "$SLOTS_DIR/slot_${SLOT}.conf"
LIVE_FILE="$live_dst"
STATIC_FILE="$static_dst"
WITH_SOUND=$WITH_SOUND
EOF
    log "Saved Slot $SLOT metadata (Sound: $WITH_SOUND)"
fi

# Update state cache
mkdir -p ~/.cache/caelestia 2>/dev/null || true
echo "$live_dst" > ~/.cache/caelestia/live-wallpaper-path.txt
echo "$static_dst" > ~/.cache/caelestia/static-wallpaper-path.txt

sound_txt=$( [[ $WITH_SOUND -eq 1 ]] && echo "Enabled" || echo "Disabled" )
notify "Wallpaper Saved" "Slot: ${SLOT:-custom} | Sound: $sound_txt"

echo ""
echo "=========================================="
echo "      Wallpaper Saved Successfully        "
echo "=========================================="
echo "  Slot:         ${SLOT:-None}"
echo "  Sound:        $sound_txt"
echo "  Video Path:   $live_dst"
echo "  Frame Path:   $static_dst"
echo "------------------------------------------"
if [[ -n "$SLOT" ]]; then
    echo "To launch this wallpaper directly with its saved sound settings:"
    echo "  wlive -$SLOT"
fi
echo "=========================================="
echo ""