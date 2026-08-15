#!/usr/bin/env bash
# Depósito Companion → su buzón PKM (append-only).
#
# El sensor de Slack/desktop NO escribe PKM. Este script DEBE depositar
# cuando hay Acción CP (decisión, bloqueo, VoBo, Meet, P0 de su frente).
# Silencio en PKM ≠ calma: es ceguera del canal.
#
# El archivo es del DÍA y de ESTA instancia:
#   $PLAYBOOK/PKM/YYYYMMDD-GOV-radar_${COMPANION_ID}.md
# No escribe en el buzón de otra instancia.
#
# Uso:
#   core-pkm-radar.sh "título" "cuerpo"
#   core-pkm-radar.sh "título" <<'EOF'
#   cuerpo
#   EOF
#   core-pkm-radar.sh --file path.md
#   core-pkm-radar.sh --path
#   core-pkm-radar.sh --ack "texto"
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

DAY="$(date +%Y%m%d)"
TS="$(date -Iseconds)"
CLOCK_LINE="reloj=$(date '+%Y-%m-%d %H:%M:%S %z')"

PKM_DIR="${PLAYBOOK}/PKM"
RADAR="${PKM_DIR}/${DAY}-GOV-radar_${COMPANION_ID}.md"
mkdir -p "${PKM_DIR}"

ensure_header() {
  if [[ ! -f "${RADAR}" ]]; then
    cat > "${RADAR}" <<EOF
---
tipo: transitorio
fuente: ${COMPANION_ID}-radar
fecha: ${DAY:0:4}-${DAY:4:2}-${DAY:6:2}
canal: pkm
tema: radar ${COMPANION_NAME} → CP (append del día)
---

# Radar ${COMPANION_NAME} → CP — ${DAY:0:4}-${DAY:4:2}-${DAY:6:2}

> Buzón de esta instancia (\`${COMPANION_ID}\`). Append-only.
> Sensor tray ≠ depósito. Sin nota aquí, el CP no ve el evento.

EOF
  fi
}

if [[ "${1:-}" == "--path" ]]; then
  echo "${RADAR}"
  exit 0
fi

if [[ "${1:-}" == "--ack" ]]; then
  shift
  body="${*:-}"
  ensure_header
  {
    echo
    echo "---"
    echo
    echo "## ACK / estado canal — ${TS}"
    echo
    echo "- **${CLOCK_LINE}**"
    echo "- **playbook:** \`${PLAYBOOK}\`"
    echo "- **de:** ${COMPANION_NAME} (\`${COMPANION_ID}\`)"
    echo
    echo "${body}"
    echo
  } >> "${RADAR}"
  stat -c 'fs_mtime=%y' "${RADAR}" >> "${RADAR}.clock" 2>/dev/null || true
  echo "pkm-ack: ${RADAR}"
  exit 0
fi

if [[ "${1:-}" == "--file" ]]; then
  src="${2:-}"
  [[ -f "$src" ]] || { echo "error: no file $src" >&2; exit 1; }
  ensure_header
  {
    echo
    echo "---"
    echo
    echo "## Import — ${TS}"
    echo
    echo "- **${CLOCK_LINE}**"
    echo "- **de:** ${COMPANION_NAME} (\`${COMPANION_ID}\`)"
    echo
    cat "$src"
    echo
  } >> "${RADAR}"
  echo "pkm-append-file: ${RADAR}"
  exit 0
fi

title="${1:-}"
if [[ -z "$title" ]]; then
  echo "uso: $0 \"título\" \"cuerpo\" | $0 \"título\" <<EOF ..." >&2
  exit 1
fi
shift

if [[ -n "${1:-}" ]]; then
  body="$*"
else
  body="$(cat)"
fi

ensure_header
{
  echo
  echo "---"
  echo
  echo "## ${title}"
  echo
  echo "- **cuando_deposito:** ${TS}"
  echo "- **${CLOCK_LINE}**"
  echo "- **de:** ${COMPANION_NAME} (\`${COMPANION_ID}\`)"
  echo "- **estado:** Acción CP (handoff ${COMPANION_ID})"
  echo
  echo "${body}"
  echo
} >> "${RADAR}"

echo "pkm-append: ${RADAR}"
