# DM100 Android smartwatch: research & modding notes

Notes, scripts and findings from taking apart (in software) the **DM100 4G Android smartwatch**, sold under several brands (Silvergear, Domino and others) and built on a MediaTek MT6739 / "Wiite" software stack.

As far as I could find (October 2026), nothing had been published about modding this watch. This repo is the attempt to fix that.

> ⚠️ Everything here is done on my own device. Following along can brick yours or void its warranty. Read [the root research notes](docs/04-root-research.md) before touching anything below the ADB level.

## Device at a glance

| | |
|---|---|
| SoC | MediaTek **MT6739WA**, 4x Cortex-A53 @ 1.27 GHz, 32-bit userspace (`armeabi-v7a`) |
| RAM / storage | 3 GB / 32 GB eMMC (verified real, not spoofed) |
| Display | 480x640 TFT, 197 dpi |
| OS | Android **7.1.1** (SDK 25), `user` build signed with **test-keys** |
| Kernel | Linux **4.4.22** built Oct 2024 (claims security patch 2024-03-05) |
| Firmware | `DM100_KI_V1.1_20241011_DW`, base `alps/full_C10_DW_480X640_TFT` |
| Bootloader | Locked (`verifiedbootstate=green`), `ro.oem_unlock_supported=1` |
| Treble / GSI | **No**: no `vendor` or `vbmeta` partition |
| USB | VID `0e8d` PID `201d` (MTP + ADB). ADB works out of the box |

## Status

| Area | Status |
|---|---|
| [Hardware & firmware identification](docs/01-hardware-and-firmware.md) | ✅ done |
| [Performance: debloat without root](docs/02-performance-debloat.md) | ✅ done, reversible scripts in [`scripts/`](scripts/) |
| [Privacy & security audit](docs/03-privacy-audit.md) | ✅ first pass: vendor phones home with IMEI/serial/SIM number over plain HTTP |
| [Root / bootloader unlock](docs/04-root-research.md) | 🔬 researching (mtkclient, BROM entry on a 2-button watch) |
| Custom ROM / GSI | ❌ not feasible on stock partition layout |

## Quick start (no root needed)

```bash
# macOS
brew install --cask android-platform-tools
adb devices -l            # watch should show up as "DM100"

./scripts/debloat.sh      # disable logger, Adups FOTA, Baidu, vendor store, ...
./scripts/tweaks.sh       # 0.5x animations + AOT compile all apps
./scripts/revert.sh       # undo both
```

## Related devices

Same SoC, Android version and very likely the same ODM base. Findings may transfer, but none are verified:

- Zeblaze Thor 5: [Hovatek thread on rooting/BL unlock](https://www.hovatek.com/forum/post-228838.html)
- LEMFO LEM10 4G
- Rugum DM20

## License

Scripts: MIT. Docs: CC BY 4.0. No vendor binaries are redistributed here.
