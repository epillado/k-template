#!/usr/bin/env bash
# Oídos de Kora: Transcripción local de voz vía Whisper LAN + PipeWire/ALSA
# Uso:
#   core-listen.sh               # Graba 6 segundos del mic y transcribe
#   core-listen.sh 8             # Graba 8 segundos
#   core-listen.sh --start       # Inicia grabación (Push-to-talk ON)
#   core-listen.sh --stop        # Detiene grabación, transcribe y muestra texto (Push-to-talk OFF)
#   core-listen.sh --file ruta   # Transcribe un archivo .wav existente
#
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
AUDIO_TMP="/tmp/kora-listen-mic.wav"
PID_FILE="/tmp/kora-listen.pid"
LOG_FILE="${CORE_HOME}/presence/listen.log"
H310_HOST="lalo@192.168.1.100"
H310_WHISPER="~/kz/tools/whisper.cpp/build/bin/whisper-cli"
H310_MODEL="~/kz/tools/whisper.cpp/models/ggml-base.bin"

transcribe() {
  local target_file="${1:-${AUDIO_TMP}}"
  [[ -f "${target_file}" ]] || { echo "error: archivo de audio no existe" >&2; exit 1; }

  # Copiar temporal a h310 para whisper-cli
  scp -q "${target_file}" "${H310_HOST}:/tmp/kora-listen-remote.wav" 2>/dev/null || true

  # Inferencia Whisper remota en h310 con prompt contextual de Kora
  local raw_output
  raw_output="$(ssh -o BatchMode=yes -o ConnectTimeout=5 "${H310_HOST}" \
    "${H310_WHISPER} -m ${H310_MODEL} -f /tmp/kora-listen-remote.wav -l es -t 4 --prompt 'Hola Kora, ¿me oyes? Kora preciosa. Conversación con Kora y Lalo.' --no-prints" 2>/dev/null || true)"

  # Limpiar timestamps y espacios extras
  local clean_text
  clean_text="$(printf '%s' "${raw_output}" | sed -E 's/\[[0-9:.]+ --> [0-9:.]+\]//g' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')"

  if [[ -n "${clean_text}" ]]; then
    echo "${clean_text}"
    mkdir -p "${CORE_HOME}/presence"
    printf '%s\t%s\n' "$(date -Iseconds)" "${clean_text}" >> "${LOG_FILE}"
  else
    echo "(sin voz detectada)"
  fi
}

play_beep() {
  local tone="${1:-start}"
  # Generar beep sintético suave con ffmpeg/aplay si no hay oga instalado
  local freq=880
  [[ "${tone}" == "stop" || "${tone}" == "end" ]] && freq=587
  (
    if command -v ffmpeg >/dev/null 2>&1 && command -v aplay >/dev/null 2>&1; then
      ffmpeg -f lavfi -i "sine=frequency=${freq}:duration=0.15" -q:a 0 -f wav - 2>/dev/null | aplay -q 2>/dev/null || true
    fi
  ) >/dev/null 2>&1 &
}

case "${1:-}" in
  --start)
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
      echo "Ya se está grabando (PID $(cat "${PID_FILE}"))"
      exit 0
    fi
    rm -f "${AUDIO_TMP}" "${PID_FILE}"
    play_beep start
    nohup arecord -q -f S16_LE -r 16000 -c 1 "${AUDIO_TMP}" >/dev/null 2>&1 &
    echo $! > "${PID_FILE}"
    echo "Grabando audio... (ejecuta 'core-listen.sh --stop' para finalizar)"
    ;;
  --stop)
    if [[ -f "${PID_FILE}" ]]; then
      pid="$(cat "${PID_FILE}")"
      rm -f "${PID_FILE}"
      if kill -0 "${pid}" 2>/dev/null; then
        kill -INT "${pid}" 2>/dev/null || kill -TERM "${pid}" 2>/dev/null || true
        sleep 0.3
      fi
    fi
    play_beep stop
    if [[ ! -f "${AUDIO_TMP}" || $(stat -c%s "${AUDIO_TMP}" 2>/dev/null || echo 0) -lt 1000 ]]; then
      echo "(sin audio grabado)"
      exit 0
    fi
    transcribe "${AUDIO_TMP}"
    ;;
  --file)
    shift
    [[ $# -ge 1 ]] || { echo "uso: $0 --file <archivo.wav>" >&2; exit 1; }
    transcribe "$1"
    ;;
  *)
    seconds="${1:-8}"
    if ! [[ "${seconds}" =~ ^[0-9]+$ ]]; then
      echo "uso: $0 [segundos | --start | --stop | --file ruta]" >&2
      exit 1
    fi
    echo "Escuchando durante ${seconds} segundos..."
    play_beep start
    nohup arecord -q -f S16_LE -r 16000 -c 1 "${AUDIO_TMP}" >/dev/null 2>&1 &
    REC_PID=$!
    sleep "${seconds}"
    kill -INT "${REC_PID}" 2>/dev/null || kill -TERM "${REC_PID}" 2>/dev/null || true
    sleep 0.2
    play_beep stop
    echo -n "Kora escuchó: "
    transcribe "${AUDIO_TMP}"
    ;;
esac
