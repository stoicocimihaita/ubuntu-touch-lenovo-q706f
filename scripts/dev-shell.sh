#!/usr/bin/env bash
# Run a command (or an interactive shell) inside the build container.
# Usage: scripts/dev-shell.sh [command...]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="ut-q706f-build:22.04"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  docker build -t "$IMAGE" --build-arg UID="$(id -u)" --build-arg GID="$(id -g)" \
    "$ROOT/scripts/docker"
fi
TTY=(); [ -t 0 ] && TTY=(-it)
PRIV=(); [ -n "${DEV_SHELL_PRIVILEGED:-}" ] && PRIV=(--privileged)
exec docker run --rm "${TTY[@]}" "${PRIV[@]}" -v "$ROOT:/work" -w /work "$IMAGE" "${@:-bash}"
