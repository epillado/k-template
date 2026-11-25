#!/usr/bin/env bash
# kz-heart.sh / core-heart.sh — El Corazón ("Wizard of Oz", Lalo 2026-11-25)
# Gestiona memoria prospectiva (expectativas con reloj) y ritmo de pulso endógeno.
#
# Uso:
#   kz-heart.sh expect <minutos|HH:MM> "<objetivo>" "<acción al vencer>"
#   kz-heart.sh list
#   kz-heart.sh done <id>
#   kz-heart.sh clear
#   kz-heart.sh bpm <minutos_dia> [minutos_noche]
#   kz-heart.sh status
set -euo pipefail

HOME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRESENCE="${HOME_DIR}/presence"
EXP_FILE="${PRESENCE}/heart-expectations.json"
ENV_FILE="${PRESENCE}/heart.env"
mkdir -p "${PRESENCE}"

[[ -f "${EXP_FILE}" ]] || echo "[]" > "${EXP_FILE}"
if [[ ! -f "${ENV_FILE}" ]]; then
  cat > "${ENV_FILE}" <<'EOF'
HEART_ENABLED=1
HEART_DAY_MINUTES=25
HEART_NIGHT_MINUTES=60
EOF
fi

cmd="${1:-status}"
shift || true

case "${cmd}" in
  expect|add)
    [[ $# -ge 3 ]] || { echo "uso: $0 expect <minutos|HH:MM> \"<objetivo>\" \"<acción>\"" >&2; exit 1; }
    when_spec="$1"
    target="$2"
    shift 2
    action="$*"
    python3 - "${EXP_FILE}" "${when_spec}" "${target}" "${action}" <<'PY'
import json, sys, time, datetime, pathlib

exp_path = pathlib.Path(sys.argv[1])
when_spec = sys.argv[2].strip()
target = sys.argv[3].strip()
action = sys.argv[4].strip()

now = time.time()
if ":" in when_spec:
    hh, mm = [int(x) for x in when_spec.split(":", 1)]
    dt = datetime.datetime.now().replace(hour=hh, minute=mm, second=0, microsecond=0)
    if dt.timestamp() <= now:
        dt += datetime.timedelta(days=1)
    due = dt.timestamp()
else:
    due = now + float(when_spec) * 60.0

try:
    items = json.loads(exp_path.read_text(encoding="utf-8"))
except Exception:
    items = []

next_id = max([int(x.get("id", 0)) for x in items] + [0]) + 1
due_str = datetime.datetime.fromtimestamp(due).strftime("%Y-%m-%d %H:%M:%S")
item = {
    "id": next_id,
    "created_at": datetime.datetime.fromtimestamp(now).strftime("%Y-%m-%d %H:%M:%S"),
    "due_epoch": round(due, 1),
    "due_str": due_str,
    "target": target,
    "action": action,
    "status": "pending",
}
items.append(item)
exp_path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"❤️ Expectativa #{next_id} agendada para {due_str}: [{target}] {action}")
PY
    ;;
  list|ls)
    python3 - "${EXP_FILE}" <<'PY'
import json, sys, time, pathlib
exp_path = pathlib.Path(sys.argv[1])
try:
    items = json.loads(exp_path.read_text(encoding="utf-8"))
except Exception:
    items = []
pending = [x for x in items if x.get("status") in ("pending", "fired")]
if not pending:
    print("❤️ Sin expectativas activas.")
    sys.exit(0)
now = time.time()
for x in pending:
    rem = int(round((float(x.get("due_epoch", now)) - now) / 60.0))
    st = x.get("status")
    print(f"  #{x['id']} [{st}] vence {x['due_str']} ({rem:+d}m) — {x['target']}: {x['action']}")
PY
    ;;
  done|resolve|rm)
    [[ $# -ge 1 ]] || { echo "uso: $0 done <id>" >&2; exit 1; }
    tid="$1"
    python3 - "${EXP_FILE}" "${tid}" <<'PY'
import json, sys, pathlib
exp_path = pathlib.Path(sys.argv[1])
tid = int(sys.argv[2].lstrip("#"))
items = json.loads(exp_path.read_text(encoding="utf-8"))
found = False
for x in items:
    if int(x.get("id", -1)) == tid:
        x["status"] = "done"
        found = True
exp_path.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"❤️ Expectativa #{tid} marcada como cumplida." if found else f"No se encontró #{tid}.")
PY
    ;;
  clear)
    echo "[]" > "${EXP_FILE}"
    echo "❤️ Expectativas limpiadas."
    ;;
  bpm)
    [[ $# -ge 1 ]] || { echo "uso: $0 bpm <minutos_dia> [minutos_noche]" >&2; exit 1; }
    day_m="$1"
    night_m="${2:-60}"
    cat > "${ENV_FILE}" <<EOF
HEART_ENABLED=1
HEART_DAY_MINUTES=${day_m}
HEART_NIGHT_MINUTES=${night_m}
EOF
    echo "❤️ Ritmo cardíaco ajustado: día=${day_m}m, noche=${night_m}m."
    ;;
  status)
    echo "=== Corazón ($(basename "${HOME_DIR}")) ==="
    cat "${ENV_FILE}"
    "$0" list
    ;;
  *)
    echo "uso: $0 {expect|list|done|clear|bpm|status}" >&2
    exit 1
    ;;
esac
