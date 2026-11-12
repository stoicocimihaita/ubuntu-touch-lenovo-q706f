# Ubuntu Touch for the Lenovo Tab P12 Pro (TB-Q706F)

An unofficial, work-in-progress [Ubuntu Touch](https://ubuntu-touch.io) port for the
**Lenovo Tab P12 Pro / Xiaoxin Pad Pro 12.6** (`TB-Q706F`, codename `q706f`, Snapdragon 870 /
SM8250, 12.6" 2560×1600 OLED).

- **Base:** Ubuntu Touch 24.04 (`24.04-2.x`) on **Halium 11**, using the stock Android 11 vendor.
- **Kernel:** Lenovo's downstream 4.19.157 with a small patch set —
  [stoicocimihaita/android_kernel_lenovo_sm8250](https://github.com/stoicocimihaita/android_kernel_lenovo_sm8250), branch `halium-11.0`.
- **State:** boots on its own, Lomiri runs with GPU acceleration, and most hardware works.
  It was brought up and tested on **one** tablet (8 GB / 256 GB, ROW/EEA, stock firmware
  `S530352`). Treat it as a developer preview.

> **This can brick your tablet and it erases all data.** Unlocking the bootloader wipes the
> device. There is no official installer and no OTA yet. Read [docs/RECOVERY.md](docs/RECOVERY.md)
> and take the EDL backup *before* you change anything. You do this at your own risk.

Discussion, questions and test reports: [XDA thread](https://xdaforums.com/t/rom-unofficial-wip-ubuntu-touch-24-04-halium-11-for-lenovo-tab-p12-pro-xiaoxin-pad-pro-12-6-tb-q706f.4808465/).

## What works

Tested on 2026-11-12. "Confirmed" means a person checked it on the device.

| Component | State | Notes |
|---|---|---|
| Boot, reboot | ✅ | Boots unattended in about 22 s |
| Display, brightness | ✅ | 2560×1600; backlight control and automatic brightness (stock Lenovo curve); the UI slider was not tested |
| GPU acceleration | ✅ | Adreno 650, OpenGL ES 3.2 through libhybris |
| Touchscreen | ✅ | Needs a 90° input rotation (included) |
| Rotation / accelerometer | ✅ | |
| Wi-Fi | ✅ | 5 GHz (Wi-Fi 6) confirmed; 2.4 GHz connection not tested |
| Bluetooth | ✅ | Audio speaker and BLE HID (the pen) confirmed |
| Speakers | ✅ | Stereo confirmed; the four speakers were not tested individually |
| Microphones | 🟡 | Recording carries real signal; quality not judged |
| Cameras | 🟡 | Rear and front viewfinder work; saving photos/videos and ultra-wide not verified |
| Hardware video decoding | 🟡 | H.264 1080p through the Qualcomm decoder; H.265 not tested |
| Vibration | ✅ | Through the Android vibrator HAL |
| Flashlight | 🟡 | LED works from sysfs; the UI toggle was not tested |
| USB OTG | ✅ | FAT32 stick mounts read/write; link runs at USB 2.0 speed |
| Battery / charging | 🟡 | Level and slow charging reported; 45 W fast charging not tested |
| Suspend | 🟡 | Enters deep sleep with the screen off and no USB host attached, but wakes often (Wi-Fi); overnight drain not measured |
| Pen (Precision Pen 3) | 🟡 | Works as a precise touch contact; barrel button configurable. **No pressure sensitivity** (see below) |
| Pen wireless charging | ❔ | NFC link to the pen works; charging did not start with the pen at 94 % |
| Pogo keyboard / touchpad | ❔ | Not tested |
| microSD | ❔ | Reader detected, no card tested |
| GPS | ➖ | No GNSS on the Wi-Fi model |
| Waydroid, OTA, UBports recovery | ❌ | Not done yet |

Known limitations:

- **Pen pressure does not reach applications.** The digitizer reports pressure (0–4095) and
  the included daemon forwards it, but the input platform of the system compositor (Mir 1.8,
  `evdev` platform) has no tablet-tool support and reports a constant touch pressure. This
  needs a change in Mir, not in this port.
- **Suspend is shallow.** The Wi-Fi driver wakes the tablet every few seconds on its own
  packet filters.
- **No slot fallback.** The tablet is Virtual A/B: only the active slot has a system in
  `super`. The other slot does not hold a bootable Android.
- **The Lenovo bootloader's fastboot is flaky.** It sometimes comes up half-initialised and
  stalls or refuses transfers; `scripts/install.sh` restarts it automatically.
- The stock core apps (Camera, Gallery, File Manager, OpenStore…) are not in the image this
  install method produces; install OpenStore first, then the rest from it.

## How it works

Three things that are specific to this tablet and were not obvious:

1. **Stock vendor kernel modules are loaded unmodified.** Audio (including the Cirrus
   CS35L45 amplifiers) and Wi-Fi only exist as prebuilt, signed modules in the vendor
   partition, and Lenovo published neither their source nor the device tree. The kernel is
   therefore built from the exact stock config, and the options Ubuntu Touch needs are
   added in a way that keeps every symbol CRC identical (`scripts/check-module-crc.sh`
   verifies 1070 of 1070). See [docs/PORTING-NOTES.md](docs/PORTING-NOTES.md).
2. **The stock device tree is reused** as a prebuilt DTB, and the `dtbo` partition is left alone.
3. **The root filesystem lives in a file on `userdata`**, so Android's `super` partition is
   not modified; the stock `vendor`/`odm` images in it are mounted as they are.

Proprietary files (the DTB, one Adreno library, the vendor modules used for the ABI check)
are **not** in this repository. `scripts/extract-stock.sh` takes them from your own copy of
the stock firmware.

## Requirements

- A **TB-Q706F** on stock firmware `S530352` (Android 13 system, Android 11 vendor). Other
  firmware versions and the 5G model (TB-Q706Z) are untested.
- An x86_64 Linux PC with Docker, `adb`/`fastboot`, `git`, `unzip`, `nc`, about 40 GB free disk.
- The stock firmware package `TB-Q706F_USR_S530352_Q00050_ROW.zip` (QFIL format).
- A USB cable; a USB 2.0 port is the safer choice for EDL.

## Build

```bash
git clone https://github.com/stoicocimihaita/ubuntu-touch-lenovo-q706f
cd ubuntu-touch-lenovo-q706f
scripts/extract-stock.sh /path/to/TB-Q706F_USR_S530352_Q00050_ROW.zip
scripts/build.sh            # kernel, boot.img, device tarball  -> out/
scripts/check-module-crc.sh # must end with "OK: stock vendor modules are ABI compatible"
scripts/make-image.sh       # Ubuntu Touch rootfs + Halium 11 GSI -> out/image/rootfs.img
```

The first run builds a container image and downloads the toolchains, the kernel, the
Ubuntu Touch root filesystem (about 1 GB) and the generic Halium 11 system image.

## Install

1. **Back up first** (read-only, over EDL): see [docs/RECOVERY.md](docs/RECOVERY.md).
2. **Unlock the bootloader** — this erases the tablet. Enable *OEM unlocking* in Developer
   options, then:
   ```bash
   adb reboot bootloader
   fastboot flashing unlock      # confirm on the tablet with the volume and power keys
   ```
   On this ROW unit no Lenovo unlock file (`sn.img`) was needed.
3. Put the tablet in fastboot (power off, hold **Power + Volume Up**) and run:
   ```bash
   scripts/install.sh boot                                  # starts our kernel once, nothing is written
   scripts/install.sh format --i-confirm-erase-userdata      # userdata -> ext4
   scripts/install.sh push                                   # copies the system image, verifies the checksum
   scripts/install.sh bootloader                             # back to fastboot without passing through Android
   scripts/install.sh boot                                   # first Ubuntu Touch boot, still nothing flashed
   ```
   After the second `boot` the setup wizard should appear. Until you flash the boot image,
   every start has to be done this way from the PC.
4. When you are satisfied that it boots, make it permanent:
   ```bash
   scripts/install.sh flash-boot --i-confirm-flash-boot      # writes boot_<active slot>
   ```

Do not let the tablet boot **Android** while `userdata` holds Ubuntu Touch: its recovery may
offer to factory-reset the partition.

Remote access once it runs: with USB connected, `ssh -p 8022 phablet@10.15.19.82`; the
`sudo` password of development images is `phablet`.

## Going back to Android

Flash the stock `boot.img` to the active slot (`scripts/install.sh restore-boot <boot.img>
--i-confirm-flash-boot`) and factory-reset from the stock recovery so that `userdata` is
formatted for Android again. Nothing else was modified. For worse situations see
[docs/RECOVERY.md](docs/RECOVERY.md).

## Repository layout

| Path | Purpose |
|---|---|
| `deviceinfo`, `build.sh` | Input for the UBports [halium-generic-adaptation-build-tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools) |
| `overlay/` | Device configuration layered over the generic Ubuntu Touch root filesystem |
| `ramdisk-overlay/` | Slot-aware dynamic-partition mapping for the boot ramdisk |
| `scripts/` | Container, build, stock extraction, ABI check, image assembly, install, EDL backup |
| `tools/reboot-to.c` | Tiny helper to reboot the initramfs into the bootloader |
| `docs/` | Porting notes and recovery procedure |

## Credits

- [UBports](https://ubports.com) for Ubuntu Touch, Halium and the build tools. The overlay is
  modelled on the community ports for the F(x)tec Pro1-X, Samsung Galaxy Z Fold3 and Xiaomi
  Poco X3 Pro; `vndservicemanager` and the AppArmor kernel patches come from those ports.
- [silime](https://github.com/silime) for the kernel tree
  ([android_kernel_lenovo_sm8250](https://github.com/silime/android_kernel_lenovo_sm8250))
  and the mainline work on this tablet, and the postmarketOS / Nura contributors whose
  device page documents the hardware.
- Lenovo for the open-source kernel drop (`s410005_220715_row`).

## License

The scripts and configuration in this repository are licensed under the GNU General Public
License v3.0 (see [LICENSE](LICENSE)). The kernel is GPL-2.0 and lives in its own repository.
Files taken from other projects keep their original licenses.
