#!/usr/bin/env bash
set -euo pipefail

MQFILE="$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"

python3 - <<'PY'
from pathlib import Path

path = Path.home() / "macos-scripts" / "terminal" / "launchers" / "mqlaunch.sh"
text = path.read_text()

func_block = '''
open_tweaks_menu() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" menu
}

show_tweaks_status() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" status
}

run_tweaks_workstation() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" workstation
}

run_tweaks_dev() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" dev
}

run_tweaks_clean() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" clean
}

run_tweaks_fast() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" fast
}

run_tweaks_all() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" all
}

revert_tweaks_latest() {
  bash "$BASE_DIR/system/tweaks/macos-tweaks.sh" revert-latest
}

'''

if 'open_tweaks_menu() {' not in text:
    marker = '# --- Menus --------------------------------------------------'
    text = text.replace(marker, func_block + marker)

text = text.replace(
    'row3 "20. AI Modes" "21. Dev / Prompts" ""',
    'row3 "20. AI Modes" "21. Dev / Prompts" "22. Tweaks"'
)

text = text.replace(
    'printf "${C_TITLE}Select option [1-10,12-21,X]: ${C_RESET}"',
    'printf "${C_TITLE}Select option [1-10,12-22,X]: ${C_RESET}"'
)

text = text.replace(
    '      20) ai_menu_loop ;;\n      21) dev_menu_loop ;;\n      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;',
    '      20) ai_menu_loop ;;\n      21) dev_menu_loop ;;\n      22) open_tweaks_menu ;;\n      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;'
)

old_help = '''show_help() {
  cat <<EOH
MQLaunch v3.4 — Old School Utility

Usage:
  mqlaunch                Open main menu
  mqlaunch ai             Open AI submenu
  mqlaunch dev            Open Dev / Prompts submenu

Main menu:
  Exit is X, not 11

Direct commands:
  finder | safari | chrome | spotify | xcode
  settings | monitor
  downloads | home | utilities | applications
  ip | lock | sleep | restart-finder | date
  repo | check | ai | dev
  prompts | prompt-files | edit | backup-prompts
  base | launchers | guide
  gitlaunch | netlaunch
  auto | one | atlas | decide | research | root | solve | pdebug | menu
EOH
}'''

new_help = '''show_help() {
  cat <<EOH
MQLaunch v3.4 — Old School Utility

Usage:
  mqlaunch                Open main menu
  mqlaunch ai             Open AI submenu
  mqlaunch dev            Open Dev / Prompts submenu
  mqlaunch tweaks         Open Tweaks menu

Main menu:
  Exit is X, not 11

Direct commands:
  finder | safari | chrome | spotify | xcode
  settings | monitor
  downloads | home | utilities | applications
  ip | lock | sleep | restart-finder | date
  repo | check | ai | dev | tweaks
  prompts | prompt-files | edit | backup-prompts
  base | launchers | guide
  gitlaunch | netlaunch
  tweaks-status | tweaks-workstation | tweaks-dev
  tweaks-clean | tweaks-fast | tweaks-all | tweaks-revert
  auto | one | atlas | decide | research | root | solve | pdebug | menu
EOH
}'''

if old_help in text:
    text = text.replace(old_help, new_help)

old_cmds = '''    ai) ai_menu_loop ;;
    dev) dev_menu_loop ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;'''

new_cmds = '''    ai) ai_menu_loop ;;
    dev) dev_menu_loop ;;
    tweaks|tweak|tw) open_tweaks_menu ;;
    tweaks-status) show_tweaks_status ;;
    tweaks-workstation) run_tweaks_workstation ;;
    tweaks-dev) run_tweaks_dev ;;
    tweaks-clean) run_tweaks_clean ;;
    tweaks-fast) run_tweaks_fast ;;
    tweaks-all) run_tweaks_all ;;
    tweaks-revert|revert-tweaks) revert_tweaks_latest ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;'''

if old_cmds in text:
    text = text.replace(old_cmds, new_cmds)

path.write_text(text)
print(f"Patched: {path}")
PY
