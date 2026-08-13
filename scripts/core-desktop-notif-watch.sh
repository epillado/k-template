#!/usr/bin/env bash
# Wrapper del watcher de notificaciones de escritorio (Slack, etc.)
set -euo pipefail
CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
export CORE_HOME
if [[ "${1:-}" == "stop" ]]; then
  exec python3 "${CORE_HOME}/scripts/core-desktop-notif-watch.py" stop
fi

# Iniciar desacoplado de la TTY con setsid si no viene con stop
exec setsid python3 -u "${CORE_HOME}/scripts/core-desktop-notif-watch.py" "$@" &
