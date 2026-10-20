#!/bin/bash
# Path A: settings tweaks for the DM100. Reversible with revert.sh.

# Halve animation durations (0.5x). 0 feels snappier but makes some UI transitions jarring.
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
adb shell settings put global animator_duration_scale 0.5

# AOT-compile all apps instead of relying on JIT + idle-time profile compilation.
# Costs storage (plenty free) and takes a while on this CPU; reverts on next OTA/app update.
adb shell cmd package compile -m speed -f -a
