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

### Next
- [ ] Reboot after AOT compile finishes, record before/after RAM + load
- [ ] mitmproxy over Wi-Fi to see the real activation payload
- [ ] jadx on `devicemsg`, `wiitestore`, `wiite.power`: what's AccountManager used for?
- [ ] Find the BROM entry (button combo vs test point)
