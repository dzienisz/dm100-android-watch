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

**First BROM/preloader attempt (`scripts/mtk.sh printgpt`, watch off, plugged in, no buttons).** The watch enumerated as `0e8d:20ff`, product name "Android". mtkclient logged `Handshake failed, retrying...` 40+ times and never connected. **Correction:** I first read `20ff` as preloader mode. A pyusb probe shows it is a **single HID-class interface** (class 03, interrupt endpoints `ep81`/`ep01`), not the CDC/bulk interface a preloader VCOM (`0e8d:2000`) or BROM (`0e8d:0003`) would have. So the watch was *not* in a mode mtkclient can talk to; the hub is not proven to be the cause. No `/dev/cu.usbmodem*` node appeared either. Open: what is `20ff` (some charging/boot-stage gadget?) and which button combination reaches `2000`/`0003`.

**Second attempt reached further: the watch's low-level chip mode responded this time** (unlike the first attempt, which only showed a generic USB mode). The tool got past the first handshake but stopped one step later because it needs a small reference file specific to this exact watch model for memory setup, and none of the ~838 bundled with the tool match this device.

**Checked the sibling watch's (Thor 5) GitHub dump for that file:** its file listing *mentions* one, but the actual file was never uploaded to the repo, only a text listing of what the original dump contained. Dead end there.

**Better plan found: pull that reference file directly from this watch's own chip** next time, instead of borrowing one from another device. Only needs a read, nothing written.

**After the attempt, watch went dark and didn't respond to a normal power press.** After holding power ~15-20s it turned back on and booted completely normally, same firmware, no data loss, just needed ADB re-authorization on the fresh boot. Lesson: a failed low-level attempt can leave the watch looking "off" for longer than usual before it responds to power again — worth knowing before trying again, and good to have the full backup done before going further.

**Checked every MT6739-family file bundled with mtkclient (~860 files, `k39tv1*` matches the MT6739 reference board name): all of them are under 2KB.** They're identification tags used to auto-match a device by its storage chip, not real usable boot-stage files. None could have helped even as a guess. Corrected course before trying any of them on the watch.

**Current wall:** reaching the watch's lowest-level mode works (twice now, no buttons needed), but completing the next step needs a real reference file specific to this watch (or something very close to it) for memory setup, and nothing found so far — not bundled, not in the Thor 5 sibling backup — is that. Pausing hardware attempts here; searching for a real candidate before trying live again.

**Searched for a real reference file instead of guessing.** A 2021 firmware zip for this watch family is dead (404). A promising multi-chipset tool (`watchrom`, by **dvalin21** — same person who opened the empty `wiite_c10_kernel` repo) turned out to wrap the same mtkclient we have, no new file inside. Confirmed via forum threads that "no reference file → fails on memory setup" is a generic, commonly-unsolved MediaTek problem, not something specific to us. No shortcut exists.

**Real lead:** dvalin21 is clearly researching this exact watch family (empty repo named for its internal project name, a 2024 forum question about it) and has since built serious device-flashing tooling. Worth a direct outreach. No file in hand yet, though.

Parking live rooting attempts here. Full writeup: [docs/04-root-research.md](docs/04-root-research.md).

**Breakthrough: pulled the real reference file straight from the watch's own chip memory.** Used mtkclient's `dumppreloader` command, which reads directly via a small built-in exploit payload rather than going through the risky full-flash DA/DRAM path that caused the earlier dark-screen scare — much safer, read-only the whole time.

Hit one macOS-specific snag first: the raw USB write failed with `Access denied (insufficient permissions)`, because macOS treats this watch's low-level interface like a keyboard/mouse (HID class) and reserves it. Fixed by running the single command with admin rights (via the visible Terminal panel, password typed directly by the user — never through chat). Second try succeeded immediately.

**Result:** `backup/brom-dumps/preloader_dm100.bin`, 121,692 bytes, genuine MediaTek header (`MMM` / `FILE_INFO`), consistent with real preloader files. Kept out of git (device-specific, same as other backups). This unblocks the wall from earlier today — we now have a real candidate file instead of nothing.

**Full targeted backup done.** Used the real preloader dump from earlier to read 13 critical partitions (`nvram, nvdata, proinfo, seccfg, boot, recovery, lk, lk2, para, nvcfg, frp, protect1, protect2`) in one connection — mtkclient's `r` command accepts a comma-separated list, so no need to repeat the plug-in dance per partition. Total 125 MB (boot/recovery turned out to be 24 MB each, bigger than expected — more safety margin, not less). All reported dumped successfully, saved under `backup/brom-dumps/` (git-ignored).

This is the safety net the unlock step has needed since the plan was first written. Root is no longer blocked on "no real file" — it's blocked on nothing structural now, just on deciding whether to actually flip the unlock switch.

**BOOTLOADER UNLOCKED.** Ran `mtk da seccfg unlock` with the real preloader from earlier (user ran it directly in their own terminal, typed their own sudo password — never through chat). Log ended with `Successfully wrote seccfg`. Confirmed on reboot:

- `ro.boot.verifiedbootstate`: `green` → **`orange`**
- `ro.boot.flash.locked`: `1` → **`0`**

**Surprise: userdata was NOT wiped.** All 12 previously-disabled apps are still disabled, `/sdcard` still has the original files. Unlike the usual phone fastboot-unlock flow, this seccfg-only unlock just flips the lock bit without forcing a format. Same recovery pattern as every attempt today: watch goes black after the mtkclient session ends, comes back fine after a ~15-20s power hold, re-authorize ADB once.

**This is the headline result of the day.** From here, root (Magisk) is the next real step — patch the `boot.bin` we already backed up, flash it back.

### Next
- [x] Display panel model: ST7701S
- [x] Reboot after AOT compile finishes, record before/after RAM + load
- [ ] mitmproxy over Wi-Fi to see the real activation payload
- [ ] jadx on `devicemsg`, `wiitestore`, `wiite.power`: what's AccountManager used for?
- [ ] Find the BROM entry (button combo vs test point)
