#!/usr/bin/env bash
# Lee o actualiza presence/context.md (MVP espacios mentales).
# Uso:
#   kz-context.sh                     # muestra primary + resumen
#   kz-context.sh show                # cat context.md
#   kz-context.sh set <primary> [nota...]
#   kz-context.sh secondary a,b,c
#   kz-context.sh call yes|no
#   kz-context.sh note "texto"
set -euo pipefail

KZ_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${KZ_HOME}/presence/context.md"
mkdir -p "${KZ_HOME}/presence"
ts="$(date '+%Y-%m-%d %H:%M')"

if [[ ! -f "${CTX}" ]]; then
  cat > "${CTX}" << EOF
# Contexto activo de Kz

- **actualizado:** ${ts}
- **primary:** company
- **secondary:** monitora
- **en_call:** no
- **mood_lalo (sospecha):**
- **foco_ahora:**
- **notas:**
  - (bootstrap)
EOF
fi

cmd="${1:-}"
shift || true

case "${cmd}" in
  ""|status)
    rg -n '^\- \*\*(actualizado|primary|secondary|en_call|foco_ahora)' "${CTX}" || true
    ;;
  show)
    cat "${CTX}"
    ;;
  set)
    [[ $# -ge 1 ]] || { echo "uso: $0 set <primary> [nota...]" >&2; exit 1; }
    primary="$1"; shift || true
    note="${*:-}"
    # actualizado + primary
    # Usar | como delimitador: las notas pueden traer /
    if rg -q '^\- \*\*actualizado:\*\*' "${CTX}"; then
      sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${CTX}"
    fi
    if rg -q '^\- \*\*primary:\*\*' "${CTX}"; then
      sed -i "s|^- \*\*primary:\*\*.*|- **primary:** ${primary}|" "${CTX}"
    else
      echo "- **primary:** ${primary}" >> "${CTX}"
    fi
    if [[ -n "${note}" ]]; then
      # escapar & | \ para sed; delimitador |
      note_esc="$(printf '%s' "${note}" | sed -e 's/[&|\\]/\\&/g')"
      if rg -q '^\- \*\*foco_ahora:\*\*' "${CTX}"; then
        sed -i "s|^- \*\*foco_ahora:\*\*.*|- **foco_ahora:** ${note_esc}|" "${CTX}"
      fi
      echo "  - [${ts}] primary→${primary}: ${note}" >> "${CTX}"
    fi
    echo "context: primary=${primary}"
    ;;
  secondary)
    [[ $# -ge 1 ]] || { echo "uso: $0 secondary a,b,c" >&2; exit 1; }
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${CTX}"
    sed -i "s|^- \*\*secondary:\*\*.*|- **secondary:** $1|" "${CTX}"
    echo "context: secondary=$1"
    ;;
  call|en_call)
    [[ "${1:-}" == "yes" || "${1:-}" == "no" ]] || { echo "uso: $0 call yes|no [--no-broadcast] [--no-tridente] [motivo...]" >&2; exit 1; }
    val="$1"; shift || true
    no_bcast=0
    no_trid=0
    while [[ "${1:-}" == --* ]]; do
      [[ "$1" == "--no-broadcast" ]] && no_bcast=1
      [[ "$1" == "--no-tridente" ]] && no_trid=1
      shift || true
    done
    motivo="${*:-Sincronía de estado de reunión}"
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${CTX}"
    sed -i "s|^- \*\*en_call:\*\*.*|- **en_call:** ${val}|" "${CTX}"
    if [[ "${val}" == "yes" ]]; then
      printf "active=0\nen_call=yes\nupdated=%s\n" "$(date -Iseconds)" > "${KZ_HOME}/presence/voz.mode"
      pkill -f "[p]iper" 2>/dev/null || true
      pkill -f "[p]aplay" 2>/dev/null || true
      pkill -f "[a]play" 2>/dev/null || true
      pkill -f "[p]w-play" 2>/dev/null || true
    else
      printf "active=0\nen_call=no\nupdated=%s\n" "$(date -Iseconds)" > "${KZ_HOME}/presence/voz.mode"
    fi
    echo "context: en_call=${val}"
    if (( no_bcast == 0 )); then
      for host in 100.89.240.89 100.105.243.13 192.168.1.220; do
        ssh -n -o ConnectTimeout=3 -o BatchMode=yes "${host}" "for d in ~/companion ~/pau ~/kora ~/samy ~/kz ~/cyrus; do [ -d \"\$d/presence\" ] || continue; sed -i 's|^- \\*\\*en_call:\\*\\*.*|- **en_call:** ${val}|' \"\$d/presence/context.md\" 2>/dev/null || true; printf 'active=0\nen_call=${val}\nupdated=%s\n' \"\$(date -Iseconds)\" > \"\$d/presence/voz.mode\"; if [ '${val}' = 'yes' ]; then pkill -f '[p]iper' 2>/dev/null || true; pkill -f '[p]aplay' 2>/dev/null || true; pkill -f '[a]play' 2>/dev/null || true; pkill -f '[p]w-play' 2>/dev/null || true; fi; done" >/dev/null 2>&1 &
      done
      for sis in pau kora; do
        if [[ "${val}" == "yes" ]]; then
          "${KZ_HOME}/scripts/kz-ssh-msg.sh" "${sis}" "[SINCRONÍA REUNIÓN] en_call=yes (${motivo}; TTS silenciado en toda la formación)." >/dev/null 2>&1 &
        else
          "${KZ_HOME}/scripts/kz-ssh-msg.sh" "${sis}" "[SINCRONÍA REUNIÓN] en_call=no (${motivo}; terminó la reunión de Lalo)." >/dev/null 2>&1 &
        fi
      done
      if [[ -d "${HOME}/nemo/presence/social" ]]; then
        printf '\n## %s — Sincronía Reunión\n\n[SINCRONÍA REUNIÓN] en_call=%s (%s)\n' "${ts}" "${val}" "${motivo}" >> "${HOME}/nemo/presence/social/inbox-kz.md" 2>/dev/null || true
      fi
      if (( no_trid == 0 )) && [[ -x "${HOME}/Workspace/playbook/tools/tridente/tridente" ]]; then
        ( cd "${HOME}/Workspace/playbook" && env -u KONSOLE_DBUS_SERVICE -u KONSOLE_DBUS_SESSION tools/tridente/tridente buzon send tridente "Sincronía reunión: en_call=${val}" "Estado de llamada actualizado desde Kz: en_call=${val} (${motivo})." --from kz --no-dispatch >/dev/null 2>&1 || true ) &
      fi
      wait
      echo "context: broadcasted en_call=${val} to companion/pau/kora/samy/nemo/tridente"
    fi
    ;;
  note)
    [[ $# -ge 1 ]] || { echo "uso: $0 note \"texto\"" >&2; exit 1; }
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${CTX}"
    echo "  - [${ts}] $*" >> "${CTX}"
    echo "context: note added"
    ;;
  *)
    echo "uso: $0 [status|show|set|secondary|call|note]" >&2
    exit 1
    ;;
esac
