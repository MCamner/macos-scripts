#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=false
GITHUB_RELEASE=false
INIT_CHANGELOG=false
VERSION=""

VERSION_FILE="VERSION"
README_FILE="README.md"
CHANGELOG_FILE="CHANGELOG.md"
CONTRACT_FILE=".mq/repo-contract.json"

BASE_BRANCH="main"
RELEASE_MODE=""
RELEASE_BRANCH=""
RELEASE_BRANCH_CREATED=false
MUTATION_STARTED=false
CLEANUP_DONE=false


# Shows usage.
show_usage() {
  cat <<'USAGE'
Usage:
  ./release.sh [--dry-run] [--github-release] [--init-changelog] <version>

Examples:
  ./release.sh 0.1.2
  ./release.sh --dry-run 0.1.2
  ./release.sh --github-release 0.1.2
  ./release.sh --init-changelog 0.1.2

Release mode:
  "release_mode" in .mq/repo-contract.json decides how the release lands.
  There is no flag for it: a flag would leave `./release.sh <version>` as a
  working direct-push path in a repo whose contract forbids one.

    pull_request  Bump on a release/v<version> branch, push the branch, open
                  a PR. No tag, no push to main. Tagging happens by hand
                  after the merge; the script prints the exact commands.
    direct        Bump on main, tag, push main and the tag (legacy flow).

Shared steps:
  1. Verifies git working tree is clean
  2. Verifies required files exist
  3. Reads release_mode from .mq/repo-contract.json
  4. Syncs with origin/main for live releases
  5. Verifies tag v<version> does not already exist
  6. Updates VERSION
  7. Updates README version badge when present
  8. Syncs .mq/repo-contract.json to the release version
  9. Verifies CHANGELOG.md contains the version
 10. Verifies the contract version matches VERSION (post-bump re-gate)
 11. Shows a diff preview
 12. Creates a release commit

Then, for pull_request:
 13. Pushes release/v<version> to origin
 14. Opens a pull request via gh when available (warn-only)
 15. Returns the checkout to main and prints the post-merge tag steps

Then, for direct:
 13. Creates annotated tag v<version>
 14. Pushes main and the new tag to origin
 15. Regenerates and pushes wiki Command-Reference (warn-only)
 16. Optionally creates a GitHub Release via gh CLI

Special mode:
  --init-changelog
    Creates a changelog template for the requested version at the top of
    CHANGELOG.md, then exits without commit/tag/push.

Safety:
  - --dry-run performs local checks and file updates, shows the diff,
    then rolls changes back and exits without fetch/branch/commit/tag/push.
  - If the script aborts before commit, VERSION, README.md and the contract
    are restored, and an unpushed release branch is removed.
USAGE
}

# Handles log step.
log_step() {
  printf '==> %s\n' "$1"
}

# Handles error.
error() {
  printf 'ERROR: %s\n' "$1" >&2
}

# Handles rollback local changes.
rollback_local_changes() {
  git checkout -- "${VERSION_FILE}" "${README_FILE}" "${CONTRACT_FILE}" 2>/dev/null || true
  log_step "Rolled back local file changes"
}

# Returns the checkout to the base branch and drops the release branch when it
# holds nothing. `branch -d` refuses to delete unmerged work, so a branch that
# already carries the release commit survives — losing that commit would be a
# worse outcome than leaving a branch behind. Runs after the file rollback, so
# the tree is clean by the time the checkout switches.
restore_base_branch() {
  [[ "${RELEASE_BRANCH_CREATED}" == true ]] || return 0

  if [[ "$(git branch --show-current 2>/dev/null || true)" == "${RELEASE_BRANCH}" ]]; then
    git checkout "${BASE_BRANCH}" >/dev/null 2>&1 || return 0
  fi

  if git branch -d "${RELEASE_BRANCH}" >/dev/null 2>&1; then
    log_step "Removed unused release branch ${RELEASE_BRANCH}"
  fi
  RELEASE_BRANCH_CREATED=false
}

# Undoes a half-finished release. Only runs once, and only after the first
# mutation: before that point the tree still holds whatever the operator had,
# and `git checkout --` would discard it rather than restore anything.
cleanup_failed_release() {
  if [[ "${MUTATION_STARTED}" != true || "${CLEANUP_DONE}" == true ]]; then
    return 0
  fi

  CLEANUP_DONE=true
  rollback_local_changes || true
  restore_base_branch || true
}

# Handles on error.
on_error() {
  error "Release command failed with exit code: $?"
  cleanup_failed_release
}

# The ERR trap alone never covered the gates. Bash does not run it for an
# explicit `exit`, and every gate here exits rather than failing a command — so
# a CHANGELOG or contract mismatch left the bumped files behind, and would now
# also leave the checkout stranded on the release branch.
on_exit() {
  local status=$?

  if [[ "${status}" -ne 0 ]]; then
    cleanup_failed_release
  fi
}

trap on_error ERR
trap on_exit EXIT

# Handles require clean tree.
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

# Handles require file.
require_file() {
  local file="$1"
  [[ -f "$file" ]] || { error "Required file missing: $file"; exit 1; }
}

# Handles require changelog version.
require_changelog_version() {
  local version="$1"

  if ! grep -Eq "^\## \[${version}\]" "${CHANGELOG_FILE}"; then
    error "${CHANGELOG_FILE} does not appear to contain a section for version ${version}"
    exit 1
  fi
}

# Handles update version file.
update_version_file() {
  local version="$1"
  log_step "Updating VERSION -> ${version}"
  printf '%s\n' "${version}" > "${VERSION_FILE}"
}

# Syncs the version the rest of the MQ stack reads. release.sh used to bump
# VERSION but not the contract, so tags shipped with the contract one version
# behind (v1.0.1). The pointer file, not the canonical contract, carries the
# version the stack gate compares.
sync_contract_version() {
  local version="$1"
  [[ -f "${CONTRACT_FILE}" ]] || { error "Required file missing: ${CONTRACT_FILE}"; exit 1; }
  log_step "Syncing ${CONTRACT_FILE} -> ${version}"
  python3 - "${CONTRACT_FILE}" "${version}" <<'PY'
import json, sys
path, version = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data["version"] = version
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
}

# Reads the release mode the contract declares. Sets a global instead of echoing
# it: an `exit` inside a command substitution only kills the subshell, so an
# unknown mode would be swallowed and the release would carry on.
read_release_mode() {
  local mode
  mode="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('release_mode','direct'))" "${CONTRACT_FILE}")"

  case "${mode}" in
    pull_request|direct)
      RELEASE_MODE="${mode}"
      ;;
    *)
      error "Unknown release_mode '${mode}' in ${CONTRACT_FILE} (expected pull_request or direct)"
      exit 1
      ;;
  esac

  log_step "Release mode: ${RELEASE_MODE} (from ${CONTRACT_FILE})"
}

# Post-bump re-gate: after the version surfaces are written, refuse to commit
# unless the contract actually matches VERSION. A silent mismatch becomes a hard
# stop here instead of a drifted tag caught later by another repo's CI.
verify_contract_matches_version() {
  local version="$1"
  local contract_ver
  contract_ver="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "${CONTRACT_FILE}")"
  if [[ "${contract_ver}" != "${version}" ]]; then
    error "${CONTRACT_FILE} version '${contract_ver}' != VERSION '${version}' after sync — aborting"
    exit 1
  fi
  log_step "Verified ${CONTRACT_FILE} matches VERSION (${version})"
}

# Handles update readme badge.
update_readme_badge() {
  local version="$1"

  if grep -Eq 'badge/version-[0-9]+\.[0-9]+\.[0-9]+' "${README_FILE}"; then
    log_step "Updating README version badge -> ${version}"
    perl -0pi -e "s/badge\/version-[0-9]+\.[0-9]+\.[0-9]+/badge\/version-${version}/g" "${README_FILE}"
  else
    log_step "Updating README version badge -> ${version}"
    printf 'README version badge not found; skipping\n'
  fi
}

# Handles init changelog section.
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

# Prints summary.
print_summary() {
  local tag="v${VERSION}"

  cat <<EOF_SUMMARY
Release summary
---------------
Version : ${VERSION}
Tag     : ${tag}$( [[ "${RELEASE_MODE}" == pull_request ]] && echo " (after merge, by hand)" )
Mode    : ${RELEASE_MODE}
Branch  : $( [[ "${RELEASE_MODE}" == pull_request ]] && echo "release/${tag} -> ${BASE_BRANCH}" || echo "${BASE_BRANCH}" )
Files   : ${VERSION_FILE}, ${README_FILE}, ${CHANGELOG_FILE}, ${CONTRACT_FILE}
GitHub  : $( [[ "${GITHUB_RELEASE}" == true ]] && echo enabled || echo disabled )
EOF_SUMMARY
}

# Refuses to reuse a release branch name. A stale local branch would otherwise
# be checked out and bumped on top of whatever it already held.
require_release_branch_absent() {
  if git rev-parse --verify -q "refs/heads/${RELEASE_BRANCH}" >/dev/null 2>&1; then
    error "Branch ${RELEASE_BRANCH} already exists locally."
    exit 1
  fi

  if git ls-remote --heads origin | grep -q "refs/heads/${RELEASE_BRANCH}$"; then
    error "Branch ${RELEASE_BRANCH} already exists on origin."
    exit 1
  fi
}

# Handles create release branch.
create_release_branch() {
  log_step "Creating release branch ${RELEASE_BRANCH}"
  git switch -c "${RELEASE_BRANCH}" >/dev/null 2>&1 || git checkout -b "${RELEASE_BRANCH}"
  RELEASE_BRANCH_CREATED=true
}

# Handles create release commit.
create_release_commit() {
  local version="$1"

  git add "${VERSION_FILE}" "${README_FILE}" "${CHANGELOG_FILE}" "${CONTRACT_FILE}"
  git commit -m "Prepare v${version} release"
}

# Handles create release commit and tag.
create_release_commit_and_tag() {
  local version="$1"
  local tag="v${version}"

  create_release_commit "${version}"
  git tag -a "${tag}" -m "${tag}"
}

# Handles push release.
push_release() {
  local version="$1"
  local tag="v${version}"

  git push origin main
  git push origin "${tag}"
}

# Handles push release branch.
push_release_branch() {
  log_step "Pushing ${RELEASE_BRANCH}"
  git push -u origin "${RELEASE_BRANCH}"
  # The branch is on origin now; the error trap must not try to delete it.
  RELEASE_BRANCH_CREATED=false
}

# Opens the release PR. Warn-only on purpose: the branch is already pushed by
# this point, so a gh failure must not abort into the rollback path — the work
# is safe on origin and the operator only needs the command to finish by hand.
open_release_pull_request() {
  local version="$1"

  if ! command -v gh >/dev/null 2>&1; then
    printf '[pr] gh CLI not found. Open the pull request manually:\n'
    printf '     gh pr create --base %s --head %s --fill\n' "${BASE_BRANCH}" "${RELEASE_BRANCH}"
    return 0
  fi

  log_step "Opening pull request for ${RELEASE_BRANCH}"
  if ! gh pr create \
    --base "${BASE_BRANCH}" \
    --head "${RELEASE_BRANCH}" \
    --title "Prepare v${version} release" \
    --body "Version surfaces bumped to ${version}. Tag after merge."
  then
    printf '[pr] gh pr create failed. Open the pull request manually:\n'
    printf '     gh pr create --base %s --head %s --fill\n' "${BASE_BRANCH}" "${RELEASE_BRANCH}"
  fi
}

# Prints the steps the pull_request mode deliberately does not automate. The tag
# has to sit on the merge commit, which does not exist until the PR is merged.
print_post_merge_steps() {
  local version="$1"

  cat <<EOF_STEPS

Release branch pushed. The tag is not automated — after the PR is merged:

  git checkout ${BASE_BRANCH} && git pull --ff-only origin ${BASE_BRANCH}
  grep -qx '${version}' ${VERSION_FILE} || echo "${BASE_BRANCH} is missing the bump"
  git tag -a v${version} -m "v${version}"
  git push origin v${version}

The wiki Command-Reference and any GitHub Release belong after that tag, not
before it: until the merge lands, ${BASE_BRANCH} does not carry ${version}.
EOF_STEPS
}

# Regenerates Command-Reference.md and pushes to the GitHub Wiki.
update_wiki_command_ref() {
  local version="$1"
  local generator="${BASH_SOURCE[0]%/*}/tools/scripts/generate-wiki-command-ref.sh"
  local wiki_tmp
  wiki_tmp="$(mktemp -d)"

  if [[ ! -x "$generator" ]]; then
    printf '[wiki] generator not found, skipping wiki update\n'
    return 0
  fi

  log_step "Updating wiki Command-Reference"

  if ! "$generator" >/dev/null 2>&1; then
    printf '[wiki] generator failed, skipping wiki push\n'
    rm -rf "$wiki_tmp"
    return 0
  fi

  local generated="$HOME/macos-scripts.wiki/Command-Reference.md"
  if [[ ! -f "$generated" ]]; then
    printf '[wiki] Command-Reference.md not found after generation, skipping wiki push\n'
    rm -rf "$wiki_tmp"
    return 0
  fi

  if ! git clone --quiet git@github.com:MCamner/macos-scripts.wiki.git "$wiki_tmp" 2>/dev/null; then
    printf '[wiki] could not clone wiki repo, skipping wiki push\n'
    rm -rf "$wiki_tmp"
    return 0
  fi

  cp "$generated" "$wiki_tmp/Command-Reference.md"
  cd "$wiki_tmp"
  git add Command-Reference.md
  if git diff --cached --quiet; then
    printf '[wiki] Command-Reference unchanged, no push needed\n'
  else
    git commit -m "Update Command-Reference for v${version}"
    git push --quiet
    printf '[wiki] Command-Reference pushed\n'
  fi
  cd - >/dev/null
  rm -rf "$wiki_tmp"
}

# Handles create github release.
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
require_file "${CONTRACT_FILE}"

if [[ "${INIT_CHANGELOG}" == true ]]; then
  init_changelog_section "${VERSION}"
  exit 0
fi

require_clean_tree
read_release_mode

print_summary
printf '\n'

if [[ "${DRY_RUN}" == false ]]; then
  log_step "Syncing with origin/${BASE_BRANCH}"
  git fetch origin "${BASE_BRANCH}"
  # Not `|| true`: a swallowed checkout failure used to mean the bump landed on
  # whatever branch happened to be out, and it would now mean branching the
  # release off that branch instead of off the base.
  git checkout "${BASE_BRANCH}"
  git pull --ff-only origin "${BASE_BRANCH}"
fi

if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
  error "Tag v${VERSION} already exists locally."
  exit 1
fi

if git ls-remote --tags origin | grep -q "refs/tags/v${VERSION}$"; then
  error "Tag v${VERSION} already exists on origin."
  exit 1
fi

if [[ "${RELEASE_MODE}" == "pull_request" ]]; then
  RELEASE_BRANCH="release/v${VERSION}"
  require_release_branch_absent
  if [[ "${DRY_RUN}" == true ]]; then
    log_step "Would create release branch ${RELEASE_BRANCH}"
  else
    MUTATION_STARTED=true
    create_release_branch
  fi
fi

MUTATION_STARTED=true
update_version_file "${VERSION}"
update_readme_badge "${VERSION}"
sync_contract_version "${VERSION}"

log_step "Verifying CHANGELOG contains version ${VERSION}"
require_changelog_version "${VERSION}"

verify_contract_matches_version "${VERSION}"

log_step "Showing diff preview"
git --no-pager diff -- "${VERSION_FILE}" "${README_FILE}" "${CHANGELOG_FILE}" "${CONTRACT_FILE}" || true

if [[ "${DRY_RUN}" == true ]]; then
  printf '\nDry run complete. No branch, commit, tag, or push performed.\n'
  rollback_local_changes
  restore_base_branch
  exit 0
fi

if [[ "${RELEASE_MODE}" == "pull_request" ]]; then
  log_step "Creating release commit on ${RELEASE_BRANCH}"
  create_release_commit "${VERSION}"

  push_release_branch
  open_release_pull_request "${VERSION}"

  log_step "Returning to ${BASE_BRANCH}"
  git checkout "${BASE_BRANCH}"

  print_post_merge_steps "${VERSION}"

  trap - ERR
  printf '\nRelease branch prepared successfully.\n'
  exit 0
fi

log_step "Creating release commit and tag"
create_release_commit_and_tag "${VERSION}"

log_step "Pushing main and tag"
push_release "${VERSION}"

update_wiki_command_ref "${VERSION}"

if [[ "${GITHUB_RELEASE}" == true ]]; then
  log_step "Creating GitHub release"
  create_github_release "${VERSION}"
fi

trap - ERR
printf '\nRelease completed successfully.\n'
