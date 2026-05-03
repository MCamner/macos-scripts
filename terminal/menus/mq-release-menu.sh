#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
RELEASE_REPO="${MQ_RELEASE_REPO:-$BASE_DIR}"
RELEASE_SCRIPT=""
CHANGELOG_FILE=""
VERSION_FILE=""

# shellcheck disable=SC2034
APP_TITLE="MQ Release"
# shellcheck disable=SC2034
APP_SUBTITLE="Release Automation and Versioning"
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

refresh_release_paths() {
  RELEASE_SCRIPT="$RELEASE_REPO/release.sh"
  CHANGELOG_FILE="$RELEASE_REPO/CHANGELOG.md"
  VERSION_FILE="$RELEASE_REPO/VERSION"
}

resolve_repo_path() {
  local path="$1"

  case "$path" in
    \~) path="$HOME" ;;
    \~/*) path="$HOME/${path#\~/}" ;;
  esac

  if [[ "$path" != /* ]]; then
    path="$(pwd)/$path"
  fi

  (cd "$path" 2>/dev/null && pwd) || return 1
}

set_release_repo() {
  local path="$1"
  local resolved

  resolved="$(resolve_repo_path "$path")" || {
    ui_err "Repo path not found: $path"
    pause_enter
    return 1
  }

  if [[ ! -d "$resolved/.git" ]]; then
    ui_err "Not a git repository: $resolved"
    pause_enter
    return 1
  fi

  RELEASE_REPO="$resolved"
  refresh_release_paths
}

choose_release_repo() {
  local path=""

  print_header
  row_bold "SELECT RELEASE REPO"
  empty_row
  row "Current repo:"
  row " $RELEASE_REPO"
  empty_row
  row "Press Enter to keep current repo."
  row "Or enter another repo path."
  print_footer

  printf "%bRepo path: %b" "$C_TITLE" "$C_RESET"
  read -r path

  if [[ -z "${path// }" ]]; then
    refresh_release_paths
    return 0
  fi

  set_release_repo "$path"
}

require_release_script() {
  if [[ ! -x "$RELEASE_SCRIPT" ]]; then
    print_header
    row_bold "RELEASE"
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
  git -C "$RELEASE_REPO" describe --tags --abbrev=0 2>/dev/null || true
}

show_release_status() {
  print_header
  row_bold "RELEASE STATUS"
  empty_row

  row "Repo:            $RELEASE_REPO"
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

  print_header
  row_bold "$prompt"
  empty_row
  row "Example: 0.1.4"
  print_footer
  printf "%bVersion: %b" "$C_TITLE" "$C_RESET"
  read -r REPLY

  if [[ -z "${REPLY// }" ]]; then
    ui_warn "No version entered."
    pause_enter
    return 1
  fi
}

run_release_command() {
  local title="$1"
  local status=0
  shift

  require_release_script || return 1

  print_header
  row_bold "$title"
  empty_row

  (
    cd "$RELEASE_REPO" || exit 1
    "$RELEASE_SCRIPT" "$@"
  ) || status=$?

  if [[ "$status" -ne 0 ]]; then
    empty_row
    row "Release command failed with exit code: $status"
  fi

  print_footer
  pause_enter
  return "$status"
}

run_release_dry() {
  local version=""
  prompt_version "DRY RUN RELEASE" || return 1
  version="$REPLY"
  run_release_command "DRY RUN RELEASE" --dry-run "$version"
}

run_release_live() {
  local version=""
  prompt_version "RUN RELEASE" || return 1
  version="$REPLY"
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
  printf "%bTag: %b" "$C_TITLE" "$C_RESET"
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
    cd "$RELEASE_REPO" || exit 1
    gh release create "$tag" \
      --title "Release $tag" \
      --notes-file "$CHANGELOG_FILE"
  )

  print_footer
  pause_enter
}

print_menu() {
  print_header
  row_bold "RELEASE"
  empty_row
  row "Repo: $RELEASE_REPO"
  empty_row

  row2 " 1. Release status" " 2. Change repo"
  row2 " 3. Dry run release" " 4. Run release"
  row2 " 5. Create GitHub release" " 6. View changelog"
  row2 " 7. Show latest tags" " 8. Open changelog"
  row2 " 9. Open release script" ""
  row2 " b. Back" ""

  print_footer
}

menu_loop() {
  local choice

  choose_release_repo || true

  while true; do
    print_menu
    read_menu_choice "Select option [1-9,b] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_release_status ;;
      2) choose_release_repo || true ;;
      3) run_release_dry || true ;;
      4) run_release_live || true ;;
      5) create_github_release_only || true ;;
      6) show_changelog ;;
      7) show_tags ;;
      8) open_changelog_in_editor ;;
      9) open_release_script_in_editor ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-release-menu.sh - interactive release menu

Usage:
  mq-release-menu.sh [command] [repo-path]

Commands:
  menu      Open menu (default)
  repo      Select repo, then open menu
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
  local repo_arg="${2:-}"

  if [[ -n "$repo_arg" ]]; then
    set_release_repo "$repo_arg" || exit 1
  else
    refresh_release_paths
  fi

  case "$cmd" in
    menu) menu_loop ;;
    repo) choose_release_repo && menu_loop ;;
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
