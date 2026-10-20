# Lab notebook

Raw, dated findings in the order they happened. Polished write-ups live in [`docs/`](docs/).

---

## 2026-10-20

**Plugged it in.** USB shows `DM100`, manufacturer MediaTek, `0e8d:201d`. Interfaces `ff/ff` (MTP) and `ff/42/01` (ADB). No serial ports, no mass storage.

**ADB works out of the box.** `brew install --cask android-platform-tools`, then `adb devices -l` lists `product:DM100`, already authorized. Shell is uid 2000, no root.

**Identity.** `alps` manufacturer, fingerprint `alps/full_C10_DW_480X640_TFT/...:user/test-keys`, display ID `DM100_KI_V1.1_20241011_DW`. Android 7.1.1, security patch string `2024-03-05`. Bootloader locked, `ro.oem_unlock_supported=1`.

**Specs are real.** `MemTotal` ≈ 3 GB, `mmcblk0` ≈ 32 GB. Many cheap watches lie about both, and this one doesn't.

**Load average ~20 on 4 cores** a few minutes after boot. Top CPU users: surfaceflinger, `com.mediatek.watchapp`, `com.wiite.power`. `com.mediatek.mtklogger` is running.

**Not Treble.** No `vendor`, no `vbmeta` in `by-name/`. `/vendor -> /system/vendor`. GSI route is dead. `seccfg`, `boot`, `recovery` present (non-A/B).

**Kernel is from 2016.** `Linux version 4.4.22+ ... Fri Oct 11 13:59:14 CST 2024`. The build date is 2024, the kernel base is 4.4.22 (Sept 2016).

**Searched for prior work.** Nothing for DM100. Closest: Zeblaze Thor 5 (same MT6739 / 7.1.1) on Hovatek. Magisk root reported, BL unlock stuck on the volume-up prompt (watch has no volume keys), mtkclient suggested, no confirmed result.

**Debloat (no root).** Disabled 10 packages with `pm disable-user --user 0`: mtklogger, Adups ×2, Baidu location, Google app (`:interactor` held 177 MB), wiitestore, 2 live wallpapers, AOSP browser, AOSP music. Animations to 0.5x. Started `cmd package compile -m speed -f -a`, which is slow and still running.

**Odd connection.** `/proc/net/tcp` snapshot: everything to Google (`2001:4860::`, `2a00:1450::`) except one `TIME_WAIT` socket to **`47.83.14.42:81`**. whois says Alibaba Cloud. The `uid=0` is meaningless (TIME_WAIT sockets lose their owner).

**Pulled 25 vendor APKs** and grepped dex strings for URLs/IPs:

- `watch.wiiteer.com`, `watch2.wiiteer.com`, `developer.wiiteer.com` all resolve to **47.83.14.42**. That's the mystery IP.
- `com.wiite.devicemsg` → `UploadingService` → `http://watch.wiiteer.com/api/v1/watch/activation`, next to `getDeviceId`, `imei`, `ro.serialno`, `getSimNumber`, `getSimOperator`. **IMEI + serial + SIM phone number, cleartext HTTP.**
- Also: Amap/Alibaba (`*.amap.com`) in the fitness app, Baidu, `face.heils.cn:8081` (→ 47.106.37.233, also Alibaba) in face unlock, `fota5tbk.adups.com` (dead).

**19 vendor apps share uid 1000 (`system`).** Every one of them has CONTACTS / SMS / CALL_LOG / ACCOUNTS / LOCATION / MIC / CAMERA granted. `com.wiite.wirteimei` runs as uid 1001 (phone) with `SEND_SMS`.

**AccountManager references** in `com.wiite.power`, `com.wiite.wiitestore`, `com.sprots.wiiteer.fitness`. No plain-string `getAuthToken` / `peekAuthToken`. Inconclusive, because the code is partly obfuscated. Needs jadx.

**Disabled `com.wiite.devicemsg` and `cn.heils.faceunlock`.** 12 packages disabled total.

**Polled for the vendor server for 5 min** (every 2 s). Zero connections to 47.83.14.42. The upload looks boot/activation-triggered, not continuous.

**Repo created** (private).

**`compile -m speed -f -a` is a mistake on this chip.** 30+ minutes in, still going, load ~20. CPU at full 1.27 GHz, `mtktscpu` 65 °C, so no throttling, just slow. Spent ages on Play Services (`com.google.android.gms`) and system apps like `WearAppDialStore`. Rewrote `tweaks.sh` to compile only `pm list packages -3` plus the launcher.

**What else could this watch become?** Searched GitHub for `mt6739`:
- `Dvalin21/wiite_c10_kernel` has the exact project name (`C10`) but is an **empty repo**, so somebody else tried in 2024.
- `cateajansmedya/android_kernel_mediatek_mt6739`: Wiite C7S/C8 kernel, Android 7.1, same vendor. No Hynitron touch driver.
- `mlm-games/thor_5_mt6739_dump`: Zeblaze Thor 5 full dump. **Identical** modem (`MOLY.LR12A.R2.MP.V5.23.P10`) and BSP (`alps-mp-n1.mp18`). Confirmed sibling.
- MT6739 phones shipped up to Android 13 Go, so newer vendor blobs exist. LineageOS 21 device config with an `mt6739/` dir exists.
- Mainline Linux + NixOS port for an MT6739 device appeared this month (itsvic-dev).

**Touch controller is Hynitron** (`[HYN]` lines in dmesg). Display panel name not in the log any more (boot messages rotated out). Grab it on the next reboot.

Full write-up: [docs/05-modding-options.md](docs/05-modding-options.md).

**Full compile finished: 34 min 32 s.** 69 packages "could not be compiled", nearly all `/system` apps, so they're probably preopted. The `-a` run mostly compiled GMS, Chrome and user apps.

**Rebooted, captured boot dmesg (5,371 lines). Full hardware ID:**
- Display: `lk_st7701S_V2_480X640_dsi_vdo`, a **Sitronix ST7701S**, DSI 1-lane burst video. Mainline has a driver for this controller.
- Touch: Hynitron, driver "Hynitron V0.1".
- Heart rate: **HRS3300**, the PineTime's sensor.
- Accelerometer: QST QMA6100 (BMA4xy probe fails first, chip id mismatch).
- Camera: GC02M2 matched. The kernel also tries GC5035, OV5648 and GC2385, so the same kernel serves several hardware variants.

**Before/after at 4 min uptime:** used RAM 1,422 → **816 MB (−43%)**, load 18.2 → 15.6.

**mtkclient installed** (2.1.4) in `tools/venv`. `pip install mtkclient` fails on Python 3.15; Python 3.13 + git checkout works. Needed a stub for `mfusepy` (macFUSE not installed, only used for mounting). `mtk --help` runs. Not yet connected to the watch.

**First BROM/preloader attempt (`scripts/mtk.sh printgpt`, watch powered off, plugged in with no buttons).** The watch enumerated as **`0e8d:20ff`, product name "Android"**, which is MediaTek's preloader USB mode, so entry into the pre-boot stage works without any button. No serial node (`/dev/cu.usbmodem*`) appeared on macOS. mtkclient logged `Handshake failed, retrying...` 40+ times and never connected. Setup used: watch to USB-C adapter/hub (VIA Labs) to Mac. Untested: direct cable without the hub, other button combos.

### Next
- [x] Display panel model: ST7701S
- [x] Reboot after AOT compile finishes, record before/after RAM + load
- [ ] mitmproxy over Wi-Fi to see the real activation payload
- [ ] jadx on `devicemsg`, `wiitestore`, `wiite.power`: what's AccountManager used for?
- [ ] Find the BROM entry (button combo vs test point)
