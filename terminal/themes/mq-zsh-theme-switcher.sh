#!/usr/bin/env bash
set -euo pipefail

# Same resolution as tools/scripts/doctor.sh and tools/scripts/scan.sh. This
# read `${HOME}/macos-scripts` outright, so a checkout anywhere else could not
# run the switcher at all: it exited 1 with "Missing UI library" before reaching
# its first command. Found by a CI runner, where the checkout is under
# /home/runner/work.
BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
THEME_FILE="$BASE_DIR/terminal/themes/mq-zsh-theme-v3.zsh"
SYNC_LIB="$BASE_DIR/terminal/themes/mq-theme-sync.sh"
UI_THEME_SCRIPT="$BASE_DIR/terminal/themes/mq-theme-manager.sh"
ZSHRC="${HOME}/.zshrc"
BACKUP_DIR="$HOME/.mq-zsh-theme-backups"

# Read by ui/terminal-ui/mq-ui.sh, which this script sources below.
# ShellCheck cannot follow a source, so it sees assignments nothing reads.
# shellcheck disable=SC2034
APP_TITLE="MQ Theme Switcher"
# shellcheck disable=SC2034
APP_SUBTITLE="ZSH Theme Manager"
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

if [[ -f "$SYNC_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$SYNC_LIB"
fi

# Handles theme list.
theme_list() {
  cat <<'LIST'
amber
green
minimal
ice
macos
LIST
}

# Handles theme description.
theme_description() {
  case "$1" in
    amber)   echo "Retro amber + MQ feel" ;;
    green)   echo "Classic green terminal vibe" ;;
    minimal) echo "Cleaner low-noise prompt" ;;
    ice)     echo "Cool cyan / blue look" ;;
    macos)   echo "Clean Apple-inspired blue/gray theme" ;;
    *)       return 1 ;;
  esac
}

# Handles current variant.
current_variant() {
  if grep -Eq '^export MQ_ZSH_VARIANT=' "$ZSHRC" 2>/dev/null; then
    grep -E '^export MQ_ZSH_VARIANT=' "$ZSHRC" | tail -n 1 | sed -E 's/^export MQ_ZSH_VARIANT="?([^"]+)"?/\1/'
  else
    echo "not-set"
  fi
}

# Handles theme source present.
theme_source_present() {
  grep -Fq 'source "$HOME/macos-scripts/terminal/themes/mq-zsh-theme-v3.zsh"' "$ZSHRC" 2>/dev/null
}

# Backs up zshrc.
backup_zshrc() {
  mkdir -p "$BACKUP_DIR"
  # Split so `local` does not mask the exit status of the substitution.
  local backup_file
  backup_file="$BACKUP_DIR/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
  if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "$backup_file"
    echo "$backup_file"
  else
    : > "$backup_file"
    echo "$backup_file"
  fi
}

# Handles clean existing theme lines.
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

# Handles apply theme.
apply_theme() {
  local variant="$1"

  if ! theme_description "$variant" >/dev/null 2>&1; then
    ui_err "Unknown theme: $variant"
    # A variant that does not exist is an invalid argument, the same class as
    # an unknown command word above — 2, not 1.
    return 2
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

  local sync_note=""
  if declare -f mq_theme_sync_counterpart >/dev/null 2>&1; then
    sync_note="$(mq_theme_sync_counterpart "$variant" "$UI_THEME_SCRIPT" "UI")"
  fi

  print_header
  row_bold "THEME APPLIED"
  empty_row
  row "Theme: $variant"
  row "Description: $(theme_description "$variant")"
  if [[ -n "$sync_note" ]]; then
    row "$sync_note"
  fi
  row "Backup:"
  row " $backup_file"
  empty_row
  row "Run this to activate it now:"
  row " exec zsh"
  print_footer
  pause_enter
}

# Handles reset theme.
reset_theme() {
  local backup_file sync_note="" mine theirs
  backup_file="$(backup_zshrc)"

  if declare -f mq_theme_reset_counterpart >/dev/null 2>&1; then
    mine="$(current_variant)"
    theirs=""
    if [[ -x "$UI_THEME_SCRIPT" ]]; then
      theirs="$("$UI_THEME_SCRIPT" current 2>/dev/null \
        | sed -n 's/^Current theme: //p' | head -1)"
    fi
    sync_note="$(mq_theme_reset_counterpart "$mine" "$theirs" \
      "$UI_THEME_SCRIPT" "UI")"
  fi

  clean_existing_theme_lines

  print_header
  row_bold "THEME RESET"
  empty_row
  row "Removed MQ_ZSH_VARIANT and theme source line from .zshrc."
  if [[ -n "$sync_note" ]]; then
    row "$sync_note"
  fi
  row "Backup:"
  row " $backup_file"
  empty_row
  row "Run this to reload your shell:"
  row " exec zsh"
  print_footer
  pause_enter
}

# Shows current.
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

# Shows list.
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

# Prints menu.
print_menu() {
  print_header
  row_bold "ZSH THEME SWITCHER"
  empty_row

  row2 " 1. Show current theme" " 2. List themes"
  row2 " 3. Apply amber" " 4. Apply green"
  row2 " 5. Apply minimal" " 6. Apply ice"
  row2 " 7. Apply macos" " 8. Reset theme"
  row2 " 0. Exit" ""

  print_footer
}

# Runs the menu loop.
menu_loop() {
  local choice
  while true; do
    print_menu
    read_menu_choice "Select option [0-8] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_current ;;
      2) show_list ;;
      3) apply_theme amber ;;
      4) apply_theme green ;;
      5) apply_theme minimal ;;
      6) apply_theme ice ;;
      7) apply_theme macos ;;
      8) reset_theme ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
usage() {
  cat <<USAGE
mq-zsh-theme-switcher.sh - switch MQ zsh theme variants

Usage:
  mq-zsh-theme-switcher.sh menu
  mq-zsh-theme-switcher.sh list
  mq-zsh-theme-switcher.sh current
  mq-zsh-theme-switcher.sh apply <amber|green|minimal|ice|macos>
  mq-zsh-theme-switcher.sh reset

Examples:
  mq-zsh-theme-switcher.sh apply amber
  mq-zsh-theme-switcher.sh current
  mq-zsh-theme-switcher.sh menu
USAGE
}

# Runs the main entry point.
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
      # 2, not 1. A command line that cannot be acted on is a usage error, and
      # the rest of mqlaunch already says so — `mqlaunch system bogusverb` and
      # the srm namespace both answer 2. This surface said 1, which is the code
      # a caller reads as "the theme could not be applied" rather than "there
      # was no theme to apply". 1 is kept below for the failures that really are
      # runtime: a missing UI library, a missing theme file.
      [[ $# -ge 2 ]] || { usage; exit 2; }
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
      exit 2
      ;;
  esac
}

main "$@"
