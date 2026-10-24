#!/usr/bin/env bash
# Record trailer shots with Godot's movie writer, 1920x1080 at 30 fps.
#   ./capture_all.sh                 every shot in the edit
#   ./capture_all.sh reveal finale   just these
# Takes go to trailer_outpost_one/work/footage/<shot>.avi (MJPEG, q 0.95).
# A temporary override.cfg sets the window (the project overrides it to
# 1280x720, and the movie writer records at the window's size) and the
# quality; it's removed after.
cd "$(dirname "$0")/../.." || exit 1
OUT="$PWD/trailer_outpost_one/work/footage"
mkdir -p "$OUT"
SHOTS=${*:-"canyon_dawn ice_fog touchdown reveal hull_glide airlock_in galley hydro siteplan furnish science power solar_field storm finale"}
printf '[display]\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/vsync/vsync_mode=0\n[editor]\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
for shot in $SHOTS; do
  timeout 900 godot --path . --write-movie "$OUT/$shot.avi" --fixed-fps 30 --resolution 1920x1080 \
    --script res://trailer_outpost_one/capture/director.gd -- shot "$shot" 2>&1 | grep -E "SCRIPT ERROR" -A4
  echo "$shot: $(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$shot.avi" 2>/dev/null) s"
done
rm -f override.cfg
