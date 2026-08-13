#!/usr/bin/env bash
# Lee o actualiza presence/context.md (MVP espacios mentales).
# Uso:
#   core-context.sh                     # muestra primary + resumen
#   core-context.sh show                # cat context.md
#   core-context.sh set <primary> [nota...]
#   core-context.sh secondary a,b,c
#   core-context.sh call yes|no
#   core-context.sh note "texto"
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CTX="${CORE_HOME}/presence/context.md"
mkdir -p "${CORE_HOME}/presence"
ts="$(date '+%Y-%m-%d %H:%M')"

if [[ ! -f "${CTX}" ]]; then
  cat > "${CTX}" << EOF
# Contexto activo

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
  call)
    [[ "${1:-}" == "yes" || "${1:-}" == "no" ]] || { echo "uso: $0 call yes|no" >&2; exit 1; }
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${CTX}"
    sed -i "s|^- \*\*en_call:\*\*.*|- **en_call:** $1|" "${CTX}"
    echo "context: en_call=$1"
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
