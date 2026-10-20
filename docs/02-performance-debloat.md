# 02: Performance: debloat without root

The watch ships noticeably sluggish. The CPU is the hard ceiling (MT6739 is entry-level phone silicon running Chrome-class apps), but the stock firmware makes it worse with always-on loggers and vendor services.

Everything below uses `pm disable-user`, not uninstall. APKs stay on `/system` and can be brought back with `pm enable` or a factory reset.

## What gets disabled ([`scripts/debloat.sh`](../scripts/debloat.sh))

| Package | Why |
|---|---|
| `com.mediatek.mtklogger` | Debug logger running permanently |
| `com.adups.fota`, `com.adups.fota.sysoper` | Adups OTA. Privacy history ([NYT, Nov 2016](https://www.nytimes.com/2016/11/16/us/politics/china-phones-software-security.html)), and `sysoper` runs as `system` |
| `com.baidu.map.location` | Baidu location SDK service |
| `com.google.android.googlequicksearchbox` | Google app. Its `:interactor` process held ~177 MB resident |
| `com.wiite.wiitestore` | Vendor app store, runs in background as `system` |
| `com.livephoto.live_wallpaper.realfire`, `com.maxelus.colorslivewallpaper` | Unused live wallpapers |
| `com.android.browser`, `com.android.music` | AOSP duplicates of installed apps |
| `com.wiite.devicemsg` | Uploads IMEI/serial/SIM number over HTTP (see [03](03-privacy-audit.md)) |
| `cn.heils.faceunlock` | Face unlock SDK phoning `face.heils.cn`. Skip this one if you use face unlock |

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
