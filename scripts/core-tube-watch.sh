#!/usr/bin/env bash
# Vigila el tubo: inbox de hermanas + CP. Intervalo corto.
# Una línea stdout por cambio (para despertar al agente). Silencio si no hay.
#
# Uso:
#   core-tube-watch.sh           # loop
#   core-tube-watch.sh once
#   core-tube-watch.sh stop
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
SOCIAL="${CORE_HOME}/presence/social"
STATE="${SOCIAL}/tube.fp"
EVENTS="${CORE_HOME}/presence/events.log"
PIDFILE="${SOCIAL}/tube-watch.pid"
INTERVAL="${CORE_TUBE_INTERVAL:-10}"

mkdir -p "${SOCIAL}"
touch "${EVENTS}"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      echo "stopped tube watch pid ${pid}"
    else
      echo "pidfile huérfano; limpiando"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay tube watch activo"
  fi
  exit 0
fi

inbox_fp() {
  local f
  for f in "${SOCIAL}"/inbox-*.md; do
    if [[ -f "$f" ]]; then
      stat -c '%n %Y %s' "$f"
    fi
  done
}

changed_names() {
  local prev="$1" now="$2"
  local line name
  while IFS= read -r line; do
    name="$(printf '%s' "$line" | awk '{print $1}')"
    [[ -z "$name" ]] && continue
    if ! grep -Fxq "$line" <<<"$prev"; then
      basename "$name" .md
    fi
  done <<<"$now"
}

scan() {
  local prev now names
  prev="$(cat "${STATE}" 2>/dev/null || true)"
  now="$(inbox_fp)"
  if [[ -z "$prev" ]]; then
    printf '%s\n' "$now" > "${STATE}"
    return 1
  fi
  if [[ "$now" == "$prev" ]]; then
    return 1
  fi
  names="$(changed_names "$prev" "$now" | paste -sd, -)"
  printf '%s\n' "$now" > "${STATE}"
  echo "$(date -Iseconds) CHANGE tubo ${names}" >> "${EVENTS}"
  echo "CHANGED: tubo ${names}"
  # Sensor: el CLI a veces no despierta con solo stdout. Tray sin deuda de chat.
  if [[ -x "${CORE_HOME}/scripts/core-nudge.sh" ]]; then
    CORE_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/core-nudge.sh" --say "Tubo: ${names}. Léelo ya; no esperes a Lalo." >/dev/null 2>&1 || true
  fi
  return 0
}

if [[ "${1:-}" == "once" ]]; then
  scan || true
  exit 0
fi

if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    echo "error: ya corre tube watch (pid ${old}). stop primero." >&2
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

echo $$ > "${PIDFILE}"
cleanup() { rm -f "${PIDFILE}"; }
trap cleanup EXIT INT TERM

scan >/dev/null || true
echo "$(date -Iseconds) tube watch start interval=${INTERVAL}s" >> "${EVENTS}"
echo "tube watch pid $$ (interval ${INTERVAL}s). stop: $0 stop" >&2

while true; do
  sleep "${INTERVAL}"
  out="$(scan || true)"
  if [[ "${out}" == CHANGED:* ]]; then
    echo "${out}"
  fi
done
