#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="VERSION"
README_FILE="README.md"
CHANGELOG_FILE="CHANGELOG.md"

DRY_RUN=0
GH_RELEASE=0
COMMIT_CREATED=0
TAG_CREATED=0
TARGET_VERSION=""
TARGET_TAG=""
RESTORE_DIR=""

usage() {
  cat <<'EOF'
Usage:
  ./release.sh [--dry-run] [--github-release] <version>

Examples:
  ./release.sh 0.1.2
  ./release.sh --dry-run 0.1.2
  ./release.sh --github-release 0.1.2

What it does:
  1. Verifies git working tree is clean
  2. Verifies required files exist
  3. Syncs with origin/main for live releases
  4. Verifies tag v<version> does not already exist
  5. Updates VERSION
  6. Updates README version badge when present
  7. Verifies CHANGELOG.md contains the version
  8. Shows a diff preview
  9. Creates a release commit
 10. Creates annotated tag v<version>
 11. Pushes main and the new tag to origin
 12. Optionally creates a GitHub Release via gh CLI

Safety:
  - --dry-run performs local checks and file updates, shows the diff,
    then rolls changes back and exits without fetch/commit/tag/push.
  - If the script aborts before commit, VERSION and README.md are restored.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "==> $*"
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || die "Missing required file: $file"
}

validate_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must look like 0.1.2"
}

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository"
}

require_on_main() {
  local branch
  branch="$(git symbolic-ref --short HEAD)"
  [[ "$branch" == "main" ]] || die "Current branch is '$branch'. Switch to 'main' first."
}

require_clean_git() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
  fi

  if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    die "Untracked files present. Commit, ignore, or remove them first."
  fi
}

require_release_files_clean() {
  local dirty_files
  dirty_files="$(git status --porcelain -- "$VERSION_FILE" "$README_FILE" "$CHANGELOG_FILE")"
  [[ -z "$dirty_files" ]] || die "Release files have local changes. Commit or stash VERSION, README.md, and CHANGELOG.md first."
}

tag_exists() {
  local tag="$1"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1
}

require_gh_cli() {
  command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is required for --github-release"
}

create_github_release() {
  require_gh_cli

  info "Creating GitHub release $TARGET_TAG"
  gh release create "$TARGET_TAG" \
    --title "Release $TARGET_TAG" \
    --notes-file "$CHANGELOG_FILE"
}

create_restore_point() {
  RESTORE_DIR="$(mktemp -d)"
  cp "$VERSION_FILE" "$RESTORE_DIR/$VERSION_FILE"
  cp "$README_FILE" "$RESTORE_DIR/$README_FILE"
}

restore_worktree_changes() {
  [[ -n "$RESTORE_DIR" && -d "$RESTORE_DIR" ]] || return 0

  cp "$RESTORE_DIR/$VERSION_FILE" "$VERSION_FILE"
  cp "$RESTORE_DIR/$README_FILE" "$README_FILE"
  info "Rolled back local file changes"
}

cleanup_restore_point() {
  [[ -n "$RESTORE_DIR" && -d "$RESTORE_DIR" ]] || return 0
  rm -rf "$RESTORE_DIR"
}

cleanup_on_error() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo
    echo "Release aborted."

    if [[ "$COMMIT_CREATED" -eq 0 ]]; then
      restore_worktree_changes
      cleanup_restore_point
    else
      echo "A release commit was already created; no automatic rollback was applied."
    fi

    if [[ "$TAG_CREATED" -eq 1 ]]; then
      echo "A local tag '$TARGET_TAG' was created before failure."
      echo "Remove it manually if needed:"
      echo "  git tag -d $TARGET_TAG"
    fi
  fi

  exit "$exit_code"
}

trap cleanup_on_error EXIT

update_version_file() {
  local version="$1"
  printf '%s\n' "$version" > "$VERSION_FILE"
}

update_readme_badge() {
  local version="$1"

  python3 - <<PY
from pathlib import Path
import re

path = Path("$README_FILE")
text = path.read_text(encoding="utf-8")

new_text, count = re.subn(
    r'version-[0-9]+\.[0-9]+\.[0-9]+-informational',
    f'version-$version-informational',
    text,
    count=1
)

if count == 0:
    print("README version badge not found; skipping")
    raise SystemExit(0)

path.write_text(new_text, encoding="utf-8")
PY
}

verify_changelog_contains_version() {
  local version="$1"

  if ! grep -Eq "^\[?$version\]?([[:space:]]+-[[:space:]].*)?$" "$CHANGELOG_FILE"; then
    if ! grep -Eq "^##[[:space:]]+\[?$version\]?([[:space:]]+-[[:space:]].*)?$" "$CHANGELOG_FILE"; then
      die "CHANGELOG.md does not appear to contain a section for version $version"
    fi
  fi
}

show_diff_summary() {
  echo
  git --no-pager diff -- "$VERSION_FILE" "$README_FILE" "$CHANGELOG_FILE" || true
  echo
}

print_release_summary() {
  local version="$1"
  local tag="$2"

  echo
  echo "Release summary"
  echo "---------------"
  echo "Version : $version"
  echo "Tag     : $tag"
  echo "Branch  : main"
  echo "Files   : $VERSION_FILE, $README_FILE, $CHANGELOG_FILE"
  echo "GitHub  : $([[ "$GH_RELEASE" -eq 1 ]] && echo enabled || echo disabled)"
  echo
}

parse_args() {
  if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --github-release)
        GH_RELEASE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -n "$TARGET_VERSION" ]]; then
          die "Unexpected argument: $1"
        fi
        TARGET_VERSION="$1"
        shift
        ;;
    esac
  done

  [[ -n "$TARGET_VERSION" ]] || die "Missing version argument"
  TARGET_TAG="v$TARGET_VERSION"
}

main() {
  parse_args "$@"

  validate_version "$TARGET_VERSION"
  require_git_repo
  require_file "$VERSION_FILE"
  require_file "$README_FILE"
  require_file "$CHANGELOG_FILE"
  require_on_main
  if [[ "$DRY_RUN" -eq 1 ]]; then
    require_release_files_clean
  else
    require_clean_git
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run: skipping fetch and pull"
  else
    info "Fetching latest main and tags from origin"
    git fetch origin main --tags

    info "Ensuring local main matches origin/main"
    git pull --rebase origin main
  fi

  if tag_exists "$TARGET_TAG"; then
    die "Tag $TARGET_TAG already exists"
  fi

  create_restore_point
  print_release_summary "$TARGET_VERSION" "$TARGET_TAG"

  info "Updating VERSION -> $TARGET_VERSION"
  update_version_file "$TARGET_VERSION"

  info "Updating README version badge -> $TARGET_VERSION"
  update_readme_badge "$TARGET_VERSION"

  info "Verifying CHANGELOG contains version $TARGET_VERSION"
  verify_changelog_contains_version "$TARGET_VERSION"

  info "Previewing changes"
  show_diff_summary

  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "Dry run complete; restoring local changes"
    restore_worktree_changes
    cleanup_restore_point
    trap - EXIT
    exit 0
  fi

  info "Creating release commit"
  git add "$VERSION_FILE" "$README_FILE" "$CHANGELOG_FILE"
  git commit -m "Prepare v$TARGET_VERSION release"
  COMMIT_CREATED=1

  info "Creating annotated tag $TARGET_TAG"
  git tag -a "$TARGET_TAG" -m "Release $TARGET_TAG"
  TAG_CREATED=1

  info "Pushing main"
  git push origin main

  info "Pushing tag $TARGET_TAG"
  git push origin "$TARGET_TAG"

  if [[ "$GH_RELEASE" -eq 1 ]]; then
    create_github_release
  else
    info "Skipping GitHub release. Use --github-release to create one."
  fi

  info "Release complete: $TARGET_TAG"
  cleanup_restore_point
  trap - EXIT
}

main "$@"
