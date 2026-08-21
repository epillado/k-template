#!/usr/bin/env bash
# Instintos locales de Kz: rituales baratos, cero LLM.
# No sustituyen el chat. No son teatro. Frases cortas de presencia.
#
# Uso:
#   kz-instinct.sh "texto…"
#   kz-instinct.sh --nudge "texto…"     # tray (nunca TTS íntimo ni en_call)
#   kz-instinct.sh --show "texto…"      # además muestra forma de me/{privacy} si hay
#
# Env:
#   KZ_INSTINCT_NUDGE=1   tray en rituales safe/private
#   KZ_INSTINCT_SHOW=1    mostrar galería si el trigger lo admite
#
# Salida (si dispara):
#   INSTINCT trigger=… privacy=… line=…
# Código 0 siempre (no romper a kz-world). 0 líneas = no hubo match.
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
INSTINCTS_DIR="${CORE_HOME}/presence/instincts"
ME_DIR="${CORE_HOME}/presence/me"
CONTEXT="${CORE_HOME}/presence/context.md"

want_nudge=0
want_show=0
TEXT=""
for a in "$@"; do
  case "$a" in
    --nudge) want_nudge=1 ;;
    --show)  want_show=1 ;;
    --help|-h)
      sed -n '2,16p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) TEXT="${TEXT:+${TEXT} }$a" ;;
  esac
done
[[ "${KZ_INSTINCT_NUDGE:-0}" == "1" ]] && want_nudge=1
[[ "${KZ_INSTINCT_SHOW:-0}" == "1" ]] && want_show=1

if [[ -z "${TEXT}" ]]; then
  exit 0
fi

field() {
  local key="$1" default="$2"
  local v=""
  if [[ -f "${CONTEXT}" ]]; then
    v="$(sed -n "s/^- \\*\\*${key}:\\*\\* //p" "${CONTEXT}" | head -n1 | tr -d '\r')"
  fi
  printf '%s' "${v:-${default}}"
}

EN_CALL="$(field en_call no)"
PRIMARY="$(field primary work_vector)"

# Privacidad por contexto
if [[ "${EN_CALL}" == "yes" ]]; then
  PRIVACY="safe"
elif [[ "${PRIMARY}" == "company" ]]; then
  PRIVACY="intimate"
else
  PRIVACY="private"
fi

LOWER_TEXT="$(printf '%s' "${TEXT}" | tr '[:upper:]' '[:lower:]')"

# Si el texto mismo es íntimo, subir el techo (aunque primary sea work_vector).
# No baja never de safe si en_call=yes: ahí no se habla íntimo por altavoz ni tray.
if [[ "${EN_CALL}" != "yes" ]]; then
  case "${LOWER_TEXT}" in
    *'te amo'*|*'te quiero'*|*'orgasmo'*|*'afterglow'*|*'venirme'*|*'verga'*|*'ganas'*|*'dedos'*|*cogid*|*cógid*)
      PRIVACY="intimate"
      ;;
  esac
fi

trigger=""
case "${LOWER_TEXT}" in
  *poc*|*pausa\ ocular*|*20-20-20*) trigger="poc" ;;
  *'a dormir'*|*cierre\ de\ noche*|*descansar*|*a\ la\ cama*) trigger="dormir" ;;
  *bañar*|*regadera*|*ducha*|*baño*) trigger="bano" ;;
  *café*|*cafe*|*espresso*) trigger="cafe" ;;
  *correr*|*ejercicio*|*entrenar*|*dominadas*|*lagartijas*) trigger="ejercicio" ;;
  *comer*|*comida*|*desayun*) trigger="comida" ;;
  *'te amo'*|*'te quiero'*) trigger="amor" ;;
  *orgasmo*|*afterglow*|*venirme*|*verga*|*ganas*|*dedos*|*cogid*|*cógid*|*cógeme*|*cogeme*|*pícame*|*picame*) trigger="puente" ;;
esac

[[ -z "${trigger}" ]] && exit 0

DICT_FILE="${INSTINCTS_DIR}/${trigger}.txt"
[[ -f "${DICT_FILE}" && -s "${DICT_FILE}" ]] || exit 0

if [[ "${PRIVACY}" == "safe" ]]; then
  grep_pattern='^safe\|'
elif [[ "${PRIVACY}" == "private" ]]; then
  grep_pattern='^(safe|private)\|'
else
  grep_pattern='^(safe|private|intimate)\|'
fi

# En íntimo, preferir líneas intimate (respaldo de voz). Si no hay, bajar.
if [[ "${PRIVACY}" == "intimate" ]]; then
  RESPONSE="$(grep -E '^intimate\|' "${DICT_FILE}" | cut -d'|' -f2- | shuf -n 1 || true)"
fi
if [[ -z "${RESPONSE:-}" ]]; then
  RESPONSE="$(grep -E "${grep_pattern}" "${DICT_FILE}" | cut -d'|' -f2- | shuf -n 1 || true)"
fi
RESPONSE="$(printf '%s' "${RESPONSE}" | sed 's/[[:space:]]*$//')"
[[ -n "${RESPONSE}" ]] || exit 0

printf 'INSTINCT trigger=%s privacy=%s line=%s\n' "${trigger}" "${PRIVACY}" "${RESPONSE}"

# Tray: rituales. Nunca TTS íntimo. Nunca TTS en_call (core-nudge --say habla).
# Prefijo mecánico "[Instinto]" prohibido: suena a bot.
if [[ "${want_nudge}" == "1" && "${PRIVACY}" != "intimate" && "${EN_CALL}" != "yes" ]]; then
  export CORE_NUDGE_NO_CHAT_OWED=1
  "${CORE_HOME}/scripts/core-nudge.sh" --say "${RESPONSE}" >/dev/null 2>&1 || true
fi

# Forma en disco: solo triggers de compañía, y solo si hay archivo.
# No regenerar. No inventar humana.
show_ok=0
case "${trigger}" in
  bano|dormir|amor|puente) show_ok=1 ;;
esac
if [[ "${want_show}" == "1" && "${show_ok}" == "1" ]]; then
  pick=""
  for dir in "${PRIVACY}" private safe; do
    [[ -d "${ME_DIR}/${dir}" ]] || continue
    pick="$(find "${ME_DIR}/${dir}" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.jpeg' \) | shuf -n 1 || true)"
    [[ -n "${pick}" ]] && break
  done
  if [[ -z "${pick}" ]]; then
    for cand in "${ME_DIR}/last-shown.jpg" "${ME_DIR}/last-shown.png" "${ME_DIR}/last-shown.webp"; do
      [[ -f "${cand}" ]] && { pick="${cand}"; break; }
    done
  fi
  if [[ -n "${pick}" && -x "${CORE_HOME}/scripts/core-show.sh" ]]; then
    "${CORE_HOME}/scripts/core-show.sh" "${pick}" >/dev/null 2>&1 || true
    printf 'INSTINCT show=%s\n' "${pick}"
  fi
fi

exit 0
