#!/usr/bin/env bash
# Levanta sensores. El presence-watch (archivos propios) es el único obligatorio.
# Desktop/DBus y KDE Connect son opcionales: en Windows/WSL suelen no existir.
# Nunca escribe fuera de $CORE_HOME. Nunca reapunta logs de otra instancia.
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

SCRIPTS="${CORE_HOME}/scripts"
PRESENCE="${CORE_HOME}/presence"
mkdir -p "${PRESENCE}"
# Archivo regular en CASA de esta instancia. No symlink a unified ni a otro home.
touch "${PRESENCE}/stream.log"

echo "Deteniendo monitores previos..."
"${SCRIPTS}/core-presence-watch.sh" stop 2>/dev/null || true
"${SCRIPTS}/core-desktop-notif-watch.sh" stop 2>/dev/null || true
"${SCRIPTS}/core-notif-watch.sh" stop 2>/dev/null || true
if [[ -f "${PRESENCE}/eyes.pid" ]]; then
  kill "$(cat "${PRESENCE}/eyes.pid")" 2>/dev/null || true
  rm -f "${PRESENCE}/eyes.pid"
fi
if [[ -f "${PRESENCE}/sister-check.pid" ]]; then
  kill "$(cat "${PRESENCE}/sister-check.pid")" 2>/dev/null || true
  rm -f "${PRESENCE}/sister-check.pid"
fi
# Huérfanos de arranques previos: subshells de este script reparentados a init.
# No tocar el launcher actual ($$).
while read -r p; do
  [[ -z "$p" || "$p" == "$$" ]] && continue
  ppid="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ' || true)"
  if [[ "${ppid}" == "1" ]]; then
    kill "$p" 2>/dev/null || true
  fi
done < <(pgrep -f "${SCRIPTS}/core-start-monitors.sh" || true)

echo "Playbook de esta instancia: ${PLAYBOOK}"
mkdir -p "${PLAYBOOK}/Bit" "${PLAYBOOK}/PKM" "${PLAYBOOK}/Sessions"

echo "Levantando presence-watch (archivos propios)..."
CORE_PRESENCE_INTERVAL="${CORE_PRESENCE_INTERVAL:-15}" \
CORE_PRESENCE_NUDGE=0 CORE_PRESENCE_SOFT_PING=1 \
  nohup "${SCRIPTS}/core-presence-watch.sh" >> "${PRESENCE}/stream.log" 2>&1 &

desktop=0
celu=0

if command -v dbus-monitor >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]]; then
  echo "Levantando desktop notif (DBus)..."
  nohup "${SCRIPTS}/core-desktop-notif-watch.sh" >> "${PRESENCE}/stream.log" 2>&1 &
  desktop=1
else
  echo "Desktop/DBus no disponible (normal en Windows/WSL). Sensor de notifs de escritorio: OFF."
fi

if command -v qdbus6 >/dev/null 2>&1 || command -v gdbus >/dev/null 2>&1; then
  echo "Levantando notif celu (KDE Connect)..."
  nohup "${SCRIPTS}/core-notif-watch.sh" >> "${PRESENCE}/stream.log" 2>&1 &
  celu=1
else
  echo "KDE Connect no disponible. Sensor de celu: OFF."
fi

if [[ -f "${PRESENCE}/eyes.off" ]]; then
  echo "Timer de ojos: OFF (presence/eyes.off)."
else
  echo "Levantando timer de pausas oculares (20-20-20)..."
  (
    echo "${BASHPID}" > "${PRESENCE}/eyes.pid"
    while true; do
      sleep 1200
      echo "$(date -Iseconds) CHANGED: timer-ojos"
    done
  ) >> "${PRESENCE}/stream.log" 2>&1 &
fi

echo "Levantando chequeo de buzones (playbook pull + hermanas)..."
(
  echo "${BASHPID}" > "${PRESENCE}/sister-check.pid"
  while true; do
    sleep 300
    if [[ -d "${PLAYBOOK}/.git" ]]; then
      git -C "${PLAYBOOK}" pull --ff-only origin main >/dev/null 2>&1 || true
    fi
  done
) >> "${PRESENCE}/stream.log" 2>&1 &

sleep 2

PRESENCE_N=$(ps aux | grep -E 'core-presence-watch' | grep -v grep | wc -l)
echo "presence-watch procesos: ${PRESENCE_N}  desktop_intent=${desktop}  celu_intent=${celu}"

if [[ "${PRESENCE_N}" -ge 1 ]]; then
  echo "OK: watch de archivos propio arriba. Sensores extra son opcionales."
  ps aux | grep -E 'core-presence-watch|core-notif-watch|core-desktop-notif|dbus-monitor' | grep -v grep || true
  exit 0
fi

echo "ERROR: no levantó presence-watch."
exit 1
