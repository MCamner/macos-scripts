#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
RELEASE_SCRIPT="$BASE_DIR/tools/release.sh"
CHANGELOG_FILE="$BASE_DIR/CHANGELOG.md"
VERSION_FILE="$BASE_DIR/VERSION"

APP_TITLE="MQ Release"
APP_SUBTITLE="Versioning and Release Automation"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

require_release_script() {
  if [[ ! -x "$RELEASE_SCRIPT" ]]; then
    print_header
    row_bold "RELEASE MENU"
    empty_row
    row "Missing or non-executable script:"
    row " $RELEASE_SCRIPT"
    row "Run:"
    row " chmod +x $RELEASE_SCRIPT"
    print_footer
    pause_enter
    return 1
  fi
}

current_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    head -n 1 "$VERSION_FILE"
  else
    echo "unknown"
  fi
}

latest_tag() {
  git -C "$BASE_DIR" describe --tags --abbrev=0 2>/dev/null || true
}

show_release_status() {
  print_header
  row_bold "RELEASE STATUS"
  empty_row

  row "Current version: $(current_version)"
  row "Latest tag:      $(latest_tag || true)"
  row "Release script:  $RELEASE_SCRIPT"
  row "Changelog:       $CHANGELOG_FILE"

  print_footer
  pause_enter
}

show_changelog() {
  print_header
  row_bold "CHANGELOG"
  empty_row

  if [[ ! -f "$CHANGELOG_FILE" ]]; then
    row "Missing changelog:"
    row " $CHANGELOG_FILE"
  elif command -v bat >/dev/null 2>&1; then
    bat --style=plain --paging=never "$CHANGELOG_FILE" | head -n 80
  else
    head -n 80 "$CHANGELOG_FILE"
  fi

  print_footer
  pause_enter
}

show_tags() {
  print_header
  row_bold "LATEST TAGS"
  empty_row

  git -C "$BASE_DIR" tag --sort=-creatordate | head -n 12 || true

  print_footer
  pause_enter
}

open_changelog_in_editor() {
  print_header
  row_bold "OPEN CHANGELOG"
  empty_row
  row "Opening:"
  row " $CHANGELOG_FILE"
  print_footer

  if command -v code >/dev/null 2>&1; then
    code "$CHANGELOG_FILE"
  else
    open "$CHANGELOG_FILE"
  fi
}

open_release_script_in_editor() {
  print_header
  row_bold "OPEN RELEASE SCRIPT"
  empty_row
  row "Opening:"
  row " $RELEASE_SCRIPT"
  print_footer

  if command -v code >/dev/null 2>&1; then
    code "$RELEASE_SCRIPT"
  else
    open "$RELEASE_SCRIPT"
  fi
}

prompt_version() {
  local prompt="$1"
  local version=""

  print_header
  row_bold "$prompt"
  empty_row
  row "Example: 0.1.4"
  print_footer
  printf "${C_TITLE}Version: ${C_RESET}"
  read -r version

  if [[ -z "${version// }" ]]; then
    ui_warn "No version entered."
    pause_enter
    return 1
  fi

  printf '%s\n' "$version"
}

run_release_command() {
  local title="$1"
  shift

  require_release_script || return 1

  print_header
  row_bold "$title"
  empty_row

  (
    cd "$BASE_DIR" || exit 1
    "$RELEASE_SCRIPT" "$@"
  )

  print_footer
  pause_enter
}

run_release_dry() {
  local version=""
  version="$(prompt_version "DRY RUN RELEASE")" || return 1
  run_release_command "DRY RUN RELEASE" --dry-run "$version"
}

run_release_live() {
  local version=""
  version="$(prompt_version "RUN RELEASE")" || return 1
  run_release_command "RUN RELEASE" "$version"
}

create_github_release_only() {
  local tag=""
  local latest=""

  latest="$(latest_tag)"

  print_header
  row_bold "CREATE GITHUB RELEASE"
  empty_row

  if [[ -n "$latest" ]]; then
    row "Press Enter to use latest tag: $latest"
  fi

  print_footer
  printf "${C_TITLE}Tag: ${C_RESET}"
  read -r tag

  if [[ -z "${tag// }" && -n "$latest" ]]; then
    tag="$latest"
  fi

  if [[ -z "${tag// }" ]]; then
    ui_warn "No tag entered."
    pause_enter
    return 1
  fi

  print_header
  row_bold "GITHUB RELEASE"
  empty_row

  (
    cd "$BASE_DIR" || exit 1
    gh release create "$tag" \
      --title "Release $tag" \
      --notes-file "$CHANGELOG_FILE"
  )

  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "RELEASE MENU"
  empty_row

  row2 " 1. Release status" " 2. Dry run release"
  row2 " 3. Run release" " 4. Create GitHub release"
  row2 " 5. View changelog" " 6. Show latest tags"
  row2 " 7. Open changelog" " 8. Open release script"
  row2 " 0. Back" ""

  print_footer
  printf "${C_TITLE}Select option [0-8]: ${C_RESET}"
}

menu_loop() {
  local choice

  while true; do
    print_menu
    read -r choice
    echo

    case "$choice" in
      1) show_release_status ;;
      2) run_release_dry ;;
      3) run_release_live ;;
      4) create_github_release_only ;;
      5) show_changelog ;;
      6) show_tags ;;
      7) open_changelog_in_editor ;;
      8) open_release_script_in_editor ;;
      0) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-release-menu.sh - interactive release menu

Usage:
  mq-release-menu.sh [command]

Commands:
  menu      Open menu (default)
  status    Show release status
  dry-run   Start dry-run release flow
  release   Start live release flow
  notes     View changelog
  tags      Show latest tags
  help      Show this help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    status) show_release_status ;;
    dry-run) run_release_dry ;;
    release) run_release_live ;;
    notes) show_changelog ;;
    tags) show_tags ;;
    help|-h|--help) usage ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "${1:-menu}"
