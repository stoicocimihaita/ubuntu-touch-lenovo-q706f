#!/usr/bin/env bash
# READ-ONLY full partition backup over Qualcomm EDL, before any modification.
# Dumps every partition of UFS LUN 0-5 except userdata (~10.6 GB) and writes SHA256SUMS.
# Nothing is written to the tablet. Usage: scripts/backup-edl.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="stock/prog_firehose_ddr.elf"
DEST="backup/edl-$(date +%F)"
SKIP="userdata"

[ -f "$ROOT/$LOADER" ] || { echo "ERROR: $LOADER missing (unzip -j <firmware.zip> "*/image/prog_firehose_ddr.elf" -d stock/)"; exit 1; }
lsusb -d 05c6:9008 >/dev/null 2>&1 || { echo "ERROR: no device in EDL mode (05c6:9008). Power off, hold Volume Up, plug USB."; exit 1; }
avail_gb=$(df --output=avail -BG "$ROOT" | tail -1 | tr -dc 0-9)
[ "$avail_gb" -ge 20 ] || { echo "ERROR: less than 20 GB free"; exit 1; }
mkdir -p "$ROOT/$DEST" "$ROOT/logs"
LOG="logs/backup-edl-$(date +%F-%H%M).log"

"$ROOT/scripts/edl.sh" bash -c "
  set -e
  for lun in 0 1 2 3 4 5; do
    mkdir -p /work/$DEST/lun\$lun
    echo \"== LUN \$lun\"
    edl rl /work/$DEST/lun\$lun --memory=ufs --lun=\$lun --skip=$SKIP --genxml --loader=/work/$LOADER
  done
  chown -R \$HOST_UID:\$HOST_GID /work/$DEST
" 2>&1 | tee "$ROOT/$LOG"

cd "$ROOT/$DEST"
find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
echo "== summary"
echo "files: $(wc -l < SHA256SUMS)   size: $(du -sh . | cut -f1)   dir: $DEST"
for p in persist modemst1 modemst2 fsg fsc devinfo abl_a abl_b xbl_a xbl_b boot_a boot_b dtbo_a dtbo_b vbmeta_a vbmeta_b super; do
  f=$(find . -name "$p.bin" | head -1); [ -n "$f" ] && [ -s "$f" ] && echo "  ok  $p" || echo "  MISSING  $p"
done
