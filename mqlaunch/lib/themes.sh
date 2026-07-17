#!/usr/bin/env bash

# Opens the themes menu from the live menu layer.
open_themes_menu() {
  local themes_script="$BASE_DIR/terminal/menus/mq-themes-menu.sh"

  if command -v themes_menu_loop >/dev/null 2>&1; then
    MQ_USE_DASHBOARD_HEADER=1 themes_menu_loop
  elif [[ -x "$themes_script" ]]; then
    MQ_USE_DASHBOARD_HEADER=1 "$themes_script"
  elif [[ -f "$themes_script" ]]; then
    chmod +x "$themes_script" 2>/dev/null || true
    MQ_USE_DASHBOARD_HEADER=1 bash "$themes_script"
  else
    print_header
    row "THEMES MENU"
    empty_row
    row "Themes menu not found:"
    row " $themes_script"
    print_footer
    pause_enter
  fi
}

# Reads or applies the theme command setting.
theme_cmd() {
  local theme_script="${THEME_SCRIPT:-$BASE_DIR/terminal/themes/mq-zsh-theme-switcher.sh}"
  local cmd="${1:-current}"
  shift || true

  if [[ -x "$theme_script" ]]; then
    bash "$theme_script" "$cmd" "$@"
  elif [[ -f "$theme_script" ]]; then
    chmod +x "$theme_script" 2>/dev/null || true
    bash "$theme_script" "$cmd" "$@"
  else
    print_header
    if [[ "${MQ_THEME_ERROR_HEADING_BOLD:-0}" == "1" ]] && command -v row_bold >/dev/null 2>&1; then
      row_bold "THEME SWITCHER"
    else
      row "THEME SWITCHER"
    fi
    empty_row
    row "Theme switcher script missing:"
    row " $theme_script"
    print_footer
    pause_enter
    return 1
  fi
}

# Reports the selected theme variant from the user's Zsh config.
theme_current_variant() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Eq '^export MQ_ZSH_VARIANT=' "$zshrc" 2>/dev/null; then
    grep -E '^export MQ_ZSH_VARIANT=' "$zshrc" | tail -n 1 | sed -E 's/^export MQ_ZSH_VARIANT="?([^"]+)"?/\1/'
  else
    echo "not-set"
  fi
}

# Reports whether the current Zsh config sources the MQ theme.
theme_source_state() {
  local zshrc="$HOME/.zshrc"

  if [[ -f "$zshrc" ]] && grep -Fq 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"' "$zshrc" 2>/dev/null; then
    echo "PRESENT"
  else
    echo "MISSING"
  fi
}
