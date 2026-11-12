#!/usr/bin/env bash
# Build inside the container. Usage: scripts/build.sh [-k]   (-k: kernel + boot.img only)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
avail_gb=$(df --output=avail -BG "$ROOT" | tail -1 | tr -dc 0-9)
[ "$avail_gb" -ge 30 ] || { echo "ERROR: less than 30 GB free"; exit 1; }
"$ROOT/scripts/dev-shell.sh" bash -c "cd /work && ./build.sh -b workdir -o /work/out $*"
cp "$ROOT/workdir/tmp/partitions/boot.img" "$ROOT/out/boot.img"
echo "boot image: out/boot.img  ($(sha256sum "$ROOT/out/boot.img" | cut -c1-16)…)"
