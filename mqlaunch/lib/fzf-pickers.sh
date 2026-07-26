#!/usr/bin/env bash
# mqlaunch fzf pickers — interactive fuzzy finders for git, processes, ports,
# scripts, and recent files.
#
# Extracted from terminal/launchers/mqlaunch.sh as part of Step 11a (monolith
# de-layering, audit P4). Sourced into the launcher's scope, so it relies on the
# launcher's ambient UI helpers (print_header/row/print_footer/pause_enter) and
# $BASE_DIR. It defines no state of its own and changes no behavior — the
# functions are verbatim moves. Pure bash (no zsh builtins), so it carries a
# bash shebang and is covered by shellcheck.

# fzf: bläddra git log med diff-preview
fzf_git_log() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_git_log needs a terminal." >&2
    return 1
  fi
  local fzf_bin commit
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Inte i ett git-repo."
    pause_enter
    return 1
  fi
  commit="$(
    git log --oneline --color=always | \
    "$fzf_bin" --ansi --reverse --border \
      --header='Git commits — Enter för att visa, Ctrl+C för att avbryta' \
      --prompt='commit > ' \
      --preview='git show --color=always {1}' \
      --preview-window=right:60%
  )"
  [[ -z "$commit" ]] && return 0
  git show "$(echo "$commit" | awk '{print $1}')"
  pause_enter
}

# fzf: byt git-branch
fzf_git_branch() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_git_branch needs a terminal." >&2
    return 1
  fi
  local fzf_bin branch
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Inte i ett git-repo."
    pause_enter
    return 1
  fi
  branch="$(
    git branch --all | grep -v HEAD | sed 's/remotes\/origin\///' | sort -u | \
    "$fzf_bin" --reverse --border \
      --header='Välj branch att checka ut' \
      --prompt='branch > '
  )"
  [[ -z "$branch" ]] && return 0
  branch="$(echo "$branch" | xargs)"
  git checkout "$branch"
  pause_enter
}

# fzf: döda processer
fzf_kill_process() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_kill_process needs a terminal." >&2
    return 1
  fi
  local fzf_bin selected pid
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  selected="$(
    ps aux | tail -n +2 | \
    "$fzf_bin" --multi --reverse --border \
      --header='Välj process(er) att döda — TAB för flerval' \
      --prompt='process > '
  )"
  [[ -z "$selected" ]] && return 0
  pid="$(echo "$selected" | awk '{print $2}')"
  echo "$pid" | xargs kill -9 2>/dev/null
  echo "Dödade PID: $(echo "$pid" | tr '\n' ' ')"
  pause_enter
}

# fzf: döda process på port
fzf_kill_port() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_kill_port needs a terminal." >&2
    return 1
  fi
  local fzf_bin selected pid port
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  selected="$(
    lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | tail -n +2 | \
    "$fzf_bin" --multi --reverse --border \
      --header='Välj port(ar) att frigöra — TAB för flerval' \
      --prompt='port > '
  )"
  [[ -z "$selected" ]] && return 0
  pid="$(echo "$selected" | awk '{print $2}')"
  port="$(echo "$selected" | awk '{print $9}' | cut -d: -f2 | tr '\n' ' ')"
  echo "$pid" | xargs kill -9 2>/dev/null
  echo "Frigjorde port(ar): $port"
  pause_enter
}

# fzf: kör script från macos-scripts
fzf_run_snippet() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_run_snippet needs a terminal." >&2
    return 1
  fi
  local fzf_bin selected
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  selected="$(
    find "$BASE_DIR" -name "*.sh" -not -path "*/.git/*" -not -path "*/backups/*" 2>/dev/null | \
    sed "s|$BASE_DIR/||" | sort | \
    "$fzf_bin" --reverse --border \
      --header='Välj script att köra' \
      --prompt='script > ' \
      --preview="bat --color=always '$BASE_DIR/{}' 2>/dev/null || cat '$BASE_DIR/{}'"
  )"
  [[ -z "$selected" ]] && return 0
  print_header
  row "Kör: $selected"
  print_footer
  bash "$BASE_DIR/$selected"
  pause_enter
}

# fzf: visa och öppna nyligen ändrade filer
fzf_recent_files() {
  # An fzf picker with no terminal blocks on its own stdin forever (#73).
  if ! mq_has_interactive_tty; then
    echo "fzf_recent_files needs a terminal." >&2
    return 1
  fi
  local fzf_bin selected search_dir
  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  [[ -z "$fzf_bin" ]] && echo "fzf not installed." && return 1
  search_dir="${1:-$HOME/repos}"
  selected="$(
    find "$search_dir" -type f -not -path "*/.git/*" -newer "$search_dir" -mtime -14 2>/dev/null | \
    sort | \
    "$fzf_bin" --reverse --border \
      --header='Senast ändrade filer (14 dagar) — Enter öppnar' \
      --prompt='fil > ' \
      --preview='bat --color=always {} 2>/dev/null || cat {}'
  )"
  [[ -z "$selected" ]] && return 0
  "${EDITOR:-code}" "$selected" 2>/dev/null || open "$selected"
}
