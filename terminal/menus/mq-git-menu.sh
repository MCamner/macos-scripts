#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-${HOME}/macos-scripts}"
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

CURRENT_REPO="${MQ_GIT_REPO:-$BASE_DIR}"

# Ensures repo is ready.
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

# Coordinates repo name behavior.
repo_name() {
  basename "$CURRENT_REPO"
}

# Normalizes remote url.
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

# Coordinates github web url behavior.
github_web_url() {
  local remote_url=""
  remote_url="$(git -C "$CURRENT_REPO" remote get-url origin 2>/dev/null || true)"
  [[ -n "$remote_url" ]] || return 1
  normalize_remote_url "$remote_url"
}

# Gets ahead behind.
get_ahead_behind() {
  local upstream="$1"
  local counts left right

  counts="$(git -C "$CURRENT_REPO" rev-list --left-right --count "${upstream}...HEAD" 2>/dev/null || true)"
  read -r left right <<< "$counts"

  case "$left" in ''|*[!0-9]*) left=0 ;; esac
  case "$right" in ''|*[!0-9]*) right=0 ;; esac

  printf '%s %s\n' "$left" "$right"
}

# Lists branches that should be pushed through PR branches instead of directly.
protected_branch_names() {
  echo "${MQLAUNCH_PROTECTED_BRANCHES:-main master}"
}

# Checks if a branch is protected by local policy.
is_protected_branch() {
  local branch="$1"
  local protected

  protected=" $(protected_branch_names) "
  [[ "$protected" == *" $branch "* ]]
}

# Creates a safe branch slug from a commit or action label.
branch_slug() {
  local text="$1"
  local slug

  slug="$(echo "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$slug" ]]; then
    slug="update-project-files"
  fi

  echo "${slug:0:48}"
}

# Pushes current commit through a PR branch when the base branch is protected.
create_pr_branch_for_push() {
  local base_branch="$1"
  local action_label="${2:-update project files}"
  local slug pr_branch confirm output status

  slug="$(branch_slug "$action_label")"
  pr_branch="mq/${slug}-$(date +%Y%m%d-%H%M%S)"

  echo
  ui_warn "Branch '$base_branch' is protected. GitHub requires a pull request."
  echo "Suggested PR branch: $pr_branch"
  printf "%bCreate and push this PR branch? [Y/n]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm

  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    ui_warn "Push cancelled. Commit remains local on $base_branch."
    return 1
  fi

  git -C "$CURRENT_REPO" switch -c "$pr_branch" 2>/dev/null || git -C "$CURRENT_REPO" checkout -b "$pr_branch"
  output="$(git -C "$CURRENT_REPO" push -u origin "$pr_branch" 2>&1)"
  status=$?
  echo "$output"

  if [[ "$status" -eq 0 ]] && command -v gh >/dev/null 2>&1; then
    echo
    echo "Next: gh pr create --base $base_branch --head $pr_branch --fill"
  fi

  return "$status"
}

# Pushes directly unless branch protection requires a PR branch.
pr_aware_push() {
  local branch="$1"
  local action_label="${2:-update project files}"
  local push_args=("${@:3}")
  local output status

  if is_protected_branch "$branch"; then
    create_pr_branch_for_push "$branch" "$action_label"
    return $?
  fi

  output="$(git -C "$CURRENT_REPO" push "${push_args[@]}" 2>&1)"
  status=$?
  echo "$output"

  if [[ "$status" -ne 0 ]] && echo "$output" | grep -E "GH013|Changes must be made through a pull request" >/dev/null; then
    create_pr_branch_for_push "$branch" "$action_label"
    return $?
  fi

  return "$status"
}

# Chooses repo.
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

# Shows status.
show_status() {
  ensure_repo || return 1

  local branch upstream ahead behind
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"

  ahead=0
  behind=0
  if [[ -n "$upstream" ]]; then
    read -r behind ahead <<< "$(get_ahead_behind "$upstream")"
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

# Analyzes diff.
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

# Suggests commit.
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

# Coordinates next action behavior.
next_action() {
  ensure_repo || return 1

  local status branch upstream ahead behind
  status="$(git -C "$CURRENT_REPO" status --short)"
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  ahead=0
  behind=0

  if [[ -n "$upstream" ]]; then
    read -r behind ahead <<< "$(get_ahead_behind "$upstream")"
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

# Stages selected.
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

# Commits changes.
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

# Runs push through guardrails before acting.
safe_push() {
  ensure_repo || return 1

  local branch upstream ahead behind confirm
  branch="$(git -C "$CURRENT_REPO" branch --show-current)"
  upstream="$(git -C "$CURRENT_REPO" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
  ahead=0
  behind=0

  if [[ -n "$upstream" ]]; then
    read -r behind ahead <<< "$(get_ahead_behind "$upstream")"
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
    pr_aware_push "$branch" "update project files" -u origin "$branch"
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

  pr_aware_push "$branch" "update project files" origin "$branch"
  echo
  pause_enter
}

# Pulls rebase.
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

# Merges a remote pull request via gh pr merge.
# Unlike a local merge, this closes the PR on GitHub (squash + delete branch by
# default) and syncs the local base branch afterwards. Delegates to the shared
# gitpr-merge-safe.sh helper so guardrails stay in one place.
merge_pull_request() {
  ensure_repo || return 1

  local merge_script="${MQ_GITPR_MERGE_SCRIPT:-}"
  if [[ -z "$merge_script" ]]; then
    if [[ -x "$BASE_DIR/terminal/launchers/gitpr-merge-safe.sh" ]]; then
      merge_script="$BASE_DIR/terminal/launchers/gitpr-merge-safe.sh"
    else
      merge_script="$HOME/mqlaunch/scripts/gitpr-merge-safe.sh"
    fi
  fi

  if [[ ! -x "$merge_script" ]]; then
    ui_err "PR-merge script not found or not executable: $merge_script"
    pause_enter
    return 1
  fi

  ( cd "$CURRENT_REPO" && "$merge_script" )
  echo
  pause_enter
}

# Shows log.
show_log() {
  ensure_repo || return 1

  print_header
  row_bold "RECENT GIT LOG"
  empty_row
  git -C "$CURRENT_REPO" log --oneline --decorate --graph -15 || true
  print_footer
  pause_enter
}

# Opens repo github.
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

# Opens local repo.
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

# Prints menu.
print_git_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Git Menu" "Git" "$width" "$panel_color"
  surface_row "Repo: $CURRENT_REPO" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "WORKSPACE" "$width" "$panel_color"
  surface_split_row "1. Repo status" "2. Diff risk analysis" "$width" "$panel_color"
  surface_split_row "3. Suggest commit message" "4. Next recommended action" "$width" "$panel_color"
  surface_split_row "5. Stage selected files" "6. Commit staged changes" "$width" "$panel_color"
  surface_split_row "7. Safe push" "8. Pull with rebase" "$width" "$panel_color"
  surface_split_row "p. Merge pull request" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "NAVIGATION" "$width" "$panel_color"
  surface_split_row "10. Open repo on GitHub" "11. Open local repo folder" "$width" "$panel_color"
  surface_split_row "12. Change repo path" "b. Back" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the menu loop.
git_menu_loop() {
  local choice=""

  while true; do
    print_git_menu
    read_menu_choice "" "git"
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
      p|P) merge_pull_request ;;
      9) show_log ;;
      10) open_repo_github ;;
      11) open_local_repo ;;
      12) choose_repo ;;
      b|B|x|X|exit) return ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
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

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) git_menu_loop ;;
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

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ -z "${ZSH_VERSION:-}" && "${0}" == *mq-git-menu* ]]; then
  main "${1:-menu}"
fi
