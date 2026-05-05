#!/usr/bin/env bash
set -u

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
AI_PROMPTS="$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"

[[ -f "$AI_PROMPTS" ]] && source "$AI_PROMPTS"

cd "$BASE_DIR" || {
  echo "Missing repo: $BASE_DIR"
  exit 1
}

rule() {
  printf '%*s\n' "${1:-72}" '' | tr ' ' '─'
}

section() {
  echo
  echo "$1"
  rule 72
}

status_ok() {
  echo "  ✔ $1"
}

status_warn() {
  echo "  ⚠ $1"
}

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

section "RECENT COMMITS"
git log --oneline -5

section "AI CHECK PROMPTS"
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

section "RELEASE CHECKLIST"
cat <<'CHECKLIST'
  [ ] git status is clean or expected
  [ ] no staged secrets found
  [ ] /review prompt checked
  [ ] /ui prompt checked
  [ ] README/help text updated if commands changed
  [ ] version/changelog updated if this is a release
  [ ] tests or syntax checks passed
CHECKLIST

echo
rule 72
echo "Status: release-check complete"
