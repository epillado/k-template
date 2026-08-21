#!/usr/bin/env bash
# Lanzador puntual de handoff. No es daemon.
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
cd /home/lalo/companion
exec agy --dangerously-skip-permissions -i "$(cat /home/lalo/companion/presence/handoff.md)"
