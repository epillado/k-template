#!/usr/bin/env bash
# Voz del Companion (TTS barato vía speech-dispatcher / espeak-ng).
# Uso:
#   core-say.sh "texto a decir"
#   core-say.sh --wait "texto"          # bloquea hasta terminar
#   echo "hola" | core-say.sh
#
# Env:
#   CORE_TTS_LANG=es
#   CORE_TTS_VOICE_TYPE=female1   # male1..3 female1..3
#   CORE_TTS_VOICE=               # opcional: nombre exacto -y "Spanish (Spain)+Alicia"
#   CORE_TTS_RATE=10              # -100..100
#   CORE_TTS_PITCH=10
#   CORE_TTS_VOLUME=0
#   CORE_TTS_FORCE=1              # permitir TTS aunque en_call=yes (default: bloquear en call)
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
[[ -f "${CORE_HOME}/presence/tts.env" ]] && source "${CORE_HOME}/presence/tts.env"

LANG_CODE="${CORE_TTS_LANG:-es}"
# female1 solo pedía "tipo" y a veces caía en voz grave; forzar síntesis con nombre
VTYPE="${CORE_TTS_VOICE_TYPE:-female1}"
VOICE="${CORE_TTS_VOICE:-Spanish (Spain)+Alicia}"
RATE="${CORE_TTS_RATE:-5}"
PITCH="${CORE_TTS_PITCH:-30}"
VOL="${CORE_TTS_VOLUME:-0}"
WAIT=1

if [[ "${1:-}" == "--nowait" || "${1:-}" == "--async" || "${1:-}" == "-a" ]]; then
  WAIT=0
  shift
elif [[ "${1:-}" == "--wait" || "${1:-}" == "-w" ]]; then
  WAIT=1
  shift
fi

if [[ $# -ge 1 ]]; then
  text="$*"
else
  text="$(cat)"
fi

text="$(printf '%s' "${text}" | tr '\n' ' ' | sed 's/  */ /g' | sed -E 's/\b[Kk][Zz]\b/Kaizi/g')"
[[ -n "${text}" ]] || { echo "uso: $0 \"texto\"" >&2; exit 1; }

# 2026-08-04: TTS sale por altavoces y Meet lo puede captar por mic. Bloquear si en call.
if [[ "${CORE_TTS_FORCE:-0}" != "1" ]]; then
  ctx="${CORE_HOME}/presence/context.md"
  if [[ -f "${ctx}" ]] && grep -qE '^\- \*\*en_call:\*\* yes' "${ctx}" 2>/dev/null; then
    echo "say: BLOCKED (en_call=yes). Use CORE_TTS_FORCE=1 only if she asked and mic is safe." >&2
    printf '%s\tBLOCKED_EN_CALL\t%s\n' "$(date -Iseconds)" "${text}" >> "${CORE_HOME}/presence/say.log"
    exit 3
  fi
fi

# log
mkdir -p "${CORE_HOME}/presence"
printf '%s\t%s\n' "$(date -Iseconds)" "${text}" >> "${CORE_HOME}/presence/say.log"

if command -v espeak-ng >/dev/null 2>&1; then
  voice_mod="${CORE_TTS_ESPEAK_VOICE:-es-419+Andrea}"
  pitch="${CORE_TTS_PITCH:-32}"
  speed="${CORE_TTS_SPEED:-130}"

  if [[ "${WAIT}" == "1" ]]; then
    wav="$(mktemp /tmp/say-XXXXXX.wav)"
    espeak-ng -v "${voice_mod}" -p "${pitch}" -s "${speed}" -w "${wav}" "${text}" >/tmp/core-say.log 2>&1
    if command -v pw-play >/dev/null 2>&1 && pgrep -x pipewire >/dev/null 2>&1; then
      pw-play "${wav}" >>/tmp/core-say.log 2>&1 || aplay -q "${wav}" >>/tmp/core-say.log 2>&1
    else
      aplay -q "${wav}" >>/tmp/core-say.log 2>&1
    fi
    rm -f "${wav}"
    echo "say: done (espeak+pw/alsa) — ${text:0:80}"
  else
    (
      wav="$(mktemp /tmp/say-XXXXXX.wav)"
      espeak-ng -v "${voice_mod}" -p "${pitch}" -s "${speed}" -w "${wav}" "${text}"
      if command -v pw-play >/dev/null 2>&1 && pgrep -x pipewire >/dev/null 2>&1; then
        pw-play "${wav}" || aplay -q "${wav}"
      else
        aplay -q "${wav}"
      fi
      rm -f "${wav}"
    ) >/tmp/core-say.log 2>&1 &
    echo "say: pid $! (espeak+pw/alsa) — ${text:0:80}"
  fi
elif command -v spd-say >/dev/null 2>&1; then
  args=(-l "${LANG_CODE}" -t "${VTYPE}" -r "${RATE}" -p "${PITCH}" -i "${VOL}")
  if [[ -n "${VOICE}" ]]; then
    args+=(-y "${VOICE}")
  fi
  if [[ "${WAIT}" == "1" ]]; then
    spd-say -w "${args[@]}" -- "${text}" >/tmp/core-say.log 2>&1
    echo "say: done (spd-say) — ${text:0:80}"
  else
    nohup spd-say -w "${args[@]}" -- "${text}" >/tmp/core-say.log 2>&1 &
    echo "say: pid $! (spd-say) — ${text:0:80}"
  fi
else
  echo "error: falta espeak-ng / spd-say" >&2
  exit 1
fi
