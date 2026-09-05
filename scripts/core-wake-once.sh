#!/usr/bin/env bash
# Despertador por evento (Agy / Claude / Codex): espera UN CHANGED y sale 0.
# Grok no usa esto — usa core-wake-feed.sh con monitor persistente.
set -euo pipefail
CORE_HOME="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "${CORE_HOME}/scripts/core-wake-once.py"
