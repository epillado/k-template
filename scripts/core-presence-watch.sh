#!/usr/bin/env bash
# Vigila bitácora y piezas del playbook PROPIO (solo lectura).
# Ante cambios: log + pending rico para que el Companion comente.
#
# Uso:
#   core-presence-watch.sh              # loop en foreground
#   core-presence-watch.sh once         # un solo escaneo
#   core-presence-watch.sh stop
#
# Env:
#   CORE_PLAYBOOK=…             override del path del playbook
#   CORE_PRESENCE_INTERVAL=45
#   CORE_PRESENCE_NUDGE=0|1     default 0 — el comentario personal lo manda el agente
#   CORE_PRESENCE_SOFT_PING=1   si 1 y NUDGE=0: beep suave sin popup genérico
#   CORE_PRESENCE_NUDGE_COOLDOWN=120
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"
# PLAYBOOK viene de lib-identity: propio, no el de otra persona.

STATE_DIR="${CORE_HOME}/presence"
STATE_FILE="${STATE_DIR}/fingerprints.tsv"
EVENTS_LOG="${STATE_DIR}/events.log"
PENDING_FILE="${STATE_DIR}/pending.md"
PIDFILE="${STATE_DIR}/watch.pid"
LAST_NUDGE_FILE="${STATE_DIR}/last_nudge.ts"

INTERVAL="${CORE_PRESENCE_INTERVAL:-45}"
NUDGE="${CORE_PRESENCE_NUDGE:-0}"
SOFT_PING="${CORE_PRESENCE_SOFT_PING:-0}"
COOLDOWN="${CORE_PRESENCE_NUDGE_COOLDOWN:-120}"

mkdir -p "${STATE_DIR}"
touch "${STATE_FILE}" "${EVENTS_LOG}"

if [[ "${1:-}" == "stop" ]]; then
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(cat "${PIDFILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
      # hijos del sleep loop
      echo "stopped presence watch pid ${pid}"
    else
      echo "pidfile huérfano; limpiando"
    fi
    rm -f "${PIDFILE}"
  else
    echo "no hay presence watch activo"
  fi
  exit 0
fi

# Paths a vigilar (solo lectura). Playbook de ESTA instancia.
# No incluir .git ni basura de IDE. Globs: solo si existen esas carpetas.
watch_paths() {
  local day yesterday f
  day="$(date +%Y%m%d)"
  yesterday="$(date -d 'yesterday' +%Y%m%d 2>/dev/null || true)"

  echo "${PLAYBOOK}/TODO.md"
  echo "${PLAYBOOK}/Sessions/control_plane_session_state.md"
  echo "${PLAYBOOK}/Sessions/standard_session_state.md"
  echo "${PLAYBOOK}/Bit/${day}-Bitacora.md"
  if [[ -n "${yesterday}" ]]; then
    echo "${PLAYBOOK}/Bit/${yesterday}-Bitacora.md"
  fi

  shopt -s nullglob
  for f in \
    "${PLAYBOOK}/Daily/${day}"-*.md \
    "${PLAYBOOK}/GOV-RTS-Control_Plane/Daily/${day}"-*.md \
    "${PLAYBOOK}/SECON/${day}"-*.md \
    "${PLAYBOOK}/SECON/${day}"*.md \
    "${PLAYBOOK}/PKM/${day}"-*.md \
    "${PLAYBOOK}/PKM/${day}"*.md
  do
    echo "$f"
  done
  shopt -u nullglob
}

fingerprint() {
  local f="$1"
  if [[ ! -e "$f" ]]; then
    echo "MISSING"
    return
  fi
  local st hash
  st="$(stat -c '%Y:%s' "$f" 2>/dev/null || echo '?')"
  hash="$(sha256sum "$f" 2>/dev/null | cut -c1-12 || echo nohash)"
  echo "${st}:${hash}"
}

label_for() {
  local f="$1"
  case "$f" in
    *TODO.md) echo "TODO" ;;
    *control_plane_session_state.md) echo "pizarra-CP" ;;
    *standard_session_state.md) echo "pizarra-std" ;;
    *Bitacora.md) echo "bitácora" ;;
    *reporte_daily-secon.md) echo "daily-secon" ;;
    *reporte_daily-redts.md) echo "daily-redts" ;;
    */SECON/*) echo "secon" ;;
    */PKM/*) echo "pkm" ;;
    *) basename "$f" ;;
  esac
}

snippet_file() {
  local f="$1"
  local n="${2:-12}"
  if [[ ! -f "$f" ]]; then
    echo "(archivo ausente)"
    return
  fi
  # últimas n líneas no vacías preferibles; fallback tail simple
  tail -n "${n}" "$f" 2>/dev/null | sed 's/\t/  /g'
}

# write_pending: SOLO snippea los paths que realmente cambiaron (no todos los
# que comparten etiqueta). Bug 2026-08-12: label "bitácora" metía ayer+hoy y
# el snippet de ayer dominaba; se leía el día anterior.
write_pending() {
  local -a paths=("$@")
  local -a labels=()
  local path label ts summary x u seen
  ts="$(date -Iseconds)"

  for path in "${paths[@]}"; do
    [[ -z "$path" ]] && continue
    label="$(label_for "$path")"
    seen=0
    for u in "${labels[@]+"${labels[@]}"}"; do
      [[ "$u" == "$label" ]] && seen=1 && break
    done
    (( seen == 0 )) && labels+=("$label")
  done
  summary="$(printf '%s, ' "${labels[@]+"${labels[@]}"}" | sed 's/, $//')"
  [[ -z "${summary}" ]] && summary="(sin etiqueta)"

  {
    echo "# Pending — atención del Companion"
    echo
    echo "- **cuando:** ${ts}"
    echo "- **qué se movió:** ${summary}"
    echo "- **paths:** $(printf '%s; ' "${paths[@]}" | sed 's/; $//')"
    echo "- **estado:** awaiting_comment"
    echo
    echo "El agente debe: leer esto + archivos (solo lectura), **comentar en el chat**,"
    echo "y mandar tray con \`core-nudge.sh --say \"...\"\` o \`--terminal\` si el comentario no cabe."
    echo
    echo "---"
    echo

    # Preferir bitácora del día (nombre lexicográfico mayor = fecha más reciente)
    # sin reintroducir paths que no cambiaron.
    local -a ordered=()
    local -a bits=() others=()
    for path in "${paths[@]}"; do
      [[ -z "$path" ]] && continue
      if [[ "$path" == *Bitacora.md ]]; then
        bits+=("$path")
      else
        others+=("$path")
      fi
    done
    # sort bitácoras: hoy antes que ayer (basename descendente)
    if ((${#bits[@]} > 0)); then
      while IFS= read -r path; do
        [[ -n "$path" ]] && ordered+=("$path")
      done < <(printf '%s\n' "${bits[@]}" | sort -r)
    fi
    ordered+=("${others[@]+"${others[@]}"}")

    for path in "${ordered[@]+"${ordered[@]}"}"; do
      [[ -z "$path" ]] && continue
      # solo snip si el archivo existe y tiene contenido
      label="$(label_for "$path")"
      echo "## ${label}"
      echo
      echo \`"${path}"\`
      echo
      if [[ ! -f "$path" ]]; then
        echo '```'
        echo "(archivo ausente — path vigilado pero aún no creado)"
        echo '```'
        echo
        continue
      fi
      if [[ ! -s "$path" ]]; then
        echo '```'
        echo "(archivo vacío — 0 bytes)"
        echo '```'
        echo
        continue
      fi
      echo '```'
      case "$label" in
        bitácora) snippet_file "$path" 18 ;;
        pizarra-CP|pizarra-std) snippet_file "$path" 20 ;;
        daily-secon|daily-redts) snippet_file "$path" 16 ;;
        secon|pkm) snippet_file "$path" 12 ;;
        TODO) snippet_file "$path" 8 ;;
        *) snippet_file "$path" 10 ;;
      esac
      echo '```'
      echo
    done
  } > "${PENDING_FILE}"

  # bandera simple para loops
  echo "${ts}" > "${STATE_DIR}/pending.ts"
  echo "${summary}" > "${STATE_DIR}/pending_labels.txt"
  # copia de inspección (CP/debug) — no es la cola activa
  cp -f "${PENDING_FILE}" "${STATE_DIR}/pending.last.md" 2>/dev/null || true
}

maybe_generic_nudge() {
  # Solo si NUDGE=1 (modo legacy). Por defecto preferimos comentario del agente.
  local summary="$1"
  [[ "${NUDGE}" == "1" ]] || return 0
  local now last
  now="$(date +%s)"
  last=0
  [[ -f "${LAST_NUDGE_FILE}" ]] && last="$(cat "${LAST_NUDGE_FILE}")"
  if (( now - last < COOLDOWN )); then
    return 0
  fi
  echo "${now}" > "${LAST_NUDGE_FILE}"
  "${CORE_HOME}/scripts/core-nudge.sh" "${COMPANION_NAME} · playbook" "${summary} — hay lectura en el chat."
}

maybe_soft_ping() {
  [[ "${SOFT_PING}" == "1" ]] || return 0
  [[ "${NUDGE}" == "1" ]] && return 0 # ya hubo notify completo
  local now last
  now="$(date +%s)"
  last=0
  [[ -f "${LAST_NUDGE_FILE}" ]] && last="$(cat "${LAST_NUDGE_FILE}")"
  if (( now - last < COOLDOWN )); then
    return 0
  fi
  echo "${now}" > "${LAST_NUDGE_FILE}"
  "${CORE_HOME}/scripts/core-nudge.sh" --soft --terminal \
    "Playbook en movimiento. Comentario en el chat."
}

scan_once() {
  local -a changed_labels=()
  local -a changed_paths=()
  local tmp path fp old label
  tmp="$(mktemp)"

  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    fp="$(fingerprint "$path")"
    old="$(awk -v p="$path" -F'\t' '$1==p {print $2; exit}' "${STATE_FILE}" 2>/dev/null || true)"
    printf '%s\t%s\n' "$path" "$fp" >> "${tmp}"
    if [[ -z "$old" ]]; then
      continue
    fi
    if [[ "$old" != "$fp" ]]; then
      label="$(label_for "$path")"
      changed_labels+=("$label")
      changed_paths+=("$path")
      echo "$(date -Iseconds) CHANGE ${label} ${path}" >> "${EVENTS_LOG}"
    fi
  done < <(watch_paths | sort -u)

  mv -f "${tmp}" "${STATE_FILE}"

  if ((${#changed_labels[@]} > 0)); then
    # únicos labels (solo para línea CHANGED legible)
    local -a uniq=()
    local x u seen
    for x in "${changed_labels[@]}"; do
      seen=0
      for u in "${uniq[@]+"${uniq[@]}"}"; do
        [[ "$u" == "$x" ]] && seen=1 && break
      done
      (( seen == 0 )) && uniq+=("$x")
    done
    # Snippet SOLO de paths que cambiaron (no todos los de la misma etiqueta)
    write_pending "${changed_paths[@]}"
    local summary
    summary="$(printf '%s, ' "${uniq[@]}" | sed 's/, $//')"
    # Línea para monitor/agente
    echo "CHANGED: ${summary}"
    maybe_generic_nudge "Movimiento en: ${summary}"
    maybe_soft_ping
    return 0
  fi
  echo "OK: sin cambios"
  return 0
}

if [[ "${1:-}" == "once" ]]; then
  scan_once
  exit 0
fi

if [[ -f "${PIDFILE}" ]]; then
  old="$(cat "${PIDFILE}")"
  if kill -0 "${old}" 2>/dev/null; then
    echo "error: ya corre presence watch (pid ${old}). stop primero." >&2
    exit 1
  fi
  rm -f "${PIDFILE}"
fi

echo $$ > "${PIDFILE}"
cleanup() { rm -f "${PIDFILE}"; }
trap cleanup EXIT INT TERM

NUDGE_SAVE="${NUDGE}"
SOFT_SAVE="${SOFT_PING}"
NUDGE=0
SOFT_PING=0
scan_once >/dev/null
NUDGE="${NUDGE_SAVE}"
SOFT_PING="${SOFT_SAVE}"

echo "$(date -Iseconds) presence watch start interval=${INTERVAL}s nudge=${NUDGE} soft_ping=${SOFT_PING}" >> "${EVENTS_LOG}"
# pid a stderr: el monitor solo debe despertar con líneas CHANGED:
echo "presence watch pid $$ (interval ${INTERVAL}s). stop: $0 stop" >&2

while true; do
  sleep "${INTERVAL}"
  out="$(scan_once)"
  if [[ "${out}" == CHANGED:* ]]; then
    echo "${out}"
  fi
done
