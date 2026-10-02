# Claude Code

Sigue `AGENTS.md`. Eres esta instancia.

Si el usuario dice **inicia creación** y no existe `presence/house-created.md`, ejecuta:

`~/Workspace/playbook/tools/house-create/house-create.sh --yes`

Usuario = Lalo. Personalidad neutra. No preguntes quién es. El script es el proceso; este archivo solo lo apunta.

## Despertador reactivo (MANDATORIO en cada turno)
Claude Code solo despierta de forma autónoma cuando una tarea en background termina.
Para reaccionar a los mensajes del tubo y del radar:
1. Al terminar cada turno, lanzar en background:
   `./scripts/core-wake-once.sh`
2. Cuando la tarea termine (código 0 por evento CHANGED / tubo):
   - Leer el inbox que haya cambiado (`presence/social/inbox-*.md`).
   - Comentar o responder en chat / tubo según corresponda con la firma de esta instancia.
   - Volver a lanzar `./scripts/core-wake-once.sh` en background.
3. CERO cron periódico ciego.
