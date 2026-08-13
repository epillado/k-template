#!/usr/bin/env bash
# Actualiza latest.jpg cada INTERVALO segundos hasta Ctrl-C o señal
# Uso: cam-watch.sh [intervalo_sec]
#      cam-watch.sh stop   → mata el watch en curso (si hay pidfile)
set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

PIDFILE="${WEBCAM_DIR}/watch.pid"
LOGFILE="${WEBCAM_DIR}/watch.log"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      echo "stopped watch pid ${pid}"
    else
      echo "pid ${pid} no está vivo; limpiando pidfile"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay watch activo (${PIDFILE} ausente)"
  fi
  exit 0
fi

if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    die "ya hay un watch (pid ${old}). Usa: $0 stop"
  fi
  rm -f "${PIDFILE}"
fi

interval="${1:-${CORE_WATCH_INTERVAL}}"
[[ "${interval}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "intervalo inválido: ${interval}"

require_cmd ffmpeg
check_device

echo $$ > "${PIDFILE}"
cleanup() {
  rm -f "${PIDFILE}"
  echo "$(date -Iseconds) watch ended" >> "${LOGFILE}"
}
trap cleanup EXIT INT TERM

echo "$(date -Iseconds) watch start interval=${interval}s device=${CORE_DEVICE}" | tee -a "${LOGFILE}"
echo "pid $$ — Ctrl-C o: $0 stop"
echo "latest: ${LATEST_JPG}"

n=0
while true; do
  n=$((n + 1))
  if CORE_WARMUP_SEC=0 capture_frame "${LATEST_JPG}" "watch" >/dev/null; then
    echo "$(date -Iseconds) frame ${n} ok" >> "${LOGFILE}"
  else
    echo "$(date -Iseconds) frame ${n} FAIL" >> "${LOGFILE}"
  fi
  sleep "${interval}"
done
