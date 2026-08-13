#!/usr/bin/env bash
# Una foto → webcam/latest.jpg (+ archive + meta.json)
# Uso: cam-snap.sh [etiqueta opcional]
set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

label="${1:-snap}"
path="$(capture_frame "${LATEST_JPG}" "${label}")"
echo "ok: ${path}"
echo "meta: ${LATEST_META}"
cat "${LATEST_META}"
