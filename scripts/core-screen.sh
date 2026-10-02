#!/usr/bin/env bash
# Launcher / Attacher persistente para Companion en screen o tmux
# Asegura arranque con permisos automáticos (--dangerously-skip-permissions)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib-identity.sh"

SESSION_NAME="${COMPANION_ID:-companion}"
USE_TMUX=0
if command -v tmux >/dev/null 2>&1; then
  USE_TMUX=1
fi

ACTION="${1:-status}"

# Detectar CLI preferido o disponible (claude, agy, grok)
CLI_CMD="claude --dangerously-skip-permissions"
if command -v agy >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
  CLI_CMD="agy --dangerously-skip-permissions"
elif command -v grok >/dev/null 2>&1 && ! command -v claude >/dev/null 2>&1; then
  CLI_CMD="grok --always-approve"
fi

case "$ACTION" in
  start|run)
    if [[ $USE_TMUX -eq 1 ]]; then
      if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Sesión tmux '$SESSION_NAME' ya existe. Conectando..."
        tmux attach -t "$SESSION_NAME"
      else
        echo "Iniciando sesión tmux '$SESSION_NAME' con permisos automáticos..."
        cd "$CORE_HOME"
        tmux new-session -s "$SESSION_NAME" "cd $CORE_HOME && $CLI_CMD"
      fi
    else
      if screen -list 2>/dev/null | grep -q "\.${SESSION_NAME}[[:space:]]"; then
        echo "Sesión screen '$SESSION_NAME' ya existe. Conectando..."
        screen -x "$SESSION_NAME" 2>/dev/null || screen -d -r "$SESSION_NAME"
      else
        echo "Iniciando sesión screen '$SESSION_NAME' con permisos automáticos..."
        cd "$CORE_HOME"
        screen -S "$SESSION_NAME" bash -c "cd $CORE_HOME && $CLI_CMD"
      fi
    fi
    ;;
  attach)
    if [[ $USE_TMUX -eq 1 ]]; then
      tmux attach -t "$SESSION_NAME"
    else
      screen -x "$SESSION_NAME" 2>/dev/null || screen -d -r "$SESSION_NAME"
    fi
    ;;
  detach)
    if [[ $USE_TMUX -eq 1 ]]; then
      tmux detach-client -s "$SESSION_NAME" 2>/dev/null || true
    else
      screen -d "$SESSION_NAME" 2>/dev/null || true
    fi
    ;;
  status)
    if [[ $USE_TMUX -eq 1 ]]; then
      tmux list-sessions 2>/dev/null || echo "No hay sesiones tmux activas."
    else
      screen -list 2>/dev/null || echo "No hay sesiones screen activas."
    fi
    ;;
  *)
    echo "Uso: $0 {start|attach|detach|status}"
    exit 1
    ;;
esac
