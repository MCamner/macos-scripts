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
# 1) Add open_dashboard() if missing
# ------------------------------------------------------------
dashboard_func = r'''
open_dashboard() {
  local dashboard_script="$BASE_DIR/ui/dashboards/mq-dashboard.sh"

  if [[ -x "$dashboard_script" ]]; then
    bash "$dashboard_script" menu
  elif [[ -f "$dashboard_script" ]]; then
    chmod +x "$dashboard_script" 2>/dev/null || true
    bash "$dashboard_script" menu
  else
    print_header
    row "MQ DASHBOARD"
    empty_row
    row "Dashboard script missing:"
    row " $dashboard_script"
    print_footer
    pause_enter
  fi
}

'''

if 'open_dashboard() {' not in text:
    if 'backup_mqlaunch() {' in text:
        text = text.replace('backup_mqlaunch() {', dashboard_func + 'backup_mqlaunch() {', 1)
    elif '# --- Menus --------------------------------------------------' in text:
        text = text.replace('# --- Menus --------------------------------------------------', dashboard_func + '# --- Menus --------------------------------------------------', 1)
    else:
        print("Could not find safe insertion point for open_dashboard().")
        sys.exit(1)

# ------------------------------------------------------------
# 2) Replace print_main_menu()
# ------------------------------------------------------------
new_print_main_menu = r'''print_main_menu() {
  print_header
  row_bold "MAIN MENU"
  empty_row

  row "APPS"
  row3 " 1. Finder" " 2. Safari" " 3. Google Chrome"
  row3 " 4. Spotify" " 5. Xcode" " 6. System Settings"
  row3 " 7. Activity Monitor" "" ""

  empty_row
  row "SYSTEM / CONTROL"
  row3 " 8. Downloads folder" " 9. Home folder" "10. Show IP + network"
  row3 "12. Lock screen" "13. Sleep display" ""

  empty_row
  row "TOOLS"
  row3 "14. Utilities folder" "15. Applications folder" "16. Restart Finder"
  row3 "17. Show date and time" "18. Open repo in browser" "19. Run system check"

  empty_row
  row "MENUS"
  row3 "20. AI Modes" "21. Dev / Prompts" "22. Tweaks"
  row3 "23. Dashboard" "" ""

  print_main_footer
  printf "${C_TITLE}Select option [1-10,12-23,X]: ${C_RESET}"
}'''

text, count = re.subn(
    r'print_main_menu\(\)\s*\{.*?^\}',
    new_print_main_menu,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch print_main_menu().")
    sys.exit(1)

# ------------------------------------------------------------
# 3) Replace main_loop()
# ------------------------------------------------------------
new_main_loop = r'''main_loop() {
  local choice

  while true; do
    print_main_menu
    read -r choice
    echo

    case "$choice" in
      1) open_app "Finder" ;;
      2) open_app "Safari" ;;
      3) open_app "Google Chrome" ;;
      4) open_app "Spotify" ;;
      5) open_app "Xcode" ;;
      6) open_app "System Settings" ;;
      7) open_app "Activity Monitor" ;;
      8) open_downloads_folder ;;
      9) open_home_folder ;;
      10) show_network_info ;;
      x|X) echo "Exiting ${APP_TITLE}..."; exit 0 ;;
      12) lock_screen ;;
      13) sleep_display ;;
      14) open_utilities_folder ;;
      15) open_applications_folder ;;
      16) restart_finder ;;
      17) show_date_time ;;
      18) open_repo_browser ;;
      19) system_check ;;
      20) ai_menu_loop ;;
      21) dev_menu_loop ;;
      22) open_tweaks_menu ;;
      23) open_dashboard ;;
      *) echo "${C_ERR}Invalid selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}'''

text, count = re.subn(
    r'main_loop\(\)\s*\{.*?^\}',
    new_main_loop,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch main_loop().")
    sys.exit(1)

# ------------------------------------------------------------
# 4) Replace show_help()
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

Main menu:
  Exit is X, not 11

Direct commands:
  finder | safari | chrome | spotify | xcode
  settings | monitor
  downloads | home | utilities | applications
  ip | lock | sleep | restart-finder | date
  repo | check | ai | dev | tweaks | dashboard
  prompts | prompt-files | edit | backup-prompts | backup-mqlaunch
  base | launchers | guide
  gitlaunch | netlaunch
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
# 5) Replace run_arg_command()
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
echo 'grep -n "open_dashboard\|23\. Dashboard\|dashboard|dash\|mqlaunch dashboard" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
