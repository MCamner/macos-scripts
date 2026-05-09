#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
SNAPSHOT_ROOT="$BASE_DIR/backups/workspaces"

# Prints usage information.
usage() {
  cat <<'USAGE'
workspace.sh - save and restore lightweight workspace snapshots

Usage:
  automation/workflows/workspace.sh [command] [snapshot-id]

Commands:
  menu       Open interactive menu
  save       Save current workspace snapshot
  list       List recent snapshots
  latest     Show latest snapshot
  show       Show snapshot details (default: latest)
  restore    Restore/open snapshot workspace (default: latest)
  help       Show this help
USAGE
}

# Ensures snapshot root is ready.
ensure_snapshot_root() {
  mkdir -p "$SNAPSHOT_ROOT"
}

# Handles current repo root.
current_repo_root() {
  git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true
}

# Handles git value.
git_value() {
  local repo="$1"
  shift

  [[ -n "$repo" ]] || return 0
  git -C "$repo" "$@" 2>/dev/null || true
}

# Handles quote value.
quote_value() {
  printf "%q" "$1"
}

# Handles latest id.
latest_id() {
  [[ -f "$SNAPSHOT_ROOT/latest" ]] || return 1
  sed -n '1p' "$SNAPSHOT_ROOT/latest"
}

# Resolves snapshot id.
resolve_snapshot_id() {
  local id="${1:-latest}"

  if [[ "$id" == "latest" || -z "$id" ]]; then
    latest_id
  else
    printf '%s\n' "$id"
  fi
}

# Handles snapshot dir.
snapshot_dir() {
  local id="$1"
  printf '%s/%s\n' "$SNAPSHOT_ROOT" "$id"
}

# Handles save snapshot.
save_snapshot() {
  ensure_snapshot_root

  local id dir work_dir repo branch upstream status_count ahead behind
  id="$(date +%Y%m%d-%H%M%S)"
  dir="$(snapshot_dir "$id")"
  work_dir="$PWD"
  repo="$(current_repo_root)"
  branch="$(git_value "$repo" branch --show-current)"
  upstream="$(git_value "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
  status_count="0"
  ahead="0"
  behind="0"

  mkdir -p "$dir"

  if [[ -n "$repo" ]]; then
    status_count="$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    git -C "$repo" status --short --branch > "$dir/git-status.txt" 2>/dev/null || true
    git -C "$repo" diff --name-only > "$dir/changed-files.txt" 2>/dev/null || true
    git -C "$repo" diff --cached --name-only >> "$dir/changed-files.txt" 2>/dev/null || true
    sort -u "$dir/changed-files.txt" -o "$dir/changed-files.txt"
    if [[ -n "$upstream" ]]; then
      behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || printf '0')"
      ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || printf '0')"
    fi
  else
    : > "$dir/git-status.txt"
    : > "$dir/changed-files.txt"
  fi

  find "$work_dir" -maxdepth 2 -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -path '*/backups/*' \
    -print 2>/dev/null | sort | tail -40 > "$dir/recent-files.txt"

  {
    printf 'SNAPSHOT_ID=%s\n' "$(quote_value "$id")"
    printf 'CREATED_AT=%s\n' "$(quote_value "$(date '+%Y-%m-%d %H:%M:%S')")"
    printf 'WORK_DIR=%s\n' "$(quote_value "$work_dir")"
    printf 'REPO_ROOT=%s\n' "$(quote_value "$repo")"
    printf 'BRANCH=%s\n' "$(quote_value "$branch")"
    printf 'UPSTREAM=%s\n' "$(quote_value "$upstream")"
    printf 'AHEAD=%s\n' "$(quote_value "$ahead")"
    printf 'BEHIND=%s\n' "$(quote_value "$behind")"
    printf 'STATUS_COUNT=%s\n' "$(quote_value "$status_count")"
  } > "$dir/metadata.env"

  printf '%s\n' "$id" > "$SNAPSHOT_ROOT/latest"

  printf 'Saved workspace snapshot: %s\n' "$id"
  printf 'Path: %s\n' "$dir"
}

# Handles list snapshots.
list_snapshots() {
  ensure_snapshot_root

  find "$SNAPSHOT_ROOT" -mindepth 1 -maxdepth 1 -type d -print \
    | sort -r \
    | while IFS= read -r dir; do
        local id work_dir branch status_count
        id="$(basename "$dir")"
        work_dir=""
        branch=""
        status_count=""
        # shellcheck disable=SC1090,SC1091
        [[ -f "$dir/metadata.env" ]] && source "$dir/metadata.env"
        printf '%s  %s  branch=%s  changes=%s\n' "$id" "${WORK_DIR:-$work_dir}" "${BRANCH:-$branch}" "${STATUS_COUNT:-$status_count}"
      done
}

# Shows snapshot.
show_snapshot() {
  ensure_snapshot_root

  local id dir
  id="$(resolve_snapshot_id "${1:-latest}")" || {
    printf 'No workspace snapshots found.\n' >&2
    return 1
  }
  dir="$(snapshot_dir "$id")"

  [[ -d "$dir" ]] || {
    printf 'Snapshot not found: %s\n' "$id" >&2
    return 1
  }

  # shellcheck disable=SC1090,SC1091
  source "$dir/metadata.env"

  printf 'Snapshot: %s\n' "$SNAPSHOT_ID"
  printf 'Created:  %s\n' "$CREATED_AT"
  printf 'Work dir: %s\n' "$WORK_DIR"
  printf 'Repo:     %s\n' "${REPO_ROOT:-none}"
  printf 'Branch:   %s\n' "${BRANCH:-none}"
  printf 'Upstream: %s\n' "${UPSTREAM:-none}"
  printf 'Ahead:    %s\n' "${AHEAD:-0}"
  printf 'Behind:   %s\n' "${BEHIND:-0}"
  printf 'Changes:  %s\n' "${STATUS_COUNT:-0}"
  printf '\nChanged files:\n'
  sed -n '1,20p' "$dir/changed-files.txt"
}

# Handles restore snapshot.
restore_snapshot() {
  ensure_snapshot_root

  local id dir confirm
  id="$(resolve_snapshot_id "${1:-latest}")" || {
    printf 'No workspace snapshots found.\n' >&2
    return 1
  }
  dir="$(snapshot_dir "$id")"

  [[ -d "$dir" ]] || {
    printf 'Snapshot not found: %s\n' "$id" >&2
    return 1
  }

  # shellcheck disable=SC1090,SC1091
  source "$dir/metadata.env"

  show_snapshot "$id"
  printf '\nRestore/open this workspace? [y/N] '
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || {
    printf 'Cancelled.\n'
    return 0
  }

  if [[ -d "$WORK_DIR" ]]; then
    if command -v code >/dev/null 2>&1; then
      code "$WORK_DIR" >/dev/null 2>&1 || true
    fi
    open -a Terminal "$WORK_DIR" >/dev/null 2>&1 || true
    printf 'Opened workspace: %s\n' "$WORK_DIR"
  else
    printf 'Workspace path missing: %s\n' "$WORK_DIR" >&2
    return 1
  fi

  if [[ -n "${REPO_ROOT:-}" && -d "$REPO_ROOT/.git" && -n "${BRANCH:-}" ]]; then
    printf 'Branch at snapshot: %s\n' "$BRANCH"
    printf 'To switch manually:\n'
    printf '  git -C %q checkout %q\n' "$REPO_ROOT" "$BRANCH"
  fi
}

# Runs the menu loop.
menu_loop() {
  local choice id

  while true; do
    clear 2>/dev/null || true
    printf 'WORKSPACE SNAPSHOTS\n'
    printf '===================\n\n'
    printf '1. Save current workspace\n'
    printf '2. List snapshots\n'
    printf '3. Show latest snapshot\n'
    printf '4. Restore latest snapshot\n'
    printf '5. Restore by snapshot id\n'
    printf 'b. Back\n\n'
    printf 'workspace > '
    read -r choice

    case "$choice" in
      1) save_snapshot ;;
      2) list_snapshots ;;
      3) show_snapshot latest ;;
      4) restore_snapshot latest ;;
      5)
        printf 'Snapshot id > '
        read -r id
        restore_snapshot "$id"
        ;;
      b|B) break ;;
      *) printf 'Invalid option.\n' ;;
    esac

    printf '\nPress Enter to continue...'
    read -r _
  done
}

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"
  shift || true

  case "$cmd" in
    menu) menu_loop ;;
    save) save_snapshot ;;
    list) list_snapshots ;;
    latest) show_snapshot latest ;;
    show) show_snapshot "${1:-latest}" ;;
    restore) restore_snapshot "${1:-latest}" ;;
    help|-h|--help) usage ;;
    *)
      printf 'Unknown command: %s\n\n' "$cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
