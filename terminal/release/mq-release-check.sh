#!/usr/bin/env bash
set -u

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
STRICT_RELEASE="${MQ_STRICT_RELEASE:-0}"

BRAIN=0
for arg in "${@:-}"; do
  [[ "$arg" == "--brain" ]] && BRAIN=1
done
AI_PROMPTS="$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"

# shellcheck source=../ai-prompts/mq-ai-prompts.sh
[[ -f "$AI_PROMPTS" ]] && source "$AI_PROMPTS"

cd "$BASE_DIR" || {
  echo "Missing repo: $BASE_DIR"
  exit 1
}

# Prints a horizontal rule sized for release-check sections.
rule() {
  printf '%*s\n' "${1:-72}" '' | tr ' ' '─'
}

# Starts a named release-check section with a visual separator.
section() {
  echo
  echo "$1"
  rule 72
}

# Prints a successful release-check status line.
status_ok() {
  echo "  ✔ $1"
}

# Prints a non-blocking release-check warning line.
status_warn() {
  echo "  ⚠ $1"
}

# Prints section.
print_section() { section "$1"; }
# Marks a validation step as passed.
pass()          { status_ok "$1"; }
# Marks a validation step as warning-only.
warn()          { status_warn "$1"; }
# Prints a blocking validation failure line.
fail()          { echo "  ✘ $1"; }

# Warns by default, but fails when MQ_STRICT_RELEASE=1.
warn_or_fail() {
  local message="$1"
  if [[ "$STRICT_RELEASE" == "1" ]]; then
    fail "$message"
    return 1
  fi
  warn "$message"
  return 0
}

# Prints release-check context before running checks.
title() {
  echo "MQ RELEASE CHECK"
  rule 72
  echo "Host: $(hostname -s 2>/dev/null || echo unknown)   User: ${USER:-unknown}   Repo: $BASE_DIR"
  if [[ "$STRICT_RELEASE" == "1" ]]; then
    echo "Mode: release-check strict"
  else
    echo "Mode: release-check"
  fi
  rule 72
}

title

section "GIT STATUS"
if [[ -z "$(git status --short)" ]]; then
  status_ok "Working tree clean"
else
  git status --short
fi

section "SECRETS SCAN"
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks git --pre-commit --staged -v; then
    status_ok "No staged secrets found"
  else
    status_warn "Secrets scan found issues"
  fi
else
  warn_or_fail "gitleaks not installed" || exit 1
fi

section "MQ STACK CONTRACT"
if [[ -x "$BASE_DIR/tests/mq-stack-contract-smoke.sh" ]]; then
  "$BASE_DIR/tests/mq-stack-contract-smoke.sh" || exit 1
else
  warn_or_fail "tests/mq-stack-contract-smoke.sh not found or not executable" || exit 1
fi

section "MQOBSIDIAN MANIFEST CONTRACT"
# Coordinates check mqobsidian manifest contract behavior.
check_mqobsidian_manifest_contract() {
  local manifest="$BASE_DIR/mqlaunch/config/mqobsidian/views.json"

  if [[ ! -f "$manifest" ]]; then
    fail "mqobsidian view manifest missing: $manifest"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    fail "jq is required to validate mqobsidian view manifest"
    return 1
  fi

  if ! jq empty "$manifest" >/dev/null 2>&1; then
    fail "mqobsidian view manifest is not valid JSON: $manifest"
    return 1
  fi

  if ! jq -e '
    type == "array" and
    length > 0 and
    all(.[]; (
      (.key | type == "string" and length > 0) and
      (.label | type == "string" and length > 0) and
      (.relative_path | type == "string" and length > 0) and
      (.type == "file" or .type == "folder")
    )) and
    ((map(.key) | length) == (map(.key) | unique | length))
  ' "$manifest" >/dev/null; then
    fail "mqobsidian view manifest violates the consumer contract"
    echo "Expected non-empty array with unique key plus label, relative_path, and type=file|folder."
    return 1
  fi

  pass "mqobsidian view manifest contract is valid"
}
check_mqobsidian_manifest_contract || exit 1

section "SYSTEM CHECK"
if [[ -x "$BASE_DIR/tools/scripts/doctor.sh" ]]; then
  "$BASE_DIR/tools/scripts/doctor.sh"
else
  status_warn "doctor.sh not found"
fi

section "WORKFLOW VALIDATION"
if [[ -x "$BASE_DIR/automation/workflows/validate.sh" ]]; then
  MACOS_SCRIPTS_HOME="$BASE_DIR" "$BASE_DIR/automation/workflows/validate.sh" || exit 1
else
  status_warn "automation/workflows/validate.sh not found"
fi

section "RECENT COMMITS"
git log --oneline -5

section "AI CHECK PROMPTS"
if [[ -t 1 ]]; then
  if declare -f mq_ai_prompt_review >/dev/null; then
    mq_ai_prompt_review
  else
    status_warn "Missing mq_ai_prompt_review"
  fi
  if declare -f mq_ai_prompt_ui >/dev/null; then
    mq_ai_prompt_ui
  else
    status_warn "Missing mq_ai_prompt_ui"
  fi
else
  status_warn "AI prompts skipped (non-interactive run)"
fi

section "RELEASE CHECKLIST"
cat <<'CHECKLIST'
  [ ] git status is clean or expected
  [ ] no staged secrets found
  [ ] doctor check reviewed
  [ ] /review prompt checked
  [ ] /ui prompt checked
  [ ] README/help text updated if commands changed
  [ ] version/changelog updated if this is a release
  [ ] tests or syntax checks passed
CHECKLIST

# Verifies the current VERSION has concrete changelog coverage for recent commits.
check_changelog_matches_commits() {
  print_section "CHANGELOG / COMMITS"

  local version
  version="$(cat VERSION 2>/dev/null | tr -d '[:space:]')"

  if [[ -z "$version" ]]; then
    fail "VERSION file missing or empty"
    return 1
  fi

  if [[ ! -f CHANGELOG.md ]]; then
    fail "CHANGELOG.md missing"
    return 1
  fi

  if ! grep -qE "^## \[?v?${version}\]?" CHANGELOG.md; then
    fail "CHANGELOG.md has no entry for version ${version}"
    echo "Expected heading like:"
    echo "  ## [${version}] - YYYY-MM-DD"
    return 1
  fi

  local previous_tag
  previous_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"

  if [[ -z "$previous_tag" ]]; then
    warn "No previous tag found; skipping commit/changelog comparison"
    return 0
  fi

  local commit_count
  commit_count="$(git log --oneline "${previous_tag}..HEAD" | wc -l | tr -d ' ')"

  if [[ "$commit_count" == "0" ]]; then
    pass "No commits since ${previous_tag}"
    return 0
  fi

  echo "Commits since ${previous_tag}: ${commit_count}"

  local changelog_block
  changelog_block="$(awk "
    /^## / {
      if (found) exit
      if (\$0 ~ /\\[?v?${version}\\]?/) found=1
    }
    found { print }
  " CHANGELOG.md)"

  local bullet_count
  bullet_count="$(printf '%s\n' "$changelog_block" \
    | grep -E '^[*-] ' \
    | grep -Ev '^[*-][[:space:]]*$' \
    | grep -Evi "^[*-][[:space:]]+(initial release setup|release[[:space:]]+setup|release[[:space:]]+${version}|todo|tbd|placeholder)[[:space:]]*$" \
    | wc -l \
    | tr -d ' ')"

  if [[ "$bullet_count" == "0" ]]; then
    fail "Version ${version} exists in CHANGELOG.md but has no real bullet entries"
    echo "Replace placeholders such as 'Initial release setup' with concrete changes."
    return 1
  fi

  pass "CHANGELOG.md contains version ${version} with ${bullet_count} documented change(s)"

  echo
  echo "Recent commits:"
  git log --oneline "${previous_tag}..HEAD" | sed 's/^/  - /'
}


check_changelog_matches_commits || exit 1

if [ -x "$BASE_DIR/terminal/release/mq-repo-signal-check.sh" ]; then
  "$BASE_DIR/terminal/release/mq-repo-signal-check.sh" "${MQ_REPO_SIGNAL_FAIL_UNDER:-14}" || exit 1
fi

echo
rule 72
echo "Status: release-check complete"

if [[ "$BRAIN" == "1" ]]; then
  echo
  echo "BRAIN RECORD"
  echo "────────────────────────────────────────────────────────────"
  if command -v mq-agent >/dev/null 2>&1; then
    mq-agent signal --brain . || status_warn "brain record failed (mq-agent signal --brain)"
  else
    status_warn "mq-agent not found; skipping brain record"
  fi
fi
