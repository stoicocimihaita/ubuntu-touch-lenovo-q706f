#!/usr/bin/env bash
# Verify that the built kernel still satisfies the symbol CRCs required by the
# prebuilt stock vendor modules (audio, Wi-Fi). Run after every kernel build.
# Usage: scripts/check-module-crc.sh [Module.symvers] [stock-modules-dir]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYMVERS="${1:-$ROOT/workdir/downloads/KERNEL_OBJ/Module.symvers}"
MODDIR="${2:-$ROOT/stock/vendor-modules/modules}"
NEED="$ROOT/stock/modversions.txt"
if [ ! -s "$NEED" ]; then
  rel="${MODDIR#"$ROOT"/}"
  "$ROOT/scripts/dev-shell.sh" bash -c "cd /work/$rel && for m in *.ko; do modprobe --dump-modversions \$m | awk -v m=\$m '{print \$1, \$2, m}'; done" > "$NEED"
fi
python3 -I - "$SYMVERS" "$NEED" <<'PY'
import sys
ours = {}
for line in open(sys.argv[1]):
    crc, sym = line.split('\t')[:2]
    ours[sym] = int(crc, 16)
need, exported_by_module = {}, 0
for line in open(sys.argv[2]):
    crc, sym, _mod = line.split()
    need[sym] = int(crc, 16)
bad = sorted(s for s in need if s in ours and ours[s] != need[s])
missing = sum(1 for s in need if s not in ours)
ok = sum(1 for s in need if ours.get(s) == need[s])
print(f"needed={len(need)} match={ok} mismatch={len(bad)} provided-by-other-modules={missing}")
if bad:
    print("MISMATCH:", ", ".join(bad[:30]))
    sys.exit(1)
print("OK: stock vendor modules are ABI compatible with this kernel")
PY
