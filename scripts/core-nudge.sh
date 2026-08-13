#!/usr/bin/env bash
# Llamar la atención del usuario: tray + sonido. Linux o Windows/WSL.
#
# Uso:
#   core-nudge.sh [título] [cuerpo]
#   core-nudge.sh --soft [título] [cuerpo]
#   core-nudge.sh --terminal [pista]
#   core-nudge.sh --say "comentario"
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

SOUND="${CORE_NUDGE_SOUND:-/usr/share/sounds/freedesktop/stereo/message-new-instant.oga}"
SOFT_SOUND="${CORE_NUDGE_SOFT_SOUND:-/usr/share/sounds/freedesktop/stereo/bell.oga}"
MAX_BODY="${CORE_NUDGE_MAX_BODY:-220}"

export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

soft=0
mode="normal"
title="${COMPANION_NAME}"
body=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --soft) soft=1; shift ;;
    --terminal)
      mode="terminal"
      shift
      body="${1:-Te escribí en el chat. Voltea a ver.}"
      shift || true
      title="${COMPANION_NAME} · mira el chat"
      break
      ;;
    --say)
      mode="say"
      shift
      body="${1:-Oye…}"
      shift || true
      title="${COMPANION_NAME}"
      break
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "uso: core-nudge.sh [--soft] [--say texto|--terminal [pista]|título cuerpo]" >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ "${mode}" == "normal" ]]; then
  title="${1:-${COMPANION_NAME}}"
  body="${2:-Oye… ¿me miras un segundo?}"
fi

body_flat="$(printf '%s' "${body}" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ //;s/ $//')"
if ((${#body_flat} > MAX_BODY)); then
  body_tray="${body_flat:0:$((MAX_BODY - 1))}…"
  truncated=1
else
  body_tray="${body_flat}"
  truncated=0
fi

play() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  if command -v paplay >/dev/null 2>&1; then
    paplay "$f" 2>/dev/null && return 0
  fi
  if command -v pw-play >/dev/null 2>&1; then
    pw-play "$f" 2>/dev/null && return 0
  fi
  return 1
}

windows_toast() {
  command -v powershell.exe >/dev/null 2>&1 || return 1
  local t="$1" b="$2"
  t="${t//\'/\'\'}"
  b="${b//\'/\'\'}"
  powershell.exe -NoProfile -Command "
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    \$n = New-Object System.Windows.Forms.NotifyIcon
    \$n.Icon = [System.Drawing.SystemIcons]::Information
    \$n.Visible = \$true
    \$n.ShowBalloonTip(4000, '${t}', '${b}', [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 5
    \$n.Dispose()
  " >/dev/null 2>&1 || return 1
  return 0
}

if (( soft == 0 )); then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -a "${COMPANION_NAME}" -i dialog-information "$title" "$body_tray" 2>/dev/null || true
  else
    windows_toast "$title" "$body_tray" || true
  fi
fi

if (( soft == 1 )); then
  play "$SOFT_SOUND" || play "$SOUND" || true
else
  play "$SOUND" || play "$SOFT_SOUND" || true
fi

mkdir -p "${CORE_HOME}/presence"
{
  echo "$(date -Iseconds) nudge mode=${mode} truncated=${truncated}"
  echo "  title: ${title}"
  echo "  body: ${body_flat}"
} >> "${CORE_HOME}/presence/nudge.log"

printf '%s\n' "${body}" > "${CORE_HOME}/presence/last_nudge_body.txt"
date -Iseconds > "${CORE_HOME}/presence/last_nudge.ts"

if [[ "${CORE_NUDGE_NO_CHAT_OWED:-0}" != "1" && "${soft}" -eq 0 ]]; then
  if [[ "${mode}" == "say" || "${mode}" == "terminal" || "${mode}" == "normal" ]]; then
    cat > "${CORE_HOME}/presence/chat_owed.md" <<EOF
# Chat owed — ${COMPANION_NAME}

- **cuando:** $(date -Iseconds)
- **origen:** core-nudge mode=${mode}
- **título tray:** ${title}
- **cuerpo:** ${body_flat}
- **estado:** awaiting_chat_in_terminal

Si sonó campanita / tray, **debe** haber comentario en el chat de esta sesión.
No basta el popup. Tras escribir:

\`\$CORE_HOME/scripts/core-presence-respond.sh delivered\`

Prohibido cerrar el turno solo con tools vacíos o solo tray.
EOF
  fi
fi
