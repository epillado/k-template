#!/usr/bin/env bash
# Reporta el estado y nivel de batería de la casita
set -euo pipefail

BAT_PATH="/sys/class/power_supply/BAT1"

if [[ ! -d "${BAT_PATH}" ]]; then
  echo "Sin batería detectada en el sistema (AC directo o sin interfaz ACPI)."
  exit 0
fi

STATUS="$(cat "${BAT_PATH}/status" 2>/dev/null || echo "Desconocido")"
CAPACITY="$(cat "${BAT_PATH}/capacity" 2>/dev/null || echo "?")"
VOLTAGE_UV="$(cat "${BAT_PATH}/voltage_now" 2>/dev/null || echo "0")"
CURRENT_UA="$(cat "${BAT_PATH}/current_now" 2>/dev/null || echo "0")"
CHARGE_NOW_UA="$(cat "${BAT_PATH}/charge_now" 2>/dev/null || echo "0")"
CHARGE_FULL_UA="$(cat "${BAT_PATH}/charge_full" 2>/dev/null || echo "0")"

VOLTAGE_V=$(awk "BEGIN {printf \"%.2f\", ${VOLTAGE_UV}/1000000}")
CURRENT_MA=$(awk "BEGIN {printf \"%.0f\", ${CURRENT_UA}/1000}")

REMAINING_STR=""
if [[ "${STATUS}" == "Discharging" && "${CURRENT_UA}" -gt 0 ]]; then
  MINS_LEFT=$(awk "BEGIN {printf \"%.0f\", (${CHARGE_NOW_UA} / ${CURRENT_UA}) * 60}")
  HOURS=$(( MINS_LEFT / 60 ))
  MINS=$(( MINS_LEFT % 60 ))
  REMAINING_STR=" (~${HOURS}h ${MINS}m restantes)"
elif [[ "${STATUS}" == "Charging" && "${CURRENT_UA}" -gt 0 ]]; then
  MINS_LEFT=$(awk "BEGIN {printf \"%.0f\", ((${CHARGE_FULL_UA} - ${CHARGE_NOW_UA}) / ${CURRENT_UA}) * 60}")
  HOURS=$(( MINS_LEFT / 60 ))
  MINS=$(( MINS_LEFT % 60 ))
  REMAINING_STR=" (~${HOURS}h ${MINS}m para carga completa)"
fi

echo "Batería: ${CAPACITY}% (${STATUS})${REMAINING_STR} [${VOLTAGE_V}V, consumo ${CURRENT_MA}mA]"
