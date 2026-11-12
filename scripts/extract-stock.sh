#!/usr/bin/env bash
# Extract the proprietary pieces this port needs from YOUR OWN stock firmware:
#   - the device tree blob (from boot.img)             -> q706f-stock.dtb
#   - the Adreno EGL sub-driver (from the vendor image) -> overlay/.../vendor/lib{,64}/
#   - the vendor kernel modules (for the ABI check)     -> stock/vendor-modules/
# Nothing extracted here is committed to the repository.
#
# Usage: scripts/extract-stock.sh <TB-Q706F stock firmware .zip (QFIL package)>
# Tested with TB-Q706F_USR_S530352_Q00050_ROW.zip.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP="${1:?usage: scripts/extract-stock.sh <stock firmware zip>}"
ZIP="$(realpath "$ZIP")"
S="$ROOT/stock"
mkdir -p "$S"

echo "== unpacking boot.img and the super chunks (about 7 GB)"
unzip -q -j -o "$ZIP" '*/image/boot.img' '*/image/super_*.img' -d "$S"

VENDOR=""
for img in "$S"/super_*.img; do
    if file "$img" | grep -q 'volume name "vendor"'; then VENDOR="$img"; fi
done
[ -n "$VENDOR" ] || { echo "ERROR: no super chunk labelled 'vendor' found"; exit 1; }
echo "vendor image: $(basename "$VENDOR")"

"$ROOT/scripts/dev-shell.sh" bash -c "
  set -e
  rm -rf /tmp/stock-boot && unpack_bootimg --boot_img /work/stock/boot.img --out /tmp/stock-boot >/dev/null
  cp /tmp/stock-boot/dtb /work/q706f-stock.dtb
  V=/work/stock/$(basename "$VENDOR")
  O=/work/overlay/system/opt/halium-overlay/vendor
  debugfs -R \"dump /lib/egl/eglSubDriverAndroid.so \$O/lib/eglSubDriverAndroid.so\" \$V 2>/dev/null
  debugfs -R \"dump /lib64/egl/eglSubDriverAndroid.so \$O/lib64/eglSubDriverAndroid.so\" \$V 2>/dev/null
  mkdir -p /work/stock/vendor-modules
  debugfs -R \"rdump /lib/modules /work/stock/vendor-modules\" \$V >/dev/null 2>&1
"
for f in q706f-stock.dtb overlay/system/opt/halium-overlay/vendor/lib/eglSubDriverAndroid.so overlay/system/opt/halium-overlay/vendor/lib64/eglSubDriverAndroid.so; do
    [ -s "$ROOT/$f" ] || { echo "ERROR: failed to extract $f"; exit 1; }
    printf '  ok  %-78s %s\n' "$f" "$(sha256sum "$ROOT/$f" | cut -c1-16)"
done
echo "  ok  stock/vendor-modules ($(ls "$S/vendor-modules/modules" | grep -c '\.ko$') modules)"
