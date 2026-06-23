#!/usr/bin/env bash

# MQ Obsidian Menu — mqlaunch surface for MQ memory/context work.
#
# Rule: this menu owns presentation and routing only.
# mqobsidian and mq-agent own memory, context-pack, and learn logic.

# Checks whether mqobsidian menu is sourced.
mq_obsidian_menu_is_sourced() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ ":${ZSH_EVAL_CONTEXT:-}:" == *:file:* ]]
    return
  fi
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

if ! command -v surface_top >/dev/null 2>&1; then
  : "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

: "${MQ_OBSIDIAN_DIR:=$HOME/mqobsidian}"
: "${MQ_OBSIDIAN_TASK_PACK:=$MQ_OBSIDIAN_DIR/.mq/context/task-pack.md}"

# mqobsidian consumer lib — shared resolver/manifest/opener (PR1/PR2). Optional:
# the menu degrades gracefully if it is absent.
: "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
for _mqobs_lib in errors resolve open; do
  [[ -f "$BASE_DIR/mqlaunch/lib/mqobsidian/$_mqobs_lib.sh" ]] \
    && source "$BASE_DIR/mqlaunch/lib/mqobsidian/$_mqobs_lib.sh"
done
unset _mqobs_lib

# Pauses safely after MQ Obsidian menu actions.
_mq_obsidian_pause_enter() {
  if command -v pause_enter >/dev/null 2>&1; then
    pause_enter
  else
    printf "\nPress Enter to continue..."
    read -r _
  fi
}

# Renders the MQ Obsidian menu panel.
render_mq_obsidian_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  surface_panel_header "MQ Obsidian / Memory" "MEMORY" "$width" "$panel_color"

  surface_row "OBSERVE" "$width" "$panel_color"
  surface_split_row "1. Open repo" "2. Open vault" "$width" "$panel_color"
  surface_split_row "3. Open roadmap" "4. Open context docs" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "CHECK" "$width" "$panel_color"
  surface_split_row "5. Public-safe checks" "6. Token budget" "$width" "$panel_color"
  surface_split_row "7. Doctor" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "CONTEXT" "$width" "$panel_color"
  surface_split_row "8. Generate task-pack" "9. Open latest task-pack" "$width" "$panel_color"
  surface_split_row "10. Export repo context" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "INBOX" "$width" "$panel_color"
  surface_split_row "11. Show memory inbox" "12. Triage learning inbox" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "MAINTAIN" "$width" "$panel_color"
  surface_split_row "13. Regenerate memory views" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf "\n"
}

# Shows missing mqobsidian repo message.
mq_obsidian_missing() {
  local width
  width="$(surface_terminal_width)"
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  surface_panel_header "MQ Obsidian / Memory" "MEMORY" "$width" ""
  surface_row "Repo not found: $MQ_OBSIDIAN_DIR" "$width" ""
  surface_row "" "$width" ""
  surface_row "Expected local repo: ~/mqobsidian" "$width" ""
  surface_bottom "$width" ""
  _mq_obsidian_pause_enter
}

# Opens a path with macOS open. Routes through the consumer lib's single opener
# when available (so menu + commands share one opener), else falls back.
mq_obsidian_open_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    if command -v open_mqobsidian_path >/dev/null 2>&1; then
      open_mqobsidian_path "$path"
    else
      open "$path"
    fi
  else
    printf "Path not found: %s\n" "$path"
    _mq_obsidian_pause_enter
  fi
}

# Opens the mqobsidian repo folder.
mq_obsidian_open_repo() {
  mq_obsidian_open_path "$MQ_OBSIDIAN_DIR"
}

# Opens the mqobsidian vault in Obsidian when possible.
mq_obsidian_open_vault() {
  if [[ ! -d "$MQ_OBSIDIAN_DIR" ]]; then
    mq_obsidian_missing
    return 1
  fi

  open -a Obsidian "$MQ_OBSIDIAN_DIR" >/dev/null 2>&1 || open "$MQ_OBSIDIAN_DIR"
}

# Opens a repo-relative file.
mq_obsidian_open_file() {
  local rel="$1"
  mq_obsidian_open_path "$MQ_OBSIDIAN_DIR/$rel"
}

# Runs a command inside mqobsidian.
mq_obsidian_run() {
  if [[ ! -d "$MQ_OBSIDIAN_DIR" ]]; then
    mq_obsidian_missing
    return 1
  fi

  (cd "$MQ_OBSIDIAN_DIR" && "$@")
}

# Runs public-safe mqobsidian checks.
mq_obsidian_public_safe_checks() {
  mq_obsidian_run python3 scripts/validate-export.py || return
  mq_obsidian_run python3 scripts/check-sensitive-content.py || return
  mq_obsidian_run python3 scripts/check-token-budget.py
}

# Runs token budget check.
mq_obsidian_token_budget() {
  mq_obsidian_run python3 scripts/check-token-budget.py
}

# Runs a compact mqobsidian doctor.
mq_obsidian_doctor() {
  printf "Repo: %s\n\n" "$MQ_OBSIDIAN_DIR"
  mq_obsidian_public_safe_checks
  printf "\nTask pack: "
  if [[ -f "$MQ_OBSIDIAN_TASK_PACK" ]]; then
    printf "present (%s)\n" "$MQ_OBSIDIAN_TASK_PACK"
  else
    printf "missing (%s)\n" "$MQ_OBSIDIAN_TASK_PACK"
  fi
  printf "Inbox files:\n"
  if [[ -d "$MQ_OBSIDIAN_DIR/inbox" ]]; then
    find "$MQ_OBSIDIAN_DIR/inbox" -maxdepth 2 -type f | sed "s#^$MQ_OBSIDIAN_DIR/##" | sort | head -40
  else
    printf "  inbox/ missing\n"
  fi
}

# Prompts for and generates a context task pack.
mq_obsidian_generate_task_pack() {
  local task repo target out

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  printf "\nGenerate context pack\n"
  printf "task [fix mq-mcp brain writer paths]> "
  read -r task
  [[ -z "${task// }" ]] && task="fix mq-mcp brain writer paths"

  printf "repo [mq-mcp]> "
  read -r repo
  [[ -z "${repo// }" ]] && repo="mq-mcp"

  printf "target [codex]> "
  read -r target
  [[ -z "${target// }" ]] && target="codex"

  out="$MQ_OBSIDIAN_TASK_PACK"
  mkdir -p "$(dirname "$out")"
  printf "\n"
  mq_obsidian_run python3 scripts/generate-context-pack.py --task "$task" --repo "$repo" --target "$target" --out "$out"
  printf "\nWrote: %s\n" "$out"
  _mq_obsidian_pause_enter
}

# Opens latest generated task pack.
mq_obsidian_open_latest_task_pack() {
  mq_obsidian_open_path "$MQ_OBSIDIAN_TASK_PACK"
}

# Exports repo context when a supported script exists.
mq_obsidian_export_repo_context() {
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  printf "\nExport repo context\n"
  if [[ -x "$MQ_OBSIDIAN_DIR/scripts/export-repo-context.py" || -f "$MQ_OBSIDIAN_DIR/scripts/export-repo-context.py" ]]; then
    mq_obsidian_run python3 scripts/export-repo-context.py
  else
    printf "No export script found yet. Next route should be mq-agent context pack once wired.\n"
    printf "Current MVP command:\n"
    printf "  python3 scripts/generate-context-pack.py --task \"fix mq-mcp brain writer paths\" --repo mq-mcp --target codex --out .mq/context/task-pack.md\n"
  fi
  _mq_obsidian_pause_enter
}

# Shows memory inbox files.
mq_obsidian_show_inbox() {
  if [[ ! -d "$MQ_OBSIDIAN_DIR/inbox" ]]; then
    printf "Inbox not found: %s/inbox\n" "$MQ_OBSIDIAN_DIR"
    return 1
  fi

  printf "Memory inbox: %s/inbox\n\n" "$MQ_OBSIDIAN_DIR"
  find "$MQ_OBSIDIAN_DIR/inbox" -maxdepth 2 -type f | sed "s#^$MQ_OBSIDIAN_DIR/##" | sort
}

# Shows learning inbox triage status without mutating memory.
mq_obsidian_triage_learning_inbox() {
  printf "Learning inbox triage is review-gated.\n\n"
  if [[ -d "$MQ_OBSIDIAN_DIR/inbox" ]]; then
    mq_obsidian_show_inbox
  fi
  printf "\nNo promote/reject action is run from mqlaunch until mq-agent owns that flow.\n"
}

# Regenerates memory views when a supported script exists.
mq_obsidian_regenerate_views() {
  if [[ -x "$MQ_OBSIDIAN_DIR/scripts/regenerate-memory-views.py" || -f "$MQ_OBSIDIAN_DIR/scripts/regenerate-memory-views.py" ]]; then
    mq_obsidian_run python3 scripts/regenerate-memory-views.py
  else
    printf "No regenerate-memory-views script found yet.\n"
    printf "Expected future owner: mqobsidian script or mq-agent orchestration.\n"
  fi
}

# Runs the MQ Obsidian menu loop.
mq_obsidian_menu_main() {
  local choice

  if [[ ! -d "$MQ_OBSIDIAN_DIR" ]]; then
    mq_obsidian_missing
    return 127
  fi

  while true; do
    render_mq_obsidian_panel

    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "mqobsidian" || break
    else
      printf "\nmqobsidian> "
      read -r choice
    fi
    echo

    case "$choice" in
      1|repo|open-repo) mq_obsidian_open_repo ;;
      2|vault|open-vault) mq_obsidian_open_vault ;;
      3|roadmap) mq_obsidian_open_file "docs/roadmap-token-reduction.md" ;;
      4|context-docs|context) mq_obsidian_open_file "docs/context-budget.md" ;;
      5|checks|public-safe) mq_obsidian_public_safe_checks; _mq_obsidian_pause_enter ;;
      6|budget|token-budget) mq_obsidian_token_budget; _mq_obsidian_pause_enter ;;
      7|doctor) mq_obsidian_doctor; _mq_obsidian_pause_enter ;;
      8|pack|context-pack|generate) mq_obsidian_generate_task_pack ;;
      9|latest|task-pack) mq_obsidian_open_latest_task_pack ;;
      10|export) mq_obsidian_export_repo_context ;;
      11|inbox) mq_obsidian_show_inbox; _mq_obsidian_pause_enter ;;
      12|triage) mq_obsidian_triage_learning_inbox; _mq_obsidian_pause_enter ;;
      13|views|regenerate) mq_obsidian_regenerate_views; _mq_obsidian_pause_enter ;;
      h|help) render_mq_obsidian_panel; _mq_obsidian_pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      *)
        if [[ -n "$choice" ]]; then
          printf "Unknown MQ Obsidian action: %s\n" "$choice"
          _mq_obsidian_pause_enter
        fi
        ;;
    esac
  done
}

if ! mq_obsidian_menu_is_sourced; then
  mq_obsidian_menu_main "$@"
fi
