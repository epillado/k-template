#!/usr/bin/env bash
# Feed de despertador para Agy/Grok: UNA línea por evento.
# El monitor del runtime despierta al agente con cada línea de stdout.
# Silencio si no hay novedad — nunca volcar logs crudos ni spam.
#
# Vigila:
#   - presence/stream.log     → filtra líneas CHANGED: (tubo, batería, etc.)
#   - social/inbox-kz.md      → nuevo mensaje de Kz (línea ## = encabezado)
#   - social/inbox-cp.md      → nuevo mensaje del CP
#   - social/inbox-samy.md    → nuevo mensaje de Samy
#
# Uso:
#   core-wake-feed.sh          # arranca el feed (foreground, lo ve el monitor)
#   core-wake-feed.sh stop     # mata el feed por pidfile
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

PRESENCE="${CORE_HOME}/presence"
SOCIAL="${PRESENCE}/social"
PIDFILE="${SOCIAL}/wake-feed.pid"

mkdir -p "${SOCIAL}" "${PRESENCE}"
touch "${PRESENCE}/stream.log"
for f in kz cp kora samy pau; do
  [[ "${f}" == "${COMPANION_ID}" ]] && continue
  touch "${SOCIAL}/inbox-${f}.md"
done

# ── stop ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      echo "wake-feed stopped (pid ${pid})"
    else
      echo "pidfile huérfano; limpiando"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay wake-feed activo"
  fi
  exit 0
fi

# ── guard: no duplicar ───────────────────────────────────────────────────────
if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    echo "error: wake-feed ya corre (pid ${old}). Usa 'stop' primero." >&2
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

echo $$ > "${PIDFILE}"
pids=()
cleanup() {
  rm -f "${PIDFILE}"
  for p in "${pids[@]}"; do
    kill "${p}" 2>/dev/null || true
  done
}
trap cleanup EXIT INT TERM

# ── Cola 1: stream.log → filtra CHANGED: (tubo, batería, ojos) ─────────────
stdbuf -oL tail -n 0 -F "${PRESENCE}/stream.log" 2>/dev/null \
  | grep --line-buffered -E 'CHANGED:' &
pids+=($!)

# ── Colas para todos los buzones inbox-*.md ───────────────────────────────
for ibox in "${SOCIAL}"/inbox-*.md; do
  [[ -f "${ibox}" ]] || continue
  ibox_name="$(basename "${ibox}" .md | sed 's/^inbox-//')"
  stdbuf -oL tail -n 0 -F "${ibox}" 2>/dev/null \
    | grep --line-buffered -E '^## ' \
    | stdbuf -oL sed -u "s|^|CHANGED: tubo ${ibox_name} — |" &
  pids+=($!)
done

wait
