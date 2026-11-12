# Backup and recovery

Read this before you unlock or flash anything.

## Boot modes

| Mode | How to enter | How to leave |
|---|---|---|
| Fastboot | powered off → hold **Power + Volume Up** (or `adb reboot bootloader`) | `fastboot reboot`, or the menu |
| Recovery | from the fastboot menu | recovery menu |
| EDL (Qualcomm 9008) | `adb reboot edl`, or powered off → hold **Volume Up** and plug in USB. The screen stays black. | `edl reset`, or hold Power for about 15 s |

## There is no second bootable slot

The tablet is Virtual A/B. `super` (8 GiB) only holds the logical partitions of the *active*
slot; the other slot keeps old boot-chain partitions but its system was overwritten by the
last OTA. Do not count on switching slots to get Android back.

## Take a full backup first (read-only)

The stock firehose programmer works with [bkerler/edl](https://github.com/bkerler/edl)
without authentication, so every partition can be read before anything is modified —
including the ones that are unique to your unit (`persist`, `modemst1/2`, `fsg`, `fsc`,
`devinfo`).

```bash
unzip -j /path/to/TB-Q706F_USR_S530352_Q00050_ROW.zip '*/image/prog_firehose_ddr.elf' -d stock/
adb reboot edl                 # lsusb must show 05c6:9008
scripts/backup-edl.sh          # dumps UFS LUN 0-5 except userdata (about 11 GB) + SHA256SUMS
scripts/edl.sh edl reset --loader=/work/stock/prog_firehose_ddr.elf
```

Keep the result somewhere safe and **never publish it**: it contains identifiers and
calibration data of your device.

Only *reading* over EDL was exercised during this port. Writing partitions back with `edl w`
is the intended last-resort path but has not been tested here.

The `rawprogram*.x` / `patch*.x` descriptors in the stock QFIL package are encrypted, so the
package cannot be flashed with `qdl` as is. A community decryption tool exists; it was not
used or verified for this port.

## What the install touches

| Partition | Change | How to undo |
|---|---|---|
| `userdata` | reformatted as ext4, holds `ubuntu.img` | factory reset from the stock recovery |
| `boot_<active slot>` | replaced by the Ubuntu Touch boot image | `scripts/install.sh restore-boot <stock boot.img> --i-confirm-flash-boot` |

`super`, `dtbo`, `vbmeta`, `recovery`, `persist`, the modem and bootloader partitions are not written.

## Unlocking

`fastboot flashing unlock` worked directly on a ROW unit with firmware `S530352` once *OEM
unlocking* was enabled; no `sn.img` from Lenovo was required. Unlocking erases all data.
Do not re-lock the bootloader with a modified system installed.

## Bootloader quirk

The Lenovo bootloader's fastboot occasionally starts half-initialised: `getvar` answers
"Variable Not found" and transfers hang or fail with "Requested download size is more than
max allowed". Choose **Restart bootloader** on the tablet (or `fastboot reboot bootloader`)
and try again. `scripts/install.sh` does this check for you. Once Ubuntu Touch is running,
a new boot image can also be written from the running system with `dd` to
`/dev/disk/by-partlabel/boot_<slot>` and verified by reading it back.
