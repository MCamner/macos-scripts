#!/usr/bin/env bash
set -u

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
AI_PROMPTS="$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"

[[ -f "$AI_PROMPTS" ]] && source "$AI_PROMPTS"

cd "$BASE_DIR" || {
  echo "Missing repo: $BASE_DIR"
  exit 1
}

echo "MQ RELEASE CHECK"
echo "────────────────────────────────────────────────────────────"

echo
echo "GIT STATUS"
echo "────────────────────────────────────────────────────────────"
git status --short

echo
echo "SECRETS SCAN"
echo "────────────────────────────────────────────────────────────"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks git --pre-commit --staged -v
else
  echo "⚠ gitleaks not installed"
fi

echo
echo "RECENT COMMITS"
echo "────────────────────────────────────────────────────────────"
git log --oneline -5

echo
echo "AI CHECK PROMPTS"
echo "────────────────────────────────────────────────────────────"

if declare -f mq_ai_prompt_review >/dev/null; then
  mq_ai_prompt_review
else
  echo "⚠ Missing mq_ai_prompt_review"
fi

if declare -f mq_ai_prompt_ui >/dev/null; then
  mq_ai_prompt_ui
else
  echo "⚠ Missing mq_ai_prompt_ui"
fi

echo
echo "RELEASE CHECKLIST"
echo "────────────────────────────────────────────────────────────"
cat <<'CHECKLIST'
[ ] git status is clean or expected
[ ] no secrets found
[ ] /review prompt checked
[ ] /ui prompt checked
[ ] README/help text updated if commands changed
[ ] version/changelog updated if this is a release
[ ] tests or syntax checks passed
CHECKLIST

echo
echo "Status: release-check complete"
