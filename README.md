# What's really inside a no-name Android watch

**My cheap 4G Android smartwatch was painfully slow. While trying to fix it, I found it sending my IMEI, serial number and SIM phone number to a server in China, over plain HTTP.**

This repo documents taking apart (in software) the **DM100**, a white-label MT6739 Android watch sold under several brands. As far as I could find (October 2026), nobody had published anything about modding it.

> **Just want the fix?** → [Make it faster](docs/02-performance-debloat.md) · [Stop the data upload](docs/03-privacy-audit.md#recommendations) · [Scripts](scripts/)
>
> **Lab notebook** with dated raw findings → [JOURNAL.md](JOURNAL.md)

---

## 1. The watch

I have a "Silvergear" DM100: a 4G watch running full Android with Play Store, WhatsApp, Chrome and Spotify on the wrist. In practice everything took seconds to open.

Plugging it into my Mac showed something unexpected. It enumerates as a **MediaTek** device with **ADB already enabled**, so no developer options and no unlocking were needed to get a shell.

## 2. Who actually made it?

The name on the box isn't the maker. The firmware tells a different story:

```
ro.product.manufacturer = alps                       ← MediaTek reference design
ro.build.fingerprint    = alps/full_C10_DW_480X640_TFT/...:user/test-keys
ro.mediatek.version     = ...aeon6739...             ← board design house
system apps             = com.wiite.*                ← Shenzhen software stack
```

So the DM100 is a Shenzhen ODM design (project `C10_DW`) on a MediaTek reference board, running a "Wiite" software stack, resold under whatever brand buys a batch. The same watch appears as Silvergear, Domino and others. Sibling designs on the same chip include the Zeblaze Thor 5, LEMFO LEM10 and Rugum DM20.

Under the hood: an **MT6739** (entry-level phone chip, 4x A53 @ 1.27 GHz, 32-bit userspace), 3 GB RAM, 32 GB storage (both real, which isn't a given on these), **Android 7.1.1**, and a **Linux 4.4.22 kernel from 2016**. The settings screen claims a March 2024 security patch.

→ Full details: [docs/01-hardware-and-firmware.md](docs/01-hardware-and-firmware.md)

## 3. Making it usable

Part of the slowness is just the chip. The rest is self-inflicted: a MediaTek debug logger running permanently, an Adups updater, a Baidu location service, a vendor app store and the Google app holding ~177 MB of RAM.

Without root, I disabled 12 packages, halved animation times and AOT-compiled the apps I use. RAM used after boot dropped from **1.42 GB to 0.82 GB (−43%)**. Everything is reversible with one script.

→ [docs/02-performance-debloat.md](docs/02-performance-debloat.md) · [`scripts/`](scripts/)

## 4. What does it say about me?

I'd signed my Google account into the watch, so I wanted to know where its traffic goes. Most of it goes to Google. One connection didn't: a root-level socket to **`47.83.14.42:81`**, an Alibaba Cloud address.

That address is `watch.wiiteer.com`, the ODM's server. Inside the system app `com.wiite.devicemsg` there's an `UploadingService` pointing at:

```
http://watch.wiiteer.com/api/v1/watch/activation
getDeviceId · imei · ro.serialno · getSimNumber · getSimOperator
```

That is my **IMEI, serial number, SIM phone number and carrier**, sent unencrypted at boot.

It gets worse structurally:

- **19 vendor apps run as uid 1000** (`system`), the same identity as Android itself. They can technically read accounts, SMS and contacts without asking.
- The firmware is signed with Android's **public test-keys**.
- Other apps phone home to Amap/Alibaba, Baidu and a face-unlock SDK at `heils.cn`.

I found **no evidence** of vendor code stealing Google credentials, but nothing on this firmware would stop it. My advice: **use a secondary Google account on this watch.**

→ Method, evidence and recommendations: [docs/03-privacy-audit.md](docs/03-privacy-audit.md)

## 5. Breaking in *(in progress)*

Next goal: root. The obstacles:

- The bootloader unlock asks for a **volume-up** press, and the watch has two buttons, neither of them volume.
- There's no `vendor` partition, so generic Android images (GSIs) are out.
- The plan is **[mtkclient](https://github.com/bkerler/mtkclient)** via MediaTek's BootROM mode: full backup first, then unlock `seccfg`, then Magisk.

→ [docs/04-root-research.md](docs/04-root-research.md)

### Can it run a newer Android?

In theory, yes. MediaTek supported the MT6739 up to Android 13 Go on phones. On this watch it needs a custom kernel with the watch's own display and touch drivers, a repartitioned eMMC, and a ported vendor image. That's months of work. The full ladder from "install apps" to "mainline Linux" is in [docs/05-modding-options.md](docs/05-modding-options.md).

## 6. Do you own one?

If you have a DM100, Thor 5, LEM10, DM20 or another `alps` MT6739 watch, please open an issue with:

```bash
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.display.id
```

That's enough to map which watches share this firmware, and which ones these findings apply to.

---

## Device reference

| | |
|---|---|
| SoC | MediaTek MT6739WA, 4x Cortex-A53 @ 1.27 GHz, `armeabi-v7a` |
| RAM / storage | 3 GB / 32 GB eMMC |
| Display | 480x640 TFT, 197 dpi |
| OS | Android 7.1.1 (SDK 25), `user` build, **test-keys** |
| Kernel | Linux 4.4.22, built Oct 2024 |
| Firmware | `DM100_KI_V1.1_20241011_DW` |
| Bootloader | Locked, `ro.oem_unlock_supported=1` |
| Treble / GSI | No |
| USB | `0e8d:201d` (MTP + ADB) |

## Status

| Area | Status |
|---|---|
| Hardware & firmware ID | ✅ |
| Debloat without root | ✅ RAM used at boot −43% (1.42 → 0.82 GB) |
| Privacy audit | ✅ first pass · traffic capture & decompile next |
| Root / bootloader unlock | 🔬 researching |
| Newer Android (Treble port + GSI) | 🗺️ mapped out, needs root + kernel first: [05](docs/05-modding-options.md) |

## Disclaimer & license

Everything here was done on my own device. Following along can brick yours or void its warranty. No vendor binaries are redistributed.

Scripts: MIT. Docs: CC BY 4.0.
