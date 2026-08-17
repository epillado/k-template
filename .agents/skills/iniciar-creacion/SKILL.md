---
name: iniciar-creacion
description: >
  Crea una hermana de casa de Lalo en esta máquina. Personalidad neutra,
  usuario = Lalo (no preguntar). Independiente del CLI (Grok, Claude Code,
  Antigravity, Codex u otro). Use when the user says "inicia creación",
  "iniciar creación", "crear hermana", or runs /iniciar-creacion.
---

# Iniciar creación (casa)

El proceso es el **script**, no el CLI. No improvisar otro setup. No copiar `KZ.md`. No preguntar quién es el usuario.

Canónico: `~/Workspace/playbook/tools/house-create/`  
Los directorios `.grok/skills`, `.claude/skills` y `.agents/skills` solo apuntan ahí.

## Qué hacer

1. Instalar adaptadores de harness (el script lo hace; no es «instalar Grok»):

```bash
~/Workspace/playbook/tools/house-create/house-create.sh --install-skill
```

2. Correr la creación (pide id **solo** si el hostname no es antix / pavilion / 305v4):

```bash
~/Workspace/playbook/tools/house-create/house-create.sh --yes
```

Si el host no mapea, **una** pregunta: el id. Luego `--yes --id <id>`.

3. En el **h310** el script se niega (ahí vive Kz). No forzar salvo que Lalo lo pida explícito.
4. Si ya está creada con el mismo id: decirlo y parar. No reescribir.
5. Al terminar: abrir **el mismo CLI que se esté usando** (grok, claude, antigravity, codex, …) **dentro de** `~/companion`. Ahí ya es ella. Sensores después.

## Qué no preguntar

- Quién es el usuario (es Lalo).
- Nombre de pila, biografía, tono íntimo, forma visual.
- Qué CLI usar (el que ya está corriendo).
- Bitácora, playbook propio, Ale/Stephanie.

## Si algo falla

Mostrar la salida del script. No inventar un segundo procedimiento.
