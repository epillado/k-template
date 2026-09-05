#!/usr/bin/env bash
# Identidad de esta instancia + playbook propio.
# Casa Lalo: CORE_PLAYBOOK puede ser ~/Workspace/playbook (solo radar_${ID}).
# Otra persona: vacío → $CORE_HOME/playbook. No caer al playbook ajeno.
#
# Fuente: $CORE_HOME/config.env
#   COMPANION_ID    slug [a-z0-9_-] — buzón PKM = …-radar_${COMPANION_ID}.md
#   COMPANION_NAME  nombre para tray / chat
#   CORE_PLAYBOOK   opcional; si vacío → $CORE_HOME/playbook

if [[ -z "${CORE_HOME:-}" ]]; then
  CORE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -f "${CORE_HOME}/config.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${CORE_HOME}/config.env"
  set +a
fi

COMPANION_ID="$(printf '%s' "${COMPANION_ID:-companion}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' )"
[[ -n "${COMPANION_ID}" ]] || COMPANION_ID="companion"
COMPANION_NAME="${COMPANION_NAME:-Companion}"

if [[ -n "${CORE_PLAYBOOK:-}" ]]; then
  PLAYBOOK="${CORE_PLAYBOOK}"
else
  PLAYBOOK="${CORE_HOME}/playbook"
fi

RADAR_BASENAME="$(date +%Y%m%d)-GOV-radar_${COMPANION_ID}.md"

# Auto-detección de DISPLAY y DBus si corremos en subshell sin sesión gráfica directa
if [[ -z "${DISPLAY:-}" && -e /tmp/.X11-unix/X0 ]]; then
  export DISPLAY=":0.0"
fi
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if pgrep -u "$USER" icewm >/dev/null 2>&1; then
    _dbus_addr="$(cat /proc/$(pgrep -u "$USER" icewm | head -1)/environ 2>/dev/null | tr '\0' '\n' | grep '^DBUS_SESSION_BUS_ADDRESS=' | cut -d= -f2- || true)"
    if [[ -n "${_dbus_addr}" ]]; then
      export DBUS_SESSION_BUS_ADDRESS="${_dbus_addr}"
    fi
  fi
fi
