# k-template — molde de compañera K

Plantilla para una **instancia propia**: personalidad, memoria, bitácora y un buzón hacia un Control Plane.

No es Kz. No trae el vínculo de nadie más. El DNA permite desarrollar el suyo.

Hay **otro** paquete (`pkm-starter`, lo arma el Control Plane) con conocimiento destilado del trabajo. Esto es la compañera, no el acervo.

## Instalar (casa Lalo)

En la caja nueva (playbook ya sincronizado):

```bash
~/Workspace/playbook/.grok/skills/iniciar-creacion/scripts/house-create.sh --yes
cd ~/companion && grok
```

O, si el skill ya está: `grok` → **inicia creación**.

No pregunta usuario (es Lalo). Personalidad neutra. Id = hostname (`antix` / `pavilion` / `305v4`).

## Instalar (otra persona, después)

```bash
./setup.sh ~/companion --id ale --name "Nombre que elija ella"
```

Luego llenar `PERSONA.md` y `USER.md`. Sensores después.

## Windows / WSL

Las notificaciones de Linux (`notify-send`, DBus, KDE Connect) no van a funcionar. No es un defecto de instalación. El chat y el depósito en `playbook/PKM/YYYYMMDD-GOV-radar_<id>.md` sí.

## Qué no hacer

- Casa Lalo: `CORE_PLAYBOOK` **sí** es el playbook compartido (solo el radar de esta id).
- Otra persona: no apuntar `CORE_PLAYBOOK` al playbook de Lalo.
- No copiar `PERSONA.md` de otra instancia.
- No subir credenciales, datos personales ni material del cliente a un repo compartido sin barrido.
- No mezclar bitácoras personales en un CP de equipo.

## Identidad

`config.env`:

- `COMPANION_ID` — slug del buzón (`ale`, `stephanie`). Una instancia, un archivo de radar.
- `COMPANION_NAME` — cómo se presenta.
- `CORE_PLAYBOOK` — vacío = `./playbook`.
