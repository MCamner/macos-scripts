#!/usr/bin/env bash
set -u

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
AI_PROMPTS="$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"

[[ -f "$AI_PROMPTS" ]] && source "$AI_PROMPTS"

cd "$BASE_DIR" || {
  echo "Missing repo: $BASE_DIR"
  exit 1
}

# Handles rule.
rule() {
  printf '%*s\n' "${1:-72}" '' | tr ' ' '─'
}

# Handles section.
section() {
  echo
  echo "$1"
  rule 72
}

# Handles status ok.
status_ok() {
  echo "  ✔ $1"
}

# Handles status warn.
status_warn() {
  echo "  ⚠ $1"
}

# Prints section.
print_section() { section "$1"; }
# Handles pass.
pass()          { status_ok "$1"; }
# Handles warn.
warn()          { status_warn "$1"; }
# Handles fail.
fail()          { echo "  ✘ $1"; }

# Handles title.
title() {
  echo "MQ RELEASE CHECK"
  rule 72
  echo "Host: $(hostname -s 2>/dev/null || echo unknown)   User: ${USER:-unknown}   Repo: $BASE_DIR"
  echo "Mode: release-check"
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
  status_warn "gitleaks not installed"
fi

section "SYSTEM CHECK"
if [[ -x "$BASE_DIR/tools/scripts/doctor.sh" ]]; then
  "$BASE_DIR/tools/scripts/doctor.sh"
else
  status_warn "doctor.sh not found"
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

# Handles check changelog matches commits.
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
