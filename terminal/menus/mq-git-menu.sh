#!/usr/bin/env zsh
set -u

BASE_DIR="${HOME}/macos-scripts"
DEFAULT_REPO="$BASE_DIR"

[[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"

CURRENT_REPO="$DEFAULT_REPO"

print_git_header() {
  clear
  if typeset -f print_header >/dev/null 2>&1; then
    print_header "GIT" "Repo workflows, risk checks, and safe actions"
  else
    echo "=============================="
    echo " GIT"
    echo " Repo workflows, risk checks, and safe actions"
    echo "=============================="
  fi
  echo "Repo: $CURRENT_REPO"
  echo
}

read_tty() {
  local prompt="$1"
  local var_name="$2"
  local value
  printf "%s" "$prompt" > /dev/tty
  IFS= read -r value < /dev/tty
  printf -v "$var_name" '%s' "$value"
}

pause_git() {
  echo > /dev/tty
  printf "Press Enter to continue..." > /dev/tty
  IFS= read -r _ < /dev/tty
}

ensure_repo() {
  [[ -d "$CURRENT_REPO/.git" ]] || {
    echo "Not a git repository: $CURRENT_REPO"
    return 1
  }
}

repo_name() {
  basename "$CURRENT_REPO"
}

github_remote_url() {
  git -C "$CURRENT_REPO" remote get-url origin 2>/dev/null
}

github_web_url() {
  local remote
  remote="$(github_remote_url)"

  if [[ -z "$remote" ]]; then
    return 1
  fi

  if [[ "$remote" == git@github.com:* ]]; then
    remote="${remote#git@github.com:}"
    remote="${remote%.git}"
    echo "https://github.com/$remote"
    return 0
  fi

  if [[ "$remote" == https://github.com/* ]]; then
    remote="${remote%.git}"
    echo "$remote"
    return 0
  fi

  return 1
}

choose_repo() {
  local path=""
  echo
  read_tty "Repo path [$CURRENT_REPO]: " path
  [[ -z "$path" ]] && return
  if [[ -d "$path/.git" ]]; then
    CURRENT_REPO="$path"
    echo "Switched repo to: $CURRENT_REPO"
  else
    echo "Not a git repo: $path"
  fi
  pause_git
}

show_status() {
  clear
  ensure_repo || { pause_git; return; }

  echo "=== Branch ==="
  git -C "$CURRENT_REPO" branch --show-current
  echo

  echo "=== Status ==="
  git -C "$CURRENT_REPO" status --short
  echo

  echo "=== Ahead / Behind ==="
  git -C "$CURRENT_REPO" fetch origin >/dev/null 2>&1 || true
  local branch upstream ahead behind counts
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  if [[ -n "$upstream" ]]; then
    counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null)"
    behind="${counts%% *}"
    ahead="${counts##* }"
    echo "Upstream: $upstream"
    echo "Ahead:    ${ahead:-0}"
    echo "Behind:   ${behind:-0}"
  else
    echo "No upstream branch configured."
  fi

  echo
  pause_git
}

analyze_diff() {
  clear
  ensure_repo || { pause_git; return; }

  local diff content risk reasons
  diff="$(git -C "$CURRENT_REPO" diff --cached -- . 2>/dev/null)"
  if [[ -z "$diff" ]]; then
    diff="$(git -C "$CURRENT_REPO" diff -- . 2>/dev/null)"
  fi

  if [[ -z "$diff" ]]; then
    echo "No diff to analyze."
    echo
    pause_git
    return
  fi

  risk="LOW"
  reasons=()

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

  local lines
  lines="$(printf "%s\n" "$diff" | wc -l | tr -d ' ')"
  if [[ "${lines:-0}" -gt 250 ]]; then
    [[ "$risk" == "LOW" ]] && risk="MEDIUM"
    reasons+=("Large diff (${lines} lines)")
  fi

  echo "=== Diff Risk Analysis ==="
  echo "Risk level: $risk"
  echo

  if (( ${#reasons[@]} > 0 )); then
    echo "Reasons:"
    for r in "${reasons[@]}"; do
      echo "- $r"
    done
  else
    echo "No obvious risk patterns detected."
  fi

  echo
  echo "=== Changed files ==="
  git -C "$CURRENT_REPO" diff --name-only --cached 2>/dev/null
  git -C "$CURRENT_REPO" diff --name-only 2>/dev/null | awk '!seen[$0]++'

  echo
  pause_git
}

suggest_commit() {
  clear
  ensure_repo || { pause_git; return; }

  local files first kind msg
  files="$(git -C "$CURRENT_REPO" diff --name-only --cached 2>/dev/null)"
  if [[ -z "$files" ]]; then
    files="$(git -C "$CURRENT_REPO" diff --name-only 2>/dev/null)"
  fi

  if [[ -z "$files" ]]; then
    echo "No changed files found."
    echo
    pause_git
    return
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

  if [[ -n "$first" ]]; then
    msg="$kind: update ${first:t}"
  fi

  echo "=== Suggested Commit Message ==="
  echo "$msg"
  echo
  echo "Changed files:"
  printf "%s\n" "$files"
  echo
  pause_git
}

next_action() {
  clear
  ensure_repo || { pause_git; return; }

  local status branch upstream counts ahead behind
  status="$(git -C "$CURRENT_REPO" status --short)"
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  ahead=0
  behind=0

  if [[ -n "$upstream" ]]; then
    git -C "$CURRENT_REPO" fetch origin >/dev/null 2>&1 || true
    counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null)"
    behind="${counts%% *}"
    ahead="${counts##* }"
  fi

  echo "=== Next Recommended Action ==="
  echo

  if [[ -n "$status" ]]; then
    if echo "$status" | grep -Eq '^\?\?'; then
      echo "1. Review untracked files before staging anything."
      echo "2. Stage intentionally, not with blind git add ."
    elif echo "$status" | grep -Eq '^( M|M |MM|A |AM| D|D )'; then
      echo "1. Review diff."
      echo "2. Stage selected changes."
      echo "3. Commit with a clear message."
    else
      echo "Working tree has changes. Review before committing."
    fi
  else
    if [[ "${behind:-0}" -gt 0 && "${ahead:-0}" -gt 0 ]]; then
      echo "Branch has diverged from upstream."
      echo "Recommended: inspect log, then pull --rebase or reconcile manually."
    elif [[ "${behind:-0}" -gt 0 ]]; then
      echo "You are behind upstream."
      echo "Recommended: git pull --rebase origin $branch"
    elif [[ "${ahead:-0}" -gt 0 ]]; then
      echo "You are ahead of upstream."
      echo "Recommended: git push origin $branch"
    else
      echo "Repo looks clean and synced."
      echo "Recommended: no action needed."
    fi
  fi

  echo
  pause_git
}

stage_selected() {
  clear
  ensure_repo || { pause_git; return; }

  echo "=== Changed / Untracked Files ==="
  git -C "$CURRENT_REPO" status --short
  echo

  local files
  read_tty "Enter file(s) to stage (space-separated), or leave blank to cancel: " files
  [[ -z "$files" ]] && return

  (
    cd "$CURRENT_REPO" || exit 1
    git add $=files
  )

  echo
  git -C "$CURRENT_REPO" status --short
  echo
  pause_git
}

commit_changes() {
  clear
  ensure_repo || { pause_git; return; }

  local msg=""
  echo "=== Staged Changes ==="
  git -C "$CURRENT_REPO" diff --cached --name-only
  echo

  if [[ -z "$(git -C "$CURRENT_REPO" diff --cached --name-only)" ]]; then
    echo "No staged changes to commit."
    echo
    pause_git
    return
  fi

  read_tty "Commit message: " msg
  [[ -z "$msg" ]] && return

  git -C "$CURRENT_REPO" commit -m "$msg"
  echo
  pause_git
}

safe_push() {
  clear
  ensure_repo || { pause_git; return; }

  local branch upstream counts ahead behind confirm
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  git -C "$CURRENT_REPO" fetch origin >/dev/null 2>&1 || true

  if [[ -z "$upstream" ]]; then
    echo "No upstream branch configured."
    echo
    read_tty "Push and set upstream to origin/$branch? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || return
    git -C "$CURRENT_REPO" push -u origin "$branch"
    pause_git
    return
  fi

  counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null)"
  behind="${counts%% *}"
  ahead="${counts##* }"

  echo "Upstream: $upstream"
  echo "Ahead:    ${ahead:-0}"
  echo "Behind:   ${behind:-0}"
  echo

  if [[ "${behind:-0}" -gt 0 && "${ahead:-0}" -gt 0 ]]; then
    echo "Branch has diverged. Push blocked."
    echo "Recommended: inspect log and reconcile first."
    echo
    pause_git
    return
  fi

  if [[ "${behind:-0}" -gt 0 ]]; then
    echo "Remote is ahead. Push blocked."
    echo "Recommended: git pull --rebase origin $branch"
    echo
    pause_git
    return
  fi

  if [[ "${ahead:-0}" -eq 0 ]]; then
    echo "Nothing to push."
    echo
    pause_git
    return
  fi

  read_tty "Push current branch to origin? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return

  git -C "$CURRENT_REPO" push origin "$branch"
  echo
  pause_git
}

pull_rebase() {
  clear
  ensure_repo || { pause_git; return; }

  local branch confirm
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  echo "This will run: git pull --rebase origin $branch"
  echo
  read_tty "Continue? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return

  git -C "$CURRENT_REPO" pull --rebase origin "$branch"
  echo
  pause_git
}

show_log() {
  clear
  ensure_repo || { pause_git; return; }

  git -C "$CURRENT_REPO" log --oneline --decorate --graph -15
  echo
  pause_git
}

open_repo_github() {
  clear
  ensure_repo || { pause_git; return; }

  local url
  url="$(github_web_url)"
  if [[ -z "$url" ]]; then
    echo "Could not determine GitHub URL from origin remote."
    echo
    pause_git
    return
  fi

  echo "Opening: $url"
  open "$url"
  echo
  pause_git
}

git_menu_loop() {
  local choice=""
  while true; do
    print_git_header
    echo "1. Repo status"
    echo "2. Diff risk analysis"
    echo "3. Suggest commit message"
    echo "4. Next recommended action"
    echo "5. Stage selected files"
    echo "6. Commit staged changes"
    echo "7. Safe push"
    echo "8. Pull with rebase"
    echo "9. Recent git log"
    echo "10. Open repo on GitHub"
    echo "11. Change repo path"
    echo "b. Back"
    echo

    read_tty "Choose an option: " choice
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
      11) choose_repo ;;
      b|B) break ;;
      *) echo "Unknown option"; sleep 1 ;;
    esac
  done
}

git_menu_loop
