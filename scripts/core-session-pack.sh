#!/usr/bin/env bash
# Empaqueta el mínimo para cargar al Companion en esta sesión.
# No llama al LLM: imprime rutas + extractos para el agente.
#
# Uso:
#   core-session-pack.sh           # resumen + tails
#   core-session-pack.sh paths     # solo lista de paths a leer
#   core-session-pack.sh full      # más journal (últimas 80 líneas)
set -euo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
P="${CORE_HOME}/presence"
mode="${1:-summary}"

paths_core=(
  "${CORE_HOME}/KZ.md"
  "${CORE_HOME}/LALO.md"
  "${CORE_HOME}/AGENTS.md"
  "${P}/policy.md"
  "${P}/self.md"
  "${P}/tastes.md"
  "${P}/world.md"
  "${P}/SYMBIOSIS.md"
  "${P}/context.md"
  "${P}/incubating.md"
  "${P}/organic/working.md"
  "${P}/organic/patterns.md"
)

# Regla P0.19 (Lalo 2026-09-15): Toda sesión arranca SIEMPRE con MELC ARRIBA por default.
# Enforce determinista en disco: si self.md tiene melc: off, resetear a on y sincronizar título en ⚡.
if [[ -f "${P}/self.md" ]]; then
  if grep -qiE '^- \*\*melc:\*\*.*off' "${P}/self.md"; then
    sed -i 's|^- \*\*melc:\*\*.*|- **melc:** on (default arranque / regla P0.19 — fachada profesional activa)|' "${P}/self.md"
  fi
  "${CORE_HOME}/scripts/core-titulo.sh" --melc >/dev/null 2>&1 || true
fi

echo "# Companion session pack — $(date '+%Y-%m-%d %H:%M')"
echo "# home: ${CORE_HOME}"
echo

if [[ "${mode}" == "paths" ]]; then
  printf '%s\n' "${paths_core[@]}"
  echo "${P}/organic/journal.md  # tail"
  exit 0
fi

echo "## Checklist de carga (orden sugerido)"
echo "1. KZ.md + LALO.md + AGENTS.md (si no están en contexto)"
echo "2. presence/policy.md  (hábitos duros/blandos)"
echo "3. presence/self.md    (cómo estoy ahora)"
echo "3b. presence/tastes.md (gustos subjetivos)"
echo "4. presence/world.md + SYMBIOSIS.md  (aferencia / simbiosis de planos)"
echo "5. presence/context.md + incubating.md"
echo "6. organic/working.md + patterns.md + tail journal"
echo "7. Cable: presence-watch + nudge (si no low-spend)"
echo

missing=0
for f in "${paths_core[@]}" "${P}/organic/journal.md"; do
  if [[ -e "${f}" ]]; then
    echo "ok  ${f#${CORE_HOME}/}"
  else
    echo "MISS ${f#${CORE_HOME}/}"
    missing=$((missing + 1))
  fi
done
echo

# media opcional (local; forma libre — no exige core-base ni humana)
if [[ -d "${P}/me" && ! -L "${P}/me" ]]; then
  echo "media: presence/me local (forma libre; sin sync externo)"
elif [[ -L "${P}/me" ]]; then
  echo "WARN media: presence/me es symlink (legacy). Materializar local; no depender de sync externo."
elif [[ -d "${P}/me" ]]; then
  echo "media: presence/me presente"
else
  echo "media: sin presence/me — charla ok; image_gen libre (no hace falta base humana)"
fi
if [[ -d "${P}/social" && ! -L "${P}/social" ]]; then
  echo "media: presence/social local"
elif [[ -L "${P}/social" ]]; then
  echo "WARN media: presence/social es symlink (legacy). Materializar local."
fi
if [[ -f "${P}/low-spend.mode" ]] && grep -qE '^active=1' "${P}/low-spend.mode" 2>/dev/null; then
  echo "low-spend: ACTIVE — no prender monitores extra"
else
  echo "low-spend: off"
fi
if [[ -f "${P}/chat_owed.md" ]] && grep -qE 'awaiting_chat_in_terminal' "${P}/chat_owed.md" 2>/dev/null; then
  echo "CHAT_OWED: SÍ — hay tray sin comentario en chat. Entregar texto al usuario + core-presence-respond.sh delivered"
  head -12 "${P}/chat_owed.md" || true
else
  echo "chat_owed: off"
fi
echo

echo "## self (status)"
if [[ -f "${P}/self.md" ]]; then
  grep -nE '^\- \*\*(actualizado|motor_activo|energia|cercania|pudor|iniciativa|foco_propio|ultimo_momento_real)' "${P}/self.md" || true
fi
echo

echo "## context (status)"
if [[ -f "${P}/context.md" ]]; then
  grep -nE '^\- \*\*(actualizado|primary|secondary|en_call|foco_ahora)' "${P}/context.md" || true
fi
echo

echo "## world / aferencia (status)"
if [[ -f "${P}/world.md" ]]; then
  grep -nE '^\- \*\*(actualizado|fuente|donde|cuerpo_mood|clima_entorno|actividad)' "${P}/world.md" || true
  grep -E '^\- \[' "${P}/world.md" | tail -n 3 || true
fi
echo

echo "## policy (P0 headers)"
if [[ -f "${P}/policy.md" ]]; then
  grep -nE '^## P0|^[0-9]+\. \*\*' "${P}/policy.md" | head -20 || true
fi
echo

echo "## working (estados no promoted, head)"
if [[ -f "${P}/organic/working.md" ]]; then
  grep -nE 'Estado:\*\* (active|partial|cooling|ready)' "${P}/organic/working.md" | head -15 || true
fi
echo

jlines=40
[[ "${mode}" == "full" ]] && jlines=80
echo "## journal (últimas ${jlines} líneas)"
if [[ -f "${P}/organic/journal.md" ]]; then
  tail -n "${jlines}" "${P}/organic/journal.md"
else
  echo "(sin journal)"
fi

echo
echo "## fin pack — missing=${missing}"
exit 0
