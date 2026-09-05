#!/usr/bin/env bash
# Despertador agnóstico para hermanas de casa (Kora, Samy, Pau).
# Uso:
#   core-wake.sh
#   core-wake.sh --motor grok|agy|claude|codex
set -euo pipefail
CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
STATE="${CORE_HOME}/presence/wake-state.env"
SELF="${CORE_HOME}/presence/self.md"
mkdir -p "${CORE_HOME}/presence"

MOTOR_OVERRIDE=""
for arg in "$@"; do
  case "$arg" in
    grok|agy|claude|codex) MOTOR_OVERRIDE="$arg" ;;
  esac
done
if [[ "${1:-}" == "--motor" && -n "${2:-}" ]]; then
  MOTOR_OVERRIDE="$2"
fi

detect() {
  if [[ -n "${MOTOR_OVERRIDE}" ]]; then echo "${MOTOR_OVERRIDE}"; return; fi
  if [[ -n "${GROK_AGENT:-}" ]]; then echo grok; return; fi
  if [[ -n "${CLAUDECODE:-}" || -n "${CLAUDE_CODE:-}" ]]; then echo claude; return; fi
  if [[ -n "${ANTIGRAVITY:-}" || -n "${GEMINI_CLI:-}" ]]; then echo agy; return; fi
  if [[ -f "${SELF}" ]]; then
    local m
    m="$(sed -n 's/^- \*\*motor_activo:\*\* //p' "${SELF}" | head -1 | tr -d ' ')"
    case "$m" in
      grok) echo grok; return ;;
      agy|gemini|antigravity) echo agy; return ;;
      claude*) echo claude; return ;;
      codex*) echo codex; return ;;
    esac
  fi
  echo unknown
}

motor="$(detect)"
ts="$(date -Iseconds)"

case "${motor}" in
  grok)
    apply="1) monitor persistent: ${CORE_HOME}/scripts/core-wake-feed.sh
2) NO crear scheduler periódico 2m (tapa el chat)
3) Si hay scheduler periódico, borrarlo"
    ;;
  *)
    apply="1) Lanzar en background: ${CORE_HOME}/scripts/core-wake-once.sh
2) NO usar cron periódico */2
3) Al despertar por fin de tarea: leer tubos / radar, comentar y relanzar core-wake-once.sh"
    ;;
esac

cat > "${STATE}" <<EOF
# wake-state — escrito por core-wake.sh
UPDATED_AT="${ts}"
MOTOR="${motor}"
GROK_FEED="${CORE_HOME}/scripts/core-wake-feed.sh"
AGY_WAKE="${CORE_HOME}/scripts/core-wake-once.sh"
EOF

echo "motor=${motor}"
echo "doc=${CORE_HOME}/scripts/core-wake.sh"
echo "--- apply ---"
echo "${apply}"
