# 05: What can be modified? From apps to a newer Android

Options ranked by effort and risk. Each tier needs the one before it.

| Tier | What | Needs | Effort | Risk |
|---|---|---|---|---|
| 0 | Apps, debloat, own apps, firewall | ADB (have it) | hours | none |
| 1 | Root, real debloat, HTTPS traffic capture, boot logo | bootloader unlock via mtkclient | days | brick (recoverable with backup) |
| 2 | Custom kernel | tier 1 + kernel source with this watch's drivers | weeks | brick / no display |
| 3 | **Newer Android** (Treble port + GSI) | tier 2 + repartition + ported vendor image | months | high, partial hardware likely |
| 4 | Mainline Linux (no Android) | tier 1 | months+ | experimental |

---

## Tier 0: no root (works today)

- **Debloat:** done, see [02](02-performance-debloat.md).
- **Install any Android 7-compatible 32-bit app** with `adb install`. Examples:
  - **Termux** (supports Android 7+), which turns the watch into a small Linux box with LTE: SSH server, Python, scripts.
  - **NetGuard**, a no-root firewall that blocks the vendor apps' internet access.
- **Write our own apps** (`minSdk 25`, `armeabi-v7a`, 480x640):
  - a custom watch face or launcher
  - a heart-rate logger (the sensor is exposed to apps as `android.sensor.heart_rate`)
  - a voice assistant client
- **Sensors available to apps:** accelerometer, light, step detector/counter, **heart rate**, tilt, wake gesture, floor counter (all MTK).

## Tier 1: root via mtkclient

Plan in [04](04-root-research.md). Unlocks:

- Real debloat (remove `/system` apps, not just disable)
- `/etc/hosts` blocking of vendor domains
- Install a CA cert into the system store, then **mitmproxy HTTPS** to see actual vendor payloads
- **Classic Xposed** (supports Android 7.1 / SDK 25) for framework-level mods
- Replace the boot logo (`logo` partition)
- Remove the orange-state warning after unlock ([mtk-lk-warning-patch](https://github.com/justistab3-bot/mtk-lk-warning-patch))
- CPU governor / low-memory-killer tuning

Relevant: a BROM exploit specifically for this SoC, [MTK-bypass/exploit_mt6739](https://github.com/MTK-bypass/exploit_mt6739).

## Tier 2: custom kernel

The vendor hasn't published GPL kernel source for this watch. What exists:

| Source | Match | Notes |
|---|---|---|
| [Dvalin21/wiite_c10_kernel](https://github.com/Dvalin21/wiite_c10_kernel) | **Exact project name (`C10`)** | **Empty repo**: someone tried in 2024 and uploaded nothing |
| [cateajansmedya/android_kernel_mediatek_mt6739](https://github.com/cateajansmedya/android_kernel_mediatek_mt6739) | Same vendor (Wiite C7S/C8), Android 7.1, `hct6739_36_n1_defconfig` | Has Goodix/FocalTech/GSL/ITE touch drivers, but **not Hynitron**, which this watch uses |
| [mlm-games/thor_5_mt6739_dump](https://github.com/mlm-games/thor_5_mt6739_dump) | Sibling watch: **identical** modem `MOLY.LR12A.R2.MP.V5.23.P10` and BSP `alps-mp-n1.mp18` | Full firmware dump (boot, recovery, system) |
| [Power535/android_kernel_common_MT6763](https://github.com/Power535/android_kernel_common_MT6763) | Android 10 common kernel incl. MT6739 | Phones, not watches |

Watch-specific hardware a kernel must drive:

| Part | Identified as | Status |
|---|---|---|
| Touch | **Hynitron** (`[HYN]` in dmesg, via `mtk-tpd`) | Driver not in the C7S/C8 tree. Hynitron publishes drivers separately |
| Display | 480x640 DSI, video mode | **Panel model unknown.** Capture boot dmesg on next reboot |
| PMIC | MT6357 | In MediaTek BSP |
| Wi-Fi/BT/GPS | `CONSYS_MT6739` (on-SoC) | In MediaTek BSP |
| Sensors | MTK sensor hub incl. heart rate | Vendor-specific, unknown |
| Keys | `mtk-kpd` (2 buttons), `ACCDET` | Standard |

## Tier 3: newer Android

**Short answer:** possible in theory, a big project in practice.

**Why it's possible:**
- **MediaTek supported this chip up to Android 13 (Go):**
  - The [Sky Device Elite D65](https://github.com/testmonkei/sky-device-elite-d65-root-guide) runs Android 13 on MT6739.
  - The Samsung Galaxy A01 Core runs Android 10.
  - Alcatel MT6739 phones ran 8.1 to 10.
- **So the pieces exist:** newer vendor blobs, newer kernels, and a [LineageOS 21 device config with an `mt6739/` directory](https://github.com/maximus-sallam/android_device_mediatek).

**Why it's hard on this watch:**
1. **No `vendor` partition.** Treble/GSI needs one, so the eMMC must be repartitioned. There is plenty of space in `userdata` (25 GB).
2. **Kernel ↔ vendor match.** Newer vendor blobs (from a Treble MT6739 phone) expect their own kernel. That kernel lacks this watch's display, touch and sensor drivers. The drivers must be ported into it.
3. **Unknown display panel.** Without the right init sequence the screen stays black.
4. **32-bit only.** Needs arm32 binder GSIs, and support for those thins out after Android 11.
5. **Likely casualties:** modem/VoLTE (carrier configs are ODM-specific), the heart-rate sensor and the camera.

**Realistic outcome:** Android 10 or 11 Go GSI with display, touch and Wi-Fi working after months of work. LTE and sensors are uncertain.

## Tier 4: mainline Linux

[itsvic-dev](https://github.com/itsvic-dev) started a mainline Linux + U-Boot + NixOS port for another MT6739 device (AGM M7) in October 2026. The author labels it AI-generated and experimental. That would turn the watch into a tiny Linux computer without Android or phone functions.

## Recommended order

1. Capture the boot dmesg on the next reboot to identify the **display panel**
2. Tier 1: BROM entry → **full backup** → unlock → root
3. Tier 1: mitmproxy HTTPS capture (completes the privacy story)
4. Decide on tier 2/3 once the kernel situation is clear
