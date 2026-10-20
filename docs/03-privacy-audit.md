# 03: Privacy & security audit (first pass)

**Question:** if I sign into my Google account on this watch, does it leak data to the vendor?

**Short answer:** the vendor collects device and SIM identifiers over plain HTTP. I found **no evidence** of vendor code reading Google credentials, but the firmware is built so that it *could*, and I can't rule it out from static strings alone. Use a secondary Google account on this watch.

## Method

1. Snapshot `/proc/net/tcp{,6}` / `udp{,6}` over ADB, map socket UIDs to packages.
2. Pull all vendor APKs (`adb shell pm list packages -f` → `adb pull`) and grep the dex/asset strings for URLs and IPs.
3. Resolve every vendor hostname, match against observed connections.
4. Dump granted permissions and UIDs per vendor package (`dumpsys package`).

No root, no traffic interception (yet).

## Finding 1: activation telemetry to `watch.wiiteer.com` over plain HTTP

Observed connection: `47.83.14.42:81` (Alibaba Cloud).

```
watch.wiiteer.com     -> 47.83.14.42
watch2.wiiteer.com    -> 47.83.14.42
developer.wiiteer.com -> 47.83.14.42
```

`com.wiite.devicemsg` (runs as uid 1000 / `system`) contains an `UploadingService` with:

```
http://watch.wiiteer.com/api/v1/watch/activation
getDeviceId  imei  ro.serialno  getSimNumber  getSimOperator  getSimType
```

The connection was seen in `TIME_WAIT` a few minutes after boot. Polling `/proc/net/tcp*` every 2 s for the next 5 minutes showed no further connections to `47.83.14.42`, so the upload looks boot- or activation-triggered rather than continuous.

So on activation it sends at least **IMEI, serial number, SIM phone number and operator** to the ODM, **unencrypted**. That's common "sales activation" telemetry for white-label devices, but the cleartext transport means anyone on the path sees it too.

## Finding 2: other hard-coded endpoints

| Package | Endpoints |
|---|---|
| `com.wiite.devicemsg` | `watch.wiiteer.com` |
| `com.wiite.wiitestore` | `watch.wiiteer.com`, `watch2.wiiteer.com`, `developer.wiiteer.com`, `223.5.5.5` (AliDNS) |
| `com.sprots.wiiteer.fitness` | `watch2.wiiteer.com`, many `*.amap.com` (AutoNavi / Alibaba maps & location), `223.5.5.5` |
| `com.baidu.map.location` | `api.map.baidu.com`, `loc.map.baidu.com`, `sapi.skyhookwireless.com` |
| `cn.heils.faceunlock` | `face.heils.cn:8081` (→ `47.106.37.233`, Alibaba Cloud), `faceunlock.sdk.heils.cn` |
| `com.adups.fota` | `fota5tbk.adups.com` (no longer resolves) |
| `com.mediatek.watchapp` | `www.weitetech.cn` (plus cert/font URLs) |

Everything else seen on the wire during the snapshot went to Google (`2001:4860::/32`, `2a00:1450::/32`) from Play Services, Play Store and Maps.

## Finding 3: 19 vendor apps run as `system`

These packages share **uid 1000** (`android.uid.system`), the same identity as the Android framework itself:

`com.adups.fota.sysoper`, `com.android.watchweather`, `com.cenon.heartrate`, `com.mediatek.watchapp`, `com.signal.main`, `com.sprots.wiiteer.fitness`, `com.ss.oobe`, `com.wiite.ambientclock`, `com.wiite.bluetoothvcard`, `com.wiite.devicemsg`, `com.wiite.freezeapp`, `com.wiite.power`, `com.wiite.systemmode`, `com.wiite.wiitestore`, `com.wiitetech.WiiWatchPro`, `creator.android.SHealth`, `fdy.wiitter.com`, `qs.wiite.cleantask`, `wiite.com.wearthirdappadater`

Plus `com.wiite.wirteimei` as uid 1001 (`phone`), with `SEND_SMS` and `AUTHENTICATE_ACCOUNTS`.

A `system`-uid app with `INTERNET` can technically read account databases, SMS, contacts and location without asking. Several of these have network endpoints (above).

Vendor code referencing account / personal-data APIs (string-level only):

| Package | References |
|---|---|
| `com.mediatek.watchapp` | `CallLog`, `ContactsContract`, `content://sms` (expected for a launcher showing missed calls/messages) |
| `com.wiite.power` | `android.accounts.AccountManager` |
| `com.wiite.wiitestore` | `AccountManager`, `ContactsContract` |
| `com.sprots.wiiteer.fitness` | `AccountManager`, `getPassword` (likely from the bundled Amap SDK) |

None reference `getAuthToken` / `peekAuthToken` as plain strings. That is weak evidence, because the code is partly obfuscated.

## Finding 4: `test-keys` platform signature

The system image is signed with AOSP **test-keys**, which are public. Any APK signed with the public platform key could be granted `signature`-level permissions or share `android.uid.system`. This is a real (if install-dependent) privilege-escalation path, and also the reason rooting may be easier than usual.

## Finding 5: stale kernel

Linux 4.4.22 (2016). Years of public kernel CVEs apply regardless of the `2024-03-05` patch string.

## Recommendations

1. **Use a secondary Google account** on the watch, not your main one. If your main account was already signed in, remove it on the watch, then revoke the device at <https://myaccount.google.com/device-activity>.
2. Disable what you don't use. At minimum `com.wiite.devicemsg` once activated, `com.wiite.wiitestore`, and `cn.heils.faceunlock` if not using face unlock. All three are in [`scripts/debloat.sh`](../scripts/debloat.sh).
3. Optional: a no-root VPN firewall (e.g. NetGuard, supports Android 5+) to block vendor uids from the internet.

## Mitigation applied with root (2026-10-20)

[`scripts/block-vendor-domains.sh`](../scripts/block-vendor-domains.sh) puts a `hosts` file into the Magisk module `dm100_debloat` (systemless, `/system` untouched) that maps these names to `0.0.0.0`:

| Domain | Why |
|---|---|
| `wiiteer.com`, `www.`, `watch.`, `watch2.`, `developer.` | activation/telemetry server of the watch's software stack |
| `face.heils.cn`, `faceunlock.sdk.heils.cn` | face-unlock SDK |
| `fota5tbk.adups.com` | Adups OTA updater |
| `www.weitetech.cn` | referenced by the launcher |
| `api.map.baidu.com`, `loc.map.baidu.com` | Baidu location SDK |

Verified on the watch: the vendor names resolve to the watch itself (nothing leaves) while `www.google.com` resolves normally, and the block survives a reboot (11 active entries).

**Limits, honestly:**
- A hosts file blocks by *name*. Anything that connects to a hard-coded IP, uses its own DNS (the fitness app embeds AliDNS `223.5.5.5`) or DNS-over-HTTPS bypasses it. A real guarantee needs a firewall rule.
- Amap (`*.amap.com`, used by the fitness app for maps/location) is deliberately **not** blocked, to avoid breaking that app. It still talks to Alibaba's map servers.
- Hosts blocking does not stop the OS from using the `devicemsg`/`Adups` code if it were still installed. Those apps are removed anyway (see [02](02-performance-debloat.md)).

## Open questions / next steps

- [ ] Capture actual traffic (mitmproxy on Wi-Fi) to see real payloads, not just strings
- [ ] Decompile `devicemsg`, `wiitestore`, `wiite.power` with jadx and read what `AccountManager` is used for
- [ ] Check whether `devicemsg` re-uploads periodically or only once
