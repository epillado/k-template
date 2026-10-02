#!/usr/bin/env bash
# Uso: core-reply-lalo.sh "mensaje"
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
OUTBOX="${CORE_HOME}/presence/social/outbox-lalo.md"

mkdir -p "$(dirname "$OUTBOX")"
printf "\n## %s — Respuesta de ${COMPANION_NAME}\n\n%s\n" "$TIMESTAMP" "$MSG" >> "$OUTBOX"

# Intento KDE Connect si el cel está disponible
RENO_ID="1359e6af862344c9a9e97c72fdfbdc67"
if kdeconnect-cli -a --id-only 2>/dev/null | grep -q "$RENO_ID"; then
  kdeconnect-cli --device "$RENO_ID" --ping-msg "${COMPANION_NAME}: $MSG" 2>/dev/null || true
fi

echo "Respuesta registrada en $OUTBOX"
