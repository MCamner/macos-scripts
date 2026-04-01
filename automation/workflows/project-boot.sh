#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${1:-macos-scripts}"
PROJECT_DIR="${2:-$HOME/macos-scripts}"
PROJECT_URL="${3:-https://github.com/MCamner/macos-scripts}"
LOG_DIR="$HOME/.macos-scripts/logs"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_FILE="$LOG_DIR/${PROJECT_NAME}_session_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

echo "====================================" | tee -a "$LOG_FILE"
echo "PROJECT BOOT" | tee -a "$LOG_FILE"
echo "Project   : $PROJECT_NAME" | tee -a "$LOG_FILE"
echo "Directory : $PROJECT_DIR" | tee -a "$LOG_FILE"
echo "Started   : $(date)" | tee -a "$LOG_FILE"
echo "====================================" | tee -a "$LOG_FILE"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: $PROJECT_DIR" | tee -a "$LOG_FILE"
  exit 1
fi

echo "[1/5] Opening project folder..." | tee -a "$LOG_FILE"
open "$PROJECT_DIR"

echo "[2/5] Opening GitHub repo..." | tee -a "$LOG_FILE"
open "$PROJECT_URL"

if [[ -f "$PROJECT_DIR/README.md" ]]; then
  echo "[3/5] Opening README.md..." | tee -a "$LOG_FILE"
  open -a "TextEdit" "$PROJECT_DIR/README.md"
else
  echo "[3/5] README.md not found, skipping." | tee -a "$LOG_FILE"
fi

echo "[4/5] Opening Terminal..." | tee -a "$LOG_FILE"
osascript <<OSA
tell application "Terminal"
  activate
  do script "cd \"$PROJECT_DIR\" && clear && echo '🚀 Project Boot: $PROJECT_NAME' && git status"
end tell
OSA

if [[ -d "/Applications/Visual Studio Code.app" ]]; then
  echo "[5/5] Opening Visual Studio Code..." | tee -a "$LOG_FILE"
  open -a "Visual Studio Code" "$PROJECT_DIR"
else
  echo "[5/5] Visual Studio Code not found, skipping." | tee -a "$LOG_FILE"
fi

echo
echo "Done."
echo "Log saved to: $LOG_FILE"
