#!/bin/bash
# Needs root (Magisk). Blocks the vendor/telemetry hostnames found in the firmware
# (see docs/03-privacy-audit.md) by mapping them to 0.0.0.0 in /system/etc/hosts.
# Systemless: the file lives in the Magisk module dm100_debloat, /system is untouched.
# Applied immediately via a bind mount, and persistently via the module (after reboot).
# Undo: scripts/revert.sh (removes the module) + reboot, or `adb shell su -c "umount /system/etc/hosts"`.
set -e
TMP=$(mktemp -d)
cat > "$TMP/hosts" <<'EOF'
127.0.0.1       localhost
::1             ip6-localhost

# --- DM100 vendor domains (docs/03-privacy-audit.md) ---
# wiiteer.com: activation/telemetry server of the watch's software stack (Alibaba Cloud)
0.0.0.0 wiiteer.com
0.0.0.0 www.wiiteer.com
0.0.0.0 watch.wiiteer.com
0.0.0.0 watch2.wiiteer.com
0.0.0.0 developer.wiiteer.com
# heils.cn: face-unlock SDK
0.0.0.0 face.heils.cn
0.0.0.0 faceunlock.sdk.heils.cn
# adups: OTA updater with a history of data collection
0.0.0.0 fota5tbk.adups.com
# weitetech.cn: referenced by the launcher
0.0.0.0 www.weitetech.cn
# Baidu location SDK
0.0.0.0 api.map.baidu.com
0.0.0.0 loc.map.baidu.com
EOF
cat > "$TMP/apply.sh" <<'EOF'
set -e
MOD=/data/adb/modules/dm100_debloat
mkdir -p $MOD/system/etc
cp /data/local/tmp/dm100_hosts $MOD/system/etc/hosts
chown root:root $MOD/system/etc/hosts
chmod 644 $MOD/system/etc/hosts
chcon u:object_r:system_file:s0 $MOD/system/etc/hosts 2>/dev/null || true
# apply right now, no reboot (bind mount; also what the module does at boot)
umount /system/etc/hosts 2>/dev/null || true
mount -o bind $MOD/system/etc/hosts /system/etc/hosts
echo "active entries: $(grep -c '^0.0.0.0' /system/etc/hosts)"
EOF
adb push "$TMP/hosts" /data/local/tmp/dm100_hosts >/dev/null
adb push "$TMP/apply.sh" /data/local/tmp/apply_hosts.sh >/dev/null
adb shell 'su -c "sh /data/local/tmp/apply_hosts.sh"'
rm -rf "$TMP"
