#!/usr/bin/env bash
# Empuja SOLO el radar de ESTA instancia. No es sync_notas (add -A).
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

DAY="$(date +%Y%m%d)"
rel="PKM/${DAY}-GOV-radar_${COMPANION_ID}.md"
RADAR="${PLAYBOOK}/${rel}"

if [[ "${1:-}" == "--path" ]]; then
  echo "${RADAR}"
  exit 0
fi

[[ -f "${RADAR}" ]] || { echo "error: no existe ${RADAR}" >&2; exit 1; }
[[ -d "${PLAYBOOK}/.git" ]] || { echo "error: playbook no es repo git: ${PLAYBOOK}" >&2; exit 1; }

cd "${PLAYBOOK}"
git add -- "${rel}"

if git diff --cached --quiet -- "${rel}"; then
  echo "pkm-push: nada nuevo en ${rel}"
  exit 0
fi

git commit -m "pkm: radar ${COMPANION_ID} ${DAY}"
git pull --rebase --autostash origin main
git push origin main
echo "pkm-push: ${rel}"
