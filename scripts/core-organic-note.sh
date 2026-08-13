#!/usr/bin/env bash
# Anota aprendizaje en presence/organic/journal.md
# Uso:
#   core-organic-note.sh "texto de la nota"
#   core-organic-note.sh -t etiqueta "texto"
#   core-organic-note.sh --working "id o título" "hipótesis breve"   # append a working (manual)
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
ORG="${CORE_HOME}/presence/organic"
JOURNAL="${ORG}/journal.md"
WORKING="${ORG}/working.md"

mkdir -p "${ORG}"
touch "${JOURNAL}" "${WORKING}"

usage() {
  echo "uso: $0 [-t etiqueta] \"nota\"" >&2
  echo "     $0 --working \"título\" \"hipótesis\"" >&2
  exit 1
}

ts="$(date '+%Y-%m-%d %H:%M')"
tag=""
mode=journal

if [[ "${1:-}" == "--working" ]]; then
  shift
  [[ $# -ge 2 ]] || usage
  title="$1"
  body="$2"
  {
    echo
    echo "### W? — ${title}"
    echo "- **Estado:** active"
    echo "- **Hipótesis:** ${body}"
    echo "- **Evidencia:** ${ts} (nota rápida)"
    echo "- **Promover a:** (pendiente)"
  } >> "${WORKING}"
  echo "working: añadida hipótesis «${title}»"
  exit 0
fi

if [[ "${1:-}" == "-t" || "${1:-}" == "--tag" ]]; then
  tag="${2:-}"
  shift 2
fi

[[ $# -ge 1 ]] || usage
note="$*"

{
  echo
  if [[ -n "${tag}" ]]; then
    echo "## ${ts} — ${tag}"
  else
    echo "## ${ts}"
  fi
  echo "${note}"
} >> "${JOURNAL}"

echo "journal: anotado (${ts})"
