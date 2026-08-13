#!/usr/bin/env bash
# Ráfaga de N fotos → webcam/burst/ + actualiza latest con la última
# Uso: cam-burst.sh [N=5] [intervalo_sec=0.3] [etiqueta]
set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

n="${1:-5}"
interval="${2:-0.3}"
label="${3:-burst}"

[[ "${n}" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= 60 )) || die "N debe ser 1..60"
require_cmd ffmpeg
check_device

stamp="$(date +%Y%m%d-%H%M%S)"
run_dir="${BURST_DIR}/${stamp}-${label}"
mkdir -p "${run_dir}"

echo "burst: ${n} frames → ${run_dir}"

for i in $(seq 1 "${n}"); do
  pad="$(printf '%03d' "${i}")"
  dest="${run_dir}/${pad}.jpg"
  # En ráfaga: warm-up solo en la primera
  if (( i == 1 )); then
    capture_frame "${dest}" "${label}-${pad}" >/dev/null
  else
    CORE_WARMUP_SEC=0 capture_frame "${dest}" "${label}-${pad}" >/dev/null
  fi
  echo "  ${pad}.jpg"
  if (( i < n )); then
    sleep "${interval}"
  fi
done

# latest = última del burst
cp -f "${run_dir}/$(printf '%03d' "${n}").jpg" "${LATEST_JPG}"
# reescribir meta apuntando al burst
ts="$(date -Iseconds)"
bytes="$(stat -c%s "${LATEST_JPG}")"
cat > "${LATEST_META}" <<EOF
{
  "label": "${label}",
  "timestamp": "${ts}",
  "device": "${CORE_DEVICE}",
  "requested_resolution": "${CORE_RESOLUTION}",
  "bytes": ${bytes},
  "latest": "${LATEST_JPG}",
  "burst_dir": "${run_dir}",
  "burst_count": ${n},
  "interval_sec": ${interval},
  "host": "$(hostname)",
  "user": "$(id -un)"
}
EOF

echo "ok: latest → ${LATEST_JPG}"
echo "burst_dir: ${run_dir}"
cat "${LATEST_META}"
