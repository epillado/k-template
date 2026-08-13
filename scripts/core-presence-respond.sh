#!/usr/bin/env bash
# Helper para el agente: comentario en chat + tray con personalidad.
#
# Orden correcto: tray sin chat = bug.
#   1) Escribir comentario personal en el chat de esta sesión.
#   2) core-presence-respond.sh say "resumen tray"   # o terminal
#   3) core-presence-respond.sh delivered            # limpia chat_owed
#   4) core-presence-respond.sh clear                # pending playbook atendido
#
# Mute call (sin tray): solo clear.
#
# Uso:
#   core-presence-respond.sh say "Tu comentario corto para el tray"
#   core-presence-respond.sh terminal [pista]
#   core-presence-respond.sh delivered   # chat ya escrito en terminal
#   core-presence-respond.sh clear       # pending atendido
#   core-presence-respond.sh status      # pending + chat_owed
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
PENDING="${CORE_HOME}/presence/pending.md"
CHAT_OWED="${CORE_HOME}/presence/chat_owed.md"
STATE_DIR="${CORE_HOME}/presence"

cmd="${1:-}"
shift || true

case "${cmd}" in
  say)
    text="${*:-Oye…}"
    "${CORE_HOME}/scripts/core-nudge.sh" --say "${text}"
    echo "tray ok — recuerda: texto en chat + $0 delivered"
    ;;
  terminal)
    pista="${*:-Te dejé un comentario en el chat. Voltea a ver.}"
    "${CORE_HOME}/scripts/core-nudge.sh" --terminal "${pista}"
    echo "terminal-ping ok — el cuerpo completo DEBE estar ya (o ya) en el chat"
    ;;
  delivered)
    if [[ -f "${CHAT_OWED}" ]]; then
      {
        echo
        echo "---"
        echo "**delivered_in_chat:** $(date -Iseconds)"
      } >> "${CHAT_OWED}"
      mv -f "${CHAT_OWED}" "${STATE_DIR}/chat_owed.last.md"
      echo "chat_owed cleared (delivered)"
    else
      echo "chat_owed: nothing pending"
    fi
    ;;
  clear)
    if [[ -f "${CHAT_OWED}" ]] && grep -q 'awaiting_chat_in_terminal' "${CHAT_OWED}" 2>/dev/null; then
      if [[ "${CORE_CLEAR_FORCE:-0}" == "1" ]]; then
        echo "warn: clear con chat_owed aún abierto (CORE_CLEAR_FORCE=1)" >&2
      else
        echo "error: hay chat_owed — escribe en el chat y corre: $0 delivered" >&2
        echo "       (mute sin tray: no debería existir chat_owed; si es basura: CORE_CLEAR_FORCE=1 $0 clear)" >&2
        head -12 "${CHAT_OWED}" >&2 || true
        exit 1
      fi
    fi
    if [[ -f "${PENDING}" ]]; then
      {
        echo
        echo "---"
        echo
        echo "**atendido:** $(date -Iseconds)"
      } >> "${PENDING}"
      mv -f "${PENDING}" "${STATE_DIR}/pending.last.md"
    fi
    rm -f "${STATE_DIR}/pending.ts" "${STATE_DIR}/pending_labels.txt"
    echo "pending cleared"
    ;;
  status)
    echo "== pending =="
    if [[ -f "${PENDING}" ]]; then
      head -12 "${PENDING}"
    else
      echo "(none)"
    fi
    echo "== chat_owed =="
    if [[ -f "${CHAT_OWED}" ]]; then
      cat "${CHAT_OWED}"
    else
      echo "(none)"
    fi
    ;;
  *)
    echo "uso: $0 say <texto> | terminal [pista] | delivered | clear | status" >&2
    exit 2
    ;;
esac
