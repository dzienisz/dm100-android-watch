# 06: How to repeat this, start to finish

A single numbered path through everything in this repo, for your own DM100 (or a close MT6739 sibling — see [the device list](../README.md#related-devices)). Each step links to the longer write-up with background and trade-offs.

> Read [docs/04](04-root-research.md) and the disclaimer in the [README](../README.md) first. Steps 5+ can brick the device if done out of order; steps 1–4 cannot.

## 0. Prerequisites

- macOS (these scripts assume it; Linux needs small path tweaks, Windows needs WSL)
- `brew install --cask android-platform-tools libusb`
- A USB cable to the watch (a hub is fine for ADB; if mtkclient's BROM step is flaky, try a direct port)

## 1. Connect and identify

```bash
adb devices -l        # watch should show up, ADB is already on by default
adb shell getprop ro.build.fingerprint
```

→ [docs/01](01-hardware-and-firmware.md) if your output differs from ours — tells you whether you really have this exact platform.

## 2. Debloat without root (reversible, no risk)

```bash
./scripts/debloat.sh      # disables vendor/logger/telemetry apps
./scripts/tweaks.sh        # animations + AOT-compile apps you use
./scripts/revert.sh        # undoes both, any time
```

→ [docs/02](02-performance-debloat.md) for what each app is and why.

## 3. Privacy check (read-only)

No script here — it's `adb shell` + `pm list packages -f` + `adb pull` + grepping the APKs for URLs, as in [docs/03](03-privacy-audit.md#method). Do this before step 5 if you want to see the vendor's cleartext upload live (we didn't capture it — see the note in docs/03).

## 4. Install mtkclient (needed from here on)

```bash
mkdir -p tools && cd tools
git clone --depth 1 https://github.com/bkerler/mtkclient.git
/opt/homebrew/bin/python3.13 -m venv venv   # a recent Python may have no wheels yet for mtkclient's deps
./venv/bin/pip install -r mtkclient/requirements.txt
```
If you hit `Unable to find libfuse`, see the macOS workaround in [docs/04](04-root-research.md#setting-up-mtkclient-on-macos-done-2026-10-20) (a 4-line stub, no macFUSE needed). Run it through `scripts/mtk.sh`.

## 5. Pull your own reference file (read-only, safe)

```bash
scripts/do-dump-preloader.sh
```
(runs `mtk dumppreloader`; see the script for the exact command). Power the watch fully off, then plug it in with **no buttons held** — that alone reaches BROM on this watch. `sudo` is needed on macOS because the watch's low-level USB interface looks like a keyboard to the OS. If the watch goes dark afterward, hold power ~15–20s; that's normal, not a brick.

→ [docs/04](04-root-research.md#update-got-a-real-reference-file-2026-10-20) for why this step exists (the generic files mtkclient ships for this chip are unusable 1–2 KB stubs).

## 6. Back up critical partitions (read-only, do this before step 7)

```bash
sudo tools/venv/bin/python tools/mtkclient/mtk.py r \
  nvram,nvdata,proinfo,seccfg,boot,recovery,lk,lk2,para,nvcfg,frp,protect1,protect2 \
  backup/brom-dumps/nvram.bin,backup/brom-dumps/nvdata.bin,backup/brom-dumps/proinfo.bin,backup/brom-dumps/seccfg.bin,backup/brom-dumps/boot.bin,backup/brom-dumps/recovery.bin,backup/brom-dumps/lk.bin,backup/brom-dumps/lk2.bin,backup/brom-dumps/para.bin,backup/brom-dumps/nvcfg.bin,backup/brom-dumps/frp.bin,backup/brom-dumps/protect1.bin,backup/brom-dumps/protect2.bin \
  --preloader backup/brom-dumps/preloader_dm100.bin
```
~125 MB, one connection. This is what makes step 7 safe to attempt.

## 7. Unlock the bootloader (wipes nothing on this watch, but is not casually reversible)

```bash
sudo tools/venv/bin/python tools/mtkclient/mtk.py da seccfg unlock --preloader backup/brom-dumps/preloader_dm100.bin
```
Confirm: `adb shell getprop ro.boot.verifiedbootstate` should read `orange` (was `green`). On our unit this did **not** wipe `/data` — don't assume that holds for your variant.

## 8. Root with Magisk

```bash
# 1. get a Magisk APK (v30.7+ still supports Android 6.0+)
adb install Magisk-v30.7.apk

# 2. patch your backed-up boot.bin — bypasses the in-app file picker,
#    which is unusable on this watch's screen (see docs/04)
scripts/patch-boot-with-magisk.sh Magisk-v30.7.apk backup/brom-dumps/boot.bin backup/magisk/boot_magisk_patched.img

# 3. flash it
sudo tools/venv/bin/python tools/mtkclient/mtk.py w boot backup/magisk/boot_magisk_patched.img --preloader backup/brom-dumps/preloader_dm100.bin
```
Reboot. Magisk will likely ask for one more "additional setup" reboot the first time you open it — let it.

**If `adb shell su -c id` says `Permission denied`** even though Settings say "Apps and ADB": open the Magisk app → **Superuser** tab → there's a `[SharedUID] Shell` entry with its toggle **off** by default. Switch it on. (Confirmed cause via `logcat`: `su: request rejected (2000)`, uid 2000 = adb shell — it's a stored deny, not a crash.)

→ full story, including the dead ends, in [docs/04](04-root-research.md).

## 9. With root: real debloat + domain blocking

```bash
scripts/make-debloat-module.sh        # systemless, hides vendor app folders from /system
scripts/block-vendor-domains.sh       # systemless /system/etc/hosts, blocks vendor telemetry domains
```
Both live in one Magisk module (`/data/adb/modules/dm100_debloat`); `scripts/revert.sh` removes it. `/system` itself is never written.

→ [docs/02](02-performance-debloat.md#with-root-really-removing-them-systemless-2026-10-20) and [docs/03](03-privacy-audit.md#mitigation-applied-with-root-2026-10-20).

## Recovery, if something goes wrong

- **Screen goes black after any mtkclient session ends:** hold power 15–20s. Happened after every BROM session in our testing; the watch always came back.
- **ADB says `unauthorized` after a reboot:** check the watch screen for the "Allow USB debugging" prompt.
- **Something is actually broken:** you have `backup/brom-dumps/*.bin` for every partition in step 6 — write the originals back the same way step 8 wrote the patched one (`mtk w <partition> <original>.bin --preloader ...`).
- **Not solved here:** a true brick (doesn't even reach BROM). We never hit this; if you do, BROM itself lives in the chip's ROM and should still be reachable — start from [docs/04](04-root-research.md)'s open questions.
