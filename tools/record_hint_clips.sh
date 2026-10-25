#!/usr/bin/env bash
# Records the tutorial's "Show me" clips from the real game
# (tools/capture_hint_clips.gd) and converts them for Godot to play:
#   assets/tutorial/clips/<clip>.ogv   960×540, 30 fps, Theora, no sound
# Usage: bash tools/record_hint_clips.sh [clip ...]   (default: all of them)
# Windowed (the movie writer needs a real window), about 20 s per clip.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
CLIPS=("$@")
[ ${#CLIPS[@]} -eq 0 ] && CLIPS=(move outside plan living airlock solar drill life_support go_in bunk air crew carry rover shielding)
OUT=assets/tutorial/clips
WORK="$(mktemp -d)"
mkdir -p "$OUT"
# 1920×1080 for the recording (the UI is laid out for it), removed afterwards.
printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n' > override.cfg
trap 'rm -f override.cfg; rm -rf "$WORK"' EXIT
for clip in "${CLIPS[@]}"; do
	echo "== $clip"
	"$GODOT" --path . --write-movie "$WORK/$clip.avi" --fixed-fps 30 --script res://tools/capture_hint_clips.gd -- "$clip" > "$WORK/$clip.log" 2>&1 || { tail -5 "$WORK/$clip.log"; continue; }
	# Skip the warm-up (45 frames), scale down, Theora at good quality.
	ffmpeg -loglevel error -y -ss 1.5 -i "$WORK/$clip.avi" -an -vf "scale=960:540:flags=lanczos" -c:v libtheora -q:v 6 "$OUT/$clip.ogv"
	ls -la "$OUT/$clip.ogv" | awk '{print $5" bytes"}'
done
