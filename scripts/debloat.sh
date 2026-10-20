#!/bin/bash
# Path A: disable bloat on the DM100 over ADB (no root). Reversible with revert.sh.
# Uses `pm disable-user` (not uninstall) so APKs stay on /system and can be re-enabled.

PACKAGES=(
  com.mediatek.mtklogger                 # MediaTek debug logger, always running
  com.adups.fota                         # Adups OTA updater (privacy issues, phones home)
  com.adups.fota.sysoper
  com.baidu.map.location                 # Baidu location SDK service
  com.google.android.googlequicksearchbox # Google app / "Hey Google" (~177 MB resident)
  com.wiite.wiitestore                   # vendor app store, runs in background
  com.livephoto.live_wallpaper.realfire  # unused live wallpapers
  com.maxelus.colorslivewallpaper
  com.android.browser                    # AOSP browser (Chrome is installed)
  com.android.music                      # AOSP music player (Spotify is installed)
)

for p in "${PACKAGES[@]}"; do
  printf '%-45s ' "$p"
  adb shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r'
done
