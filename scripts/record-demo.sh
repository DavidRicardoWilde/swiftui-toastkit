#!/usr/bin/env bash
# Record a simulator clip and turn it into a README GIF in docs/assets/.
#
#   scripts/record-demo.sh <name> [seconds] [width] [simulator]
#
#   <name>     output is docs/assets/demo-<name>.gif (the .mov is kept next to it, ignored by git)
#   seconds    how long to record; default 8. Press Ctrl-C to stop earlier.
#   width      GIF width in pixels; default 360
#   simulator  device to record; default "booted"
#
# Start the example first (scripts/run-example.sh ios), get it to the opening state, then
# run this and perform the interaction. For the macOS example, record the window with
# Cmd-Shift-5 instead and convert it with:  scripts/record-demo.sh --convert <name> <file.mov> [width]
#
# Needs Xcode, ffmpeg (brew install ffmpeg) and, for smaller, sharper GIFs, gifski
# (brew install gifski). Falls back to an ffmpeg palette when gifski is missing.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
assets="$root/docs/assets"
mkdir -p "$assets"

convert() {  # <mov> <gif> <width>
    local mov="$1" gif="$2" width="$3" fps=15
    command -v ffmpeg >/dev/null || { echo "ffmpeg is missing: brew install ffmpeg" >&2; exit 69; }
    if command -v gifski >/dev/null; then
        local frames; frames="$(mktemp -d)"
        ffmpeg -loglevel error -i "$mov" -vf "fps=$fps,scale=$width:-1:flags=lanczos" "$frames/f%04d.png"
        gifski --quiet --fps "$fps" --width "$width" --quality 85 -o "$gif" "$frames"/f*.png
        rm -rf "$frames"
    else
        ffmpeg -loglevel error -y -i "$mov" -filter_complex \
            "fps=$fps,scale=$width:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
            "$gif"
    fi
    echo "Wrote $gif ($(du -h "$gif" | cut -f1)). Keep README GIFs under ~5 MB."
}

if [[ "${1:-}" == --convert ]]; then
    [[ $# -ge 3 ]] || { echo "usage: $0 --convert <name> <file.mov> [width]" >&2; exit 64; }
    convert "$3" "$assets/demo-$2.gif" "${4:-720}"
    exit 0
fi

name="${1:?usage: $0 <name> [seconds] [width] [simulator]}"
seconds="${2:-8}"
width="${3:-360}"
sim="${4:-booted}"
mov="$assets/demo-$name.mov"

echo "Recording $sim for ${seconds}s into $mov; start the interaction now."
xcrun simctl io "$sim" recordVideo --codec=h264 --force "$mov" &
rec=$!
trap 'kill -INT $rec 2>/dev/null || true' INT
sleep "$seconds" || true
kill -INT "$rec" 2>/dev/null || true
wait "$rec" 2>/dev/null || true

convert "$mov" "$assets/demo-$name.gif" "$width"
