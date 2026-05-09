#!/usr/bin/env bash

command_git_status() {
  print_header
  print_section "Git Status"
  (cd "$PROJECT_ROOT" && git status)
  pause_enter
}

command_git_pull() {
  print_header
  print_section "Git Pull"
  (cd "$PROJECT_ROOT" && git pull)
  pause_enter
}

command_git_push() {
  print_header
  print_section "Git Push"
  (cd "$PROJECT_ROOT" && git push)
  pause_enter
}

command_git_log_recent() {
  print_header
  print_section "Recent Commits"
  (cd "$PROJECT_ROOT" && git log --oneline --decorate -n 12)
  pause_enter
}

command_git_branch_current() {
  print_header
  print_section "Current Branch"
  (cd "$PROJECT_ROOT" && git branch --show-current)
  echo
  print_section "Branch Overview"
  (cd "$PROJECT_ROOT" && git branch -vv)
  pause_enter
}

command_repo_open_root() {
  open_path "$PROJECT_ROOT"
}

command_repo_open_terminal() {
  open_path "$PROJECT_ROOT/terminal"
}

command_repo_open_tools() {
  open_path "$PROJECT_ROOT/tools"
}

command_repo_open_ai_prompts() {
  if [[ -d "$PROJECT_ROOT/ai-prompts" ]]; then
    open_path "$PROJECT_ROOT/ai-prompts"
  else
    err "Directory not found: $PROJECT_ROOT/ai-prompts"
    pause_enter
    return 1
  fi
}

command_edit_v1_launcher() {
  local target="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"

  if command_exists code; then
    code "$target"
  else
    open "$target"
  fi
}

command_dev_repo_health() {
  print_header
  print_section "Repo Health"

  local current_branch
  local last_commit
  local changed_count
  local untracked_count

  current_branch="$(cd "$PROJECT_ROOT" && git branch --show-current 2>/dev/null || echo "unknown")"
  last_commit="$(cd "$PROJECT_ROOT" && git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo "No commits found")"
  changed_count="$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null | grep -vc '^??' || true)"
  untracked_count="$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null | grep -c '^??' || true)"

  print_kv "Branch:" "$current_branch"
  print_kv "Last commit:" "$last_commit"
  print_kv "Changed files:" "$changed_count"
  print_kv "Untracked files:" "$untracked_count"

  echo
  print_section "Git Status Summary"
  (cd "$PROJECT_ROOT" && git status --short)

  pause_enter
}
