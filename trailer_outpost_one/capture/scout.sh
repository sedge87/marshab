#!/usr/bin/env bash
# Scout stills for shots: ./scout.sh shot1 shot2 ...  (t = 0.0 and 1.0, or SCOUT_T="0 .5 1")
cd "$(dirname "$0")/../.." || exit 1
OUT="$PWD/trailer_outpost_one/work/stills"
mkdir -p "$OUT"
for shot in "$@"; do
  for t in ${SCOUT_T:-0 1}; do
    timeout 240 godot --path . --resolution 1280x720 --script res://trailer_outpost_one/capture/director.gd -- still "$shot" "$t" "$OUT/${shot}_${t}.png" 2>&1 | grep -E "SCRIPT ERROR" -A3
    echo "$shot $t done"
  done
done
