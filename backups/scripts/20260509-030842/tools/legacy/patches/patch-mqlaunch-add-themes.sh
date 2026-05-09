#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

path = Path.home() / "macos-scripts" / "terminal" / "launchers" / "mqlaunch.sh"

if not path.exists():
    print(f"Missing file: {path}")
    sys.exit(1)

text = path.read_text()
original = text

# ------------------------------------------------------------
# 1) Add theme helper functions if missing
# ------------------------------------------------------------
theme_block = r'''
theme_cmd() {
  local theme_script="$BASE_DIR/terminal/themes/mq-theme-manager.sh"
  local cmd="${1:-list}"
  shift || true

  if [[ -x "$theme_script" ]]; then
    bash "$theme_script" "$cmd" "$@"
  elif [[ -f "$theme_script" ]]; then
    chmod +x "$theme_script" 2>/dev/null || true
    bash "$theme_script" "$cmd" "$@"
  else
    print_header
    row "THEME MANAGER"
    empty_row
    row "Theme manager script missing:"
    row " $theme_script"
    print_footer
    pause_enter
    return 1
  fi
}

print_themes_menu() {
  print_header
  row "THEMES"
  empty_row

  row2 " 1. List themes" " 2. Current theme"
  row2 " 3. Preview classic" " 4. Preview green"
  row2 " 5. Apply classic" " 6. Apply green"
  row2 " 7. Apply amber" " 8. Apply ice"
  row2 " 9. Apply synth" "10. Reset theme"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select theme option [0-10]: ${C_RESET}"
}

themes_menu_loop() {
  local choice

  while true; do
    print_themes_menu
    read -r choice
    echo

    case "$choice" in
      1) theme_cmd list; pause_enter ;;
      2) theme_cmd current; pause_enter ;;
      3) theme_cmd preview classic ;;
      4) theme_cmd preview green ;;
      5) theme_cmd apply classic; pause_enter ;;
      6) theme_cmd apply green; pause_enter ;;
      7) theme_cmd apply amber; pause_enter ;;
      8) theme_cmd apply ice; pause_enter ;;
      9) theme_cmd apply synth; pause_enter ;;
      10) theme_cmd reset; pause_enter ;;
      0) break ;;
      *) echo "${C_ERR}Invalid theme selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}

'''

if 'themes_menu_loop() {' not in text:
    marker = '# --- Menus --------------------------------------------------'
    if marker not in text:
        print("Could not find menu marker.")
        sys.exit(1)
    text = text.replace(marker, theme_block + marker, 1)

# ------------------------------------------------------------
# 2) Patch print_dev_menu()
# ------------------------------------------------------------
new_print_dev_menu = r'''print_dev_menu() {
  print_header
  row "DEV / PROMPTS"
  empty_row

  row2 " 1. Open AI Prompts folder" " 2. Show prompt files"
  row2 " 3. Edit mqlaunch" " 4. Backup prompts"
  row2 " 5. Backup mqlaunch" " 6. Open macos-scripts folder"
  row2 " 7. Open launcher folder" " 8. Open mac terminal guide"
  row2 " 9. Git Launch" "10. Net Launch"
  row2 "11. Themes" " 0. Back"

  print_footer
  printf "${C_TITLE}Select dev option [0-11]: ${C_RESET}"
}'''

text, count = re.subn(
    r'print_dev_menu\(\)\s*\{.*?^\}',
    new_print_dev_menu,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch print_dev_menu().")
    sys.exit(1)

# ------------------------------------------------------------
# 3) Patch dev_menu_loop()
# ------------------------------------------------------------
new_dev_menu_loop = r'''dev_menu_loop() {
  local choice

  while true; do
    print_dev_menu
    read -r choice
    echo

    case "$choice" in
      1) open_ai_prompts_folder ;;
      2) show_prompt_files ;;
      3) edit_mqlaunch ;;
      4) backup_prompts ;;
      5) backup_mqlaunch ;;
      6) open_base_dir ;;
      7) open_launcher_folder ;;
      8) open_terminal_guide ;;
      9) git_menu_loop ;;
      10) net_menu_loop ;;
      11) themes_menu_loop ;;
      0) break ;;
      *) echo "${C_ERR}Invalid dev selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}'''

text, count = re.subn(
    r'dev_menu_loop\(\)\s*\{.*?^\}',
    new_dev_menu_loop,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch dev_menu_loop().")
    sys.exit(1)

# ------------------------------------------------------------
# 4) Patch show_help()
# ------------------------------------------------------------
new_show_help = r'''show_help() {
  cat <<EOH
MQLaunch v3.4 — Old School Utility

Usage:
  mqlaunch                Open main menu
  mqlaunch ai             Open AI submenu
  mqlaunch dev            Open Dev / Prompts submenu
  mqlaunch tweaks         Open Tweaks menu
  mqlaunch dashboard      Open Dashboard
  mqlaunch theme          Open Themes menu

Main menu:
  Exit is X, not 11

Direct commands:
  finder | safari | chrome | spotify | xcode
  settings | monitor
  downloads | home | utilities | applications
  ip | lock | sleep | restart-finder | date
  repo | check | ai | dev | tweaks | dashboard | theme
  prompts | prompt-files | edit | backup-prompts | backup-mqlaunch
  base | launchers | guide
  gitlaunch | netlaunch
  theme-list | theme-current | theme-reset
  theme-classic | theme-green | theme-amber | theme-ice | theme-synth
  tweaks-status | tweaks-workstation | tweaks-dev
  tweaks-clean | tweaks-fast | tweaks-all | tweaks-revert
  auto | one | atlas | decide | research | root | solve | pdebug | menu
EOH
}'''

text, count = re.subn(
    r'show_help\(\)\s*\{.*?^\}',
    new_show_help,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch show_help().")
    sys.exit(1)

# ------------------------------------------------------------
# 5) Patch run_arg_command()
# ------------------------------------------------------------
new_run_arg_command = r'''run_arg_command() {
  local cmd="${1:l}"

  case "$cmd" in
    finder) open_app "Finder" ;;
    safari) open_app "Safari" ;;
    chrome) open_app "Google Chrome" ;;
    spotify) open_app "Spotify" ;;
    xcode) open_app "Xcode" ;;
    settings) open_app "System Settings" ;;
    monitor) open_app "Activity Monitor" ;;
    downloads) open_downloads_folder ;;
    home) open_home_folder ;;
    utilities) open_utilities_folder ;;
    applications|apps) open_applications_folder ;;
    ip|network) show_network_info ;;
    lock) lock_screen ;;
    sleep) sleep_display ;;
    restart-finder|finder-restart) restart_finder ;;
    date|time) show_date_time ;;
    repo) open_repo_browser ;;
    check|health) system_check ;;
    ai) ai_menu_loop ;;
    dev) dev_menu_loop ;;
    tweaks|tweak|tw) open_tweaks_menu ;;
    tweaks-status) show_tweaks_status ;;
    tweaks-workstation) run_tweaks_workstation ;;
    tweaks-dev) run_tweaks_dev ;;
    tweaks-clean) run_tweaks_clean ;;
    tweaks-fast) run_tweaks_fast ;;
    tweaks-all) run_tweaks_all ;;
    tweaks-revert|revert-tweaks) revert_tweaks_latest ;;
    dashboard|dash) open_dashboard ;;
    theme|themes) themes_menu_loop ;;
    theme-list) theme_cmd list ;;
    theme-current) theme_cmd current ;;
    theme-reset) theme_cmd reset ;;
    theme-classic) theme_cmd apply classic ;;
    theme-green) theme_cmd apply green ;;
    theme-amber) theme_cmd apply amber ;;
    theme-ice) theme_cmd apply ice ;;
    theme-synth) theme_cmd apply synth ;;
    prompts|prompt-folder) open_ai_prompts_folder ;;
    prompt-files|files) show_prompt_files ;;
    edit|edit-mqlaunch) edit_mqlaunch ;;
    backup-prompts|backup) backup_prompts ;;
    backup-mqlaunch|backup-launcher) backup_mqlaunch ;;
    base|macos-scripts) open_base_dir ;;
    launchers|launcher-folder) open_launcher_folder ;;
    guide|terminal-guide) open_terminal_guide ;;
    gitlaunch|git) git_menu_loop ;;
    netlaunch|net) net_menu_loop ;;
    auto|one|atlas|decide|research|root|solve|pdebug|menu) safe_run_ai "$cmd" ;;
    help|-h|--help) show_help ;;
    *)
      echo "${C_ERR}Unknown command:${C_RESET} $1"
      echo
      show_help
      exit 1
      ;;
  esac
}'''

text, count = re.subn(
    r'run_arg_command\(\)\s*\{.*?^\}',
    new_run_arg_command,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch run_arg_command().")
    sys.exit(1)

if text == original:
    print("No changes were needed.")
else:
    path.write_text(text)
    print(f"Patched: {path}")
PY

echo
echo "Verify with:"
echo 'grep -n "themes_menu_loop\|11\. Themes\|theme-current\|theme-green\|mqlaunch theme" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
