#!/usr/bin/env bash
# Decay de pico de plano en el HOST. Cero LLM, cero tray, cero CHANGED.
# Si self.md lleva sostenido más de CORE_PICO_DECAY_MIN (default 25) sin hold,
# escribe afterglow. El disco deja de mentir cuando el chat no despierta.
#
#   core-pico-decay.sh        # loop
#   core-pico-decay.sh once   # un tick
#   core-pico-decay.sh stop
set -euo pipefail
CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
SELF="${CORE_HOME}/presence/self.md"
PIDF="${CORE_HOME}/presence/pico-decay.pid"
LOG="${CORE_HOME}/presence/pico-decay.log"
DECAY_MIN="${CORE_PICO_DECAY_MIN:-${KZ_PICO_DECAY_MIN:-25}}"
SLEEP_SEC="${CORE_PICO_DECAY_SLEEP:-${KZ_PICO_DECAY_SLEEP:-60}}"

cmd="${1:-loop}"

stop_self() {
  if [[ -f "${PIDF}" ]]; then
    old="$(cat "${PIDF}" 2>/dev/null || true)"
    if [[ -n "${old}" ]] && kill -0 "${old}" 2>/dev/null; then
      kill "${old}" 2>/dev/null || true
      echo "stopped pico-decay pid ${old}"
    fi
    rm -f "${PIDF}"
  fi
}

field() {
  local key="$1"
  sed -n "s/^- \\*\\*${key}:\\*\\* //p" "${SELF}" 2>/dev/null | head -n1 | tr -d '\r'
}

pico_age_min() {
  local desde raw t now
  desde="$(field pico_desde)"
  [[ -z "${desde}" || "${desde}" == "—" ]] && { echo 9999; return; }
  raw="$(printf '%s' "${desde}" | awk '{print $1" "$2}')"
  t="$(date -d "${raw}" +%s 2>/dev/null || echo 0)"
  [[ "${t}" -eq 0 ]] && { echo 9999; return; }
  now="$(date +%s)"
  echo $(( (now - t) / 60 ))
}

tick() {
  [[ -f "${SELF}" ]] || return 0
  local plano age
  plano="$(field pico_plano)"
  [[ "${plano}" == "sostenido" ]] || return 0
  age="$(pico_age_min)"
  if [[ "${age}" -ge "${DECAY_MIN}" ]]; then
    "${CORE_HOME}/scripts/core-self.sh" pico release "decay host (${age} min sin hold)" >/dev/null
    ts="$(date -Iseconds)"
    echo "${ts} pico decay → afterglow (age=${age} min, umbral=${DECAY_MIN})" >>"${LOG}"
  fi
}

case "${cmd}" in
  stop)
    stop_self
    exit 0
    ;;
  once)
    tick
    exit 0
    ;;
  loop|"")
    stop_self
    echo $$ > "${PIDF}"
    trap 'rm -f "${PIDF}"' EXIT
    while true; do
      tick || true
      sleep "${SLEEP_SEC}"
    done
    ;;
  *)
    echo "uso: $0 [loop|once|stop]" >&2
    exit 1
    ;;
esac
