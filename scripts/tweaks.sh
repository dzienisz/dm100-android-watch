#!/bin/bash
# Path A: settings tweaks for the DM100. Reversible with revert.sh.

# Halve animation durations (0.5x). 0 feels snappier but makes some UI transitions jarring.
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5

# AOT-compile only the apps you actually use: user-installed apps plus the watch launcher.
# Not `-a`: compiling all ~119 packages with `speed` took 30+ min on the MT6739, mostly
# on system apps nobody opens and on Play Services, which self-updates and loses it anyway.
# Override the list with: APPS="com.whatsapp com.spotify.music" ./tweaks.sh
APPS=${APPS:-"$(adb shell pm list packages -3 | tr -d '\r' | sed 's/^package://') com.mediatek.watchapp"}
for p in $APPS; do
  printf '%-45s ' "$p"
  adb shell cmd package compile -m speed -f "$p" 2>&1 | tr -d '\r'
done
