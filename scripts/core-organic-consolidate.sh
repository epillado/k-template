#!/usr/bin/env bash
# Pase de consolidación (“sueño” ligero) — MVP.
# No llama a un LLM: prepara un paquete para que el Companion revise y promueva.
#
# Uso:
#   core-organic-consolidate.sh           # escribe presence/organic/consolidate-pending.md
#   core-organic-consolidate.sh --nudge   # + tray pidiendo voltear al chat
#   core-organic-consolidate.sh clear     # marca consolidación atendida
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
ORG="${CORE_HOME}/presence/organic"
OUT="${ORG}/consolidate-pending.md"
ts="$(date -Iseconds)"
human="$(date '+%Y-%m-%d %H:%M')"

mkdir -p "${ORG}"

if [[ "${1:-}" == "clear" ]]; then
  if [[ -f "${OUT}" ]]; then
    {
      echo
      echo "---"
      echo "cleared: ${human}"
    } >> "${OUT}"
    mv -f "${OUT}" "${ORG}/consolidate-last.md"
  fi
  echo "consolidate: cleared → consolidate-last.md"
  exit 0
fi

{
  echo "# Consolidación pendiente — ${human}"
  echo
  echo "- **cuando:** ${ts}"
  echo "- **estado:** awaiting_kz_pass"
  echo
  echo "El Companion debe (en un turno con headspace, no en medio de P0 ajeno):"
  echo "1. Revisar **journal** reciente y **working** activos."
  echo "2. Revisar **patterns** (confianza low→medium si hay anclas)."
  echo "3. Revisar **incubating** open/cooking."
  echo "4. Proponer o aplicar: promotes, discards, updates a context.md."
  echo "5. Anotar en journal lo consolidado; \`core-organic-consolidate.sh clear\`."
  echo "6. Si hay idea proactiva de verdad (no relleno), chat + nudge."
  echo
  echo "---"
  echo
  echo "## context (ahora)"
  echo
  echo '```'
  if [[ -f "${CORE_HOME}/presence/context.md" ]]; then
    head -n 40 "${CORE_HOME}/presence/context.md"
  else
    echo "(sin context.md)"
  fi
  echo '```'
  echo
  echo "## working (activos / no promoted)"
  echo
  echo '```'
  if [[ -f "${ORG}/working.md" ]]; then
    # líneas de headers W y estado
    rg -n '^### |^\- \*\*Estado:\*\*' "${ORG}/working.md" | head -n 80 || true
  fi
  echo '```'
  echo
  echo "## journal (tail)"
  echo
  echo '```'
  if [[ -f "${ORG}/journal.md" ]]; then
    tail -n 40 "${ORG}/journal.md"
  fi
  echo '```'
  echo
  echo "## incubating"
  echo
  echo '```'
  if [[ -f "${CORE_HOME}/presence/incubating.md" ]]; then
    cat "${CORE_HOME}/presence/incubating.md"
  fi
  echo '```'
  echo
  echo "## patterns (tail headers)"
  echo
  echo '```'
  if [[ -f "${ORG}/patterns.md" ]]; then
    rg -n '^## ' "${ORG}/patterns.md" || true
  fi
  echo '```'
} > "${OUT}"

echo "consolidate: wrote ${OUT}"

if [[ "${1:-}" == "--nudge" ]]; then
  "${CORE_HOME}/scripts/core-nudge.sh" --say "Tengo un pase de consolidación listo (organic). Cuando puedas, lo reviso contigo o sola."
fi
