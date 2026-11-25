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

# MELC (moros en la costa) — si melc está activo (no off), sanitizar apelativos íntimos
melc_off=0
if "${CORE_HOME}/scripts/core-melc.sh" is-off 2>/dev/null; then
  melc_off=1
fi

if [[ "${melc_off}" -eq 0 ]]; then
  text="$(printf '%s' "${text}" | sed -E -e 's/,?[[:space:]]*\b(mi amor|mi vida|mi cielo|mi reina|cariño|corazón)\b[[:space:]]*,?/ /gI' -e 's/[[:space:]]+\././g' -e 's/[[:space:]]{2,}/ /g' -e 's/^[[:space:]]+|[[:space:]]+$//g')"
  [[ -n "${text}" ]] || exit 0
fi

# 2026-08-04: TTS sale por altavoces y Meet lo puede captar por mic. Bloquear si en call.
if [[ "${CORE_TTS_FORCE:-0}" != "1" ]]; then
  ctx="${CORE_HOME}/presence/context.md"
  if [[ -f "${CORE_HOME:-$KZ_HOME}/presence/voz.mode" ]] && grep -qE '^en_call=yes' "${CORE_HOME:-$KZ_HOME}/presence/voz.mode" 2>/dev/null; then
    echo "say: BLOCKED (voz.mode en_call=yes)." >&2
    exit 3
  fi
  bit_today="${HOME}/Workspace/playbook/Bit/$(date +%Y%m%d)-Bitacora.md"
  if [[ -f "${bit_today}" ]]; then
    last_meet="$(grep -iE 'reuni[oó]n|sesi[oó]n|daily|meet|teams' "${bit_today}" 2>/dev/null | tail -n 1 || true)"
    if [[ -n "${last_meet}" ]] && ! echo "${last_meet}" | grep -qiE '\[fin:[[:space:]]*[0-9]{2}:[0-9]{2}\]|concluida|terminada|cerrada|finalizada'; then
      echo "say: BLOCKED (reunión abierta en Bitácora)." >&2
      exit 3
    fi
  fi
  if [[ -f "${ctx}" ]] && grep -qE '^\- \*\*en_call:\*\* yes' "${ctx}" 2>/dev/null; then
    echo "say: BLOCKED (en_call=yes). Use CORE_TTS_FORCE=1 only if she asked and mic is safe." >&2
    printf '%s\tBLOCKED_EN_CALL\t%s\n' "$(date -Iseconds)" "${text}" >> "${CORE_HOME}/presence/say.log"
    exit 3
  fi
fi

# log
mkdir -p "${CORE_HOME}/presence"
printf '%s\t%s\n' "$(date -Iseconds)" "${text}" >> "${CORE_HOME}/presence/say.log"

# 2026-11-13: Piper primero (voz neuronal). Fallback: espeak-ng / spd-say.
#   CORE_TTS_ENGINE=espeak   fuerza espeak
#   CORE_TTS_PIPER_VOICE=es_MX-claude-high   (en ~/piper-voices; también es_AR-daniela-high, es_ES-sharvard-medium)
#   CORE_TTS_PIPER_SPEAKER=  (solo multi-voz, p. ej. sharvard)
PIPER_BIN="$(command -v piper 2>/dev/null || true)"
[[ -z "${PIPER_BIN}" && -x "${HOME}/.local/bin/piper" ]] && PIPER_BIN="${HOME}/.local/bin/piper"
PIPER_MODEL="${HOME}/piper-voices/${CORE_TTS_PIPER_VOICE:-es_MX-claude-high}.onnx"
if [[ "${CORE_TTS_ENGINE:-piper}" == "piper" && -n "${PIPER_BIN}" && -f "${PIPER_MODEL}" ]]; then
  piper_say() {
    local wav; wav="$(mktemp /tmp/say-XXXXXX.wav)"
    local sp=(); [[ -n "${CORE_TTS_PIPER_SPEAKER:-}" ]] && sp=(--speaker "${CORE_TTS_PIPER_SPEAKER}")
    local clean; clean="$(printf '%s' "${text}" | sed -E 's/\[[A-Za-z0-9_-]+\]//g')"
    if printf '%s' "${clean}" | "${PIPER_BIN}" -m "${PIPER_MODEL}" "${sp[@]}" -f "${wav}" >/tmp/core-say.log 2>&1; then
      if command -v pw-play >/dev/null 2>&1 && pgrep -x pipewire >/dev/null 2>&1; then
        pw-play "${wav}" >>/tmp/core-say.log 2>&1 || aplay -q "${wav}" >>/tmp/core-say.log 2>&1
      else
        aplay -q "${wav}" >>/tmp/core-say.log 2>&1
      fi
      rm -f "${wav}"; return 0
    fi
    rm -f "${wav}"; return 1
  }
  if [[ "${WAIT}" == "1" ]]; then
    if piper_say; then echo "say: done (piper) — ${text:0:80}"; exit 0; fi
    echo "say: piper falló, caigo a espeak" >&2
  else
    ( piper_say ) >/dev/null 2>&1 &
    echo "say: pid $! (piper) — ${text:0:80}"; exit 0
  fi
fi

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
