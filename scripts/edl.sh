#!/usr/bin/env bash
# Run bkerler/edl (or qdl) inside the EDL container with USB passthrough.
# The tablet must be in EDL mode (Qualcomm 05c6:9008).
# Usage: scripts/edl.sh edl printgpt --memory=ufs --lun=0
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="ut-q706f-edl:1"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker build -t "$IMAGE" "$ROOT/scripts/docker-edl"
TTY=(); [ -t 0 ] && TTY=(-it)
exec docker run --rm "${TTY[@]}" --privileged -v /dev:/dev -v "$ROOT:/work" -w /work \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" "$IMAGE" "$@"
