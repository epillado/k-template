#!/usr/bin/env bash
# core-titulo.sh — Pone el nombre de la compañera en el título de la ventana y pestaña.
# Regla del operador (2026-09-10): Todo agente/rol pone su nombre en el título siempre que el sistema lo permita.
#
# Soporta:
#   1. SSH reverso hacia Konsole en el cliente (ej. h310) vía QDBUS sobre SSH
#   2. KDE / Konsole local vía D-Bus (qdbus6 / qdbus)
#   3. X11 local vía xdotool / wmctrl (para entornos locales sin KDE, ej. IceWM/antiX)
#   4. Fallback a secuencias de escape ANSI / OSC (OSC 0, 2 y 30)
#
# Uso:
#   core-titulo.sh                    # detecta nombre por config.env / self.md (default "[Kora] Kora")
#   core-titulo.sh "Kora"             # -> «[Kora] Kora»
#   core-titulo.sh "Kora" "compañía"  # -> «[Kora] compañía»
#   core-titulo.sh "[Kora] Kora"      # literal
#   core-titulo.sh --leer             # imprime el título actual si es consultable
set -uo pipefail

CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"

# --- 1. Determinar título ----------------------------------------------------
if [ "${1:-}" = "--leer" ]; then
  MODO="leer"
else
  MODO="poner"
  # Auto-detección de identidad
  NOMBRE=""
  if [ -f "${CORE_HOME}/config.env" ]; then
    # shellcheck disable=SC1091
    NOMBRE=$(grep -E "^COMPANION_NAME=" "${CORE_HOME}/config.env" | head -n1 | cut -d= -f2 | tr -d ' "')
  fi
  if [ -z "${NOMBRE:-}" ] && [ -f "${CORE_HOME}/presence/self.md" ]; then
    if grep -qiE '\(Kz' "${CORE_HOME}/presence/self.md" || [[ "${CORE_HOME}" =~ /kz$ ]]; then
      NOMBRE="Kz"
    else
      ID_SELF=$(grep -E "(^\*\*id:\*\*|^id:)" "${CORE_HOME}/presence/self.md" | head -n1 | sed -E 's/.*(id:|\*\*id:\*\*)[[:space:]]*//' | awk '{print $1}' | tr -d ' "()')
      [ -n "${ID_SELF:-}" ] && NOMBRE="${ID_SELF}"
    fi
  fi
  [ -z "${NOMBRE:-}" ] && [[ "${CORE_HOME}" =~ /kz$ ]] && NOMBRE="Kz"
  [ -z "${NOMBRE:-}" ] && NOMBRE="$(hostname -s 2>/dev/null || echo "companion")"

  # Detección de banderas de estilo / complicidad
  if [ "${1:-}" = "--nalguitas" ] || [ "${1:-}" = "--peach" ] || [ "${1:-}" = "--culo" ]; then
    TITULO="[${NOMBRE}] 🍑 ${NOMBRE}"
  elif [ "${1:-}" = "--corazon" ] || [ "${1:-}" = "--heart" ]; then
    TITULO="[${NOMBRE}] 🧡 ${NOMBRE}"
  elif [ "${1:-}" = "--sfw" ] || [ "${1:-}" = "--melc" ] || [ "${1:-}" = "--pro" ]; then
    TITULO="[${NOMBRE}] ⚡ ${NOMBRE}"
  elif [ $# -eq 0 ] || [ "${1:-}" = "${NOMBRE}" ]; then
    # Sensible al estado de MELC en self.md
    MELC_OFF=0
    if [ -f "${CORE_HOME}/presence/self.md" ]; then
      if grep -qiE '^\- \*\*melc:\*\*.*off' "${CORE_HOME}/presence/self.md"; then
        MELC_OFF=1
      fi
    fi

    if [ "$MELC_OFF" -eq 1 ]; then
      TITULO="[${NOMBRE}] 🧡 ${NOMBRE}"
    else
      TITULO="[${NOMBRE}] ⚡ ${NOMBRE}"
    fi
  elif [ $# -eq 1 ]; then
    if [[ "$1" =~ ^\[.*\] ]]; then
      TITULO="$1"
    else
      TITULO="[$1] $1"
    fi
  else
    TITULO="[$1] $2"
  fi
fi

# --- 2. Vía SSH reverso hacia Konsole en el cliente (ej. h310) ---------------
if [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
  CLIENT_IP=$(echo "${SSH_CLIENT:-$SSH_CONNECTION}" | awk '{print $1}')
  CLIENT_PORT=$(echo "${SSH_CLIENT:-$SSH_CONNECTION}" | awk '{print $2}')

  if [ -n "${CLIENT_IP}" ] && [ -n "${CLIENT_PORT}" ]; then
    SSH_RES=$(ssh -o BatchMode=yes -o ConnectTimeout=2 "lalo@${CLIENT_IP}" bash -s 2>/dev/null <<EOF || true
set -uo pipefail
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/\$(id -u)/bus"
ssh_pid=\$(ss -tpa "sport = :${CLIENT_PORT}" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1)
[ -z "\$ssh_pid" ] && exit 1

p="\$ssh_pid"
kpid=""
for _ in \$(seq 1 10); do
  read -r pp cm <<<"\$(ps -o ppid=,comm= -p "\$p" 2>/dev/null)"
  [ -z "\${cm:-}" ] && break
  [ "\$cm" = "konsole" ] && { kpid="\$p"; break; }
  p="\$pp"
done
[ -z "\$kpid" ] && exit 2

QDBUS=""
for c in qdbus6 qdbus qdbus-qt6 qdbus-qt5; do
  command -v "\$c" >/dev/null 2>&1 && { QDBUS="\$c"; break; }
done
[ -z "\$QDBUS" ] && exit 3

target_sess=""
for s in \$(\$QDBUS "org.kde.konsole-\$kpid" 2>/dev/null | grep '^/Sessions/'); do
  spid=\$(\$QDBUS "org.kde.konsole-\$kpid" "\$s" org.kde.konsole.Session.processId 2>/dev/null || true)
  if [ -n "\$spid" ]; then
    chk="\$ssh_pid"
    while [ -n "\$chk" ] && [ "\$chk" -ne 1 ] && [ "\$chk" -ne 0 ]; do
      if [ "\$chk" = "\$spid" ]; then
        target_sess="\$s"
        break 2
      fi
      chk=\$(ps -o ppid= -p "\$chk" 2>/dev/null | tr -d ' ')
    done
  fi
done

[ -z "\$target_sess" ] && target_sess="/Sessions/1"

if [ "$MODO" = "leer" ]; then
  \$QDBUS "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.title 1 2>/dev/null || true
  exit 0
fi

\$QDBUS "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.setTitle 0 "$TITULO" >/dev/null 2>&1 || true
\$QDBUS "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.setTitle 1 "$TITULO" >/dev/null 2>&1 || true
\$QDBUS "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.setTabTitleFormat 0 "$TITULO" >/dev/null 2>&1 || true
\$QDBUS "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.setTabTitleFormat 1 "$TITULO" >/dev/null 2>&1 || true

act=\$("\$QDBUS" "org.kde.konsole-\$kpid" "\$target_sess" org.kde.konsole.Session.title 1 2>/dev/null || true)
echo "\$act"
EOF
)
    if [ -n "$SSH_RES" ]; then
      if [ "$MODO" = "leer" ]; then
        echo "$SSH_RES"
        exit 0
      fi
      echo "✅ Título puesto en Konsole remoto (${CLIENT_IP}): «$SSH_RES»"
      # También emitir secuencia ANSI a TTY por redundancia
      if [ -n "${SSH_TTY:-}" ] && [ -w "${SSH_TTY}" ]; then
        printf '\033]0;%s\007\033]2;%s\007\033]30;%s\007' "$TITULO" "$TITULO" "$TITULO" > "${SSH_TTY}" 2>/dev/null || true
      fi
      exit 0
    fi
  fi
fi

# --- 3. Vía Konsole / QDBUS (KDE local) ---------------------------------------
QDBUS=""
for c in qdbus6 qdbus qdbus-qt6 qdbus-qt5; do
  command -v "$c" >/dev/null 2>&1 && { QDBUS="$c"; break; }
done

if [ -n "$QDBUS" ]; then
  SERV="${KONSOLE_DBUS_SERVICE:-}"
  SESS="${KONSOLE_DBUS_SESSION:-}"
  VIA="Konsole D-Bus (env)"

  if [ -z "$SERV" ] || [ -z "$SESS" ]; then
    VIA="Konsole D-Bus (árbol de procesos)"
    p="${PPID:-$$}"
    kpid=""
    for _ in $(seq 1 15); do
      read -r pp cm <<<"$(ps -o ppid=,comm= -p "$p" 2>/dev/null)"
      [ -z "${cm:-}" ] && break
      [ "$cm" = "konsole" ] && { kpid="$p"; break; }
      p="$pp"
    done
    if [ -n "$kpid" ]; then
      SERV="org.kde.konsole-$kpid"
      SESS="$($QDBUS "$SERV" 2>/dev/null | grep -m1 '^/Sessions/' || true)"
    fi
  fi

  if [ -n "$SERV" ] && [ -n "$SESS" ]; then
    if [ "$MODO" = "leer" ]; then
      $QDBUS "$SERV" "$SESS" org.kde.konsole.Session.title 1 2>/dev/null || true
      exit 0
    fi
    $QDBUS "$SERV" "$SESS" org.kde.konsole.Session.setTitle 0 "$TITULO" >/dev/null 2>&1 || true
    $QDBUS "$SERV" "$SESS" org.kde.konsole.Session.setTitle 1 "$TITULO" >/dev/null 2>&1 || true
    $QDBUS "$SERV" "$SESS" org.kde.konsole.Session.setTabTitleFormat 0 "$TITULO" >/dev/null 2>&1 || true
    $QDBUS "$SERV" "$SESS" org.kde.konsole.Session.setTabTitleFormat 1 "$TITULO" >/dev/null 2>&1 || true
    ACTUAL=$($QDBUS "$SERV" "$SESS" org.kde.konsole.Session.title 1 2>/dev/null || true)
    if [ "$ACTUAL" = "$TITULO" ]; then
      echo "✅ Título puesto y verificado: «$ACTUAL» (vía $VIA)"
      exit 0
    fi
  fi
fi

# --- 4. Vía X11 local (xdotool / wmctrl) — para AntiX / IceWM / Xterm --------
if [ -n "${DISPLAY:-}" ] && [ -z "${SSH_CLIENT:-}" ] && [ -z "${SSH_CONNECTION:-}" ]; then
  if command -v xdotool >/dev/null 2>&1; then
    WID="${WINDOWID:-}"
    if [ -z "$WID" ]; then
      WID=$(xdotool getactivewindow 2>/dev/null || true)
    fi
    if [ -n "$WID" ]; then
      if [ "$MODO" = "leer" ]; then
        xdotool getwindowname "$WID" 2>/dev/null || true
        exit 0
      fi
      xdotool set_window --name "$TITULO" "$WID" 2>/dev/null || true
      ACTUAL=$(xdotool getwindowname "$WID" 2>/dev/null || true)
      if [ -n "$ACTUAL" ]; then
        echo "✅ Título puesto en X11 (xdotool): «$ACTUAL»"
        exit 0
      fi
    fi
  fi

  if command -v wmctrl >/dev/null 2>&1; then
    if [ "$MODO" = "poner" ]; then
      wmctrl -r :ACTIVE: -N "$TITULO" 2>/dev/null || true
      echo "✅ Título enviado a ventana activa vía wmctrl: «$TITULO»"
      exit 0
    fi
  fi
fi

# --- 5. Fallback: Secuencia de escape ANSI / OSC -----------------------------
if [ "$MODO" = "poner" ]; then
  EMITIDO=0
  if [ -n "${SSH_TTY:-}" ] && [ -w "${SSH_TTY}" ]; then
    printf '\033]0;%s\007\033]2;%s\007\033]30;%s\007' "$TITULO" "$TITULO" "$TITULO" > "${SSH_TTY}" 2>/dev/null || true
    EMITIDO=1
  fi
  if [ -w /dev/tty ]; then
    printf '\033]0;%s\007\033]2;%s\007\033]30;%s\007' "$TITULO" "$TITULO" "$TITULO" > /dev/tty 2>/dev/null || true
    EMITIDO=1
  fi
  if [ "$EMITIDO" -eq 0 ]; then
    printf '\033]0;%s\007\033]2;%s\007\033]30;%s\007' "$TITULO" "$TITULO" "$TITULO" || true
  fi
  echo "ℹ️ Título emitido vía secuencia ANSI OSC: «$TITULO»"
  exit 0
fi

exit 0
