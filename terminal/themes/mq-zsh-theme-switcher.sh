#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
THEME_FILE="$BASE_DIR/terminal/themes/mq-zsh-theme-v3.zsh"
ZSHRC="${HOME}/.zshrc"
BACKUP_DIR="$HOME/.mq-zsh-theme-backups"

APP_TITLE="MQ Theme Switcher"
APP_SUBTITLE="ZSH Theme Manager"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

theme_list() {
  cat <<'LIST'
amber
green
minimal
ice
LIST
}

theme_description() {
  case "$1" in
    amber)   echo "Retro amber + MQ feel" ;;
    green)   echo "Classic green terminal vibe" ;;
    minimal) echo "Cleaner low-noise prompt" ;;
    ice)     echo "Cool cyan / blue look" ;;
    *)       return 1 ;;
  esac
}

current_variant() {
  if grep -Eq '^export MQ_ZSH_VARIANT=' "$ZSHRC" 2>/dev/null; then
    grep -E '^export MQ_ZSH_VARIANT=' "$ZSHRC" | tail -n 1 | sed -E 's/^export MQ_ZSH_VARIANT="?([^"]+)"?/\1/'
  else
    echo "not-set"
  fi
}

theme_source_present() {
  grep -Fq 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"' "$ZSHRC" 2>/dev/null
}

backup_zshrc() {
  mkdir -p "$BACKUP_DIR"
  local backup_file="$BACKUP_DIR/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
  if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "$backup_file"
    echo "$backup_file"
  else
    : > "$backup_file"
    echo "$backup_file"
  fi
}

clean_existing_theme_lines() {
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$ZSHRC" ]]; then
    grep -v 'mq-zsh-theme-v3.zsh\|MQ_ZSH_VARIANT=' "$ZSHRC" > "$tmp" || true
    mv "$tmp" "$ZSHRC"
  else
    : > "$ZSHRC"
    rm -f "$tmp"
  fi
}

apply_theme() {
  local variant="$1"

  if ! theme_description "$variant" >/dev/null 2>&1; then
    ui_err "Unknown theme: $variant"
    return 1
  fi

  if [[ ! -f "$THEME_FILE" ]]; then
    ui_err "Missing theme file: $THEME_FILE"
    return 1
  fi

  local backup_file
  backup_file="$(backup_zshrc)"
  clean_existing_theme_lines

  {
    echo
    echo "export MQ_ZSH_VARIANT=\"$variant\""
    echo 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"'
  } >> "$ZSHRC"

  print_header
  row_bold "THEME APPLIED"
  empty_row
  row "Theme: $variant"
  row "Description: $(theme_description "$variant")"
  row "Backup:"
  row " $backup_file"
  empty_row
  row "Run this to activate it now:"
  row " exec zsh"
  print_footer
  pause_enter
}

reset_theme() {
  local backup_file
  backup_file="$(backup_zshrc)"
  clean_existing_theme_lines

  print_header
  row_bold "THEME RESET"
  empty_row
  row "Removed MQ_ZSH_VARIANT and theme source line from .zshrc."
  row "Backup:"
  row " $backup_file"
  empty_row
  row "Run this to reload your shell:"
  row " exec zsh"
  print_footer
  pause_enter
}

show_current() {
  print_header
  row_bold "CURRENT THEME"
  empty_row
  row "Current variant: $(current_variant)"
  if theme_source_present; then
    row "Theme source: PRESENT"
  else
    row "Theme source: MISSING"
  fi
  row "Theme file:"
  row " $THEME_FILE"
  print_footer
  pause_enter
}

show_list() {
  print_header
  row_bold "AVAILABLE THEMES"
  empty_row
  while read -r name; do
    [[ -z "$name" ]] && continue
    row2 " $name" " $(theme_description "$name")"
  done < <(theme_list)
  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "ZSH THEME SWITCHER"
  empty_row

  row2 " 1. Show current theme" " 2. List themes"
  row2 " 3. Apply amber" " 4. Apply green"
  row2 " 5. Apply minimal" " 6. Apply ice"
  row2 " 7. Reset theme" " 0. Exit"

  print_footer
  printf "${C_TITLE}Select option [0-7]: ${C_RESET}"
}

menu_loop() {
  local choice
  while true; do
    print_menu
    read -r choice
    echo

    case "$choice" in
      1) show_current ;;
      2) show_list ;;
      3) apply_theme amber ;;
      4) apply_theme green ;;
      5) apply_theme minimal ;;
      6) apply_theme ice ;;
      7) reset_theme ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-zsh-theme-switcher.sh - switch MQ zsh theme variants

Usage:
  mq-zsh-theme-switcher.sh menu
  mq-zsh-theme-switcher.sh list
  mq-zsh-theme-switcher.sh current
  mq-zsh-theme-switcher.sh apply <amber|green|minimal|ice>
  mq-zsh-theme-switcher.sh reset

Examples:
  mq-zsh-theme-switcher.sh apply amber
  mq-zsh-theme-switcher.sh current
  mq-zsh-theme-switcher.sh menu
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu)
      menu_loop
      ;;
    list)
      while read -r name; do
        [[ -z "$name" ]] && continue
        printf "%-10s %s\n" "$name" "$(theme_description "$name")"
      done < <(theme_list)
      ;;
    current)
      echo "Current variant: $(current_variant)"
      if theme_source_present; then
        echo "Theme source: PRESENT"
      else
        echo "Theme source: MISSING"
      fi
      ;;
    apply)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      apply_theme "$2"
      ;;
    reset)
      reset_theme
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "$@"
