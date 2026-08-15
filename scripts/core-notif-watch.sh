#!/usr/bin/env bash
# Vigila notificaciones del celular vía KDE Connect (solo lectura).
# Filtra por importancia; escribe pending + emite CHANGED: notif:…
#
# Uso:
#   core-notif-watch.sh              # loop
#   core-notif-watch.sh once
#   core-notif-watch.sh stop
#   core-notif-watch.sh list         # dump filtrable de activas (debug; cuidado privacidad)
#
# Env: ver presence/notif/filters.env
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
NOTIF_DIR="${CORE_HOME}/presence/notif"
FILTERS="${NOTIF_DIR}/filters.env"
STATE_FILE="${NOTIF_DIR}/seen.tsv"
EVENTS_LOG="${NOTIF_DIR}/events.log"
PENDING_FILE="${NOTIF_DIR}/pending.md"
PIDFILE="${NOTIF_DIR}/watch.pid"
PENDING_TS="${NOTIF_DIR}/pending.ts"
PENDING_LABELS="${NOTIF_DIR}/pending_labels.txt"

mkdir -p "${NOTIF_DIR}"
touch "${STATE_FILE}" "${EVENTS_LOG}"

# shellcheck source=/dev/null
[[ -f "${FILTERS}" ]] && source "${FILTERS}"

INTERVAL="${CORE_NOTIF_INTERVAL:-20}"
# 0 por defecto: el agente comenta primero y pica con contenido real (no "voltea" vacío)
SOFT_PING="${CORE_NOTIF_SOFT_PING:-0}"
APP_IMP="${CORE_NOTIF_APP_IMPORTANT:-Phone|Teléfono|Messages|Mensajes|SMS}"
KW_IMP="${CORE_NOTIF_KW_IMPORTANT:-Missed call|llamada|Incoming}"
APP_MAIL="${CORE_NOTIF_APP_MAIL:-Gmail|Email|Correo}"
KW_MAIL="${CORE_NOTIF_KW_MAIL:-Josué|Josue|SECON|Elizeth|factura|VPN}"
BLOCK="${CORE_NOTIF_BLOCK:-Mercado Pago|promoci|Facebook|Instagram}"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      echo "stopped notif watch pid ${pid}"
    else
      echo "pidfile huérfano; limpiando"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay notif watch activo"
  fi
  exit 0
fi

require_tools() {
  command -v qdbus6 >/dev/null 2>&1 || command -v gdbus >/dev/null 2>&1 || {
    echo "error: hace falta qdbus6 o gdbus" >&2
    exit 1
  }
}

primary_device() {
  # Prefer reachable phone
  local line id
  if command -v kdeconnect-cli >/dev/null 2>&1; then
    line="$(kdeconnect-cli --list-devices 2>/dev/null | rg -i 'phone|reno|pixel|galaxy|paired' | head -n 1 || true)"
    if [[ -z "${line}" ]]; then
      line="$(kdeconnect-cli --list-available 2>/dev/null | head -n 1 || true)"
    fi
    # format: "- Name: id (paired)"
    id="$(echo "${line}" | sed -n 's/.*: \([a-f0-9]\{16,\}\).*/\1/p' | head -n 1)"
    if [[ -n "${id}" ]]; then
      echo "${id}"
      return
    fi
  fi
  # fallback known path discovery
  gdbus call --session --dest org.kde.kdeconnect --object-path /modules/kdeconnect \
    --method org.kde.kdeconnect.daemon.devices true true 2>/dev/null \
    | tr -d "(),'" | tr ' ' '\n' | rg '^[a-f0-9]{20,}$' | head -n 1 || true
}

notif_base() {
  local dev="$1"
  echo "/modules/kdeconnect/devices/${dev}/notifications"
}

list_active_ids() {
  local dev="$1" base
  base="$(notif_base "${dev}")"
  if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.kdeconnect "${base}" org.kde.kdeconnect.device.notifications.activeNotifications 2>/dev/null \
      | tr ' ' '\n' | rg -v '^$' || true
  else
    gdbus call --session --dest org.kde.kdeconnect --object-path "${base}" \
      --method org.kde.kdeconnect.device.notifications.activeNotifications 2>/dev/null \
      | tr -d "(),[]'" | tr ' ' '\n' | rg -v '^$' || true
  fi
}

get_prop() {
  local path="$1" prop="$2"
  if command -v qdbus6 >/dev/null 2>&1; then
    qdbus6 org.kde.kdeconnect "${path}" "org.kde.kdeconnect.device.notifications.notification.${prop}" 2>/dev/null || echo ""
  else
    gdbus call --session --dest org.kde.kdeconnect --object-path "${path}" \
      --method org.freedesktop.DBus.Properties.Get \
      org.kde.kdeconnect.device.notifications.notification "${prop}" 2>/dev/null \
      | sed "s/.*<'\(.*\)'>/\1/;s/^variant//" | tr -d "\"'" | head -n 1 || echo ""
  fi
}

ci_match() {
  # $1=haystack $2=regex-alternation (ERE). Usar grep -E: rg del entorno a veces interpreta -E raro.
  local h="$1" r="$2"
  [[ -z "${r}" || -z "${h}" ]] && return 1
  printf '%s\n' "${h}" | grep -qiE -- "${r}" 2>/dev/null
}

is_blocked() {
  local blob="$1"
  ci_match "${blob}" "${BLOCK}"
}

classify() {
  # stdout: important|mail_work|skip
  local app="$1" title="$2" text="$3" ticker="$4"
  local blob="${app} | ${title} | ${text} | ${ticker}"

  if is_blocked "${blob}"; then
    echo "skip"
    return
  fi
  # Por defecto: no avisar Phone/SMS/llamadas perdidas (spam)
  if ci_match "${app}" 'Phone|Teléfono|Telephony|Messages|Mensajes|^SMS$|KDE Connect'; then
    echo "skip"
    return
  fi
  if ci_match "${blob}" 'Missed call|missed call|Sensitive notification'; then
    echo "skip"
    return
  fi
  if ci_match "${app}" "${APP_IMP}"; then
    echo "important"
    return
  fi
  if ci_match "${blob}" "${KW_IMP}"; then
    echo "important"
    return
  fi
  if ci_match "${app}" "${APP_MAIL}" && ci_match "${blob}" "${KW_MAIL}"; then
    echo "mail_work"
    return
  fi
  echo "skip"
}

fingerprint_row() {
  local id="$1" app="$2" title="$3" text="$4"
  # stable id from internal content when possible
  printf '%s\t%s\n' "${id}" "$(printf '%s|%s|%s' "${app}" "${title}" "${text}" | sha256sum | cut -c1-16)"
}

soft_ping() {
  [[ "${SOFT_PING}" == "1" ]] || return 0
  "${CORE_HOME}/scripts/core-nudge.sh" --terminal \
    "Notif importante del celu. Lectura en el chat." 2>/dev/null || true
}

# Tray con texto real (sensor). No chat_owed — análisis solo si gordo / el usuario pide / digest.
# Contrato 2026-08-10. CORE_NOTIF_SENSOR_TRAY=0 desactiva.
sensor_tray() {
  local app="$1" title="$2" text="$3"
  local body
  [[ "${CORE_NOTIF_SENSOR_TRAY:-1}" == "1" ]] || return 0
  body="$(printf '%s: %s — %s' "${app}" "${title}" "${text}" | tr '\n' ' ' | cut -c1-200)"
  [[ -n "${body// /}" ]] || return 0
  CORE_NUDGE_NO_CHAT_OWED=1 "${CORE_HOME}/scripts/core-nudge.sh" --say "${body}" 2>/dev/null || true
}

write_pending() {
  local kind="$1" app="$2" title="$3" text="$4" ticker="$5"
  local ts summary
  ts="$(date -Iseconds)"
  summary="${kind}: ${app} — ${title}"
  {
    echo "# Pending — notif"
    echo
    echo "- **cuando:** ${ts}"
    echo "- **clase:** ${kind}"
    echo "- **app:** ${app}"
    echo "- **título:** ${title}"
    echo "- **texto:** ${text}"
    echo "- **ticker:** ${ticker}"
    echo "- **estado:** awaiting_comment"
    echo
    echo "El agente: leer esto, **comentar en chat** (¿importante? ¿avisar/silenciar?),"
    echo "tray corto si cabe, y clear: \`rm -f ${PENDING_FILE} ${PENDING_TS}\` o \`core-notif-watch.sh clear\`."
  } > "${PENDING_FILE}"
  echo "${ts}" > "${PENDING_TS}"
  echo "${summary}" > "${PENDING_LABELS}"
}

cmd_clear() {
  rm -f "${PENDING_FILE}" "${PENDING_TS}" "${PENDING_LABELS}"
  echo "notif pending cleared"
}

if [[ "${1:-}" == "clear" ]]; then
  cmd_clear
  exit 0
fi

scan_once() {
  # CORE_NOTIF_BASELINE=1 → registrar estado sin pending/CHANGED (arranque)
  require_tools
  local dev base id path app title text ticker kind fp old hits baseline
  baseline="${CORE_NOTIF_BASELINE:-0}"
  dev="$(primary_device)"
  if [[ -z "${dev}" ]]; then
    echo "OK: sin dispositivo KDE Connect"
    return 0
  fi
  base="$(notif_base "${dev}")"
  hits=0
  local -a news=()

  local tmp
  tmp="$(mktemp)"
  : > "${tmp}"

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    path="${base}/${id}"
    app="$(get_prop "${path}" appName)"
    title="$(get_prop "${path}" title)"
    text="$(get_prop "${path}" text)"
    ticker="$(get_prop "${path}" ticker)"
    # una línea
    app="$(echo "${app}" | tr '\n' ' ')"
    title="$(echo "${title}" | tr '\n' ' ')"
    text="$(echo "${text}" | tr '\n' ' ')"
    ticker="$(echo "${ticker}" | tr '\n' ' ')"
    kind="$(classify "${app}" "${title}" "${text}" "${ticker}")"
    fp="$(printf '%s|%s|%s|%s' "${app}" "${title}" "${text}" "${ticker}" | sha256sum | cut -c1-16)"
    printf '%s\t%s\t%s\n' "${id}" "${fp}" "${kind}" >> "${tmp}"

    if [[ "${kind}" == "skip" ]]; then
      continue
    fi
    if awk -v f="${fp}" -F'\t' '$2==f {found=1; exit} END{exit !found}' "${STATE_FILE}" 2>/dev/null; then
      continue
    fi

    if [[ "${baseline}" == "1" ]]; then
      continue
    fi

    hits=$((hits + 1))
    echo "$(date -Iseconds) NOTIF ${kind} app=${app} title=${title}" >> "${EVENTS_LOG}"
    news+=("${kind}|${app}|${title}|${text}|${ticker}")
  done < <(list_active_ids "${dev}")

  if [[ -s "${tmp}" ]]; then
    cat "${STATE_FILE}" "${tmp}" 2>/dev/null | awk -F'\t' 'NF>=2 && !seen[$2]++' > "${STATE_FILE}.new" || true
    mv -f "${STATE_FILE}.new" "${STATE_FILE}"
  fi
  rm -f "${tmp}"

  if (( hits > 0 )); then
    local last rest n
    n=${#news[@]}
    last="${news[$((n - 1))]}"
    kind="${last%%|*}"
    rest="${last#*|}"
    app="${rest%%|*}"
    rest="${rest#*|}"
    title="${rest%%|*}"
    rest="${rest#*|}"
    text="${rest%%|*}"
    ticker="${rest#*|}"
    write_pending "${kind}" "${app}" "${title}" "${text}" "${ticker}"
    local summary
    summary="${kind}:${app}:${title}"
    summary="$(echo "${summary}" | tr '\n' ' ' | cut -c1-120)"
    echo "CHANGED: notif:${summary}"
    # Wake confiable para el monitor del agente
    printf '%s\tCHANGED: notif:%s\n' "$(date -Iseconds)" "${summary}" >> "${NOTIF_DIR}/changed.log"
    sensor_tray "${app}" "${title}" "${text}"
    soft_ping
    return 0
  fi
  echo "OK: sin notifs nuevas importantes"
  return 0
}

cmd_list() {
  require_tools
  local dev base id path app title text kind
  dev="$(primary_device)"
  echo "device=${dev}"
  base="$(notif_base "${dev}")"
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    path="${base}/${id}"
    app="$(get_prop "${path}" appName)"
    title="$(get_prop "${path}" title)"
    text="$(get_prop "${path}" text)"
    ticker="$(get_prop "${path}" ticker)"
    kind="$(classify "${app}" "${title}" "${text}" "${ticker}")"
    printf '[%s] %s | %s | %s\n' "${kind}" "${app}" "${title}" "${text}"
  done < <(list_active_ids "${dev}")
}

if [[ "${1:-}" == "list" ]]; then
  cmd_list
  exit 0
fi

if [[ "${1:-}" == "once" ]]; then
  scan_once
  exit 0
fi

# Exclusive lock — evita zombies si se arranca dos veces
LOCKFILE="${NOTIF_DIR}/watch.lock"
exec 9>"${LOCKFILE}"
if ! flock -n 9; then
  echo "error: ya corre notif watch (lock ${LOCKFILE}). stop primero." >&2
  exit 1
fi
if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    echo "error: ya corre notif watch (pid ${old}). stop primero." >&2
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

echo $$ > "${PIDFILE}"
cleanup() { rm -f "${PIDFILE}"; flock -u 9 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# baseline: marcar lo ya presente sin alertar (no spam al cablear)
CORE_NOTIF_BASELINE=1 scan_once >/dev/null || true

echo "$(date -Iseconds) notif watch start interval=${INTERVAL}s device=$(primary_device)" >> "${EVENTS_LOG}"
echo "notif watch pid $$ (interval ${INTERVAL}s). stop: $0 stop" >&2

while true; do
  sleep "${INTERVAL}"
  out="$(CORE_NOTIF_BASELINE=0 scan_once)" || true
  if [[ "${out}" == CHANGED:* ]]; then
    echo "${out}"
  fi
done
