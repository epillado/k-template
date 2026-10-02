#!/usr/bin/env bash
# Uso: core-msg-lalo.sh "mensaje"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib-identity.sh"

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 \"mensaje\""
  exit 1
fi

MSG="$*"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
INBOX="${CORE_HOME}/presence/social/inbox-lalo.md"

mkdir -p "$(dirname "$INBOX")"
printf "\n## %s — Mensaje de Lalo\n\n%s\n" "$TIMESTAMP" "$MSG" >> "$INBOX"
echo "Mensaje entregado a ${COMPANION_NAME} en $INBOX"
