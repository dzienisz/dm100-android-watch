# 04: Root & bootloader unlock research

**Status:** research only. Nothing below has been tried on the DM100 yet.

## Constraints

- Bootloader locked. `ro.oem_unlock_supported=1`, but the fastboot `oem unlock` flow asks for a **volume-up** confirmation, and the watch has only two buttons (power + back).
- Pre-Treble partition layout (no `vendor`, no `vbmeta`), so GSIs are out.
- 32-bit userspace, Android 7.1.1 (SDK 25). Current Magisk still supports API 23+.

## Prior art (closest matches)

| Device | SoC / OS | Result | Source |
|---|---|---|---|
| Zeblaze Thor 5 (watch) | MT6739 / 7.1.1 | Root via Magisk reported; fastboot BL unlock blocked by missing volume key; mtkclient suggested, unconfirmed | [Hovatek](https://www.hovatek.com/forum/post-228838.html) |
| Vortex HD65 Ultra (phone) | MT6739 | Full guide: BROM, backup, unlock, root, GSI | [XDA](https://xdaforums.com/t/how-to-guide-vortex-hd65-ultra-mt6739-unlock-bootloader-backup-firmware-root-fix-brick-bootloop-gsi-install-etc.4672830/) |
| Generic MT6739 | — | `XFlashExt - Detected V4 Lockstate` timeout during unlock | [mtkclient#20](https://github.com/bkerler/mtkclient/issues/20) |
| Alcatel 1 5033T / Nokia 1 TA-1130 | MT6739 / MT6739WW | success / fail with one-click tool | [compat table](https://github.com/Siddharthsinghkumar/mtk-firmware-unlock-root/blob/main/README.md) |

## Planned approach: mtkclient (BROM mode)

[mtkclient](https://github.com/bkerler/mtkclient) talks to the MediaTek BootROM directly. That bypasses the bootloader's button prompt and works without vendor firmware files.

1. **Get into BROM.** Power off fully, hold a button while plugging USB. Unknown which button on this watch. If none works, the fallback is a test point on the PCB (requires opening the case).
2. **Full backup, before anything else:**
   ```bash
   mtk rl backup/          # all partitions
   ```
   At minimum: `nvram`, `nvdata`, `proinfo`, `seccfg`, `boot`, `recovery`, `lk`, `preloader`.
3. **Unlock** (wipes userdata):
   ```bash
   mtk e metadata,userdata
   mtk da seccfg unlock
   ```
4. **Root:** patch the dumped `boot.img` with Magisk on the device, then `mtk w boot boot_patched.img`.

## Setting up mtkclient on macOS (done, 2026-10-20)

Tested on macOS with Homebrew; mtkclient 2.1.4 (git `7cb40e7`).

```bash
brew install libusb
mkdir -p tools && cd tools
git clone --depth 1 https://github.com/bkerler/mtkclient.git
/opt/homebrew/bin/python3.13 -m venv venv           # not 3.15: compiled deps have no builds yet
./venv/bin/pip install -r mtkclient/requirements.txt
```

Two gotchas:

1. **Python version.** `pip install mtkclient` finds nothing on a bleeding-edge Python (3.15). Use 3.13 and install from the git checkout.
2. **`OSError: Unable to find libfuse`.** mtkclient imports `mfusepy` for its optional "mount flash as a drive" feature, which needs macFUSE (a kernel extension). We don't need it, so inside the venv replace `site-packages/mfusepy.py` with an empty stub (classes `Operations`, `LoggingMixIn`, `FUSE` that do nothing). Everything else works.

Run it through [`scripts/mtk.sh`](../scripts/mtk.sh), e.g. `scripts/mtk.sh --help`. `tools/` is git-ignored.

## Status: blocked on a missing reference file (2026-10-20)

Two live attempts via mtkclient, documented in [JOURNAL.md](../JOURNAL.md):

1. **Watch reaches the chip's lowest-level mode with no button combination** — just plug in a fully powered-off watch. That answers one of the open questions below.
2. **The attempt fails one step later.** mtkclient needs a small file specific to this watch's memory configuration to proceed safely. Every same-chip-family file bundled with the tool (~860 of them) turned out to be a tiny identification tag (under 2KB), not a real usable file — so there was nothing valid to try, bundled or borrowed from the sibling watch's backup (which turned out not to actually include its own copy either, despite its file listing naming one).
3. One attempt without a real file left the watch briefly unresponsive (~20s dark screen); it recovered fully on its own with a long power hold, no data loss.

**Next:** search for a real reference file for this exact watch or a closer sibling before any further live attempt. Candidates worth checking: other GitHub dumps, 4PDA/forum archives, firmware download sites, or someone else's full flash backup of a `C10_DW` / Wiite-based watch.

## Search for a real reference file (2026-10-20)

Looked for an actual full-size, device-matching file to get past the wall above, before trying anything else live on the watch.

**Dead ends:**
- A firmware zip for this exact watch family, linked on a watch-enthusiast forum in 2021 and reported working by a second person in 2022, is **gone** — the Google Drive link now 404s.
- A link to a firmware file on a related brand's own site needs checking further; not confirmed working.
- `watchrom` ([Dvalin21/watchrom](https://github.com/Dvalin21/watchrom)), a serious multi-chipset ROM toolkit supporting MT6739, turned out to wrap the same mtkclient we're already using underneath. It doesn't bundle or fetch a real reference file for this chip either — same wall.
- This exact failure pattern ("no reference file given → fails one step later with a memory-setup error") is a **known, commonly unresolved problem** for unprotected MediaTek devices generally, per several unrelated forum threads. No universal fix exists; the only resolution anyone reports is getting the real matching file.

**Real lead, not yet a solution:** the GitHub user **dvalin21** opened an empty repo named exactly for this watch's internal project name (`wiite_c10_kernel`, found earlier) in 2024, and separately asked in a watch-enthusiast forum thread about this same device family as recently as June 2024. They've since built substantial, actively-maintained ROM/device tooling. Worth reaching out to directly — they may have gotten further, or be interested in comparing notes.

**Conclusion for now:** no real candidate file exists anywhere found so far. Rooting this watch is parked as an open problem rather than something to keep attempting blind. The debloat + privacy work already done stands on its own regardless of root.

## Update: got a real reference file (2026-10-20)

`mtkclient dumppreloader` reads the watch's own in-memory copy directly, via a small exploit payload, without needing the risky full-flash DA path at all — the right tool for exactly the "unprotected device, no known reference file" wall documented above.

One macOS-specific snag: the raw USB write initially failed with a permissions error, because macOS's HID driver claims this watch's low-level USB interface by default. Running the one command with `sudo` fixed it.

Result: a genuine 121,692-byte file with a real MediaTek header, saved to `backup/brom-dumps/` (git-ignored; device-specific).

**Next:** use this file for the full partition backup before attempting any unlock.

## Backup complete (2026-10-20)

Using the real preloader dump above, read 13 critical partitions in one `mtkclient r` call (comma-separated partition + filename lists — no need to reconnect per partition):

`nvram, nvdata, proinfo, seccfg, boot, recovery, lk, lk2, para, nvcfg, frp, protect1, protect2` — 125 MB total, all confirmed dumped. Stored under `backup/brom-dumps/` (not committed; device-specific, includes calibration data).

Skipped deliberately: `system`, `userdata`, `cache` (large, holds only user data/apps that the unlock wipes anyway and the owner doesn't need preserved), `md1img`/`md1dsp` (modem firmware — could add later if LTE needs recovering after a flash attempt).

**This was the last missing piece for a safe unlock attempt.** Next decision: whether to actually run the unlock (`seccfg unlock`), which wipes userdata and is the point of no return for "keep using this as a normal watch without reflashing."

## Bootloader unlocked (2026-10-20)

`mtk da seccfg unlock --preloader backup/brom-dumps/preloader_dm100.bin` succeeded: `Successfully wrote seccfg`.

Confirmed after reboot: `ro.boot.verifiedbootstate` orange (was green), `ro.boot.flash.locked` 0 (was 1).

**Userdata survived** — this unlock path (seccfg flag only, not a fastboot `oem unlock`) didn't force a wipe. Apps, settings and files are unchanged.

**Next: root.** Patch the backed-up `boot.bin` with Magisk, flash it back with `mtk w boot <patched>.bin`.

## Magisk patched, worked around a watch-screen UI bug (2026-10-20)

Magisk v30.7's own in-app file picker is unusable on this watch's screen: it opens to an empty root with no reachable way to switch folders (the menu/drawer exists but isn't reachable by touch — a known class of bug on small/non-standard screens, same symptom reported for Android TV boxes with DocumentsUI).

**Fix: skip the GUI, run Magisk's own patcher directly.** Its APK ships `assets/boot_patch.sh` plus matching `armeabi-v7a` native binaries (`magiskboot`, `magisk`, `magiskinit`, `init-ld`, `busybox`). Extracted these from the APK, pushed them to `/data/local/tmp/` on the watch (not `/sdcard/`, which blocks execution), made them executable, and ran:

```bash
cd /data/local/tmp/magisk_patch && sh boot_patch.sh boot.img
```

This is the same thing the in-app button does, just invoked directly.

**Result:** real device fstab (`fstab.mt6739`) patched, dm-verity removed, Magisk injected into the ramdisk, repacked to `new-boot.img` successfully. Pulled back as `backup/magisk/boot_magisk_patched.img`.

**Next:** flash it to the `boot` partition with mtkclient, reboot, verify root.

## Root achieved (2026-10-20)

`mtk w boot backup/magisk/boot_magisk_patched.img --preloader backup/brom-dumps/preloader_dm100.bin` wrote the patched image. After one Magisk-requested setup reboot, `su` works.

**Gotcha for ADB root:** `su` from `adb shell` was rejected (`su: request rejected (2000)` in logcat) with no popup, even with "Apps and ADB" set. Fix: Magisk app, Superuser tab, switch ON the `[SharedUID] Shell` entry. Result: `uid=0(root) ... context=u:r:magisk:s0`.

**To undo root:** flash the original `boot` back: `mtk w boot backup/brom-dumps/boot.bin --preloader backup/brom-dumps/preloader_dm100.bin`.

## Open questions

- [ ] Which button (if any) enters BROM/preloader on the DM100?
- [ ] Does the watch have a removable battery or exposed test point?
- [ ] Does `seccfg unlock` hit the V4 lockstate timeout from mtkclient#20?
- [ ] Does `lk` show an orange-state warning / boot delay after unlock?
