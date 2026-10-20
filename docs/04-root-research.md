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

## Open questions

- [ ] Which button (if any) enters BROM/preloader on the DM100?
- [ ] Does the watch have a removable battery or exposed test point?
- [ ] Does `seccfg unlock` hit the V4 lockstate timeout from mtkclient#20?
- [ ] Does `lk` show an orange-state warning / boot delay after unlock?
