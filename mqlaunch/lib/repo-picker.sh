#!/usr/bin/env bash
# mqlaunch GitHub repo picker — fzf over `gh repo list`, then an action menu to
# open in the browser, cd into the repo, or clone to ~/repos (optionally opening
# in VS Code or Finder).
#
# Extracted from terminal/launchers/mqlaunch.sh as part of Step 11a (monolith
# de-layering, audit P4). Sourced into the launcher's scope, so it relies on the
# launcher's ambient UI helpers (print_header/row/row_bold/empty_row/
# print_footer/pause_enter) and on $HOME/$SHELL. Requires gh and fzf at runtime
# (both checked, with an install hint when missing). No behavior change — the
# function body is a verbatim move (the launcher's mislabeled "# Opens repo
# browser." comment is corrected here). Pure bash, covered by shellcheck.

# Picks a GitHub repo via fzf and runs an open/clone action on it.
run_github_repo_picker() {
  local fzf_bin gh_bin selected action clone_dir

  fzf_bin="$(command -v fzf 2>/dev/null || true)"
  gh_bin="$(command -v gh 2>/dev/null || true)"

  # A terminal is as much a precondition as gh and fzf are. Without one the
  # picker used to reach fzf and block on its stdin, which is what made
  # `mqlaunch repos` (via `hub`) never return without a TTY (#73).
  if ! mq_has_interactive_tty; then
    echo "GitHub repo picker needs a terminal." >&2
    return 1
  fi

  print_header

  if [[ -z "$gh_bin" ]]; then
    row_bold "GITHUB REPO PICKER"
    empty_row
    row "gh (GitHub CLI) is not installed."
    row "Install: brew install gh"
    print_footer
    pause_enter
    return 1
  fi

  if [[ -z "$fzf_bin" ]]; then
    row_bold "GITHUB REPO PICKER"
    empty_row
    row "fzf is not installed."
    row "Install: brew install fzf"
    print_footer
    pause_enter
    return 1
  fi

  row_bold "GITHUB REPO PICKER"
  empty_row
  row "Hämtar dina repos från GitHub..."
  print_footer

  selected="$(
    "$gh_bin" repo list --limit 1000 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null \
      | "$fzf_bin" \
          --reverse \
          --border \
          --header='Välj ett GitHub-repo (ESC = avbryt)' \
          --prompt='repo > ' \
          --height=70%
  )"

  [[ -z "$selected" ]] && return 0

  action="$(printf '%s\n' \
    "Öppna i webbläsaren" \
    "Gå till repo i terminalen" \
    "Klona och hoppa in i terminalen" \
    "Klona till ~/repos" \
    "Klona till ~/repos och öppna i VS Code" \
    "Klona till ~/repos och öppna i Finder" \
    | "$fzf_bin" \
        --reverse \
        --border \
        --header="$selected" \
        --prompt='åtgärd > ' \
        --height=40%
  )"

  [[ -z "$action" ]] && return 0

  clone_dir="$HOME/repos"
  mkdir -p "$clone_dir"
  local repo_name repo_dir home_repo_dir
  repo_name="$(basename "$selected")"
  repo_dir="$clone_dir/$repo_name"
  home_repo_dir="$HOME/$repo_name"

  case "$action" in
    "Öppna i webbläsaren")
      "$gh_bin" repo view "$selected" --web
      print_footer
      pause_enter
      ;;
    "Gå till repo i terminalen")
      if [[ -d "$home_repo_dir" ]]; then
        repo_dir="$home_repo_dir"
      elif [[ ! -d "$repo_dir" ]]; then
        printf "Repo saknas lokalt: %s\nKlona först med 'Klona och hoppa in i terminalen'.\n" "$home_repo_dir"
        pause_enter
        return 0
      fi
      cd "$repo_dir" || return 1
      clear
      printf "📁 %s\n" "$repo_dir"
      exec "$SHELL" -l
      ;;
    "Klona och hoppa in i terminalen")
      if [[ ! -d "$repo_dir" ]]; then
        "$gh_bin" repo clone "$selected" "$repo_dir" 2>&1 | tail -3
      fi
      cd "$repo_dir" || return 1
      clear
      printf "📁 %s\n" "$repo_dir"
      exec "$SHELL" -l
      ;;
    "Klona till ~/repos")
      "$gh_bin" repo clone "$selected" "$repo_dir" 2>&1 | tail -3
      row "Klonat till $repo_dir"
      print_footer
      pause_enter
      ;;
    "Klona till ~/repos och öppna i VS Code")
      "$gh_bin" repo clone "$selected" "$repo_dir" 2>&1 | tail -3
      code "$repo_dir" 2>/dev/null || open -a "Visual Studio Code" "$repo_dir" 2>/dev/null
      print_footer
      pause_enter
      ;;
    "Klona till ~/repos och öppna i Finder")
      "$gh_bin" repo clone "$selected" "$repo_dir" 2>&1 | tail -3
      open "$repo_dir"
      print_footer
      pause_enter
      ;;
  esac
}
