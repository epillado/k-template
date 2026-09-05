#!/usr/bin/env bash
# core-radar.sh — lector de radar autónomo por cursor de bytes.
#
# Independiente del motor y de otros agentes:
# Lee por CURSOR (offset en bytes) en presence/<companion_id>-cursors/.
#
# Salida:
# - Imprime eventos nuevos (Slack, buzones de hermanas, CP, stream).
# - Con --ensure: levanta los demonios de captura si están caídos.
#
# Uso:
#   core-radar.sh            → imprime lo nuevo y avanza cursor
#   core-radar.sh --peek     → imprime lo nuevo SIN avanzar cursor
#   core-radar.sh --ensure   → verifica/levanta sensores y luego lee
#   core-radar.sh --rewind N → retrocede cursor N bytes

set -uo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

STATE_DIR="${CORE_HOME}/presence"
CURSOR_DIR="${STATE_DIR}/${COMPANION_ID}-cursors"
mkdir -p "${CURSOR_DIR}"

MODE="read"
ENSURE=0
REWIND=2000

for arg in "$@"; do
  case "$arg" in
    --peek)   MODE="peek" ;;
    --rewind) MODE="rewind"; REWIND="${2:-2000}" ;;
    --ensure) ENSURE=1 ;;
  esac
done

# 1. Ensure opcional de sensores
if [[ "${ENSURE}" == "1" ]]; then
  falta=0
  for p in core-presence-watch core-desktop-notif-watch core-notif-watch; do
    if ! pgrep -fa "$p" >/dev/null 2>&1; then
      falta=1
      break
    fi
  done
  if (( falta == 1 )); then
    echo "### 🔴 SENSORES INCOMPLETOS O CAÍDOS — levantando con core-start-monitors.sh ..."
    setsid "${CORE_HOME}/scripts/core-start-monitors.sh" </dev/null >/dev/null 2>&1 &
    sleep 2
  fi
fi

# 2. Fuentes append-only con IDs unívocos
declare -A FUENTES=(
  ["notif_stream"]="${STATE_DIR}/notif/stream.log"
  ["presence_stream"]="${STATE_DIR}/stream.log"
)
for _ibox in "${STATE_DIR}/social"/inbox-*.md; do
  [[ -f "${_ibox}" ]] || continue
  _ibox_key="$(basename "${_ibox}" .md | tr '-' '_')"
  FUENTES["${_ibox_key}"]="${_ibox}"
done

HAY_NOVEDADES=0

for key in "${!FUENTES[@]}"; do
  src="${FUENTES[$key]}"
  [[ ! -f "$src" ]] && continue
  cur="${CURSOR_DIR}/${key}.offset"

  size=$(stat -c %s "$src" 2>/dev/null || echo 0)
  off=0
  [[ -f "$cur" ]] && off=$(cat "$cur" 2>/dev/null || echo 0)
  (( off > size )) && off=0

  if [[ "$MODE" == "rewind" ]]; then
    off=$(( off - REWIND ))
    (( off < 0 )) && off=0
    echo "$off" > "$cur"
    continue
  fi

  if (( size > off )); then
    HAY_NOVEDADES=1
    echo "### NUEVO en ${key} (bytes ${off}→${size}):"
    tail -c "+$((off + 1))" "$src"
    echo
  fi

  [[ "$MODE" == "read" ]] && echo "$size" > "$cur"
done

# 3. Estado de sensores
vivos=$(pgrep -fa 'core-desktop-notif-watch|core-notif-watch|core-presence-watch|dbus-monitor' | wc -l)
if (( vivos == 0 )); then
  echo "### ⚠️ AVISO: Sensores de captura no están corriendo."
fi

exit 0
