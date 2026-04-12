#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${1:-macos-scripts}"
PROJECT_DIR="${2:-$HOME/macos-scripts}"
LOG_DIR="$HOME/.macos-scripts/logs"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
LOG_FILE="$LOG_DIR/${PROJECT_NAME}_check_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

say() {
  printf '%s\n' "${1-}" | tee -a "$LOG_FILE"
}

ok() {
  say "[OK]   $1"
}

warn() {
  say "[WARN] $1"
}

fail() {
  say "[FAIL] $1"
}

say "===================================="
say "PROJECT CHECK"
say "Project   : $PROJECT_NAME"
say "Directory : $PROJECT_DIR"
say "Started   : $(date)"
say "===================================="

if [[ ! -d "$PROJECT_DIR" ]]; then
  fail "Project directory not found: $PROJECT_DIR"
  say
  say "Log saved to: $LOG_FILE"
  exit 1
fi

cd "$PROJECT_DIR"

issues=0

if [[ -d ".git" ]]; then
  ok "Git repository found"
else
  fail "Not a git repository"
  issues=$((issues + 1))
fi

if [[ -f "README.md" ]]; then
  ok "README.md present"
else
  warn "README.md missing"
fi

if [[ -f "VERSION" ]]; then
  ok "VERSION file present"
else
  warn "VERSION file missing"
fi

if [[ -f "CHANGELOG.md" ]]; then
  ok "CHANGELOG.md present"
else
  warn "CHANGELOG.md missing"
fi

if [[ -f "install.sh" ]]; then
  ok "install.sh present"
else
  warn "install.sh missing"
fi

if [[ -x "bin/mqlaunch" ]]; then
  ok "bin/mqlaunch executable"
elif [[ -f "bin/mqlaunch" ]]; then
  warn "bin/mqlaunch present but not executable"
else
  warn "bin/mqlaunch missing"
fi

if [[ -x "tools/scripts/test-all.sh" ]]; then
  ok "Smoke test script available"
else
  warn "Smoke test script missing or not executable"
fi

if [[ -d ".git" ]]; then
  branch="$(git branch --show-current 2>/dev/null || true)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  if [[ -n "$branch" ]]; then
    ok "Current branch: $branch"
  else
    warn "Could not resolve current branch"
  fi

  if git diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
    ok "Working tree clean"
  else
    warn "Working tree has local changes"
  fi

  if [[ -n "$upstream" ]]; then
    ok "Upstream configured: $upstream"
  else
    warn "No upstream configured for current branch"
  fi

  remotes="$(git remote 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  if [[ -n "$remotes" ]]; then
    ok "Git remotes: $remotes"
  else
    warn "No git remotes configured"
  fi
fi

say
if [[ "$issues" -eq 0 ]]; then
  say "Project check completed."
else
  say "Project check completed with $issues blocking issue(s)."
fi
say "Log saved to: $LOG_FILE"
