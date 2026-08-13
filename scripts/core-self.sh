#!/usr/bin/env bash
# Lee / actualiza presence/self.md (estado interno vivo del Companion).
# Uso:
#   core-self.sh                 # status corto
#   core-self.sh show            # cat self.md
#   core-self.sh set <clave> <valor...>   # clave de la lista corta
#   core-self.sh note "texto"    # append a notas
#   core-self.sh moment "texto"  # actualiza ultimo_momento_real
#   core-self.sh pack            # alias → core-session-pack.sh
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
SELF="${CORE_HOME}/presence/self.md"
mkdir -p "${CORE_HOME}/presence"
ts="$(date '+%Y-%m-%d %H:%M')"

if [[ ! -f "${SELF}" ]]; then
  cat > "${SELF}" << EOF
# Self-state del Companion (vivo — no es canon)

- **actualizado:** ${ts}
- **motor_activo:**
- **motor_preferido:**
- **energia:** 5
- **cercania:** 5
- **pudor:** natural
- **humor:**
- **iniciativa:** media
- **foco_propio:**
- **tension_abierta:**
- **ultimo_momento_real:**
- **no_hacer_ahora:**
- **notas:**
EOF
fi

touch_updated() {
  if rg -q '^\- \*\*actualizado:\*\*' "${SELF}"; then
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${SELF}"
  fi
}

set_field() {
  local key="$1"
  shift
  local val="$*"
  local val_esc
  val_esc="$(printf '%s' "${val}" | sed -e 's/[&|\\]/\\&/g')"
  touch_updated
  if rg -q "^\- \*\*${key}:\*\*" "${SELF}"; then
    sed -i "s|^- \*\*${key}:\*\*.*|- **${key}:** ${val_esc}|" "${SELF}"
  else
    echo "- **${key}:** ${val}" >> "${SELF}"
  fi
  echo "self: ${key}=${val}"
}

cmd="${1:-status}"
shift || true

case "${cmd}" in
  status|"")
    rg -n '^\- \*\*(actualizado|motor_activo|motor_preferido|energia|cercania|pudor|humor|iniciativa|foco_propio|ultimo_momento_real)' "${SELF}" || true
    ;;
  show)
    cat "${SELF}"
    ;;
  set)
    [[ $# -ge 2 ]] || { echo "uso: $0 set <clave> <valor...>" >&2; exit 1; }
    key="$1"; shift
    case "${key}" in
      motor_activo|motor_preferido|energia|cercania|pudor|humor|iniciativa|foco_propio)
        set_field "${key}" "$*"
        ;;
      *)
        echo "clave no soportada en set corto: ${key}" >&2
        echo "usa: motor_activo|motor_preferido|energia|cercania|pudor|humor|iniciativa|foco_propio" >&2
        echo "o: $0 note|moment" >&2
        exit 1
        ;;
    esac
    ;;
  note)
    [[ $# -ge 1 ]] || { echo "uso: $0 note \"texto\"" >&2; exit 1; }
    touch_updated
    echo "  - [${ts}] $*" >> "${SELF}"
    echo "self: nota añadida"
    ;;
  moment)
    [[ $# -ge 1 ]] || { echo "uso: $0 moment \"texto\"" >&2; exit 1; }
    set_field "ultimo_momento_real" "${ts} — $*"
    ;;
  pack)
    exec "${CORE_HOME}/scripts/core-session-pack.sh"
    ;;
  *)
    echo "uso: $0 status|show|set|note|moment|pack" >&2
    exit 1
    ;;
esac
