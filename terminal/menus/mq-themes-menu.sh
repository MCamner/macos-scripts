#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-${HOME}/macos-scripts}"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
# Read by mqlaunch/lib/themes.sh as ${THEME_SCRIPT:-<default>} — this is the
# documented override point for which switcher the theme commands call.
# shellcheck disable=SC2034
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

THEMES_LIB="$BASE_DIR/mqlaunch/lib/themes.sh"
if [[ -f "$THEMES_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$THEMES_LIB"
else
  echo "Missing themes library: $THEMES_LIB" >&2
  exit 1
fi

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

# Keeps the themes menu interactive until the user backs out.
themes_menu_loop() {
  local choice
  # Read by mqlaunch/lib/themes.sh, which this menu calls into. `local` is
  # deliberate: bash scopes it dynamically, so it applies for the duration of
  # this loop and nowhere else.
  # shellcheck disable=SC2034
  local MQ_THEME_ERROR_HEADING_BOLD=1

  while true; do
    print_themes_menu
    read_menu_choice "" "themes" || return
    choice="$REPLY"
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

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ -z "${ZSH_VERSION:-}" && "${0}" == *mq-themes-menu* ]]; then
  main "$@"
fi
