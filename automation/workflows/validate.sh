#!/usr/bin/env bash

set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

checks=0
warnings=0
failures=0

# Prints a section heading.
section() {
  printf '\n%s\n' "$1"
  printf '%s\n' "────────────────────────────────────────────────────────────"
}

# Records a passing check.
pass() {
  checks=$((checks + 1))
  printf '  ✔ %s\n' "$1"
}

# Records a warning.
warn() {
  warnings=$((warnings + 1))
  printf '  ⚠ %s\n' "$1"
}

# Records a failing check.
fail() {
  failures=$((failures + 1))
  printf '  ✘ %s\n' "$1"
}

# Checks a file exists.
require_file() {
  local path="$1"
  local label="$2"

  if [[ -f "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing: $path"
  fi
}

# Checks a directory exists.
require_dir() {
  local path="$1"
  local label="$2"

  if [[ -d "$path" ]]; then
    pass "$label exists"
  else
    fail "$label missing: $path"
  fi
}

# Checks a script exists and is executable.
require_executable() {
  local path="$1"
  local label="$2"

  if [[ -x "$path" ]]; then
    pass "$label executable"
  elif [[ -f "$path" ]]; then
    fail "$label exists but is not executable: $path"
  else
    fail "$label missing: $path"
  fi
}

# Checks bash syntax for a script.
check_bash_syntax() {
  local path="$1"
  local label="$2"

  if [[ ! -f "$path" ]]; then
    fail "$label syntax skipped; file missing"
    return
  fi

  if bash -n "$path"; then
    pass "$label syntax OK"
  else
    fail "$label syntax failed"
  fi
}

# Checks docs contain a command reference.
require_doc_reference() {
  local doc="$1"
  local needle="$2"
  local label="$3"

  if [[ ! -f "$doc" ]]; then
    fail "$label missing doc: $doc"
    return
  fi

  if grep -qF "$needle" "$doc"; then
    pass "$label documents '$needle'"
  else
    warn "$label does not mention '$needle'"
  fi
}

printf 'MQ WORKFLOW VALIDATION\n'
printf '%s\n' "────────────────────────────────────────────────────────────"
printf 'Repo: %s\n' "$BASE_DIR"

if [[ ! -d "$BASE_DIR" ]]; then
  fail "Repo directory missing: $BASE_DIR"
  printf '\nStatus: failed (%d failure(s), %d warning(s))\n' "$failures" "$warnings"
  exit 1
fi

cd "$BASE_DIR"

WORKFLOWS_DIR="$BASE_DIR/automation/workflows"
PROJECT_BOOT="$WORKFLOWS_DIR/project-boot.sh"
PROJECT_CHECK="$WORKFLOWS_DIR/project-check.sh"
WORKSPACE="$WORKFLOWS_DIR/workspace.sh"
VALIDATE="$WORKFLOWS_DIR/validate.sh"
WORKFLOWS_MENU="$BASE_DIR/terminal/menus/mq-workflows-menu.sh"
COMMAND_MODE="$BASE_DIR/terminal/launchers/mqlaunch-command-mode.sh"
LAUNCHER="$BASE_DIR/terminal/launchers/mqlaunch.sh"
COMMANDS_DOC="$BASE_DIR/docs/COMMANDS.md"
README="$BASE_DIR/README.md"

section "FILES"
require_dir "$WORKFLOWS_DIR" "Workflows directory"
require_executable "$PROJECT_BOOT" "Project boot workflow"
require_executable "$PROJECT_CHECK" "Project check workflow"
require_executable "$WORKSPACE" "Workspace workflow"
require_executable "$VALIDATE" "Workflow validator"
require_file "$WORKFLOWS_MENU" "Workflows menu"

section "SYNTAX"
check_bash_syntax "$PROJECT_BOOT" "project-boot.sh"
check_bash_syntax "$PROJECT_CHECK" "project-check.sh"
check_bash_syntax "$WORKSPACE" "workspace.sh"
check_bash_syntax "$VALIDATE" "validate.sh"
check_bash_syntax "$WORKFLOWS_MENU" "mq-workflows-menu.sh"

section "COMMAND SURFACE"
if grep -q "validate|health)" "$WORKFLOWS_MENU" && grep -q "run_workflows_validation" "$WORKFLOWS_MENU"; then
  pass "Workflows menu routes validate"
else
  fail "Workflows menu does not route validate"
fi

if grep -q "workflows|workflow" "$COMMAND_MODE"; then
  pass "Command mode routes workflows"
else
  fail "Command mode missing workflows route"
fi

if grep -q "run_mqworkflows" "$LAUNCHER"; then
  pass "Main launcher routes workflows"
else
  fail "Main launcher missing workflows route"
fi

section "DOCUMENTATION"
require_doc_reference "$COMMANDS_DOC" "mqlaunch workflows validate" "Command reference"
require_doc_reference "$README" "mqlaunch workflows validate" "README"

printf '\n'
if [[ "$failures" -eq 0 ]]; then
  printf 'Status: workflow validation passed (%d check(s), %d warning(s))\n' "$checks" "$warnings"
else
  printf 'Status: workflow validation failed (%d failure(s), %d warning(s))\n' "$failures" "$warnings"
  exit 1
fi
