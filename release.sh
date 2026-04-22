#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=false
GITHUB_RELEASE=false
INIT_CHANGELOG=false
VERSION=""

VERSION_FILE="VERSION"
README_FILE="README.md"
CHANGELOG_FILE="CHANGELOG.md"

ORIG_VERSION_CONTENT=""
ORIG_README_CONTENT=""

show_usage() {
  cat <<'USAGE'
Usage:
  ./release.sh [--dry-run] [--github-release] [--init-changelog] <version>

Examples:
  ./release.sh 0.1.2
  ./release.sh --dry-run 0.1.2
  ./release.sh --github-release 0.1.2
  ./release.sh --init-changelog 0.1.2

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

Special mode:
  --init-changelog
    Creates a changelog template for the requested version at the top of
    CHANGELOG.md, then exits without commit/tag/push.

Safety:
  - --dry-run performs local checks and file updates, shows the diff,
    then rolls changes back and exits without fetch/commit/tag/push.
  - If the script aborts before commit, VERSION and README.md are restored.
USAGE
}

log_step() {
  printf '==> %s\n' "$1"
}

error() {
  printf 'ERROR: %s\n' "$1" >&2
}

rollback_local_changes() {
  local rolled_back=false

  if [[ -n "${ORIG_VERSION_CONTENT}" && -f "${VERSION_FILE}" ]]; then
    printf '%s' "${ORIG_VERSION_CONTENT}" > "${VERSION_FILE}"
    rolled_back=true
  fi

  if [[ -n "${ORIG_README_CONTENT}" && -f "${README_FILE}" ]]; then
    printf '%s' "${ORIG_README_CONTENT}" > "${README_FILE}"
    rolled_back=true
  fi

  if [[ "${rolled_back}" == true ]]; then
    log_step "Rolled back local file changes"
  fi
}

on_error() {
  error "Release command failed with exit code: $?"
  rollback_local_changes || true
}

trap on_error ERR

require_clean_tree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    error "Git working tree is not clean. Commit or stash changes first."
    exit 1
  fi

  if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
    error "Untracked files detected. Commit, remove, or ignore them first."
    exit 1
  fi
}

require_file() {
  local file="$1"
  [[ -f "$file" ]] || { error "Required file missing: $file"; exit 1; }
}

require_changelog_version() {
  local version="$1"

  if ! grep -Eq "^\## \[${version}\]" "${CHANGELOG_FILE}"; then
    error "${CHANGELOG_FILE} does not appear to contain a section for version ${version}"
    exit 1
  fi
}

update_version_file() {
  local version="$1"
  log_step "Updating VERSION -> ${version}"
  ORIG_VERSION_CONTENT="$(cat "${VERSION_FILE}")"
  printf '%s\n' "${version}" > "${VERSION_FILE}"
}

update_readme_badge() {
  local version="$1"

  ORIG_README_CONTENT="$(cat "${README_FILE}")"

  if grep -Eq 'badge/version-[0-9]+\.[0-9]+\.[0-9]+' "${README_FILE}"; then
    log_step "Updating README version badge -> ${version}"
    perl -0pi -e "s/badge\/version-[0-9]+\.[0-9]+\.[0-9]+/badge\/version-${version}/g" "${README_FILE}"
  else
    log_step "Updating README version badge -> ${version}"
    printf 'README version badge not found; skipping\n'
  fi
}

init_changelog_section() {
  local version="$1"
  local today tmp_file
  today="$(date +%F)"

  require_file "${CHANGELOG_FILE}"

  if grep -Eq "^\## \[${version}\]" "${CHANGELOG_FILE}"; then
    printf 'CHANGELOG already contains version %s\n' "${version}"
    return 0
  fi

  tmp_file="$(mktemp)"

  {
    printf '## [%s] - %s\n\n' "${version}" "${today}"
    printf '### Added\n'
    printf -- '- \n\n'
    printf '### Changed\n'
    printf -- '- \n\n'
    printf '### Fixed\n'
    printf -- '- \n\n'
    cat "${CHANGELOG_FILE}"
  } > "${tmp_file}"

  mv "${tmp_file}" "${CHANGELOG_FILE}"
  printf 'Initialized CHANGELOG.md template for version %s\n' "${version}"
}

print_summary() {
  local tag="v${VERSION}"

  cat <<EOF_SUMMARY
Release summary
---------------
Version : ${VERSION}
Tag     : ${tag}
Branch  : main
Files   : ${VERSION_FILE}, ${README_FILE}, ${CHANGELOG_FILE}
GitHub  : $( [[ "${GITHUB_RELEASE}" == true ]] && echo enabled || echo disabled )
EOF_SUMMARY
}

create_release_commit_and_tag() {
  local version="$1"
  local tag="v${version}"

  git add "${VERSION_FILE}" "${README_FILE}" "${CHANGELOG_FILE}"
  git commit -m "Prepare ${tag} release"
  git tag -a "${tag}" -m "${tag}"
}

push_release() {
  local version="$1"
  local tag="v${version}"

  git push origin main
  git push origin "${tag}"
}

create_github_release() {
  local version="$1"
  local tag="v${version}"

  command -v gh >/dev/null 2>&1 || {
    error "gh CLI is required for --github-release"
    exit 1
  }

  gh release create "${tag}" \
    --title "${tag}" \
    --notes-file "${CHANGELOG_FILE}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --github-release)
      GITHUB_RELEASE=true
      shift
      ;;
    --init-changelog)
      INIT_CHANGELOG=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    -*)
      error "Unknown option: $1"
      show_usage
      exit 1
      ;;
    *)
      if [[ -n "${VERSION}" ]]; then
        error "Only one version argument is allowed."
        show_usage
        exit 1
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

if [[ -z "${VERSION}" ]]; then
  show_usage
  printf '\nRelease aborted.\n'
  exit 1
fi

require_file "${VERSION_FILE}"
require_file "${README_FILE}"
require_file "${CHANGELOG_FILE}"

if [[ "${INIT_CHANGELOG}" == true ]]; then
  init_changelog_section "${VERSION}"
  exit 0
fi

require_clean_tree

print_summary
printf '\n'

if [[ "${DRY_RUN}" == false ]]; then
  log_step "Syncing with origin/main"
  git fetch origin main
  git checkout main >/dev/null 2>&1 || true
  git pull --ff-only origin main
fi

if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
  error "Tag v${VERSION} already exists locally."
  exit 1
fi

if git ls-remote --tags origin | grep -q "refs/tags/v${VERSION}$"; then
  error "Tag v${VERSION} already exists on origin."
  exit 1
fi

update_version_file "${VERSION}"
update_readme_badge "${VERSION}"

log_step "Verifying CHANGELOG contains version ${VERSION}"
require_changelog_version "${VERSION}"

log_step "Showing diff preview"
git --no-pager diff -- "${VERSION_FILE}" "${README_FILE}" "${CHANGELOG_FILE}" || true

if [[ "${DRY_RUN}" == true ]]; then
  printf '\nDry run complete. No commit, tag, or push performed.\n'
  rollback_local_changes
  exit 0
fi

log_step "Creating release commit and tag"
create_release_commit_and_tag "${VERSION}"

log_step "Pushing main and tag"
push_release "${VERSION}"

if [[ "${GITHUB_RELEASE}" == true ]]; then
  log_step "Creating GitHub release"
  create_github_release "${VERSION}"
fi

trap - ERR
printf '\nRelease completed successfully.\n'
