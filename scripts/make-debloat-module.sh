#!/bin/bash
# Needs root (Magisk). Builds a systemless Magisk module that hides vendor/bloat app
# folders from /system. Undo: delete /data/adb/modules/dm100_debloat (or toggle it off
# in the Magisk app) and reboot. /system itself is never modified.
set -e
TMP=$(mktemp -d)
cat > "$TMP/build.sh" <<'EOF'
set -e
MOD=/data/adb/modules/dm100_debloat
mkdir -p $MOD
cat > $MOD/module.prop <<PROP
id=dm100_debloat
name=DM100 debloat
version=1
versionCode=1
author=dm100-android-watch
description=Hides vendor bloat apps (systemless)
PROP
for a in \
  /system/vendor/app/MTKLogger \
  /system/app/AdupsFota \
  /system/app/AdupsFotaReboot \
  /system/vendor/priv-app/Baidu_Location \
  /system/priv-app/Velvet \
  /system/app/WearAppDialStore \
  /system/priv-app/WearUpDeviceInfo \
  /system/priv-app/HeilsFaceUnlock \
  /system/app/SymphonyofColors \
  /system/vendor/app/WearBrowser \
  /system/vendor/app/WearMusic \
  /system/app/RealFireLiveWallpaper
do
  mkdir -p "$MOD$a"
  touch "$MOD$a/.replace"
done
chown -R root:root $MOD
chmod -R 755 $MOD
chcon -R u:object_r:system_file:s0 $MOD/system 2>/dev/null || true
echo "replace markers: $(find $MOD -name .replace | wc -l)"
EOF
adb push "$TMP/build.sh" /data/local/tmp/build_debloat.sh >/dev/null
adb shell 'su -c "sh /data/local/tmp/build_debloat.sh"'
rm -rf "$TMP"
echo "Module created. Reboot the watch to apply: adb reboot"
