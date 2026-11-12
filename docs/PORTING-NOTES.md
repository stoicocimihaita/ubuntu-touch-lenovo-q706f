# Porting notes

What was learned bringing Ubuntu Touch 24.04 / Halium 11 up on the TB-Q706F. Everything
here was observed on one device with stock firmware `S530352`.

## Device facts

| Item | Value |
|---|---|
| Codename / board | `Q706F`, Lenovo board name `paladin`, SKU `paladin_row_wifi` |
| SoC | SM8250 (kona v2.1), `ro.board.platform=kona` |
| Android | system 13, **vendor 11 (VNDK 30) → Halium 11** |
| Kernel | 4.19.157, clang, uncompressed `Image` |
| Boot image | header v2, page 4096, DTB inside boot, separate `recovery_a/b`, **no** `vendor_boot` |
| Offsets | kernel 0x8000, ramdisk 0x1000000, tags 0x100, dtb 0x1f00000; boot partition 96 MiB |
| Partitions | Virtual A/B, dynamic `super` (8 GiB): system, system_ext, product, vendor, odm |
| Panel | `qcom,mdss_dsi_samsung_2k_dsc_cmd`, driven as 2560×1600, 60/120 Hz |
| Touch / pen | Goodix Berlin on SPI: `goodix_ts` and `goodix_ts,pen` |
| Audio | `kona-mtp-snd-card`, Cirrus **CS35L45** amplifiers |
| Wi-Fi / BT | QCA6390 (`qca_cld3_qca6390.ko` in vendor) |
| Pen charger | NXP CTN730 (NFC wireless charging) at i2c `0-0028` |

## Kernel

Source: Lenovo's open-source drop as mirrored by silime (`android-11` branch). Neither that
tree nor Lenovo's official archive contains the device tree, the audio techpack or the
CS35L45 driver.

### Keeping the stock module ABI

The audio and Wi-Fi drivers are prebuilt vendor modules with `modversions` and
`vermagic=4.19.157-perf+`. With the unmodified stock config (extracted from the stock
`Image` with `extract-ikconfig`), the tree reproduces **all 1070** symbol CRCs those modules
need, i.e. it is ABI-identical to the shipped kernel.

Options Ubuntu Touch needs that change CRCs, found by bisecting 27 builds:

| Option | Why it breaks | Handling |
|---|---|---|
| `SYSVIPC` | adds `sysvsem`/`sysvshm` to `task_struct` | fields moved to the tail, hidden from genksyms |
| `FANOTIFY` | `fanotify_listeners` in `user_struct` | fills an existing 4-byte hole; hidden from genksyms |
| `POSIX_MQUEUE` | `mq_bytes` in `user_struct` | appended, hidden from genksyms |
| `CGROUP_DEVICE` | one more cgroup subsystem id | listed last so stock ids do not move; hidden from genksyms |
| `CGROUP_PERF`, `NETFILTER_NETLINK_ACCT` | same kind of change | left disabled |

`scripts/check-module-crc.sh` compares `Module.symvers` with the stock modules after every build.

### Other kernel changes

- **Module loading.** The stock config has `MODULE_SIG_FORCE=y` and the vendor modules are
  signed with Lenovo's key ("Required key not available"). `MODULE_SIG` stays (it affects
  `struct module`), `MODULE_SIG_FORCE` is dropped. The silime tree also forces
  `MODULE_INIT_IGNORE_MODVERSIONS|VERMAGIC` in `load_module()`, which silently fails every
  load (`ENOEXEC`) without `MODULE_FORCE_LOAD`; that hack is removed. Android's own init then
  loads the 31 vendor modules.
- **AppArmor.** Upstream 4.19 AppArmor has no `af_unix` mediation, so D-Bus cannot learn a
  peer's label and `media-hub-server` aborts ("apparmor::Context cannot be created for empty
  name") — which shows up as `std::bad_function_call` in the camera and media player apps.
  Fixed with the four AppArmor patches carried by the F(x)tec Pro1-X kernel.
- **Suspend.** `repowerd` suspends through `/sys/power/autosleep`; the stock config lacks
  `PM_AUTOSLEEP`.
- **Bluetooth.** `BT_HCIVHCI` for `bluebinder`.
- **Haptics.** `qti-haptics` gains `FF_RUMBLE`; in practice vibration is routed through the
  Android vibrator HAL instead (`HFD_VIBRATOR_IMPL=binder-aidl`).
- **Networking.** `net.ifnames=0` on the command line: the Wi-Fi interface was otherwise named
  `wlan0` on some boots and `wlp1s0` on others, and saved networks are matched by name.

## Boot and partitions

- **Dynamic partitions and slots.** The Halium tool `parse-android-dynparts` always reads
  logical-partition metadata slot 0, but on this Virtual A/B device the active system lives
  in the metadata slot of the active A/B slot. `ramdisk-overlay/sbin/parse-android-dynparts`
  wraps the tool: it builds a device-mapper view of `super` in which the active metadata
  slot sits where slot 0 is expected.
- **Root filesystem on userdata.** No `systempart=` is passed; the initramfs finds
  `ubuntu.img` on an ext4 `userdata`. This avoids writing to `super` during bring-up; moving
  the root filesystem into `system_<slot>` (needed for OTA) is future work.

## Userspace (overlay)

- **Adreno EGL.** The driver `dlopen`s `eglSubDriverAndroid.so` by name, but the vendor image
  only has it under `egl/`. `vendor/lib{,64}/.halium-overlay-dir` plus the extracted library
  put it where it is looked for.
- **`vndservicemanager`.** The stock binary aborts in a loop on Halium 11; the replacement
  used by other Halium 11 ports is overlaid.
- **Orientation.** The panel is driven as a landscape display, while touch, pen, sensors and
  cameras report in Android's portrait frame (stock uses
  `ro.surface_flinger.primary_display_orientation=ORIENTATION_270`). Fixes:
  `LIBINPUT_CALIBRATION_MATRIX="0 1 0 -1 0 1"` for touch, a 90° `transformation_matrix` in
  sensorfw, and `aal.camera.orientations.<id>=0` in `prop.halium` for the camera plugin.
- **Pen.** The Goodix controller only scans for the pen after `support_pen` is written.
  Mir's `evdev` input platform ignores tablet-tool devices, and an absolute pointer does not
  work in Lomiri (the cursor is moved by relative deltas), so `q706f-pen-touch` re-emits tip
  contacts as a direct-touch device. The driver raises `BTN_TOUCH` while hovering, so contact
  is derived from pressure. The single barrel button arrives as `BTN_STYLUS2`.
- **Brightness.** `repowerd` needs a device config to enable auto-brightness; the values in
  `config-q706f.xml` are the stock ones from `FrameworksResCommon_Sys.apk`.
- **AppArmor.** `apparmor.service` failed because a cache-wipe helper exits non-zero on
  installs that are not system-image based; a drop-in makes it non-fatal. Confined apps also
  need read access to the kgsl and CPU topology nodes (`hardware/graphics.d`).
- **Wi-Fi in suspend.** Without WoWLAN the driver disconnects on every suspend attempt; the
  boot hook enables wake on disconnect / magic packet.

## Open problems

- Pen pressure: Mir 1.8.3 `src/platforms/evdev/libinput_device.cpp` has no tablet-tool
  handling and falls back to a constant touch pressure. Mir 2.20/2.28 upstream have none either.
- Pen wireless charging: the CTN730 reads the pen's Bluetooth MAC over NFC, but its
  activation self-test answers "no WLC capability" with the pen at 94 %. Whether charging
  starts with a lower pen battery is not yet known.
- Suspend: frequent wake-ups from the Wi-Fi driver's packet filters; `hid-over-i2c` (pogo
  touchpad) logs a resume error on every cycle while no keyboard is attached.
- USB host mode enumerates at high speed (480 Mbit/s) only.
- Root filesystem in a partition, UBports recovery, installer configuration and OTA.
