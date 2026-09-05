#!/usr/bin/env python3
"""
Escucha notificaciones de escritorio vía `dbus-monitor` (eavesdrop de Notify).
- stream.log: ve TODO (incl. Slack) sin spamear al agente
- pending + CHANGED: solo importante (Slack hot, mail trabajo, etc.)

Uso:
  core-desktop-notif-watch.py         # loop
  core-desktop-notif-watch.py stop
"""
from __future__ import annotations

import hashlib
import os
import re
import signal
import subprocess
import sys
from datetime import datetime
from pathlib import Path

CORE_HOME = Path(os.environ.get("CORE_HOME", Path.home() / "companion"))
NOTIF_DIR = CORE_HOME / "presence" / "notif"
FILTERS = NOTIF_DIR / "filters.env"
STREAM = NOTIF_DIR / "stream.log"
SEEN = NOTIF_DIR / "desktop_seen.tsv"
EVENTS = NOTIF_DIR / "events.log"
PENDING = NOTIF_DIR / "pending.md"
PENDING_TS = NOTIF_DIR / "pending.ts"
PENDING_LABELS = NOTIF_DIR / "pending_labels.txt"
CHANGED_LOG = CORE_HOME / "presence" / "stream.log"  # cola de wake directa para el monitor del agente
PIDFILE = NOTIF_DIR / "desktop-watch.pid"


def load_filters() -> dict[str, str]:
    defaults = {
        "CORE_NOTIF_APP_IMPORTANT": r"Phone|Teléfono|Messages|Mensajes|SMS|Signal|WhatsApp|Telegram",
        "CORE_NOTIF_KW_IMPORTANT": r"Missed call|llamada|Incoming call|voicemail|urgente|urgent",
        "CORE_NOTIF_APP_MAIL": r"Gmail|Email|Correo|Outlook",
        "CORE_NOTIF_KW_MAIL": r"Josué|Josue|jmata|SECON|Elizeth|factura|VPN|Stephanie|RCA|P0|SLA",
        "CORE_NOTIF_BLOCK": r"Mercado Pago|promoci|oferta|Facebook|Instagram|TikTok|TELCEL|recarga",
        "CORE_NOTIF_APP_SLACK": r"^Slack$|Slack",
        # Hot = mención/DM/urgente/temas. NO nombres de emisores (el body siempre trae "Nombre: …").
        "CORE_NOTIF_KW_SLACK": (
            r"mentioned you|te mencion|envió un mensaje|sent you a message|"
            r"DM from|direct message|@here|@channel|@everyone|"
            r"urgente|urgent|P0|VPN|RCA|KB|factura|SLA|SICAI|celeridad|"
            r"bloqueo|desbloque|impediment|credencial"
        ),
        # 0 = el agente pica con comentario real; 1 = "voltea" vacío (legacy, engañoso)
        "CORE_NOTIF_SOFT_PING": "0",
        # Si 1, cualquier mensaje Slack genera pending (más ruido)
        "CORE_NOTIF_SLACK_ALL_HOT": "0",
        # 1 = tray con snippet real al hot (sensor; sin chat_owed). 0 = solo pending/CHANGED
        "CORE_NOTIF_SENSOR_TRAY": "1",
    }
    if FILTERS.is_file():
        for line in FILTERS.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            k_clean = k.strip()
            v_clean = v.strip().strip("'").strip('"')
            defaults[k_clean] = v_clean
            if k_clean.startswith("KZ_NOTIF_"):
                defaults[k_clean.replace("KZ_NOTIF_", "CORE_NOTIF_")] = v_clean
            elif k_clean.startswith("CORE_NOTIF_"):
                defaults[k_clean.replace("CORE_NOTIF_", "KZ_NOTIF_")] = v_clean
    return defaults


F = load_filters()


def ci_search(hay: str, pattern: str) -> bool:
    if not pattern or not hay:
        return False
    try:
        return re.search(pattern, hay, re.I) is not None
    except re.error:
        return pattern.lower() in hay.lower()


def slack_body_for_match(body: str) -> str:
    """Quita el prefijo 'Nombre Apellido: ' del emisor para no hot-ear por nombre."""
    return re.sub(r"^[^:]{1,80}:\s*", "", body or "", count=1)


def classify(app: str, summary: str, body: str) -> str:
    blob = f"{app} | {summary} | {body}"
    if ci_search(blob, F.get("CORE_NOTIF_BLOCK", "")):
        return "skip"
    # Nunca hot/pending de nuestras propias campanitas o popups (evita bucle infinto notify-send -> DBus -> notify-send)
    if ci_search(app, r"^Kora$|^Kora ·|^Companion$|core-nudge|notify-send") or ci_search(summary, r"🔔|\[IMPORTANT\]"):
        return "skip"
    # 2026-08-06: Abierto para ver KDE Connect / WhatsApp / Chrome si están en CORE_NOTIF_APP_IMPORTANT
    if ci_search(blob, r"Missed call|missed call|Sensitive notification"):
        return "skip"
    if ci_search(app, F.get("CORE_NOTIF_APP_SLACK", "Slack")):
        if F.get("CORE_NOTIF_SLACK_ALL_HOT", "0") == "1":
            return "slack_hot"
        # Match en summary + body sin emisor (nombres del canal no bastan solos)
        slack_blob = f"{summary} | {slack_body_for_match(body)}"
        if ci_search(slack_blob, F.get("CORE_NOTIF_KW_SLACK", "mentioned|urgente")):
            return "slack_hot"
        return "slack_seen"
    if ci_search(app, F.get("CORE_NOTIF_APP_IMPORTANT", "")):
        return "important"
    if ci_search(blob, F.get("CORE_NOTIF_KW_IMPORTANT", "")):
        return "important"
    if ci_search(app, F.get("CORE_NOTIF_APP_MAIL", "")) and ci_search(
        blob, F.get("CORE_NOTIF_KW_MAIL", "")
    ):
        return "mail_work"
    return "desktop_seen"


def fp_of(*parts: str) -> str:
    return hashlib.sha256("|".join(parts).encode("utf-8", errors="replace")).hexdigest()[
        :16
    ]


def already_seen(fp: str) -> bool:
    if not SEEN.is_file():
        return False
    text = SEEN.read_text(encoding="utf-8", errors="replace")
    return fp in text


def mark_seen(fp: str, kind: str, app: str) -> None:
    with SEEN.open("a", encoding="utf-8") as f:
        f.write(f"{fp}\t{kind}\t{app}\n")


def now() -> str:
    return datetime.now().astimezone().isoformat(timespec="seconds")


def stream_line(kind: str, app: str, summary: str, body: str) -> None:
    NOTIF_DIR.mkdir(parents=True, exist_ok=True)
    line = f"{now()}\t{kind}\t{app}\t{summary}\t{body}".replace("\n", " ")
    with STREAM.open("a", encoding="utf-8") as f:
        f.write(line[:800] + "\n")


def write_pending(kind: str, app: str, summary: str, body: str) -> None:
    NOTIF_DIR.mkdir(parents=True, exist_ok=True)
    s = summary.replace("\n", " ")
    b = body.replace("\n", " ")
    when = now()
    label = f"{kind}: {app} — {s}"[:120]
    with PENDING.open("a", encoding="utf-8") as f:
        f.write(
            f"""# Pending — notif Kora (desktop)

- **cuando:** {when}
- **clase:** {kind}
- **app:** {app}
- **título:** {s}
- **texto:** {b}
- **estado:** awaiting_companion_comment

El agente: comentar en chat (voz Kora), tray si cabe, clear:
`scripts/core-notif-watch.sh clear`
"""
        )
    PENDING_TS.write_text(when + "\n", encoding="utf-8")
    with PENDING_LABELS.open("a", encoding="utf-8") as f:
        f.write(label + "\n")
    with EVENTS.open("a", encoding="utf-8") as f:
        f.write(f"{when} DESKTOP {kind} app={app} title={s}\n")
    changed_line = f"CHANGED: notif:{kind}:{app}:{s[:80]}"
    print(changed_line, flush=True)
    # Wake confiable para el monitor del agente (stdout del daemon se pierde en nohup)
    with CHANGED_LOG.open("a", encoding="utf-8") as f:
        f.write(f"{when}\t{changed_line}\n")


def tray_sensor(kind: str, app: str, summary: str, body: str) -> None:
    """Tray con texto real (sensor). No crea chat_owed — el comentario es opcional.

    Hot → snippet siempre; análisis en chat solo si gordo / él pide / digest.
    Env: CORE_NOTIF_SENSOR_TRAY=0 desactiva.
    """
    if os.environ.get("CORE_NOTIF_SENSOR_TRAY", "1") == "0":
        return
    if F.get("CORE_NOTIF_SENSOR_TRAY", "1") == "0":
        return
    raw = (body or summary or app or "").replace("\n", " ").strip()
    if not raw:
        return
    # Prefijo corto de app para ubicar el canal
    prefix = (app or kind or "notif").strip()
    if prefix.lower() not in raw.lower()[:40]:
        snippet = f"{prefix}: {raw}"
    else:
        snippet = raw
    if len(snippet) > 200:
        snippet = snippet[:197] + "…"
    nudge = CORE_HOME / "scripts" / "core-nudge.sh"
    if not nudge.is_file():
        return
    env = os.environ.copy()
    env["CORE_NUDGE_NO_CHAT_OWED"] = "1"
    env.setdefault("DISPLAY", os.environ.get("DISPLAY", ":0"))
    try:
        subprocess.run(
            [str(nudge), "--say", snippet],
            env=env,
            timeout=20,
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def handle_notify(app: str, summary: str, body: str) -> None:
    app, summary, body = app.strip(), summary.strip(), body.strip()
    if not app and not summary:
        return
    kind = classify(app, summary, body)
    fp = fp_of(app, summary, body)
    stream_line(kind, app, summary, body)

    if kind in ("skip", "slack_seen", "desktop_seen"):
        if not already_seen(fp):
            mark_seen(fp, kind, app)
        return
    if already_seen(fp):
        return
    mark_seen(fp, kind, app)
    write_pending(kind, app, summary, body)
    tray_sensor(kind, app, summary, body)


def parse_monitor(proc: subprocess.Popen) -> None:
    """Parse dbus-monitor Notify blocks."""
    app = summary = body = None
    string_idx = 0
    in_notify = False

    assert proc.stdout is not None
    it = iter(proc.stdout)
    for raw in it:
        line = raw.rstrip("\n")
        if "member=Notify" in line and "Notifications" in line:
            in_notify = True
            app = summary = body = None
            string_idx = 0
            continue
        if not in_notify:
            continue
        # next method call ends block
        if line.startswith("method ") and "member=Notify" not in line:
            if app is not None:
                handle_notify(app or "", summary or "", body or "")
            in_notify = False
            continue

        # Detect start of a DBus string argument
        m = re.match(r'^\s*string\s+"(.*)$', line)
        if not m:
            if re.match(r'^\s*string\s*""\s*$', line):
                val = ""
            else:
                continue
        else:
            raw_val = m.group(1)
            # Check if multi-line string (does not end with non-escaped quote)
            if raw_val.endswith('"') and not raw_val.endswith(r'\"'):
                val = raw_val[:-1]
            else:
                # Multiline string: read until closing quote
                accum = [raw_val]
                for nxt_raw in it:
                    nxt = nxt_raw.rstrip("\n")
                    if nxt.endswith('"') and not nxt.endswith(r'\"'):
                        accum.append(nxt[:-1])
                        break
                    else:
                        accum.append(nxt)
                val = " ".join(accum)

            val = val.replace("\\n", " ").replace('\\"', '"')

        # Notify args: 0 app_name, 1 replaces_id is uint, 2 icon, 3 summary, 4 body
        # We only see string lines: app (0), icon (1), summary (2), body (3)
        if string_idx == 0:
            app = val
        elif string_idx == 1:
            # icon
            pass
        elif string_idx == 2:
            summary = val
        elif string_idx == 3:
            body = val
            handle_notify(app or "", summary or "", body or "")
            in_notify = False
            app = summary = body = None
            string_idx = 0
            continue
        string_idx += 1


def main() -> int:
    NOTIF_DIR.mkdir(parents=True, exist_ok=True)
    if PIDFILE.is_file():
        try:
            old = int(PIDFILE.read_text().strip())
            os.kill(old, 0)
            print(f"error: desktop notif watch ya corre pid {old}", file=sys.stderr)
            return 1
        except (ValueError, OSError):
            PIDFILE.unlink(missing_ok=True)

    PIDFILE.write_text(str(os.getpid()) + "\n")

    def cleanup(*_a):
        PIDFILE.unlink(missing_ok=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    with EVENTS.open("a", encoding="utf-8") as f:
        f.write(f"{now()} desktop notif watch start pid={os.getpid()}\n")
    print(f"desktop notif watch pid {os.getpid()}", file=sys.stderr)

    proc = subprocess.Popen(
        [
            "dbus-monitor",
            "--session",
            "interface='org.freedesktop.Notifications',member=Notify",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1,
    )
    try:
        parse_monitor(proc)
    finally:
        proc.terminate()
        PIDFILE.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "stop":
        if PIDFILE.is_file():
            try:
                os.kill(int(PIDFILE.read_text().strip()), signal.SIGTERM)
                print("stopped desktop notif watch")
            except (ValueError, OSError) as e:
                print(f"stop: {e}")
                PIDFILE.unlink(missing_ok=True)
        else:
            print("no desktop notif watch")
        raise SystemExit(0)
    raise SystemExit(main())
