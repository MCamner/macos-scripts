#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

APP_TITLE="MQ UI Demo"
APP_SUBTITLE="Shared UI Preview"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

show_demo() {
  print_header
  row_bold "MQ UI DEMO"
  empty_row

  row "Detta är en demo av det delade UI-lagret."
  row "Filen mq-ui.sh gör inget själv — den används av andra script."
  empty_row

  row "EXEMPEL PÅ KOMPONENTER"
  row2 " row()" " en enkel rad"
  row2 " row2()" " två kolumner"
  row3 " row3()" " tre kolumner" " meny-layout"
  empty_row

  row "STATUS"
  row2 " UI library" " OK"
  row2 " Terminal launcher" " MQ style"
  row2 " Tweaks module" " Shared UI"
  empty_row

  row "MENU"
  row2 " 1. Refresh demo" " 2. Show paths"
  row2 " 0. Exit" ""

  print_footer
  printf "${C_TITLE}Select option [0-2]: ${C_RESET}"
}

show_paths() {
  print_header
  row_bold "PATHS"
  empty_row
  row "BASE_DIR:"
  row " $BASE_DIR"
  empty_row
  row "UI_LIB:"
  row " $UI_LIB"
  print_footer
  pause_enter
}

main() {
  local choice

  while true; do
    show_demo
    read -r choice
    echo

    case "$choice" in
      1) ;;
      2) show_paths ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

main
