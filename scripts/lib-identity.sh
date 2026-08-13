#!/usr/bin/env bash
# Identidad de esta instancia + playbook propio.
# Nunca cae al playbook de otra persona (no ~/Workspace/playbook ajeno).
#
# Fuente: $CORE_HOME/config.env
#   COMPANION_ID    slug [a-z0-9_-] — buzón PKM = …-radar_${COMPANION_ID}.md
#   COMPANION_NAME  nombre para tray / chat
#   CORE_PLAYBOOK   opcional; si vacío → $CORE_HOME/playbook

if [[ -z "${CORE_HOME:-}" ]]; then
  CORE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

if [[ -f "${CORE_HOME}/config.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${CORE_HOME}/config.env"
  set +a
fi

COMPANION_ID="$(printf '%s' "${COMPANION_ID:-companion}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' )"
[[ -n "${COMPANION_ID}" ]] || COMPANION_ID="companion"
COMPANION_NAME="${COMPANION_NAME:-Companion}"

if [[ -n "${CORE_PLAYBOOK:-}" ]]; then
  PLAYBOOK="${CORE_PLAYBOOK}"
else
  PLAYBOOK="${CORE_HOME}/playbook"
fi

RADAR_BASENAME="$(date +%Y%m%d)-GOV-radar_${COMPANION_ID}.md"
