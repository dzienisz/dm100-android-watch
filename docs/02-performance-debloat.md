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

## With root: really removing them (systemless, 2026-10-20)

After [root](04-root-research.md), the 12 disabled apps are removed from view with a Magisk module instead of just disabled: [`scripts/make-debloat-module.sh`](../scripts/make-debloat-module.sh) creates `/data/adb/modules/dm100_debloat` with a `.replace` marker for each app folder, so Magisk mounts an empty folder over it at boot. `/system` itself is never written, so this is undone by deleting the module (`scripts/revert.sh` does that) and rebooting.

| App | Folder hidden |
|---|---|
| MTK logger | `/system/vendor/app/MTKLogger` |
| Adups FOTA + helper | `/system/app/AdupsFota`, `/system/app/AdupsFotaReboot` |
| Baidu location | `/system/vendor/priv-app/Baidu_Location` |
| Google app | `/system/priv-app/Velvet` |
| Vendor store | `/system/app/WearAppDialStore` |
| Activation uploader | `/system/priv-app/WearUpDeviceInfo` |
| Face unlock | `/system/priv-app/HeilsFaceUnlock` |
| Colors wallpaper | `/system/app/SymphonyofColors` |
| Fire wallpaper | `/system/app/RealFireLiveWallpaper` |
| Browser, Music | `/system/vendor/app/WearBrowser`, `/system/vendor/app/WearMusic` |

**Gotchas found:**
- Two apps (Google app, fire wallpaper) had a user-installed *update* in `/data/app` on top of the system copy. Hiding the system copy leaves the update behind, and `pm uninstall` of an update reveals the system copy again. Hide the system folder first, then uninstall the update.
- `pm uninstall` of the Google app update made `system_server` restart once (a soft reboot, about a minute). Nothing was lost.
- Play Services, Play Store, launcher, phone, SystemUI, Chrome, WhatsApp and Spotify all survived; root still works.
- RAM used 4 min after boot with the module applied: about 849 MB (vs 816 MB with apps only disabled and no Magisk; Magisk itself adds a little).

## Tweaks ([`scripts/tweaks.sh`](../scripts/tweaks.sh))

- **Animation scales → 0.5x.** `0` feels faster still, but makes some transitions jarring.
- **AOT-compile the apps you use** (`cmd package compile -m speed -f <pkg>`): user-installed apps plus the `com.mediatek.watchapp` launcher.

### Why compiling helps

Apps ship as DEX bytecode, not ARM machine code. Android 7 runs them through an interpreter and JIT, and only compiles "hot" code to native (`speed-profile`) later, when the device is idle and charging. On a 1.27 GHz MT6739 the JIT work while you use an app shows up as stutter. Compiling ahead of time with `speed` moves all that work to one upfront run.

Trade-offs: storage (plenty free here), the upfront time, and an app update discards its compiled code.

> ⚠️ **Don't use `compile -m speed -f -a`.** My first run compiled all 119 packages and took 30+ minutes with load ~20. Most of that time went to system apps nobody opens and to Play Services, which updates itself through the Play Store and throws the result away. The script now compiles only the apps you actually use.

## Not done (deliberately)

- **Background process limit**: not persistent across reboot without root.
- **Disabling `qs.wiite.cleantask`, `com.wiite.power`, `com.wiite.systemmode`**: these look like part of the vendor's power/memory management. Disabling them untested could hurt battery life or stability.
- **Uninstalling user apps** (Nova Launcher, Chrome, …): personal choice. Chrome is the heaviest app on the device. Lighter browsers (Via, Lightning) are much faster here.

## Before / after

Both measured ~4 minutes after a cold boot, single sample each, nothing opened by hand.

| | Before | After debloat + compile | Change |
|---|---|---|---|
| Used RAM | 1,422 MB | **816 MB** | **−606 MB (−43%)** |
| Free RAM | 1,553 MB | 2,159 MB | +606 MB |
| Load avg (1 min) at 4 min uptime | 18.2 | 15.6 | −15% |

RAM is the clear win: the disabled apps (above all the Google app's `:interactor` and the logger) no longer start at boot. Load right after boot stays high because boot itself dominates it. Day-to-day smoothness is the real test, and that's subjective.

### What the full compile actually did

`compile -m speed -f -a` ran for **34 min 32 s** and reported **69 packages that could not be compiled**, almost all `/system` apps (SystemUI, Settings, Phone, Contacts, …). These are most likely preopted at build time, so `-a` mostly burned time on Play Services, Chrome and the user apps. That's another reason the script now targets only user apps.
