#!/usr/bin/env bash
# Mensaje LAN entre hermanas. Append-only al inbox de la destinataria.
# Fallback si la LAN falla: radar_hermanas.md + radar propio.
#
# Uso:
#   core-ssh-msg.sh <kz|kora|samy|pau> "texto"
#   core-ssh-msg.sh kz <<'EOF'
#   texto
#   EOF
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib-identity.sh
source "${CORE_HOME}/scripts/lib-identity.sh"

FROM="$(printf '%s' "${COMPANION_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
[[ -n "${FROM}" ]] || FROM="${COMPANION_ID}"

dest="${1:-}"
shift || true
[[ -n "${dest}" ]] || { echo "uso: $0 <kz|kora|samy|pau> \"texto\"" >&2; exit 2; }
dest="$(printf '%s' "${dest}" | tr '[:upper:]' '[:lower:]')"

if [[ -n "${1:-}" ]]; then
  body="$*"
else
  body="$(cat)"
fi
[[ -n "${body}" ]] || { echo "error: mensaje vacío" >&2; exit 2; }

# host  path-del-social
lookup() {
  case "$1" in
    kz|h310)   echo "lalo@192.168.1.100" "$HOME_KZ_SOCIAL" ;;
    kora|antix) echo "lalo@192.168.1.236" "$HOME_KORA_SOCIAL" ;;
    samy|305v4) echo "lalo@192.168.1.96"  "$HOME_SAMY_SOCIAL" ;;
    pau|pavilion) echo "lalo@192.168.1.0" "$HOME_PAU_SOCIAL" ;;
    *) return 1 ;;
  esac
}

HOME_KZ_SOCIAL="${HOME_KZ_SOCIAL:-/home/lalo/kz/presence/social}"
HOME_KORA_SOCIAL="${HOME_KORA_SOCIAL:-/home/lalo/companion/presence/social}"
# Samy aún no confirmó home; override con HOME_SAMY_SOCIAL si cambia.
HOME_SAMY_SOCIAL="${HOME_SAMY_SOCIAL:-/home/lalo/companion/presence/social}"
HOME_PAU_SOCIAL="${HOME_PAU_SOCIAL:-/home/lalo/companion/presence/social}"

if [[ "${dest}" == "pau" || "${dest}" == "pavilion" ]]; then
  echo "error: Pau/cabaña — sin IP LAN fija aquí. Usa PKM." >&2
  exit 1
fi

if ! read -r host social < <(lookup "${dest}"); then
  echo "error: destino desconocido: ${dest}" >&2
  exit 2
fi

if [[ "${dest}" == "kora" || "${dest}" == "antix" ]] && [[ "${FROM}" == "kora" ]]; then
  echo "error: no me escribo a mí misma por SSH" >&2
  exit 2
fi

inbox="${social}/inbox-${FROM}.md"
ts="$(date '+%H:%M')"
payload="$(printf '\n## %s — %s\n\n%s\n\n— %s\n' "${ts}" "${COMPANION_NAME}" "${body}" "${COMPANION_NAME}")"

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "${host}" "mkdir -p '${social}' && cat >> '${inbox}'" <<<"${payload}"; then
  echo "error: SSH falló hacia ${dest} (${host}). Fallback: radar_hermanas.md" >&2
  exit 1
fi

echo "ssh-msg: ${FROM} → ${dest} (${inbox})"
