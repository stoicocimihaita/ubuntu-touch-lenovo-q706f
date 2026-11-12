#!/usr/bin/env bash
# Install Ubuntu Touch on a Lenovo Tab P12 Pro (TB-Q706F) with an UNLOCKED bootloader.
#
# Layout used: the root filesystem is a file (ubuntu.img) on an ext4-formatted userdata
# partition; Android's super partition (system/vendor/odm) is left untouched and the vendor
# and odm images in it are used as they are. Only userdata and boot_<active slot> are written.
#
# Each step is a separate subcommand; the ones that write need an explicit flag.
#
#   status                                  what the tablet currently exposes over USB
#   boot                                    [fastboot] start out/boot.img once, without flashing
#   format --i-confirm-erase-userdata       [initrd]   format userdata as ext4 (ERASES Android data)
#   push                                    [initrd]   copy out/image/rootfs.img to userdata, verified
#   bootloader                              [initrd]   reboot straight into the bootloader
#   flash-boot --i-confirm-flash-boot       [fastboot] write out/boot.img to boot_<active slot>
#   restore-boot <stock boot.img> --i-confirm-flash-boot   [fastboot] put the stock kernel back
#
# "[initrd]" steps talk to the Halium initramfs debug shell (telnet 192.168.2.15 over USB),
# which is what the tablet shows after `boot` while no root filesystem is installed yet.
# See README.md for the full sequence and for how to go back to Android.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOT="$ROOT/out/boot.img"
IMG="$ROOT/out/image/rootfs.img"
IP=192.168.2.15
FB=(fastboot); [ -n "${SERIAL:-}" ] && FB=(fastboot -s "$SERIAL")

# Run one command line in the initramfs shell and print its output.
tn() { { sleep 1; printf '%s\n' "$1"; sleep "${2:-3}"; printf 'exit\n'; sleep 1; } \
        | nc -w "$(( ${2:-3} + 15 ))" "$IP" 23 | tr -d '\r' | LC_ALL=C sed 's/\xff[\xfb-\xfe].//g'; }
need_initrd() { ping -c1 -W2 "$IP" >/dev/null 2>&1 || { echo "ERROR: initramfs shell not reachable at $IP (run '$0 boot' first)"; exit 1; }; }
confirm() { [[ " $* " == *" $CONFIRM_FLAG "* ]] || { echo "Refusing: this step writes to the tablet. Pass $CONFIRM_FLAG"; exit 1; }; }

# The Lenovo bootloader sometimes comes up half-initialised: it then knows no variables and
# stalls or refuses transfers. Restart it until it reports its download size.
need_fastboot() {
    "${FB[@]}" devices | grep -q fastboot || { echo "ERROR: no device in fastboot mode (power off, hold Power + Volume Up)"; exit 1; }
    for _ in 1 2 3 4; do
        if timeout 8 "${FB[@]}" getvar max-download-size 2>&1 | grep -q 'max-download-size: [0-9]'; then return 0; fi
        echo "bootloader not ready, restarting it…"; timeout 10 "${FB[@]}" reboot bootloader >/dev/null 2>&1 || true; sleep 8
    done
    echo "ERROR: bootloader stays unresponsive; choose 'Restart bootloader' on the tablet and retry"; exit 1
}

case "${1:-}" in
  status)
    fastboot devices; lsusb | grep -iE '18d1|17ef|05c6' || true
    ping -c1 -W1 "$IP" >/dev/null 2>&1 && echo "initramfs shell reachable at $IP" || echo "initramfs shell not reachable"
    ;;
  boot)
    [ -s "$BOOT" ] || { echo "ERROR: $BOOT missing (run scripts/build.sh)"; exit 1; }
    need_fastboot
    "${FB[@]}" getvar unlocked 2>&1 | grep -q 'unlocked: yes' || { echo "ERROR: bootloader is locked"; exit 1; }
    "${FB[@]}" boot "$BOOT"
    ;;
  format)
    CONFIRM_FLAG=--i-confirm-erase-userdata; confirm "${@:2}"
    need_initrd
    tn 'U=$(readlink -f /dev/disk/by-partlabel/userdata); grep -q " /tmpmnt " /proc/mounts && umount /tmpmnt; mke2fs -F -q -t ext4 -L userdata $U && mkdir -p /tmpmnt && mount -t ext4 $U /tmpmnt && df -h /tmpmnt | tail -1' 60 | grep -E "tmpmnt" \
        || { echo "ERROR: formatting or mounting userdata failed"; exit 1; }
    ;;
  push)
    [ -s "$IMG" ] || { echo "ERROR: $IMG missing (run scripts/make-image.sh)"; exit 1; }
    need_initrd
    want=$(sha256sum "$IMG" | cut -d' ' -f1); echo "image sha256:  $want"
    tn 'grep -q " /tmpmnt " /proc/mounts || { mkdir -p /tmpmnt; mount /dev/disk/by-partlabel/userdata /tmpmnt; }; grep " /tmpmnt " /proc/mounts' 4 | grep -q ext4 \
        || { echo "ERROR: userdata is not an ext4 filesystem mounted on the tablet (run '$0 format …')"; exit 1; }
    { sleep 1; printf 'nc -l -p 9000 > /tmpmnt/ubuntu.img.part\n'; sleep 3600; } | nc "$IP" 23 >/dev/null 2>&1 &
    listener=$!
    sleep 4
    echo "copying (about 10 minutes over USB)…"
    nc -N "$IP" 9000 < "$IMG"
    sleep 3; kill "$listener" 2>/dev/null || true; pkill -P $$ sleep 2>/dev/null || true
    got=$(tn 'sha256sum /tmpmnt/ubuntu.img.part' 120 | grep -oE '^[0-9a-f]{64}' | head -1)
    echo "tablet sha256: $got"
    [ "$got" = "$want" ] || { echo "ERROR: checksum mismatch; ubuntu.img.part left in place"; exit 1; }
    tn 'mv /tmpmnt/ubuntu.img.part /tmpmnt/ubuntu.img; sync; umount /tmpmnt; echo done' 8 | grep -q done
    echo "OK: ubuntu.img is on userdata"
    ;;
  bootloader)
    need_initrd
    # busybox reboot cannot pass an argument, and a plain reboot would start Android,
    # whose recovery may offer to wipe the freshly written userdata.
    "$ROOT/scripts/dev-shell.sh" bash -c 'mkdir -p /work/out && aarch64-linux-gnu-gcc -static -nostdlib -ffreestanding -Os -o /work/out/reboot-to /work/tools/reboot-to.c'
    { sleep 1; printf 'nc -l -p 9001 > /reboot-to\n'; sleep 8; } | nc -w 12 "$IP" 23 >/dev/null 2>&1 &
    sleep 3; nc -N "$IP" 9001 < "$ROOT/out/reboot-to"; sleep 3
    { sleep 1; printf 'chmod +x /reboot-to; sync; /reboot-to\n'; sleep 3; } | nc -w 8 "$IP" 23 >/dev/null 2>&1 || true
    echo "tablet is rebooting into the bootloader"
    ;;
  flash-boot)
    CONFIRM_FLAG=--i-confirm-flash-boot; confirm "${@:2}"
    [ -s "$BOOT" ] || { echo "ERROR: $BOOT missing"; exit 1; }
    need_fastboot
    slot=$("${FB[@]}" getvar current-slot 2>&1 | sed -n 's/^current-slot: *//p' | tr -d '\r')
    [ -n "$slot" ] || { echo "ERROR: cannot read the active slot"; exit 1; }
    echo "writing $(basename "$BOOT") ($(sha256sum "$BOOT" | cut -c1-16)…) to boot_$slot"
    "${FB[@]}" flash "boot_$slot" "$BOOT"
    ;;
  restore-boot)
    STOCK="${2:?usage: $0 restore-boot <stock boot.img> --i-confirm-flash-boot}"
    CONFIRM_FLAG=--i-confirm-flash-boot; confirm "${@:3}"
    need_fastboot
    slot=$("${FB[@]}" getvar current-slot 2>&1 | sed -n 's/^current-slot: *//p' | tr -d '\r')
    "${FB[@]}" flash "boot_$slot" "$STOCK"
    ;;
  *)
    sed -n 2,20p "$0"; exit 1 ;;
esac
