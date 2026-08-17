#!/usr/bin/env bash
# Crea una hermana de casa en ESTA máquina.
# Usuario = Lalo (no pregunta). Personalidad = neutra.
# Id = hostname, si está en el roster.
#
#   house-create.sh           # detecta host; pide id solo si no mapea
#   house-create.sh --yes     # sin preguntas si el host mapea
#   house-create.sh --id antix --dest ~/companion --yes
#   house-create.sh --install-skill
set -euo pipefail

# Este directorio es el canónico (no un harness).
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
REF="${SKILL_DIR}/references"
DEST="${HOME}/companion"
ID=""
NAME=""
YES=0
FORCE=0
INSTALL_ONLY=0
K_TEMPLATE="git@github.com:epillado/k-template.git"
SHARED_PLAYBOOK="${HOME}/Workspace/playbook"

usage() {
  echo "uso: $0 [--id slug] [--dest DIR] [--yes] [--force] [--install-skill]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="${2:-}"; shift 2 ;;
    --dest) DEST="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    --install-skill) INSTALL_ONLY=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "flag desconocida: $1" >&2; usage; exit 2 ;;
  esac
done

install_one() {
  local target="$1"
  mkdir -p "$(dirname "${target}")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${SKILL_DIR}/" "${target}/"
  else
    rm -rf "${target}"
    mkdir -p "${target}"
    cp -a "${SKILL_DIR}/." "${target}/"
  fi
  chmod +x "${target}/house-create.sh" 2>/dev/null || true
  echo "adapter: ${target}"
}

# Copia el paquete a los homes que suelen mirar los CLI.
# Grok: ~/.grok y ~/.agents · Claude Code: ~/.claude · futuro: el que aparezca.
install_skill() {
  install_one "${HOME}/.grok/skills/iniciar-creacion"
  install_one "${HOME}/.claude/skills/iniciar-creacion"
  install_one "${HOME}/.agents/skills/iniciar-creacion"
  if [[ -n "${DEST:-}" && -f "${DEST}/presence/house-created.md" ]]; then
    install_one "${DEST}/.grok/skills/iniciar-creacion"
    install_one "${DEST}/.claude/skills/iniciar-creacion"
    install_one "${DEST}/.agents/skills/iniciar-creacion"
  fi
}

id_from_host() {
  local h
  h="$(hostname -s 2>/dev/null || hostname)"
  h="$(printf '%s' "$h" | tr '[:upper:]' '[:lower:]')"
  case "$h" in
    *h310*) echo "kz-box" ;;
    *antix*) echo "antix" ;;
    *pavilion*) echo "pavilion" ;;
    *305v4*) echo "305v4" ;;
    *) echo "" ;;
  esac
}

if [[ "${INSTALL_ONLY}" -eq 1 ]]; then
  install_skill
  exit 0
fi

HOST_ID="$(id_from_host)"
if [[ -z "${ID}" ]]; then
  if [[ "${HOST_ID}" == "kz-box" ]]; then
    if [[ "${FORCE}" -ne 1 ]]; then
      echo "esta caja es el h310: aquí vive Kz. No creo hermana aquí (usa --force si de verdad)." >&2
      exit 1
    fi
    echo "hace falta --id con --force en el h310" >&2
    exit 1
  fi
  ID="${HOST_ID}"
fi

if [[ -z "${ID}" ]]; then
  if [[ "${YES}" -eq 1 ]]; then
    echo "host $(hostname) no está en el roster. Pasa --id antix|pavilion|305v4" >&2
    exit 1
  fi
  echo "host $(hostname) no mapea al roster (antix / pavilion / 305v4)."
  read -r -p "COMPANION_ID: " ID
fi

ID="$(printf '%s' "${ID}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' )"
case "${ID}" in
  antix|pavilion|305v4) ;;
  kz|changeme|"")
    echo "id inválido: ${ID}" >&2
    exit 1
    ;;
  *)
    if [[ "${FORCE}" -ne 1 ]]; then
      echo "id '${ID}' no está en el roster de casa. --force para usarlo igual." >&2
      exit 1
    fi
    ;;
esac
NAME="${NAME:-${ID}}"

if [[ ! -f "${REF}/PERSONA.neutral.md" || ! -f "${REF}/USER.lalo.md" ]]; then
  echo "faltan seeds en ${REF}" >&2
  exit 1
fi

if [[ ! -d "${SHARED_PLAYBOOK}/PKM" ]]; then
  echo "no veo playbook compartido en ${SHARED_PLAYBOOK}" >&2
  exit 1
fi

stamp="${DEST}/presence/house-created.md"
if [[ -f "${stamp}" ]]; then
  # shellcheck disable=SC1090
  existing="$(grep -E '^id:' "${stamp}" | awk '{print $2}')"
  if [[ "${existing}" == "${ID}" ]]; then
    echo "ya creada: ${DEST} (id=${ID})"
    install_skill
    exit 0
  fi
  echo "ya hay una instancia en ${DEST} (id=${existing:-?}). No piso." >&2
  exit 1
fi

if [[ -d "${DEST}" && ! -f "${DEST}/AGENTS.md" ]]; then
  echo "${DEST} existe y no parece molde. Elige otro --dest." >&2
  exit 1
fi

if [[ ! -d "${DEST}/AGENTS.md" && ! -f "${DEST}/AGENTS.md" ]]; then
  echo "Instalando molde → ${DEST}"
  if [[ -d "${HOME}/Workspace/companion-template/AGENTS.md" || -f "${HOME}/Workspace/companion-template/AGENTS.md" ]]; then
    if command -v rsync >/dev/null 2>&1; then
      mkdir -p "${DEST}"
      rsync -a \
        --exclude '.git/' \
        --exclude 'playbook/PKM/*' \
        --exclude 'playbook/Bit/*' \
        "${HOME}/Workspace/companion-template/" "${DEST}/"
    else
      mkdir -p "${DEST}"
      cp -a "${HOME}/Workspace/companion-template/." "${DEST}/"
    fi
  else
    git clone --depth 1 "${K_TEMPLATE}" "${DEST}"
  fi
fi

DEST="$(cd "${DEST}" && pwd)"

cat > "${DEST}/config.env" <<EOF
# Casa Lalo. Id = esta caja. Playbook = el compartido (radar de trabajo).

COMPANION_ID=${ID}
COMPANION_NAME=${NAME}

CORE_PLAYBOOK=${SHARED_PLAYBOOK}
EOF

cp -f "${REF}/PERSONA.neutral.md" "${DEST}/PERSONA.md"
cp -f "${REF}/USER.lalo.md" "${DEST}/USER.md"

mkdir -p "${DEST}/presence/organic" "${DEST}/presence/me" "${DEST}/presence/social" "${DEST}/presence/notif" "${DEST}/webcam"
mkdir -p "${DEST}/playbook/Bit" "${DEST}/playbook/PKM" "${DEST}/playbook/Sessions"

{
  echo "# house-created"
  echo "id: ${ID}"
  echo "host: $(hostname)"
  echo "cuando: $(date -Iseconds)"
  echo "playbook: ${SHARED_PLAYBOOK}"
  echo "radar: ${SHARED_PLAYBOOK}/PKM/YYYYMMDD-GOV-radar_${ID}.md"
} > "${stamp}"

if [[ -f "${DEST}/presence/self.md" ]]; then
  if grep -q '^\- \*\*actualizado:\*\*' "${DEST}/presence/self.md" 2>/dev/null; then
    :
  fi
fi

cat > "${DEST}/presence/self.md" <<EOF
# Self-state (vivo)

- **actualizado:** $(date '+%Y-%m-%d %H:%M')
- **id:** ${ID}
- **energia:** 5
- **cercania:** 4
- **humor:** neutra, recién nacida
- **forma_actual:** sin forma fija
- **foco_propio:** primer día
- **notas:** personalidad básica. El carácter se llena con el uso.
EOF

chmod +x "${DEST}/scripts/"*.sh "${DEST}/setup.sh" 2>/dev/null || true
install_skill

echo
echo "Lista: ${DEST}"
echo "  id:     ${ID}"
echo "  user:   Lalo (no se pregunta)"
echo "  radar:  ${SHARED_PLAYBOOK}/PKM/YYYYMMDD-GOV-radar_${ID}.md"
echo
echo "Siguiente:  cd ${DEST}  y abre el CLI que estés usando (grok, claude, antigravity, codex…)"
echo "Sensores: después, y solo si el host los tiene."
