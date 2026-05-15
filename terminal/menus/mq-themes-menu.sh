#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
THEME_SCRIPT="$BASE_DIR/terminal/themes/mq-zsh-theme-switcher.sh"

# shellcheck disable=SC2034
APP_TITLE="MQ Themes"
# shellcheck disable=SC2034
APP_SUBTITLE="Theme Switcher"
# shellcheck disable=SC2034
APP_AUTHOR="Author Mattias Camner"
# shellcheck disable=SC2034
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

# Handles theme cmd.
theme_cmd() {
  local cmd="${1:-current}"
  shift || true

  if [[ -x "$THEME_SCRIPT" ]]; then
    bash "$THEME_SCRIPT" "$cmd" "$@"
  elif [[ -f "$THEME_SCRIPT" ]]; then
    chmod +x "$THEME_SCRIPT" 2>/dev/null || true
    bash "$THEME_SCRIPT" "$cmd" "$@"
  else
    print_header
    row_bold "THEME SWITCHER"
    empty_row
    row "Theme switcher script missing:"
    row " $THEME_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

# Prints themes menu.
print_themes_menu() {
  local width color
  width="$(surface_terminal_width)"
  color="$(surface_panel_color)"

  print_header
  surface_panel_header "Themes" "Themes" "$width" "$color"
  surface_split_row " 1. Current theme" " 2. Apply amber" "$width" "$color"
  surface_split_row " 3. Apply green" " 4. Apply minimal" "$width" "$color"
  surface_split_row " 5. Apply ice" " 6. Apply macos" "$width" "$color"
  surface_split_row " 7. Reset theme" " b. Back" "$width" "$color"
  surface_row "" "$width" "$color"
  surface_bottom "$width" "$color"
  printf '\n'
}

# Handles themes menu loop.
themes_menu_loop() {
  local choice

  while true; do
    print_themes_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "themes" || return
    else
      printf "\nthemes > "; read -r choice
    fi
    echo

    case "$choice" in
      1) theme_cmd current; pause_enter ;;
      2) theme_cmd apply amber ;;
      3) theme_cmd apply green ;;
      4) theme_cmd apply minimal ;;
      5) theme_cmd apply ice ;;
      6) theme_cmd apply macos ;;
      7) theme_cmd reset ;;
      b|B|0) break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Runs the main entry point.
main() {
  themes_menu_loop
}

main "$@"
