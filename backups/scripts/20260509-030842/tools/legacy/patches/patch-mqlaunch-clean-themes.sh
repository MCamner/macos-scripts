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
# 1) Replace theme block (theme_cmd + print_themes_menu + themes_menu_loop)
# ------------------------------------------------------------
new_theme_block = r'''theme_cmd() {
  local theme_script="$BASE_DIR/terminal/themes/mq-zsh-theme-switcher.sh"
  local cmd="${1:-current}"
  shift || true

  if [[ -x "$theme_script" ]]; then
    bash "$theme_script" "$cmd" "$@"
  elif [[ -f "$theme_script" ]]; then
    chmod +x "$theme_script" 2>/dev/null || true
    bash "$theme_script" "$cmd" "$@"
  else
    print_header
    row "THEME SWITCHER"
    empty_row
    row "Theme switcher script missing:"
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

  row2 " 1. Current theme" " 2. Apply amber"
  row2 " 3. Apply green" " 4. Apply minimal"
  row2 " 5. Apply ice" " 6. Reset theme"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select theme option [0-6]: ${C_RESET}"
}

themes_menu_loop() {
  local choice

  while true; do
    print_themes_menu
    read -r choice
    echo

    case "$choice" in
      1) theme_cmd current; pause_enter ;;
      2) theme_cmd apply amber ;;
      3) theme_cmd apply green ;;
      4) theme_cmd apply minimal ;;
      5) theme_cmd apply ice ;;
      6) theme_cmd reset ;;
      0) break ;;
      *) echo "${C_ERR}Invalid theme selection:${C_RESET} $choice"; pause_enter ;;
    esac
  done
}'''

text, count = re.subn(
    r'theme_cmd\(\)\s*\{.*?themes_menu_loop\(\)\s*\{.*?^\}',
    new_theme_block,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not replace theme menu block.")
    sys.exit(1)

# ------------------------------------------------------------
# 2) Replace help text
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
  theme-current | theme-reset
  theme-amber | theme-green | theme-minimal | theme-ice
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
# 3) Replace run_arg_command
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
    theme-current) theme_cmd current ;;
    theme-reset) theme_cmd reset ;;
    theme-amber) theme_cmd apply amber ;;
    theme-green) theme_cmd apply green ;;
    theme-minimal) theme_cmd apply minimal ;;
    theme-ice) theme_cmd apply ice ;;
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
echo 'grep -n "mq-zsh-theme-switcher.sh\|Apply amber\|Apply green\|Apply minimal\|Apply ice\|theme-minimal" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
