#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
PROMPT_DIR="${BASE_DIR}/ai-prompts"

copy_and_open() {
  local file="$1"

  if [[ ! -f "$file" ]]; then
    echo "Prompt file not found: $file"
    exit 1
  fi

  cat "$file" | pbcopy
  echo "Copied: $(basename "$file")"

  open "https://chatgpt.com/"
}

show_menu() {
  cat <<EOF
AI MODES
1) Auto Mode
2) Atlas One
3) Atlas Analysis Engine
4) Decision & Trade-off
5) Research Synthesizer
6) Root Cause Analyzer
7) Problem Solving Engine
8) Prompt Debugger
9) Prompt Index
0) Exit
EOF

  read -r -p "Choose mode: " choice

  case "$choice" in
    1) copy_and_open "${PROMPT_DIR}/01-18-auto-mode.txt" ;;
    2) copy_and_open "${PROMPT_DIR}/01-17-atlas-one.txt" ;;
    3) copy_and_open "${PROMPT_DIR}/01-00-atlas-analysis.txt" ;;
    4) copy_and_open "${PROMPT_DIR}/01-11-decision.txt" ;;
    5) copy_and_open "${PROMPT_DIR}/01-12-research.txt" ;;
    6) copy_and_open "${PROMPT_DIR}/01-13-root-cause.txt" ;;
    7) copy_and_open "${PROMPT_DIR}/01-14-problem-solving.txt" ;;
    8) copy_and_open "${PROMPT_DIR}/01-09-prompt-debugger.txt" ;;
    9) copy_and_open "${PROMPT_DIR}/00-index.txt" ;;
    0) exit 0 ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
}

case "${1:-menu}" in
  ai|menu)
    show_menu
    ;;
  auto)
    copy_and_open "${PROMPT_DIR}/01-18-auto-mode.txt"
    ;;
  one)
    copy_and_open "${PROMPT_DIR}/01-17-atlas-one.txt"
    ;;
  atlas)
    copy_and_open "${PROMPT_DIR}/01-00-atlas-analysis.txt"
    ;;
  decide)
    copy_and_open "${PROMPT_DIR}/01-11-decision.txt"
    ;;
  research)
    copy_and_open "${PROMPT_DIR}/01-12-research.txt"
    ;;
  root)
    copy_and_open "${PROMPT_DIR}/01-13-root-cause.txt"
    ;;
  solve)
    copy_and_open "${PROMPT_DIR}/01-14-problem-solving.txt"
    ;;
  pdebug)
    copy_and_open "${PROMPT_DIR}/01-09-prompt-debugger.txt"
    ;;
  index)
    copy_and_open "${PROMPT_DIR}/00-index.txt"
    ;;
  *)
    echo "Usage: mqlaunch [ai|menu|auto|one|atlas|decide|research|root|solve|pdebug|index]"
    exit 1
    ;;
esac
