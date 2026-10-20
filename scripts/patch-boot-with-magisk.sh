#!/bin/bash
# Patch a boot image with Magisk by running Magisk's own boot_patch.sh on the watch over ADB.
# Why not the Magisk app? On this watch its file picker is unusable (see docs/04-root-research.md).
#
# Usage: scripts/patch-boot-with-magisk.sh <Magisk.apk> <boot.img> <output.img>
# Needs: adb with the watch connected (no root needed), unzip.
# Non-destructive: only reads your boot image and writes <output.img> on your Mac.
set -e
APK="$1"; BOOT="$2"; OUT="$3"
[ -f "$APK" ] && [ -f "$BOOT" ] && [ -n "$OUT" ] || { echo "usage: $0 <Magisk.apk> <boot.img> <output.img>"; exit 1; }

ARCH=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
echo "device ABI: $ARCH"
case "$ARCH" in armeabi-v7a|arm64-v8a|x86|x86_64) ;; *) echo "unsupported ABI"; exit 1;; esac

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
unzip -oq "$APK" "assets/*" "lib/$ARCH/*" -d "$WORK/x"
P="$WORK/p"; mkdir -p "$P"
cp "$WORK/x/assets/boot_patch.sh" "$WORK/x/assets/util_functions.sh" "$WORK/x/assets/stub.apk" "$P/"
# Magisk ships its executables as lib*.so inside the APK; the patcher wants plain names.
cp "$WORK/x/lib/$ARCH/libmagiskboot.so" "$P/magiskboot"
cp "$WORK/x/lib/$ARCH/libmagisk.so"     "$P/magisk"
cp "$WORK/x/lib/$ARCH/libmagiskinit.so" "$P/magiskinit"
cp "$WORK/x/lib/$ARCH/libinit-ld.so"    "$P/init-ld" 2>/dev/null || true
cp "$WORK/x/lib/$ARCH/libbusybox.so"    "$P/busybox"

# /sdcard is mounted noexec, so run from /data/local/tmp
DIR=/data/local/tmp/magisk_patch
adb shell "rm -rf $DIR; mkdir -p $DIR"
for f in "$P"/*; do adb push "$f" "$DIR/" >/dev/null; done
adb push "$BOOT" "$DIR/boot.img" >/dev/null
adb shell "cd $DIR && chmod 755 magiskboot magisk magiskinit busybox boot_patch.sh && chmod 755 init-ld 2>/dev/null; sh boot_patch.sh boot.img"
adb pull "$DIR/new-boot.img" "$OUT" >/dev/null
adb shell "rm -rf $DIR"
echo "patched image: $OUT ($(wc -c < "$OUT") bytes, original $(wc -c < "$BOOT"))"
