#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_header() {
  printf '\n'
  printf '════════════════════════════════════════════════════════════\n'
  printf ' MQ DOCTOR — Environment Readiness Check\n'
  printf '════════════════════════════════════════════════════════════\n'
}

print_section() {
  printf '\n%s\n' "$1"
  printf '%s\n' "$(printf '─%.0s' {1..60})"
}

status_line() {
  local label="$1"
  local value="$2"
  printf '%-24s %s\n' "$label" "$value"
}

detect_shell_name() {
  basename "${SHELL:-unknown}"
}

detect_os() {
  sw_vers -productName 2>/dev/null || uname -s
}

detect_os_version() {
  sw_vers -productVersion 2>/dev/null || uname -r
}

git_branch() {
  git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "n/a"
}

repo_detected() {
  if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "yes"
  else
    echo "no"
  fi
}

git_dirty() {
  if [[ "$(repo_detected)" != "yes" ]]; then
    echo "n/a"
    return
  fi

  if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null)" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

file_present() {
  local rel="$1"
  if [[ -e "$PROJECT_ROOT/$rel" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

dependency_status() {
  local name="$1"
  if command_exists "$name"; then
    echo "installed"
  else
    echo "missing"
  fi
}

workflow_git() {
  if [[ "$(repo_detected)" == "yes" ]] && command_exists git; then
    echo "READY"
  else
    echo "NOT READY"
  fi
}

workflow_release() {
  if [[ "$(repo_detected)" == "yes" ]] \
    && command_exists git \
    && [[ "$(file_present VERSION)" == "yes" ]] \
    && [[ "$(file_present CHANGELOG.md)" == "yes" ]]; then

    if [[ "$(git_dirty)" == "no" ]]; then
      echo "READY"
    else
      echo "PARTIAL (dirty tree)"
    fi
  else
    echo "NOT READY"
  fi
}

workflow_dev() {
  if command_exists python3 || command_exists node; then
    echo "READY"
  else
    echo "LIMITED"
  fi
}

workflow_system() {
  if command_exists top && command_exists df; then
    echo "READY"
  else
    echo "LIMITED"
  fi
}

print_recommendations() {
  local repo_state git_state gh_state brew_state python_state node_state jq_state dirty_state
  local printed=0

  repo_state="$(repo_detected)"
  git_state="$(dependency_status git)"
  gh_state="$(dependency_status gh)"
  brew_state="$(dependency_status brew)"
  python_state="$(dependency_status python3)"
  node_state="$(dependency_status node)"
  jq_state="$(dependency_status jq)"
  dirty_state="$(git_dirty)"

  print_section "Recommendations"

  if [[ "$git_state" == "missing" ]]; then
    printf -- '- Install git\n'
    printed=1
  fi

  if [[ "$gh_state" == "missing" ]]; then
    printf -- '- Install GitHub CLI (gh)\n'
    printed=1
  fi

  if [[ "$brew_state" == "missing" ]]; then
    printf -- '- Install Homebrew\n'
    printed=1
  fi

  if [[ "$python_state" == "missing" ]]; then
    printf -- '- Install python3\n'
    printed=1
  fi

  if [[ "$node_state" == "missing" ]]; then
    printf -- '- Install Node.js\n'
    printed=1
  fi

  if [[ "$jq_state" == "missing" ]]; then
    printf -- '- Install jq\n'
    printed=1
  fi

  if [[ "$repo_state" == "yes" && "$dirty_state" == "yes" ]]; then
    printf -- '- Commit or stash changes before release workflows\n'
    printed=1
  fi

  if [[ "$printed" -eq 0 ]]; then
    printf 'Environment looks healthy.\n'
  fi
}

main() {
  print_header

  print_section "Environment"
  status_line "OS" "$(detect_os)"
  status_line "Version" "$(detect_os_version)"
  status_line "Shell" "$(detect_shell_name)"

  print_section "Dependencies"
  status_line "git" "$(dependency_status git)"
  status_line "gh" "$(dependency_status gh)"
  status_line "brew" "$(dependency_status brew)"
  status_line "python3" "$(dependency_status python3)"
  status_line "node" "$(dependency_status node)"
  status_line "jq" "$(dependency_status jq)"

  print_section "Repository"
  status_line "Repo" "$(repo_detected)"
  status_line "Branch" "$(git_branch)"
  status_line "Dirty" "$(git_dirty)"

  print_section "Workflows"
  status_line "Git" "$(workflow_git)"
  status_line "Release" "$(workflow_release)"
  status_line "Dev" "$(workflow_dev)"
  status_line "System" "$(workflow_system)"

  print_recommendations

  printf '\nDone.\n'
}

main "$@"
