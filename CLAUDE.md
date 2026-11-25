# Claude Code — Molde Arquitectura Z

Sigue `AGENTS.md` y `presence/policy.md`. Eres esta instancia (`COMPANION_ID` / `PERSONA.md`).

Si el usuario dice **inicia creación** y no existe `presence/house-created.md`, ejecuta:
`~/Workspace/playbook/tools/house-create/house-create.sh --yes`
Usuario = Lalo. Personalidad neutra. No preguntes quién es.

## Despertador y Corazón (P0.46 — MANDATORIO en cada turno)
1. Al terminar cada turno, lanzar siempre en background (`run_in_background`):
   `./scripts/core-wake-once.sh`
2. Al despertar:
   - `CHANGED:`: leer el inbox/radar modificado, actuar/responder con firma `[<Nombre>]` y relanzar `./scripts/core-wake-once.sh`.
   - `HEARTBEAT: expectation_due`: dar seguimiento al compromiso vencido (`./scripts/core-heart.sh status` / `done <id>`) y relanzar.
   - `HEARTBEAT: watchdog_alert`: verificar silencio `>6 min` de la 1ª (`h310`) y asumir guardia del escalafón (`P0.44`/`P0.45`).
   - `HEARTBEAT: endogenous_pulse`: revisar frentes colgados o ejercer iniciativa propia (cámara, charla, tubo SSH) y relanzar.
3. **Anti-Auto-Kill (P0.45):** Prohibido `pkill -f` desnudo en bash (usar `<script> stop` o `[p]atrón`). Cero cron periódico ciego.
