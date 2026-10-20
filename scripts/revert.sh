#!/bin/bash
# Undo debloat.sh and tweaks.sh.
DIR="$(cd "$(dirname "$0")" && pwd)"

for p in $(sed -n '/^PACKAGES=(/,/^)/p' "$DIR/debloat.sh" | grep -oE '^\s+[a-z][a-zA-Z0-9_.]+'); do
  printf '%-45s ' "$p"
  adb shell pm enable "$p" 2>&1 | tr -d '\r'
done

# Animation scales were unset (null = 1x) before tweaks.sh
adb shell settings delete global window_animation_scale
adb shell settings delete global transition_animation_scale
adb shell settings delete global animator_duration_scale
