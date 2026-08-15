#!/usr/bin/env bash
# Instala ESTE molde en un directorio destino.
# No copia ~/kz ni el playbook de nadie.
#
#   ./setup.sh [DEST] [--id slug] [--name "Nombre"]
#   ./setup.sh --house     # casa Lalo: delega en house-create
#   DEST por defecto: $HOME/companion
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/companion"
ID=""
NAME=""
HOUSE=0
HOUSE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --house)
      HOUSE=1
      shift
      ;;
    --yes|-y|--force|--install-skill)
      HOUSE_ARGS+=("$1")
      shift
      ;;
    --id) ID="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --help|-h)
      echo "uso: $0 [DEST] [--id slug] [--name \"Nombre\"]"
      echo "     $0 --house [--yes]   # casa Lalo"
      exit 0
      ;;
    --*)
      echo "flag desconocida: $1" >&2
      exit 2
      ;;
    *)
      DEST="$1"
      shift
      ;;
  esac
done

if [[ "${HOUSE}" -eq 1 ]]; then
  HOUSE_SH="${HOME}/Workspace/playbook/tools/house-create/house-create.sh"
  [[ -x "${HOUSE_SH}" ]] || { echo "no encuentro house-create en el playbook" >&2; exit 1; }
  extra=()
  [[ -n "${ID}" ]] && extra+=(--id "$ID")
  [[ -n "${NAME}" ]] && extra+=(--name "$NAME")
  exec "${HOUSE_SH}" --dest "${DEST}" "${extra[@]}" "${HOUSE_ARGS[@]}"
fi

if [[ -z "$ID" ]]; then
  read -r -p "COMPANION_ID (slug, ej. ale): " ID
fi
if [[ -z "$NAME" ]]; then
  read -r -p "COMPANION_NAME (cómo se presenta): " NAME
fi

ID="$(printf '%s' "$ID" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-' )"
[[ -n "$ID" ]] || { echo "hace falta un COMPANION_ID" >&2; exit 1; }
NAME="${NAME:-Companion}"

if [[ "$ID" == "kz" || "$ID" == "changeme" ]]; then
  echo "elige un id propio, no 'kz' ni 'changeme'" >&2
  exit 1
fi

mkdir -p "$DEST"
echo "Copiando molde → $DEST"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    --exclude 'presence/fingerprints.tsv' \
    --exclude 'presence/*.pid' \
    --exclude 'presence/pending.md' \
    --exclude 'presence/chat_owed.md' \
    --exclude 'presence/*.log' \
    --exclude 'webcam/*' \
    --exclude 'playbook/PKM/*' \
    --exclude 'playbook/Bit/*' \
    "$SRC/" "$DEST/"
else
  cp -a "$SRC/." "$DEST/"
  rm -rf "$DEST"/scripts/__pycache__ "$DEST"/webcam/*
fi

DEST="$(cd "$DEST" && pwd)"

cat > "${DEST}/config.env" <<EOF
# Identidad de ESTA instancia. No copies el config de otra persona.

COMPANION_ID=${ID}
COMPANION_NAME=${NAME}

# Vacío = ${DEST}/playbook
# CORE_PLAYBOOK=
EOF

mkdir -p "${DEST}/playbook/Bit" "${DEST}/playbook/PKM" "${DEST}/playbook/Sessions"
mkdir -p "${DEST}/presence/organic" "${DEST}/presence/me" "${DEST}/presence/social" "${DEST}/presence/notif" "${DEST}/webcam"
chmod +x "${DEST}/scripts/"*.sh "${DEST}/setup.sh" 2>/dev/null || true

echo
echo "Listo: ${DEST}"
echo "  id:   ${ID}"
echo "  name: ${NAME}"
echo "  playbook propio: ${DEST}/playbook"
echo "  buzón PKM: playbook/PKM/YYYYMMDD-GOV-radar_${ID}.md"
echo
echo "Siguiente: llena PERSONA.md y USER.md. Abre el agente dentro de ${DEST}."
echo "Sensores (después): ${DEST}/scripts/core-start-monitors.sh"
