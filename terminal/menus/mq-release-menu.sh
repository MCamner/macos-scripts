#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"
RELEASE_REPO="${MQ_RELEASE_REPO:-}"
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

default_release_repo() {
  local detected=""

  detected="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$detected" ]]; then
    printf '%s\n' "$detected"
  else
    printf '%s\n' "$BASE_DIR"
  fi
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
  row "Detected from current PATH:"
  row " $(default_release_repo)"
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

init_release_files() {
  local version today confirm

  print_header
  row_bold "INITIALIZE RELEASE FILES"
  empty_row
  row "Repo:"
  row " $RELEASE_REPO"
  empty_row
  row "This can create missing files:"
  row " release.sh"
  row " VERSION"
  row " CHANGELOG.md"
  empty_row
  row "Existing files will not be overwritten."
  print_footer

  printf "%bInitial version [0.1.0]: %b" "$C_TITLE" "$C_RESET"
  read -r version
  version="${version:-0.1.0}"

  printf "%bCreate missing release files? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || {
    ui_warn "Initialization cancelled."
    pause_enter
    return 1
  }

  today="$(date +%F)"

  if [[ ! -f "$VERSION_FILE" ]]; then
    printf '%s\n' "$version" > "$VERSION_FILE"
  fi

  if [[ ! -f "$CHANGELOG_FILE" ]]; then
    cat > "$CHANGELOG_FILE" <<EOF_CHANGELOG
# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

## [$version] - $today

### Added

* Initial release setup
EOF_CHANGELOG
  fi

  if [[ ! -f "$RELEASE_SCRIPT" ]]; then
    cp "$BASE_DIR/release.sh" "$RELEASE_SCRIPT"
    chmod +x "$RELEASE_SCRIPT"
  elif [[ ! -x "$RELEASE_SCRIPT" ]]; then
    chmod +x "$RELEASE_SCRIPT"
  fi

  print_header
  row_bold "INITIALIZE RELEASE FILES"
  empty_row
  row "Release files are ready:"
  row " $RELEASE_SCRIPT"
  row " $VERSION_FILE"
  row " $CHANGELOG_FILE"
  print_footer
  pause_enter
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

  git -C "$RELEASE_REPO" tag --sort=-creatordate | head -n 12 || true

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

  local exit_code=0
  (
    cd "$RELEASE_REPO" || exit 1
    gh release create "$tag" \
      --title "Release $tag" \
      --notes-file "$CHANGELOG_FILE"
  ) || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    ui_err "GitHub release failed (exit $exit_code). Check network/API status and try again."
  else
    ui_ok "Release $tag created successfully."
  fi

  print_footer
  pause_enter
}

generate_changelog_section() {
  local version="$1"
  local changelog="$2"
  local today last_tag commits entry confirm

  today="$(date +%F)"
  last_tag="$(git -C "$RELEASE_REPO" describe --tags --abbrev=0 2>/dev/null || true)"

  if [[ -n "$last_tag" ]]; then
    commits="$(git -C "$RELEASE_REPO" log "${last_tag}..HEAD" --oneline --no-merges 2>/dev/null || true)"
  else
    commits="$(git -C "$RELEASE_REPO" log --oneline --no-merges --max-count=20 2>/dev/null || true)"
  fi

  print_header
  row_bold "AUTO RELEASE — CHANGELOG"
  empty_row
  row "Genererar sektion för $version baserat på commits sedan $last_tag:"
  empty_row

  if [[ -n "$commits" ]]; then
    while IFS= read -r line; do
      row "  $line"
    done <<< "$commits"
  else
    row "  (inga commits hittades)"
  fi

  empty_row
  print_footer

  printf "%bSkriv in changelog-sektion automatiskt? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || {
    ui_warn "Hoppar över changelog-generering. Lägg till manuellt."
    pause_enter
    return 1
  }

  # Build the new section
  entry="## [$version] - $today"$'\n'
  entry+=$'\n'
  entry+="### Changed"$'\n'
  entry+=$'\n'
  if [[ -n "$commits" ]]; then
    while IFS= read -r line; do
      entry+="* ${line#* }"$'\n'
    done <<< "$commits"
  else
    entry+="* Release $version"$'\n'
  fi
  entry+=$'\n'"---"$'\n'

  # Insert after the header block (first blank line after the intro paragraph)
  local header_end
  header_end="$(grep -n "^All notable" "$changelog" | head -1 | cut -d: -f1)"

  if [[ -n "$header_end" ]]; then
    local before after
    before="$(head -n "$((header_end + 1))" "$changelog")"
    after="$(tail -n "+$((header_end + 2))" "$changelog")"
    printf '%s\n\n%s\n%s\n' "$before" "$entry" "$after" > "$changelog"
  else
    # Fallback: prepend after first line
    local rest
    rest="$(tail -n +2 "$changelog")"
    printf '%s\n\n%s\n%s\n' "$(head -1 "$changelog")" "$entry" "$rest" > "$changelog"
  fi

  ui_ok "Changelog-sektion för $version skriven."
  pause_enter
}

auto_release() {
  local version confirm dry_status

  prompt_version "AUTO RELEASE" || return 1
  version="$REPLY"

  print_header
  row_bold "AUTO RELEASE — PREVIEW"
  empty_row
  row "Repo:    $RELEASE_REPO"
  row "Version: $version"
  empty_row
  row "Steps:"
  row " 1. Check working tree (commit or stash if dirty)"
  row " 2. Auto-generate changelog (if missing)"
  row " 3. Dry run"
  row " 4. Live release"
  row " 5. Create GitHub release"
  empty_row
  print_footer

  printf "%bProceed with auto release %s? [y/N]: %b" "$C_TITLE" "$version" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { ui_warn "Cancelled."; pause_enter; return 1; }

  # Check for unclean working tree
  if ! git -C "$RELEASE_REPO" diff --quiet --ignore-submodules HEAD 2>/dev/null; then
    local dirty_files
    dirty_files="$(git -C "$RELEASE_REPO" status --short)"

    print_header
    row_bold "AUTO RELEASE — UNCOMMITTED CHANGES"
    empty_row
    ui_warn "Working tree is not clean:"
    empty_row
    while IFS= read -r line; do row "  $line"; done <<< "$dirty_files"
    empty_row
    row "  c) Commit all changes"
    row "  s) Stash changes"
    row "  x) Abort"
    print_footer

    printf "%b[c/s/x]: %b" "$C_TITLE" "$C_RESET"
    read -r confirm
    case "$confirm" in
      c|C)
        printf "%bCommit message: %b" "$C_TITLE" "$C_RESET"
        read -r msg
        msg="${msg:-chore: prepare release $version}"
        (cd "$RELEASE_REPO" && git add -A && git commit -m "$msg") || {
          ui_err "Commit failed."
          pause_enter
          return 1
        }
        ui_ok "Committed."
        ;;
      s|S)
        (cd "$RELEASE_REPO" && git stash push -m "auto-release stash before $version") || {
          ui_err "Stash failed."
          pause_enter
          return 1
        }
        ui_ok "Stashed."
        ;;
      *)
        ui_warn "Aborted."
        pause_enter
        return 1
        ;;
    esac
  fi

  # Auto-generate changelog section if missing
  if [[ -f "$CHANGELOG_FILE" ]] && ! grep -q "$version" "$CHANGELOG_FILE"; then
    generate_changelog_section "$version" "$CHANGELOG_FILE"
  fi

  print_header
  row_bold "AUTO RELEASE — DRY RUN"
  empty_row
  dry_status=0
  (cd "$RELEASE_REPO" && "$RELEASE_SCRIPT" --dry-run "$version") || dry_status=$?

  if [[ $dry_status -ne 0 ]]; then
    empty_row
    ui_err "Dry run failed (exit $dry_status). Aborting."
    print_footer
    pause_enter
    return 1
  fi

  empty_row
  row "Dry run OK."
  print_footer

  printf "%bDry run passed. Run live release? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { ui_warn "Cancelled after dry run."; pause_enter; return 1; }

  print_header
  row_bold "AUTO RELEASE — LIVE"
  empty_row
  (cd "$RELEASE_REPO" && "$RELEASE_SCRIPT" "$version") || {
    ui_err "Live release failed. Check output above."
    print_footer
    pause_enter
    return 1
  }
  empty_row
  row "Release $version complete."
  row "Pushing commits and tags..."
  print_footer

  (cd "$RELEASE_REPO" && git push && git push --tags) || {
    ui_err "Push failed. Fix and push manually before creating GitHub release."
    pause_enter
    return 1
  }
  ui_ok "Pushed."

  printf "%bCreate GitHub release for %s? [y/N]: %b" "$C_TITLE" "$version" "$C_RESET"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    (
      cd "$RELEASE_REPO"
      gh release create "$version" \
        --title "Release $version" \
        --notes-file "$CHANGELOG_FILE"
    ) && ui_ok "GitHub release $version created." || ui_err "GitHub release failed."
  fi

  pause_enter
}

print_menu() {
  print_header
  row_bold "RELEASE"
  empty_row
  row "Repo: $RELEASE_REPO"
  empty_row

  row2 " 1. Release status" " 2. Change repo"
  row2 " 3. Initialize files" " 4. Dry run release"
  row2 " 5. Run release" " 6. Create GitHub release"
  row2 " 7. View changelog" " 8. Show latest tags"
  row2 " 9. Open changelog" "10. Open release script"
  row2 "11. Auto release" " b. Back"

  print_footer
}

menu_loop() {
  local choice

  choose_release_repo || true

  while true; do
    print_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "release" || return
    else
      read_menu_choice "Select option [1-11,b] > " "release" || return
      choice="$REPLY"
    fi
    echo

    case "$choice" in
      1) show_release_status ;;
      2) choose_release_repo || true ;;
      3) init_release_files || true ;;
      4) run_release_dry || true ;;
      5) run_release_live || true ;;
      6) create_github_release_only || true ;;
      7) show_changelog ;;
      8) show_tags ;;
      9) open_changelog_in_editor ;;
      10) open_release_script_in_editor ;;
      11) require_release_script && auto_release || true ;;
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
  init      Create missing release files for selected repo
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
  elif [[ -n "$RELEASE_REPO" ]]; then
    set_release_repo "$RELEASE_REPO" || exit 1
  else
    RELEASE_REPO="$(default_release_repo)"
    refresh_release_paths
  fi

  case "$cmd" in
    menu) menu_loop ;;
    repo) choose_release_repo && menu_loop ;;
    init) init_release_files ;;
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

main "$@"
