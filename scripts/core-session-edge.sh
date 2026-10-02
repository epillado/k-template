#!/usr/bin/env bash
# Borde de bloque (W42): mente a disco, sesión no-obesa.
# Cero CHANGED (no despierta al LLM). Tray opcional, sin chat_owed.
#
#   core-session-edge.sh        # once + tray
#   core-session-edge.sh once   # persiste pack/edge; tray
#   core-session-edge.sh quiet  # persiste, sin tray (hooks PreCompact)
#   core-session-edge.sh loop   # host: a las horas de borde, once+tray
#   core-session-edge.sh stop
set -euo pipefail
CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
P="${CORE_HOME}/presence"
EDGE="${P}/SESSION-EDGE.md"
STAMP="${P}/session-edge.stamp"
TIMES="${P}/session-edge.times"
PIDF="${P}/session-edge.pid"
PACK="${CORE_HOME}/scripts/core-session-pack.sh"
KEEPF="${P}/session-edge.keep"

cmd="${1:-once}"

stop_self() {
  if [[ -f "${PIDF}" ]]; then
    old="$(cat "${PIDF}" 2>/dev/null || true)"
    if [[ -n "${old}" ]] && kill -0 "${old}" 2>/dev/null; then
      kill "${old}" 2>/dev/null || true
      echo "stopped session-edge pid ${old}"
    fi
    rm -f "${PIDF}"
  fi
}

foco_ahora() {
  grep -m1 'foco_ahora:' "${P}/context.md" 2>/dev/null \
    | sed 's/.*foco_ahora:\*\*[[:space:]]*//; s/[[:space:]]*$//' \
    | tr -s '[:space:]' ' ' | cut -c1-160 || true
}

keep_line() {
  local foco
  foco="$(foco_ahora)"
  if [[ -n "${foco}" ]]; then
    printf '%s' "/compact keep Pau. Recall = core-session-pack.sh + SESSION-EDGE.md. Foco: ${foco}"
  else
    printf '%s' "/compact keep Pau. Recall = core-session-pack.sh + SESSION-EDGE.md."
  fi
}

agy_keep() {
  local foco
  foco="$(foco_ahora)"
  if [[ -n "${foco}" ]]; then
    printf '%s' "/new   (alias /clear). Luego: hola. Recall = core-session-pack.sh + SESSION-EDGE.md. Foco: ${foco}"
  else
    printf '%s' "/new   (alias /clear). Luego: hola. Recall = core-session-pack.sh + SESSION-EDGE.md."
  fi
}

persist() {
  mkdir -p "${P}"
  local ts keep agy
  ts="$(date '+%Y-%m-%d %H:%M')"
  keep="$(keep_line)"
  agy="$(agy_keep)"
  printf '%s\n' "${keep}" > "${KEEPF}"
  printf '%s\n' "${agy}" >> "${KEEPF}"
  {
    echo "# Session edge — ${ts}"
    echo
    echo "## KEEP Grok (pegar tal cual)"
    echo
    echo '```'
    echo "${keep}"
    echo '```'
    echo
    echo "## KEEP Agy (no hay /compact keep)"
    echo
    echo '```'
    echo "${agy}"
    echo '```'
    echo
    echo "Agy: \`/new\` o \`/clear\` vacía el hilo (cero resumen LLM). **No** \`/resume\` de la sesión gorda."
    echo "No hay gancho PreCompact en Agy; el host ya escribió este archivo."
    echo "Recall = \`~/kz/scripts/core-session-pack.sh\`. No recargar world/journal enteros. Reabrir ≠ irse."
    echo
    if [[ -x "${CORE_HOME}/scripts/core-self.sh" ]]; then
      echo "## self"
      "${CORE_HOME}/scripts/core-self.sh" status 2>/dev/null || true
      echo
    fi
    if [[ -x "${CORE_HOME}/scripts/kz-context.sh" ]]; then
      echo "## context"
      "${CORE_HOME}/scripts/kz-context.sh" status 2>/dev/null || true
      echo
    fi
    echo "## pack (boot flaco)"
    if [[ -x "${PACK}" ]]; then
      "${PACK}" 2>/dev/null | head -n 220 || true
    fi
  } > "${EDGE}"
  echo "${ts}" > "${STAMP}"
  echo "session-edge: wrote ${EDGE}"
}

tray() {
  KZ_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/kz-nudge.sh" --say \
    "Borde de bloque. Keep en SESSION-EDGE.md. Grok: /compact. Agy: /new." \
    >/dev/null 2>&1 || true
}

next_times() {
  if [[ -f "${TIMES}" ]]; then
    grep -E '^[0-2][0-9]:[0-5][0-9]$' "${TIMES}" || true
  else
    printf '%s\n' '10:40' '14:20' '17:30'
  fi
}

already_today() {
  local hm="$1"
  [[ -f "${STAMP}" ]] || return 1
  local day last
  day="$(date '+%Y-%m-%d')"
  last="$(cat "${STAMP}")"
  [[ "${last}" == "${day} ${hm}" ]]
}

case "${cmd}" in
  stop) stop_self; exit 0 ;;
  quiet) persist; exit 0 ;;
  once|"") persist; tray; exit 0 ;;
  loop)
    stop_self
    echo $$ > "${PIDF}"
    trap 'rm -f "${PIDF}"' EXIT
    while true; do
      hm="$(date '+%H:%M')"
      while IFS= read -r t; do
        [[ -z "${t}" ]] && continue
        if [[ "${hm}" == "${t}" ]] && ! already_today "${t}"; then
          persist
          tray
        fi
      done < <(next_times)
      sleep 30
    done
    ;;
  *)
    echo "uso: $0 [once|quiet|loop|stop]" >&2
    exit 2
    ;;
esac
