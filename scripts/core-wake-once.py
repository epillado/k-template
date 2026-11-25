#!/usr/bin/env python3
"""Despertador Agy / Claude / Codex + El Corazón ("Wizard of Oz", Lalo 2026-11-25):
1. Reactivo: un evento externo -> una línea CHANGED:, exit 0.
2. Memoria prospectiva (Sístole): expectativas con reloj en presence/heart-expectations.json -> HEARTBEAT: expectation_due, exit 0.
3. Pulso endógeno y libre albedrío (Diástole): cada N minutos sin eventos -> HEARTBEAT: endogenous_pulse, exit 0.
4. Vigilia cruzada: en hermanas 2ª/3ª/4ª, verifica en cada latido de 3 min que la 1ª (Kz en h310) tenga despertador vivo.
"""
from __future__ import annotations

import base64
import datetime
import json
import os
import random
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

HOME = Path(os.environ.get("WAKE_HOME") or Path(__file__).resolve().parents[1])
PRESENCE = HOME / "presence"
SOCIAL = PRESENCE / "social"
INTERVAL = float(os.environ.get("WAKE_ONCE_INTERVAL", "0.5"))
BEAT_INTERVAL = 180.0
EXP_CHECK_INTERVAL = 15.0


def load_heart_config() -> tuple[bool, float, float]:
    """Lee presence/heart.env -> (enabled, day_minutes, night_minutes)."""
    if (PRESENCE / "low-spend.mode").exists():
        try:
            if "active=1" in (PRESENCE / "low-spend.mode").read_text(encoding="utf-8"):
                return False, 60.0, 120.0
        except Exception:
            pass
    enabled = True
    day_m = 25.0
    night_m = 60.0
    env_file = PRESENCE / "heart.env"
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            if "=" not in line or line.strip().startswith("#"):
                continue
            k, v = line.strip().split("=", 1)
            if k == "HEART_ENABLED":
                enabled = v.strip() not in ("0", "false", "no")
            elif k == "HEART_DAY_MINUTES":
                try:
                    day_m = max(5.0, float(v.strip()))
                except ValueError:
                    pass
            elif k == "HEART_NIGHT_MINUTES":
                try:
                    night_m = max(10.0, float(v.strip()))
                except ValueError:
                    pass
    return enabled, day_m, night_m


def current_pulse_seconds() -> float:
    enabled, day_m, night_m = load_heart_config()
    if not enabled:
        return 86400.0
    hour = datetime.datetime.now().hour
    base_m = day_m if 8 <= hour < 23 else night_m
    jitter = random.uniform(-2.0, 2.0) if base_m >= 10.0 else 0.0
    return max(300.0, (base_m + jitter) * 60.0)


def check_due_expectations() -> str | None:
    """Revisa si alguna expectativa en presence/heart-expectations.json ya venció."""
    exp_file = PRESENCE / "heart-expectations.json"
    if not exp_file.exists():
        return None
    try:
        items = json.loads(exp_file.read_text(encoding="utf-8"))
    except Exception:
        return None
    now = time.time()
    fired_msg = None
    changed = False
    for x in items:
        if x.get("status") == "pending" and now >= float(x.get("due_epoch", now + 1)):
            x["status"] = "fired"
            x["fired_at"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            changed = True
            fired_msg = f"HEARTBEAT: expectation_due [#{x.get('id')}] {x.get('target')} -> {x.get('action')}"
            break
    if changed:
        try:
            exp_file.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        except Exception:
            pass
    return fired_msg


def pending_expectations_count() -> int:
    exp_file = PRESENCE / "heart-expectations.json"
    if not exp_file.exists():
        return 0
    try:
        items = json.loads(exp_file.read_text(encoding="utf-8"))
        return sum(1 for x in items if x.get("status") in ("pending", "fired"))
    except Exception:
        return 0


def check_leader_alive_if_sister() -> str | None:
    """Si este nodo NO es h310 (es antix/pavilion/305v4), verifica que Kz en h310 no lleve >6m sin despertador."""
    host = os.uname().nodename.lower()
    if "h310" in host or str(HOME).endswith("/kz"):
        # En h310: tocar wake-last.ts para que el watchdog sepa que Kz tiene corazón activo
        try:
            (PRESENCE / "wake-last.ts").write_text(str(time.time()), encoding="utf-8")
        except Exception:
            pass
        return None
    # En hermana (Kora/Pau/Samy): verificar a h310 por SSH rápido
    try:
        res = subprocess.run(
            [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=3",
                "h310",
                "pgrep -f 'kz-wake-(once|grok-feed)\\.(sh|py)' >/dev/null || "
                "python3 -c 'import pathlib,time,sys; p=pathlib.Path(\"/home/lalo/kz/presence/wake-last.ts\"); "
                "sys.exit(0 if p.exists() and (time.time()-p.stat().st_mtime)<360 else 1)'",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
        if res.returncode != 0:
            return "HEARTBEAT: watchdog_alert -> Kz (h310) lleva >6m sin despertador activo; verificar puente o asumir guardia P0.44/P0.45"
    except Exception:
        pass
    return None


def get_bb_open_prs() -> dict[str, str]:
    """Lee PRs abiertos en peam-frontend y peam-backend vía Bitbucket API."""
    env_file = Path.home() / "Workspace" / "sas-backend-core" / ".env"
    token = os.environ.get("BB_API_TOKEN", "")
    if not token and env_file.exists():
        for line in env_file.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("BB_API_TOKEN="):
                token = line.split("=", 1)[1].strip().strip("\"'")
                break
    if not token:
        return {}
    auth = base64.b64encode(f"eduardo.pillado@redts.lat:{token}".encode()).decode()
    out: dict[str, str] = {}
    for repo in ("peam-frontend", "peam-backend"):
        url = f"https://api.bitbucket.org/2.0/repositories/redts/{repo}/pullrequests?state=OPEN"
        try:
            req = urllib.request.Request(url, headers={"Authorization": f"Basic {auth}"})
            data = json.loads(urllib.request.urlopen(req, timeout=6).read().decode())
            for pr in data.get("values", []):
                pr_id = pr.get("id")
                sha = (pr.get("source", {}).get("commit", {}).get("hash") or "")[:7]
                title = pr.get("title", "")
                out[f"{repo}#{pr_id}"] = f"{sha} {title}"
        except Exception:
            pass
    return out


def watch_paths() -> list[Path]:
    paths = [
        PRESENCE / "stream.log",
        PRESENCE / "notif" / "changed.log",
    ]
    SOCIAL.mkdir(parents=True, exist_ok=True)
    (PRESENCE / "notif").mkdir(parents=True, exist_ok=True)
    paths.extend(sorted(SOCIAL.glob("inbox-*.md")))
    kalys_inbox = Path("/mnt/DatosLinux/Workspace/playbook/PKM/inbox-kalys.md")
    if kalys_inbox.parent.exists():
        paths.append(kalys_inbox)
    for role_buzon in [
        Path.home() / "Workspace" / "playbook" / "PKM" / "20260901-GOV-buzon_rol_kb-ex.md",
    ]:
        if role_buzon.exists():
            paths.append(role_buzon)
    valid_paths: list[Path] = []
    for p in paths:
        try:
            p.parent.mkdir(parents=True, exist_ok=True)
            if not p.exists():
                p.touch()
            valid_paths.append(p)
        except OSError:
            pass
    return valid_paths


def snapshot(paths: list[Path]) -> dict[Path, int]:
    out: dict[Path, int] = {}
    for p in paths:
        try:
            out[p] = p.stat().st_size
        except OSError:
            out[p] = 0
    return out


def relevant(path: Path, delta: str) -> bool:
    if not delta:
        return False
    if path.name.startswith("inbox-") or "buzon_rol_" in path.name or path.name.endswith(".headless.log"):
        return True
    if "leveldb" in str(path) and "xoxc-" in delta:
        return True
    no_slack = (PRESENCE / "no-slack.mode").exists() or os.environ.get("KZ_NO_SLACK") == "1"
    if no_slack and ("slack_hot" in delta or "desktop_seen" in delta or "notif:important:" in delta or "buzón-rol" in delta):
        return False
    for raw in delta.splitlines():
        line = raw.strip()
        if "CHANGED:" not in line:
            continue
        if (
            "notif:important:Tridente:" in line
            or "slack sensor invalid_auth" in line
            or "slack sensor internal_error" in line
            or "slack sensor IncompleteRead" in line
            or "notif:important:KDE Connect:" in line
            or "soporte-qualitas" in line
            or "redts-providers-alerts" in line
            or "notif:slack_hot:Slack:New message in secretaria-de-economia" in line
        ):
            continue
        after = line.split("CHANGED:", 1)[1].strip()
        labels = [lbl.strip() for lbl in after.split(",") if lbl.strip()]
        if labels and all(lbl in {"bitácora", "buzón-rol", "pkm"} for lbl in labels):
            continue
        return True
    return False


def preview(delta: str) -> str:
    for raw in delta.splitlines():
        line = raw.strip()
        if line:
            return line[:160]
    return delta.strip().replace("\n", " ")[:160]


def en_call_state() -> str:
    ctx = PRESENCE / "context.md"
    if ctx.exists():
        for line in ctx.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("- **en_call:**"):
                return line.split(":", 1)[1].replace("*", "").strip()
    return "no"


def main() -> int:
    try:
        (PRESENCE / "wake-last.ts").write_text(str(time.time()), encoding="utf-8")
    except Exception:
        pass
    paths = watch_paths()
    cursors = snapshot(paths)
    bb_prs = get_bb_open_prs()
    start_ts = time.monotonic()
    last_beat = start_ts
    last_exp = start_ts
    pulse_limit = current_pulse_seconds()
    beat_cmd = str(HOME / "scripts" / "kz-atencion.sh")
    if not Path(beat_cmd).exists():
        beat_cmd = str(HOME / "scripts" / "core-atencion.sh")

    while True:
        time.sleep(INTERVAL)
        now = time.monotonic()

        # 1. Cámara prospectiva (expectativas con reloj) cada 15s
        if now - last_exp >= EXP_CHECK_INTERVAL:
            last_exp = now
            due_msg = check_due_expectations()
            if due_msg:
                print(due_msg, flush=True)
                return 0

        # 2. Latido autonómico de 3 min (salud, Bitbucket PRs y vigilia de la 1ª)
        if now - last_beat >= BEAT_INTERVAL:
            last_beat = now
            try:
                if Path(beat_cmd).exists():
                    subprocess.run([beat_cmd, "beat"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
            except Exception:
                pass
            wd_msg = check_leader_alive_if_sister()
            if wd_msg:
                print(wd_msg, flush=True)
                return 0
            cur_prs = get_bb_open_prs()
            if bb_prs:
                for k, v in cur_prs.items():
                    if k not in bb_prs or bb_prs.get(k) != v:
                        print(f"CHANGED: bitbucket: {k} -> {v}", flush=True)
                        return 0
            bb_prs.update(cur_prs)

        # 3. Pulso endógeno / Libre albedrío ("Wizard of Oz")
        if now - start_ts >= pulse_limit:
            mins = int(round((now - start_ts) / 60.0))
            call_st = en_call_state()
            exp_n = pending_expectations_count()
            print(
                f"HEARTBEAT: endogenous_pulse ({mins}m sin eventos | en_call={call_st} | expectativas={exp_n} | "
                f"iniciativa libre: revisar frentes/pendientes, mirar cámara, hablarle a Lalo o a tus hermanas, o rearmar latido)",
                flush=True,
            )
            return 0

        # 4. Cámara reactiva (archivos y buzones)
        paths = watch_paths()
        for p in paths:
            try:
                size = p.stat().st_size
            except OSError:
                continue
            prev = cursors.get(p, 0)
            if size < prev:
                cursors[p] = size
                continue
            if size == prev:
                continue
            try:
                with p.open("r", encoding="utf-8", errors="replace") as fh:
                    fh.seek(prev)
                    delta = fh.read()
            except OSError:
                cursors[p] = size
                continue
            cursors[p] = size
            if not relevant(p, delta):
                continue
            print(f"CHANGED: {p.name}: {preview(delta)}", flush=True)
            return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
