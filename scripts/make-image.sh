#!/usr/bin/env bash
# Assemble the flashable root filesystem image (Ubuntu Touch rootfs + Halium 11 GSI + this
# device's tarball) from the build output. Result: out/image/rootfs.img
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -s "$ROOT/out/device_q706f.tar.xz" ] || { echo "ERROR: run scripts/build.sh first"; exit 1; }
DEV_SHELL_PRIVILEGED=1 "$ROOT/scripts/dev-shell.sh" bash -c '
  cd /work && ./build/prepare-fake-ota.sh /work/out/device_q706f.tar.xz /work/out/ota \
    && ./build/system-image-from-ota.sh /work/out/ota/ubuntu_command /work/out/image'
echo "image: out/image/rootfs.img  ($(sha256sum "$ROOT/out/image/rootfs.img" | cut -c1-16)…)"
