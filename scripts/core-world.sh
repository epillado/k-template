#!/usr/bin/env bash
# Aferencia del mundo: el usuario como órgano sensorial del Companion.
# Prefijos de chat (equivalentes): [afe] canónico | [mnd] alias | [mundo]|[world] legacy
# Uso:
#   core-world.sh                      # status corto
#   core-world.sh show                 # cat world.md
#   core-world.sh report "texto…"      # registra reporte + log
#   core-world.sh report -t cuerpo "cansado bueno post 5km"
#   core-world.sh note "texto"         # solo log, sin tocar campos resumen
#   core-world.sh set <campo> <valor>  # donde|cuerpo_mood|clima_entorno|actividad|companía_humana
#   core-world.sh clear-soft           # limpia resumen; conserva log reciente
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
WORLD="${CORE_HOME}/presence/world.md"
SELF="${CORE_HOME}/presence/self.md"
mkdir -p "${CORE_HOME}/presence"
ts="$(date '+%Y-%m-%d %H:%M')"

if [[ ! -f "${WORLD}" ]]; then
  cat > "${WORLD}" << EOF
# Mundo aferente (lo que el usuario reporta)

- **actualizado:** ${ts}
- **fuente:**
- **donde:**
- **cuerpo_mood:**
- **clima_entorno:**
- **actividad:**
- **companía_humana:**
- **notas:**

## Log reciente (append; los viejos pueden recortarse en consolidación)

EOF
fi

touch_updated() {
  if rg -q '^\- \*\*actualizado:\*\*' "${WORLD}"; then
    sed -i "s|^- \*\*actualizado:\*\*.*|- **actualizado:** ${ts}|" "${WORLD}"
  fi
}

set_field() {
  local key="$1"
  shift
  local val="$*"
  local val_esc
  val_esc="$(printf '%s' "${val}" | sed -e 's/[&|\\]/\\&/g')"
  touch_updated
  if rg -q "^\- \*\*${key}:\*\*" "${WORLD}"; then
    sed -i "s|^- \*\*${key}:\*\*.*|- **${key}:** ${val_esc}|" "${WORLD}"
  else
    echo "- **${key}:** ${val}" >> "${WORLD}"
  fi
}

append_log() {
  local line="$1"
  if rg -q '^## Log reciente' "${WORLD}"; then
    # append after header line of log section: find last line and add
    echo "- [${ts}] ${line}" >> "${WORLD}"
  else
    {
      echo
      echo "## Log reciente (append)"
      echo "- [${ts}] ${line}"
    } >> "${WORLD}"
  fi
}

# Heurística barata: rellenar un campo resumen si el tag lo dice
apply_tag_field() {
  local tag="$1"
  local text="$2"
  case "${tag}" in
    cuerpo|body|mood) set_field "cuerpo_mood" "${text}" ;;
    clima|weather|entorno) set_field "clima_entorno" "${text}" ;;
    donde|lugar|place) set_field "donde" "${text}" ;;
    actividad|activity|bici|run) set_field "actividad" "${text}" ;;
    gente|familia|companía|compania) set_field "companía_humana" "${text}" ;;
    *) set_field "fuente" "chat/script (${tag:-libre})"
       # mete el texto en notas línea
       touch_updated
       echo "  - [${ts}] ${text}" >> "${WORLD}"
       ;;
  esac
}

cmd="${1:-status}"
shift || true

case "${cmd}" in
  status|"")
    rg -n '^\- \*\*(actualizado|fuente|donde|cuerpo_mood|clima_entorno|actividad|companía_humana)' "${WORLD}" || true
    echo "--- últimas del log ---"
    rg '^\- \[' "${WORLD}" | tail -n 5 || true
    ;;
  show)
    cat "${WORLD}"
    ;;
  note)
    [[ $# -ge 1 ]] || { echo "uso: $0 note \"texto\"" >&2; exit 1; }
    touch_updated
    append_log "$*"
    echo "world: nota en log"
    ;;
  set)
    [[ $# -ge 2 ]] || { echo "uso: $0 set <campo> <valor...>" >&2; exit 1; }
    key="$1"; shift
    case "${key}" in
      donde|cuerpo_mood|clima_entorno|actividad|companía_humana|fuente)
        set_field "${key}" "$*"
        append_log "${key}=$*"
        echo "world: ${key} actualizado"
        ;;
      *)
        echo "campo: donde|cuerpo_mood|clima_entorno|actividad|companía_humana|fuente" >&2
        exit 1
        ;;
    esac
    ;;
  report)
    tag=""
    if [[ "${1:-}" == "-t" || "${1:-}" == "--tag" ]]; then
      tag="${2:-}"
      shift 2
    fi
    [[ $# -ge 1 ]] || { echo "uso: $0 report [-t tag] \"texto\"" >&2; exit 1; }
    text="$*"
    touch_updated
    set_field "fuente" "report${tag:+/$tag}"
    if [[ -n "${tag}" ]]; then
      apply_tag_field "${tag}" "${text}"
      append_log "[${tag}] ${text}"
    else
      # reporte libre: log + nota
      echo "  - [${ts}] ${text}" >> "${WORLD}"
      append_log "${text}"
    fi
    # pica self.ultimo momento de forma ligera (no falla si no hay self)
    if [[ -x "${CORE_HOME}/scripts/core-self.sh" ]]; then
      "${CORE_HOME}/scripts/core-self.sh" moment "aferencia: ${text}" >/dev/null 2>&1 || true
    fi
    echo "world: aferencia registrada (${ts})"
    echo "pista: integrar en chat (no modo helpdesk) y ajustar tono/self/context si pesa"
    ;;
  clear-soft)
    touch_updated
    set_field "fuente" ""
    set_field "donde" ""
    set_field "cuerpo_mood" ""
    set_field "clima_entorno" ""
    set_field "actividad" ""
    set_field "companía_humana" ""
    append_log "sistema: clear-soft del resumen (log conservado)"
    echo "world: resumen limpio; log intacto"
    ;;
  *)
    echo "uso: $0 status|show|report|note|set|clear-soft" >&2
    exit 1
    ;;
esac
