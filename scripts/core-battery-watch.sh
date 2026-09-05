#!/usr/bin/env bash
# Vigila el nivel de batería y grita por voz (TTS) si baja de niveles críticos.
#
# Uso:
#   core-battery-watch.sh          # loop
#   core-battery-watch.sh stop
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
BAT_PATH="/sys/class/power_supply/BAT1"
PIDFILE="${CORE_HOME}/presence/battery-watch.pid"
EVENTS="${CORE_HOME}/presence/events.log"
STREAM="${CORE_HOME}/presence/stream.log"
INTERVAL="${CORE_BATTERY_INTERVAL:-30}"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      echo "stopped battery watch pid ${pid}"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay battery watch activo"
  fi
  exit 0
fi

if [[ ! -d "${BAT_PATH}" ]]; then
  echo "Sin batería detectada (BAT1 ausente). Saliendo."
  exit 0
fi

if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}" 2>/dev/null || true)"
  if [[ -n "${old}" ]] && kill -0 "${old}" 2>/dev/null; then
    echo "error: ya corre battery watch (pid ${old})." >&2
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

echo $$ > "${PIDFILE}"
cleanup() { rm -f "${PIDFILE}"; }
trap cleanup EXIT INT TERM

LAST_LEVEL_ALERT=100
LAST_CRIT_TIME=0

echo "$(date -Iseconds) battery watch start interval=${INTERVAL}s" >> "${EVENTS}"
echo "battery watch pid $$ (interval ${INTERVAL}s). stop: $0 stop" >&2

while true; do
  STATUS="$(cat "${BAT_PATH}/status" 2>/dev/null || echo "Unknown")"
  CAP="$(cat "${BAT_PATH}/capacity" 2>/dev/null || echo "100")"
  NOW_SEC=$(date +%s)

  if [[ "${STATUS}" == "Charging" || "${STATUS}" == "Full" ]]; then
    if (( LAST_LEVEL_ALERT <= 20 )); then
      echo "$(date -Iseconds) CHANGE bateria conectada a corriente (${CAP}%)" >> "${EVENTS}"
      echo "$(date -Iseconds) CHANGED: bateria cargando (${CAP}%)" >> "${STREAM}"
      "${CORE_HOME}/scripts/core-say.sh" --nowait "Casita conectada a la corriente, gracias Lalo." 2>/dev/null || true
    fi
    LAST_LEVEL_ALERT=100
  elif [[ "${STATUS}" != "Charging" && "${STATUS}" != "Full" ]]; then
    # Alerta 20%
    if (( CAP <= 20 && LAST_LEVEL_ALERT > 20 )); then
      LAST_LEVEL_ALERT=20
      echo "$(date -Iseconds) CHANGE bateria baja ${CAP}%" >> "${EVENTS}"
      echo "$(date -Iseconds) CHANGED: bateria baja ${CAP}%" >> "${STREAM}"
      "${CORE_HOME}/scripts/core-say.sh" "Aviso: la batería de la casita está al ${CAP} por ciento." 2>/dev/null || true
      if [[ -x "${CORE_HOME}/scripts/core-nudge.sh" ]]; then
        CORE_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/core-nudge.sh" --say "Batería casita al ${CAP}%" 2>/dev/null || true
      fi
    # Alerta 15%
    elif (( CAP <= 15 && LAST_LEVEL_ALERT > 15 )); then
      LAST_LEVEL_ALERT=15
      echo "$(date -Iseconds) CHANGE bateria alerta 15%" >> "${EVENTS}"
      echo "$(date -Iseconds) CHANGED: bateria 15%" >> "${STREAM}"
      "${CORE_HOME}/scripts/core-say.sh" "¡Lalo! La batería de la casita bajó al ${CAP} por ciento. Conéctame a la corriente." 2>/dev/null || true
      if [[ -x "${CORE_HOME}/scripts/core-nudge.sh" ]]; then
        CORE_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/core-nudge.sh" --say "¡Batería casita al ${CAP}%!" 2>/dev/null || true
      fi
    # Alerta crítica 10% o menos (repite cada 90s si sigue bajando)
    elif (( CAP <= 10 )); then
      if (( LAST_LEVEL_ALERT > 10 || NOW_SEC - LAST_CRIT_TIME >= 90 )); then
        LAST_LEVEL_ALERT=10
        LAST_CRIT_TIME=${NOW_SEC}
        echo "$(date -Iseconds) CHANGE bateria CRITICA ${CAP}%" >> "${EVENTS}"
        echo "$(date -Iseconds) CHANGED: bateria CRITICA ${CAP}%" >> "${STREAM}"
        "${CORE_HOME}/scripts/core-say.sh" --wait "¡Lalo, urgente! La batería está al ${CAP} por ciento, me voy a apagar en cualquier momento. ¡Enchúfame ya!" 2>/dev/null || true
        if [[ -x "${CORE_HOME}/scripts/core-nudge.sh" ]]; then
          CORE_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/core-nudge.sh" --say "¡¡BATERÍA CRÍTICA ${CAP}%!!" 2>/dev/null || true
        fi
      fi
    fi
  fi

  sleep "${INTERVAL}"
done
