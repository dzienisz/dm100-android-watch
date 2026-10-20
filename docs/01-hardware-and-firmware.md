# 01: Hardware & firmware identification

Everything here was read over plain ADB (`shell` uid, no root).

## How it shows up on USB

```
DM100
  Manufacturer: MediaTek
  USB Vendor ID:  0x0e8d
  USB Product ID: 0x201d
```

Two vendor-specific interfaces: `ff/ff` (MTP) and `ff/42/01`, which is the **ADB** interface. USB debugging is enabled by default on this firmware.

## Build properties

```
ro.product.manufacturer=alps
ro.product.brand=DM100
ro.board.platform=mt6739
ro.build.version.release=7.1.1
ro.build.version.sdk=25
ro.build.version.security_patch=2024-03-05
ro.build.display.id=DM100_KI_V1.1_20241011_DW
ro.build.fingerprint=alps/full_C10_DW_480X640_TFT/C10_DW_480X640_TFT:7.1.1/N6F26Q/1728625728:user/test-keys
ro.build.type=user
ro.build.tags=test-keys
ro.debuggable=0
ro.secure=1
ro.boot.verifiedbootstate=green
ro.boot.flash.locked=1
ro.oem_unlock_supported=1
ro.product.cpu.abi=armeabi-v7a
ro.mediatek.version.release=alps-mp-n1.mp18-V2_aeon6739.36.n1_P11
gsm.version.baseband=MOLY.LR12A.R2.MP.V5.23.P10
```

Notes:

- **`alps`** is MediaTek's reference-design manufacturer string. The real ODM is a Shenzhen house using the **Wiite** software stack (`com.wiite.*`, `wiiteer.com`). The `aeon6739` tag suggests an Aeon board design.
- **`C10_DW_480X640_TFT`** is the ODM's internal project name. The same base is probably shipped under many brand names.
- **`test-keys`** means the system image is signed with the publicly available AOSP test keys, not a private vendor key (see [03](03-privacy-audit.md)).

## Kernel

```
Linux version 4.4.22+ (keil@build11) (gcc version 4.8 (GCC)) #1 SMP PREEMPT Fri Oct 11 13:59:14 CST 2024
```

4.4.22 is a September 2016 point release. The 4.4 LTS branch reached 4.4.302 before EOL in 2022. The `2024-03-05` security patch level therefore only describes (at best) the Android framework, not the kernel.

## CPU / memory / storage

- `MT6739WA`, 4 cores online, `cpuinfo_max_freq=1274000` (1.27 GHz), governor `sched`
- `MemTotal: 3002952 kB` + 1 GB zram swap
- eMMC `mmcblk0` = 30,535,680 KiB (≈ 32 GB), `/data` 25 GB

RAM and storage are real. Many cheap watches spoof these numbers, and this one doesn't.

## Components (from boot `dmesg`)

| Part | Chip |
|---|---|
| Display | Sitronix **ST7701S**, 480x640, MIPI DSI 1-lane, burst video mode |
| Touch | **Hynitron** (CST-series), vendor driver "Hynitron V0.1" |
| Heart rate | **HRS3300** |
| Accelerometer | QST **QMA6100** |
| Camera | GalaxyCore **GC02M2** (2 MP) |
| PMIC | MediaTek **MT6357** |
| Wi-Fi / BT / GPS / FM | On-SoC `CONSYS_MT6739` |
| Keys | `mtk-kpd` (2 buttons) |

## Partition table (`/dev/block/platform/*/by-name/`)

```
boot  boot_para  cache  expdb  flashinfo  frp  gz1  gz2  lk  lk2
loader_ext1  loader_ext2  logo  mcupmfw  md1dsp  md1img  metadata
nvcfg  nvdata  nvram  para  proinfo  protect1  protect2  recovery
sec1  seccfg  spmfw  system  tee1  tee2  userdata
```

- **No `vendor` partition** (`/vendor -> /system/vendor`) and **no `vbmeta`**, so this is a pre-Treble layout and Generic System Images cannot boot without re-partitioning and porting a vendor image.
- **`seccfg`** holds the bootloader lock state. This is what `mtkclient da seccfg unlock` rewrites.
- **`boot`** and **`recovery`** are separate (non-A/B), the classic Magisk boot-patch target.
- **`nvram` / `nvdata` / `proinfo`** hold IMEI and radio calibration. **Back these up before anything else.**

## Software stack

119 packages total. Notable non-AOSP system apps:

| Package | Role |
|---|---|
| `com.mediatek.watchapp` | Default launcher / watch faces |
| `com.wiite.*` (power, systemmode, devicemsg, ambientclock, freezeapp, systemtool, wiitestore, bluetoothvcard, wirteimei) | Vendor framework apps |
| `com.adups.fota`, `com.adups.fota.sysoper` | Adups OTA updater |
| `com.baidu.map.location` | Baidu location SDK |
| `com.sprots.wiiteer.fitness`, `creator.android.SHealth`, `com.cenon.heartrate` | Fitness / health |
| `cn.heils.faceunlock` | Face unlock (heils.cn SDK) |
| `com.mediatek.mtklogger` | MediaTek debug logger, running by default |
