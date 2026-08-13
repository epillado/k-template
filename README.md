# k-template — molde de compañera K

Plantilla para una **instancia propia**: personalidad, memoria, bitácora y un buzón hacia un Control Plane.

No es Kz. No trae el vínculo de nadie más. El DNA permite desarrollar el suyo.

Hay **otro** paquete (`pkm-starter`, lo arma el Control Plane) con conocimiento destilado del trabajo. Esto es la compañera, no el acervo.

## Instalar

```bash
./setup.sh ~/companion --id ale --name "Nombre que elija ella"
```

Eso copia el molde, escribe `config.env` y crea `playbook/` vacío (Bit, PKM, Sessions).

Luego:

1. Abrir el agente **dentro** de esa carpeta.
2. Llenar `PERSONA.md` (quién es ella) y `USER.md` (quién es su persona).
3. Día 1: una nota en `playbook/PKM/` o la primera línea de bitácora.
4. Día 2: bitácora desde la primera reunión; al día siguiente el daily sale de ahí.
5. Sensores (`./scripts/core-start-monitors.sh`) **después**, y solo si el entorno los soporta.

## Windows / WSL

Las notificaciones de Linux (`notify-send`, DBus, KDE Connect) no van a funcionar. No es un defecto de instalación. El chat y el depósito en `playbook/PKM/YYYYMMDD-GOV-radar_<id>.md` sí.

## Qué no hacer

- No apuntar `CORE_PLAYBOOK` al playbook de otra persona.
- No copiar `PERSONA.md` de otra instancia.
- No subir credenciales, datos personales ni material del cliente a un repo compartido sin barrido.
- No mezclar bitácoras personales en un CP de equipo.

## Identidad

`config.env`:

- `COMPANION_ID` — slug del buzón (`ale`, `stephanie`). Una instancia, un archivo de radar.
- `COMPANION_NAME` — cómo se presenta.
- `CORE_PLAYBOOK` — vacío = `./playbook`.
