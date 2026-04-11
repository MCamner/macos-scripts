#!/usr/bin/env bash
set -euo pipefail

VERSION_FILE="VERSION"
README_FILE="README.md"
CHANGELOG_FILE="CHANGELOG.md"

usage() {
  cat <<'EOF'
Usage:
  ./tools/release.sh <version>

Example:
  ./tools/release.sh 0.1.2

What it does:
  1. Verifies git working tree is clean
  2. Verifies required files exist
  3. Verifies tag v<version> does not already exist
  4. Updates VERSION
  5. Updates README version badge
  6. Verifies CHANGELOG.md mentions the version
  7. Creates a release commit
  8. Creates annotated tag v<version>
  9. Pushes main and the new tag to origin
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

require_clean_git() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    die "Working tree is not clean. Commit or stash your changes first."
  fi

  if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    die "Untracked files present. Commit, ignore, or remove them first."
  fi
}

require_on_main() {
  local branch
  branch="$(git symbolic-ref --short HEAD)"
  [[ "$branch" == "main" ]] || die "Current branch is '$branch'. Switch to 'main' first."
}

validate_version() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version must look like 0.1.2"
}

tag_exists() {
  local tag="$1"
  git fetch --tags origin >/dev/null 2>&1 || true
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1
}

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
    raise SystemExit("README version badge not found")

path.write_text(new_text, encoding="utf-8")
PY
}

verify_changelog_contains_version() {
  local version="$1"

  if ! grep -Eq "^##[[:space:]]+\[?$version\]?|^##[[:space:]]+$version" "$CHANGELOG_FILE"; then
    die "CHANGELOG.md does not appear to contain a section for version $version"
  fi
}

show_diff_summary() {
  echo
  git --no-pager diff -- "$VERSION_FILE" "$README_FILE" "$CHANGELOG_FILE" || true
  echo
}

main() {
  [[ $# -eq 1 ]] || { usage; exit 1; }

  local version="$1"
  local tag="v$version"

  validate_version "$version"
  require_file "$VERSION_FILE"
  require_file "$README_FILE"
  require_file "$CHANGELOG_FILE"
  require_clean_git
  require_on_main

  info "Fetching latest main and tags from origin"
  git fetch origin main --tags

  info "Ensuring local main matches origin/main"
  git pull --rebase origin main

  if tag_exists "$tag"; then
    die "Tag $tag already exists"
  fi

  info "Updating VERSION -> $version"
  update_version_file "$version"

  info "Updating README version badge -> $version"
  update_readme_badge "$version"

  info "Verifying CHANGELOG contains version $version"
  verify_changelog_contains_version "$version"

  info "Previewing changes"
  show_diff_summary

  info "Creating release commit"
  git add "$VERSION_FILE" "$README_FILE" "$CHANGELOG_FILE"
  git commit -m "Prepare v$version release"

  info "Creating annotated tag $tag"
  git tag -a "$tag" -m "Release $tag"

  info "Pushing main"
  git push origin main

  info "Pushing tag $tag"
  git push origin "$tag"

  info "Release complete: $tag"
}

main "$@"
