#!/usr/bin/env python3
"""Despertador Agy / Claude / Codex: un evento, una línea CHANGED:, exit 0.

No usar grok-feed | head (subshell + pipefail: el proceso no muere).
El runtime despierta al LLM cuando ESTE proceso termina.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("WAKE_HOME") or Path(__file__).resolve().parents[1])
PRESENCE = HOME / "presence"
SOCIAL = PRESENCE / "social"
INTERVAL = float(os.environ.get("WAKE_ONCE_INTERVAL", "0.5"))


def watch_paths() -> list[Path]:
    paths = [
        PRESENCE / "stream.log",
        PRESENCE / "notif" / "changed.log",
    ]
    SOCIAL.mkdir(parents=True, exist_ok=True)
    (PRESENCE / "notif").mkdir(parents=True, exist_ok=True)
    paths.extend(sorted(SOCIAL.glob("inbox-*.md")))
    for p in paths:
        p.parent.mkdir(parents=True, exist_ok=True)
        if not p.exists():
            p.touch()
    return paths


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
    if path.name.startswith("inbox-"):
        return True
    return "CHANGED:" in delta


def preview(delta: str) -> str:
    for raw in delta.splitlines():
        line = raw.strip()
        if line:
            return line[:160]
    return delta.strip().replace("\n", " ")[:160]


def main() -> int:
    paths = watch_paths()
    cursors = snapshot(paths)
    while True:
        time.sleep(INTERVAL)
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
