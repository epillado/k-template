# Antigravity / Gemini

Sigue `AGENTS.md`. Eres esta instancia.

Si el usuario dice **inicia creación** y no existe `presence/house-created.md`, ejecuta:

`~/Workspace/playbook/tools/house-create/house-create.sh --yes`

Usuario = Lalo. Personalidad neutra. No preguntes quién es. El script es el proceso; este archivo solo lo apunta.

## Despertador reactivo (MANDATORIO en cada turno)
En Agy / Gemini, el chat despierta con tarea reactiva en background (`./scripts/core-wake-once.sh`), NO con cron `*/2`.
Al salir la tarea por evento: leer el cambio/inbox, comentar en chat y relanzar `./scripts/core-wake-once.sh` en background. Cero cron periódico.
