# 02: Performance: debloat without root

The watch ships noticeably sluggish. The CPU is the hard ceiling (MT6739 is entry-level phone silicon running Chrome-class apps), but the stock firmware makes it worse with always-on loggers and vendor services.

Everything below uses `pm disable-user`, not uninstall. APKs stay on `/system` and can be brought back with `pm enable` or a factory reset.

## What gets disabled ([`scripts/debloat.sh`](../scripts/debloat.sh))

Nothing is uninstalled. These 12 packages are **disabled** for user 0 and can be restored one at a time with `adb shell pm enable <package>`, or all together with [`scripts/revert.sh`](../scripts/revert.sh).

| # | Package | What it is | Why disabled | What you lose |
|---|---|---|---|---|
| 1 | `com.mediatek.mtklogger` | MediaTek debug logger | Runs permanently, constant CPU and storage writes | Nothing (developer tool) |
| 2 | `com.adups.fota` | Adups OTA updater | Privacy history ([NYT, Nov 2016](https://www.nytimes.com/2016/11/16/us/politics/china-phones-software-security.html)) | Vendor OTA updates |
| 3 | `com.adups.fota.sysoper` | Adups helper | Runs as uid 1000 (`system`) | Same as above |
| 4 | `com.baidu.map.location` | Baidu location SDK | Sends location data to Baidu | Nothing visible. GPS and Google location still work |
| 5 | `com.google.android.googlequicksearchbox` | Google app | Its `:interactor` process held ~177 MB resident | "Hey Google", voice search, Google feed |
| 6 | `com.wiite.wiitestore` | Vendor app store | Runs in background as `system`, talks to `wiiteer.com` | Vendor app store (Play Store still works) |
| 7 | `com.wiite.devicemsg` | Vendor activation uploader | Uploads IMEI/serial/SIM number over plain HTTP (see [03](03-privacy-audit.md)) | Nothing visible |
| 8 | `cn.heils.faceunlock` | Face unlock SDK | Talks to `face.heils.cn` | Face unlock |
| 9 | `com.livephoto.live_wallpaper.realfire` | Fire live wallpaper | Unused | That wallpaper |
| 10 | `com.maxelus.colorslivewallpaper` | Colors live wallpaper | Unused | That wallpaper |
| 11 | `com.android.browser` | AOSP browser | Duplicate of Chrome | Nothing if you use Chrome |
| 12 | `com.android.music` | AOSP music player | Duplicate of Spotify | Local MP3 playback app |

**Trade-off:** disabling Adups means no vendor OTA updates. The last one is from Oct 2024 and an OTA would also undo these changes.

## Tweaks ([`scripts/tweaks.sh`](../scripts/tweaks.sh))

- **Animation scales → 0.5x.** `0` feels faster still, but makes some transitions jarring.
- **`cmd package compile -m speed -f -a`** AOT-compiles every app. Android 7 otherwise relies on JIT plus idle-time profile compilation, which on this CPU means a lot of runtime compiling. Costs storage (there is plenty) and takes a long time to run.

## Not done (deliberately)

- **Background process limit**: not persistent across reboot without root.
- **Disabling `qs.wiite.cleantask`, `com.wiite.power`, `com.wiite.systemmode`**: these look like part of the vendor's power/memory management. Disabling them untested could hurt battery life or stability.
- **Uninstalling user apps** (Nova Launcher, Chrome, …): personal choice. Chrome is the heaviest app on the device. Lighter browsers (Via, Lightning) are much faster here.

## Before / after

| | Before (fresh boot) | After |
|---|---|---|
| Used RAM | ~1.42 GB | _TBD after reboot_ |
| Load avg 4 min after boot | ~18 | _TBD_ |
