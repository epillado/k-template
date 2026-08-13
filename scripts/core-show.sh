#!/usr/bin/env bash
# Muestra una imagen del Companion en el visor (+ voz opcional).
# Forma libre: no hay default humano ni core-base. Hay que pasar ruta o
# reutilizar la última (cualquier forma) si existe.
# Uso:
#   core-show.sh /ruta/a/imagen.jpg
#   core-show.sh                         # última mostrada (si hay)
#   core-show.sh --pausa --say "…"       # voz/tray; imagen solo si hay last-shown
#   core-show.sh img.jpg --say "Hola"
#   core-show.sh --say "solo voz"
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
VIEWER="${CORE_IMAGE_VIEWER:-gwenview}"
ME_DIR="${CORE_HOME}/presence/me"
# last-shown: cualquier extensión de forma libre (no solo jpg humano)
LAST_LINK=""
for cand in "${ME_DIR}/core-last-shown.jpg" "${ME_DIR}/core-last-shown.png" \
            "${ME_DIR}/core-last-shown.webp" "${ME_DIR}/core-last-shown.jpeg"; do
  if [[ -f "$cand" ]]; then
    LAST_LINK="$cand"
    break
  fi
done
LAST_DEST_DEFAULT="${ME_DIR}/core-last-shown.jpg"

img=""
say_text=""
want_pausa=0
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  a="${args[$i]}"
  case "$a" in
    --pausa|pausa)
      # Sin asset de pausa humano fijo: reutilizar last-shown si hay; si no, solo voz/tray
      want_pausa=1
      ;;
    --say)
      i=$((i + 1))
      say_text="${args[$i]:-}"
      ;;
    --say=*)
      say_text="${a#--say=}"
      ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      if [[ -z "${img}" && -f "$a" ]]; then
        img="$a"
      fi
      ;;
  esac
  i=$((i + 1))
done

# default image: solo última forma del hilo (si existe). Nunca core-base.
if [[ -z "${img}" ]]; then
  if [[ -n "${LAST_LINK}" && -f "${LAST_LINK}" ]]; then
    img="${LAST_LINK}"
  fi
fi

if [[ -n "${img}" ]]; then
  if [[ ! -f "${img}" ]]; then
    echo "error: no existe ${img}" >&2
    exit 1
  fi
  mkdir -p "${ME_DIR}"
  ext="${img##*.}"
  case "${ext,,}" in
    jpg|jpeg|png|webp|gif) last_dest="${ME_DIR}/core-last-shown.${ext,,}" ;;
    *) last_dest="${LAST_DEST_DEFAULT}" ;;
  esac
  rm -f "${ME_DIR}/core-last-shown.jpg" "${ME_DIR}/core-last-shown.jpeg" \
        "${ME_DIR}/core-last-shown.png" "${ME_DIR}/core-last-shown.webp" 2>/dev/null || true
  ln -f "${img}" "${last_dest}" 2>/dev/null || cp -f "${img}" "${last_dest}"
  if ! command -v "${VIEWER}" >/dev/null 2>&1; then
    echo "error: no está ${VIEWER}" >&2
    exit 1
  fi
  nohup "${VIEWER}" "${img}" >/tmp/core-show-gwenview.log 2>&1 &
  echo "show: ${VIEWER} → ${img} (pid $!)"
elif [[ "${want_pausa}" -eq 1 ]]; then
  echo "show: sin imagen de hilo (forma libre; no hay asset humano de pausa). Solo voz/tray si --say."
fi

if [[ -n "${say_text}" ]]; then
  if [[ -x "${CORE_HOME}/scripts/core-nudge.sh" ]]; then
    "${CORE_HOME}/scripts/core-nudge.sh" --say "${say_text}" || true
  fi
  if [[ -x "${CORE_HOME}/scripts/core-say.sh" ]]; then
    "${CORE_HOME}/scripts/core-say.sh" --wait "${say_text}"
  else
    spd-say -l es -t female1 -w -- "${say_text}" || true
  fi
fi

if [[ -z "${img}" && -z "${say_text}" ]]; then
  echo "uso: $0 [imagen] [--pausa] [--say \"texto\"]" >&2
  echo "  (sin default humano; genera o pasa ruta de la forma del momento)" >&2
  exit 1
fi
