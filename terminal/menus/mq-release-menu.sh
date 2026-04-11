#!/usr/bin/env zsh
set -u

BASE_DIR="${HOME}/macos-scripts"
RELEASE_SCRIPT="$BASE_DIR/tools/release.sh"

[[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"

print_release_header() {
  clear
  if typeset -f print_header >/dev/null 2>&1; then
    print_header "RELEASE" "Versioning and release automation"
  else
    echo "=============================="
    echo " RELEASE"
    echo " Versioning and release automation"
    echo "=============================="
  fi
}

read_tty() {
  local prompt="$1"
  local var_name="$2"
  local value
  printf "%s" "$prompt" > /dev/tty
  IFS= read -r value < /dev/tty
  printf -v "$var_name" '%s' "$value"
}

pause_release() {
  if typeset -f pause_enter >/dev/null 2>&1; then
    pause_enter
  else
    echo > /dev/tty
    printf "Press Enter to continue..." > /dev/tty
    IFS= read -r _ < /dev/tty
  fi
}

show_changelog() {
  clear
  if command -v bat >/dev/null 2>&1; then
    bat --paging=always "$BASE_DIR/CHANGELOG.md"
  else
    ${PAGER:-less} "$BASE_DIR/CHANGELOG.md"
  fi
  pause_release
}

show_tags() {
  clear
  git -C "$BASE_DIR" tag --sort=-creatordate | head -10
  echo
  pause_release
}

open_release_script() {
  ${EDITOR:-nano} "$RELEASE_SCRIPT"
}

run_release_dry() {
  local version=""
  echo
  read_tty "Version (example 0.1.4): " version
  [[ -z "$version" ]] && return
  cd "$BASE_DIR" || return
  "$RELEASE_SCRIPT" --dry-run "$version"
  pause_release
}

run_release_live() {
  local version=""
  echo
  read_tty "Version (example 0.1.4): " version
  [[ -z "$version" ]] && return
  cd "$BASE_DIR" || return
  "$RELEASE_SCRIPT" "$version"
  pause_release
}

latest_tag() {
  git -C "$BASE_DIR" describe --tags --abbrev=0 2>/dev/null
}

create_github_release_only() {
  local tag=""
  local latest=""
  latest="$(latest_tag)"

  echo
  if [[ -n "$latest" ]]; then
    read_tty "Tag to publish as GitHub release [$latest]: " tag
    [[ -z "$tag" ]] && tag="$latest"
  else
    read_tty "Tag to publish as GitHub release: " tag
  fi

  [[ -z "$tag" ]] && return

  cd "$BASE_DIR" || return

  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) is not installed."
    pause_release
    return
  fi

  gh release create "$tag" \
    --title "Release $tag" \
    --notes-file "$BASE_DIR/CHANGELOG.md"

  pause_release
}

release_menu_loop() {
  local choice=""
  while true; do
    print_release_header

    echo "1. Dry run release"
    echo "2. Run release"
    echo "3. View changelog"
    echo "4. Show latest tags"
    echo "5. Edit release script"
    echo "6. Create GitHub release"
    echo "b. Back"
    echo

    read_tty "Choose an option: " choice
    case "$choice" in
      1) run_release_dry ;;
      2) run_release_live ;;
      3) show_changelog ;;
      4) show_tags ;;
      5) open_release_script ;;
      6) create_github_release_only ;;
      b|B) break ;;
      *) echo "Unknown option"; sleep 1 ;;
    esac
  done
}

release_menu_loop
