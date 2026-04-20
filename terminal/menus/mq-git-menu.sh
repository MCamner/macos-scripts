#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/macos-scripts"
UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

APP_TITLE="MQ Git"
APP_SUBTITLE="Git Workspace and Safe Repo Actions"
APP_AUTHOR="Author Mattias Camner"
BOX_INNER=88

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

CURRENT_REPO="$BASE_DIR"

ensure_repo() {
  if [[ ! -d "$CURRENT_REPO/.git" ]]; then
    print_header
    row_bold "GIT WORKSPACE"
    empty_row
    row "Not a git repository:"
    row " $CURRENT_REPO"
    print_footer
    pause_enter
    return 1
  fi
}

repo_name() {
  basename "$CURRENT_REPO"
}

normalize_remote_url() {
  local remote_url="$1"

  if [[ "$remote_url" =~ ^git@github\.com:(.*)$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$remote_url" =~ ^https://github\.com/(.*)\.git$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$remote_url" =~ ^git@([^:]+):(.*)$ ]]; then
    echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    return 0
  fi

  echo "${remote_url%.git}"
}

github_web_url() {
  local remote_url=""
  remote_url="$(git -C "$CURRENT_REPO" remote get-url origin 2>/dev/null || true)"
  [[ -n "$remote_url" ]] || return 1
  normalize_remote_url "$remote_url"
}

choose_repo() {
  local path=""

  print_header
  row_bold "CHANGE REPO"
  empty_row
  row "Current repo:"
  row " $CURRENT_REPO"
  print_footer
  printf "${C_TITLE}Repo path: ${C_RESET}"
  read -r path

  if [[ -z "${path// }" ]]; then
    ui_warn "No path entered."
    pause_enter
    return 1
  fi

  if [[ -d "$path/.git" ]]; then
    CURRENT_REPO="$path"
    ui_ok "Switched repo to: $CURRENT_REPO"
  else
    ui_err "Not a git repo: $path"
  fi

  pause_enter
}

show_status() {
  ensure_repo || return 1

  local branch upstream counts ahead behind
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  ahead=0
  behind=0
  if [[ -n "$upstream" ]]; then
    counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || true)"
    behind="${counts%% *}"
    ahead="${counts##* }"
  fi

  print_header
  row_bold "REPO STATUS"
  empty_row
  row "Repo:     $CURRENT_REPO"
  row "Branch:   ${branch:-unknown}"
  row "Upstream: ${upstream:-none}"
  row "Ahead:    ${ahead:-0}"
  row "Behind:   ${behind:-0}"
  empty_row

  git -C "$CURRENT_REPO" status --short --branch || true

  print_footer
  pause_enter
}

analyze_diff() {
  ensure_repo || return 1

  local diff risk lines
  local reasons=()

  diff="$(git -C "$CURRENT_REPO" diff --cached -- . 2>/dev/null)"
  if [[ -z "$diff" ]]; then
    diff="$(git -C "$CURRENT_REPO" diff -- . 2>/dev/null)"
  fi

  print_header
  row_bold "DIFF RISK ANALYSIS"
  empty_row

  if [[ -z "$diff" ]]; then
    row "No diff to analyze."
    print_footer
    pause_enter
    return 0
  fi

  risk="LOW"

  if echo "$diff" | grep -Eqi '(api[_-]?key|secret|token|password|passwd|PRIVATE KEY|BEGIN RSA|BEGIN OPENSSH)'; then
    risk="HIGH"
    reasons+=("Possible secret or credential content detected")
  fi

  if echo "$diff" | grep -Eqi 'rm -rf|chmod 777|curl .*\|.*sh|sudo '; then
    risk="HIGH"
    reasons+=("Potentially dangerous shell command pattern detected")
  fi

  if echo "$diff" | grep -Eqi '^diff --git a/.*\.(sh|zsh|bash)$'; then
    [[ "$risk" == "LOW" ]] && risk="MEDIUM"
    reasons+=("Shell script changes detected")
  fi

  lines="$(printf "%s\n" "$diff" | wc -l | tr -d ' ')"
  if [[ "${lines:-0}" -gt 250 ]]; then
    [[ "$risk" == "LOW" ]] && risk="MEDIUM"
    reasons+=("Large diff (${lines} lines)")
  fi

  row "Risk level: $risk"
  empty_row

  if (( ${#reasons[@]} > 0 )); then
    row "Reasons:"
    for r in "${reasons[@]}"; do
      row " - $r"
    done
  else
    row "No obvious risk patterns detected."
  fi

  empty_row
  row "Changed files:"
  git -C "$CURRENT_REPO" diff --name-only --cached 2>/dev/null || true
  git -C "$CURRENT_REPO" diff --name-only 2>/dev/null | awk '!seen[$0]++' || true

  print_footer
  pause_enter
}

suggest_commit() {
  ensure_repo || return 1

  local files first kind msg

  files="$(git -C "$CURRENT_REPO" diff --name-only --cached 2>/dev/null)"
  if [[ -z "$files" ]]; then
    files="$(git -C "$CURRENT_REPO" diff --name-only 2>/dev/null)"
  fi

  print_header
  row_bold "SUGGESTED COMMIT"
  empty_row

  if [[ -z "$files" ]]; then
    row "No changed files found."
    print_footer
    pause_enter
    return 0
  fi

  first="$(printf "%s\n" "$files" | head -1)"
  kind="update"

  if printf "%s\n" "$files" | grep -Eq 'README|CHANGELOG|docs/'; then
    kind="docs"
  elif printf "%s\n" "$files" | grep -Eq '\.sh$|terminal/|tools/|ui/'; then
    kind="improve"
  elif printf "%s\n" "$files" | grep -Eq 'test|spec'; then
    kind="test"
  fi

  msg="$kind: refine $(repo_name)"
  [[ -n "$first" ]] && msg="$kind: update $(basename "$first")"

  row "Suggested message:"
  row " $msg"
  empty_row
  row "Changed files:"
  printf "%s\n" "$files"

  print_footer
  pause_enter
}

next_action() {
  ensure_repo || return 1

  local status branch upstream counts ahead behind
  status="$(git -C "$CURRENT_REPO" status --short)"
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  ahead=0
  behind=0

  if [[ -n "$upstream" ]]; then
    counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || true)"
    behind="${counts%% *}"
    ahead="${counts##* }"
  fi

  print_header
  row_bold "NEXT RECOMMENDED ACTION"
  empty_row

  if [[ -n "$status" ]]; then
    if echo "$status" | grep -Eq '^\?\?'; then
      row "1. Review untracked files before staging."
      row "2. Stage intentionally, not with blind git add ."
    elif echo "$status" | grep -Eq '^( M|M |MM|A |AM| D|D )'; then
      row "1. Review diff."
      row "2. Stage selected changes."
      row "3. Commit with a clear message."
    else
      row "Working tree has changes. Review before committing."
    fi
  else
    if [[ "${behind:-0}" -gt 0 && "${ahead:-0}" -gt 0 ]]; then
      row "Branch has diverged from upstream."
      row "Recommended: inspect log, then reconcile."
    elif [[ "${behind:-0}" -gt 0 ]]; then
      row "You are behind upstream."
      row "Recommended: git pull --rebase origin $branch"
    elif [[ "${ahead:-0}" -gt 0 ]]; then
      row "You are ahead of upstream."
      row "Recommended: git push origin $branch"
    else
      row "Repo looks clean and synced."
      row "Recommended: no action needed."
    fi
  fi

  print_footer
  pause_enter
}

stage_selected() {
  ensure_repo || return 1

  local files=""

  print_header
  row_bold "STAGE SELECTED FILES"
  empty_row

  git -C "$CURRENT_REPO" status --short || true
  empty_row
  print_footer
  printf "${C_TITLE}File(s) to stage: ${C_RESET}"
  read -r files

  if [[ -z "${files// }" ]]; then
    ui_warn "No files entered."
    pause_enter
    return 1
  fi

  (
    cd "$CURRENT_REPO" || exit 1
    git add $files
  )

  print_header
  row_bold "UPDATED STATUS"
  empty_row
  git -C "$CURRENT_REPO" status --short || true
  print_footer
  pause_enter
}

commit_changes() {
  ensure_repo || return 1

  local msg=""

  print_header
  row_bold "COMMIT STAGED CHANGES"
  empty_row

  if [[ -z "$(git -C "$CURRENT_REPO" diff --cached --name-only)" ]]; then
    row "No staged changes to commit."
    print_footer
    pause_enter
    return 0
  fi

  git -C "$CURRENT_REPO" diff --cached --name-only || true
  empty_row
  print_footer
  printf "${C_TITLE}Commit message: ${C_RESET}"
  read -r msg

  if [[ -z "${msg// }" ]]; then
    ui_warn "No commit message entered."
    pause_enter
    return 1
  fi

  git -C "$CURRENT_REPO" commit -m "$msg"
  echo
  pause_enter
}

safe_push() {
  ensure_repo || return 1

  local branch upstream counts ahead behind confirm
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  ahead=0
  behind=0

  if [[ -n "$upstream" ]]; then
    counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || true)"
    behind="${counts%% *}"
    ahead="${counts##* }"
  fi

  print_header
  row_bold "SAFE PUSH"
  empty_row
  row "Branch:   ${branch:-unknown}"
  row "Upstream: ${upstream:-none}"
  row "Ahead:    ${ahead:-0}"
  row "Behind:   ${behind:-0}"
  empty_row

  if [[ -z "$upstream" ]]; then
    row "No upstream branch configured."
    print_footer
    printf "${C_TITLE}Push with -u origin $branch? [y/N]: ${C_RESET}"
    read -r confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return 0
    git -C "$CURRENT_REPO" push -u origin "$branch"
    pause_enter
    return 0
  fi

  if [[ "${behind:-0}" -gt 0 && "${ahead:-0}" -gt 0 ]]; then
    row "Branch has diverged. Push blocked."
    print_footer
    pause_enter
    return 1
  fi

  if [[ "${behind:-0}" -gt 0 ]]; then
    row "Remote is ahead. Push blocked."
    row "Recommended: git pull --rebase origin $branch"
    print_footer
    pause_enter
    return 1
  fi

  if [[ "${ahead:-0}" -eq 0 ]]; then
    row "Nothing to push."
    print_footer
    pause_enter
    return 0
  fi

  print_footer
  printf "${C_TITLE}Push current branch to origin? [y/N]: ${C_RESET}"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return 0

  git -C "$CURRENT_REPO" push origin "$branch"
  echo
  pause_enter
}

pull_rebase() {
  ensure_repo || return 1

  local branch confirm
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"

  print_header
  row_bold "PULL WITH REBASE"
  empty_row
  row "This will run:"
  row " git pull --rebase origin $branch"
  print_footer
  printf "${C_TITLE}Continue? [y/N]: ${C_RESET}"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return 0

  git -C "$CURRENT_REPO" pull --rebase origin "$branch"
  echo
  pause_enter
}

show_log() {
  ensure_repo || return 1

  print_header
  row_bold "RECENT GIT LOG"
  empty_row
  git -C "$CURRENT_REPO" log --oneline --decorate --graph -15 || true
  print_footer
  pause_enter
}

open_repo_github() {
  ensure_repo || return 1

  local url=""
  url="$(github_web_url || true)"

  if [[ -z "$url" ]]; then
    print_header
    row_bold "OPEN REPO ON GITHUB"
    empty_row
    row "Could not determine GitHub URL from origin remote."
    print_footer
    pause_enter
    return 1
  fi

  print_header
  row_bold "OPEN REPO ON GITHUB"
  empty_row
  row "Opening:"
  row " $url"
  print_footer
  open "$url"
}

open_local_repo() {
  ensure_repo || return 1

  print_header
  row_bold "OPEN LOCAL REPO"
  empty_row
  row "Opening:"
  row " $CURRENT_REPO"
  print_footer
  open "$CURRENT_REPO"
}

print_menu() {
  print_header
  row_bold "GIT MENU"
  empty_row
  row "Repo: $CURRENT_REPO"
  empty_row

  row2 " 1. Repo status" " 2. Diff risk analysis"
  row2 " 3. Suggest commit message" " 4. Next recommended action"
  row2 " 5. Stage selected files" " 6. Commit staged changes"
  row2 " 7. Safe push" " 8. Pull with rebase"
  row2 " 9. Recent git log" "10. Open repo on GitHub"
  row2 "11. Open local repo folder" "12. Change repo path"
  row2 " b. Back" ""

  print_footer
}

menu_loop() {
  local choice=""

  while true; do
    print_menu
    read_menu_choice "Select option [1-12,b] > " || return
    choice="$REPLY"
    echo

    case "$choice" in
      1) show_status ;;
      2) analyze_diff ;;
      3) suggest_commit ;;
      4) next_action ;;
      5) stage_selected ;;
      6) commit_changes ;;
      7) safe_push ;;
      8) pull_rebase ;;
      9) show_log ;;
      10) open_repo_github ;;
      11) open_local_repo ;;
      12) choose_repo ;;
      b|B) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

usage() {
  cat <<USAGE
mq-git-menu.sh - interactive git menu

Usage:
  mq-git-menu.sh [command]

Commands:
  menu      Open menu (default)
  status    Show repo status
  log       Show recent log
  github    Open repo on GitHub
  local     Open local repo folder
  help      Show this help
USAGE
}

main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) menu_loop ;;
    status) show_status ;;
    log) show_log ;;
    github) open_repo_github ;;
    local) open_local_repo ;;
    help|-h|--help) usage ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

main "${1:-menu}"
