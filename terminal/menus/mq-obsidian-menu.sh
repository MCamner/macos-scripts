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
for _mqobs_lib in errors resolve manifest open; do
  if [[ -f "$BASE_DIR/mqlaunch/lib/mqobsidian/$_mqobs_lib.sh" ]]; then
    # Path is built per iteration over errors/resolve/manifest/open, so no
    # single target can be named.
    # shellcheck source=/dev/null
    source "$BASE_DIR/mqlaunch/lib/mqobsidian/$_mqobs_lib.sh"
  elif command -v mq_debug >/dev/null 2>&1; then
    # Optional lib absent — degrade gracefully, but make it observable so a
    # missing Obsidian feature is diagnosable under MQ_DEBUG instead of silent.
    mq_debug "mq-obsidian-menu: lib not found: mqlaunch/lib/mqobsidian/$_mqobs_lib.sh"
  fi
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

  surface_row "NAVIGATE" "$width" "$panel_color"
  surface_split_row "14. Open any view (manifest)" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf "\n"
}

# Shows missing mqobsidian repo message.
mq_obsidian_missing() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi
  surface_panel_header "MQ Obsidian / Memory" "MEMORY" "$width" "$panel_color"
  surface_row "Repo not found: $MQ_OBSIDIAN_DIR" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Expected local repo: ~/mqobsidian" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
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

# Opens a manifest-defined view via the consumer lib; falls back to the given
# repo-relative path when the lib/manifest is unavailable. Keeps view paths in
# the manifest, not hardcoded in this menu.
mq_obsidian_open_manifest_view() {
  local key="$1" fallback_rel="${2:-}"
  if command -v open_mqobsidian_target >/dev/null 2>&1; then
    open_mqobsidian_target "$key" || _mq_obsidian_pause_enter
  elif [[ -n "$fallback_rel" ]]; then
    mq_obsidian_open_file "$fallback_rel"
  else
    printf "Consumer lib unavailable for view: %s\n" "$key"
    _mq_obsidian_pause_enter
  fi
}

# Lists every manifest view and opens the chosen one (by number or key).
# Exposes views the panel does not list (decisions, execution, repo hot files).
mq_obsidian_open_view_picker() {
  if ! command -v list_supported_views >/dev/null 2>&1; then
    printf "Consumer lib/manifest not available.\n"
    _mq_obsidian_pause_enter
    return 1
  fi

  local keys=() key i=0 sel idx
  printf "\nManifest views:\n"
  while IFS= read -r key; do
    keys+=("$key")
    i=$((i + 1))
    printf "  %2d. %s\n" "$i" "$key"
  done < <(list_supported_views)

  printf "view [number or key]> "
  read -r sel
  [[ -z "${sel// }" ]] && return 0
  if [[ "$sel" =~ ^[0-9]+$ ]]; then
    idx=$((sel - 1))
    sel="${keys[$idx]:-}"
  fi
  if [[ -z "$sel" ]]; then
    printf "No such view.\n"
    _mq_obsidian_pause_enter
    return 1
  fi
  open_mqobsidian_target "$sel" || _mq_obsidian_pause_enter
}

# Runs a command inside mqobsidian.
mq_obsidian_run() {
  if [[ ! -d "$MQ_OBSIDIAN_DIR" ]]; then
    mq_obsidian_missing
    return 1
  fi

  (cd "$MQ_OBSIDIAN_DIR" && "$@")
}

# Resolves mqobsidian's Python, preferring its isolated repo environment.
mq_obsidian_python() {
  if [[ -x "$MQ_OBSIDIAN_DIR/.venv/bin/python3" ]]; then
    printf '%s\n' "$MQ_OBSIDIAN_DIR/.venv/bin/python3"
  else
    command -v python3
  fi
}

# Runs public-safe mqobsidian checks.
mq_obsidian_public_safe_checks() {
  local python
  python="$(mq_obsidian_python)" || return
  mq_obsidian_run "$python" scripts/validate-export.py || return
  mq_obsidian_run "$python" scripts/check-sensitive-content.py || return
  mq_obsidian_run "$python" scripts/check-token-budget.py
}

# Runs token budget check.
mq_obsidian_token_budget() {
  local python
  python="$(mq_obsidian_python)" || return
  mq_obsidian_run "$python" scripts/check-token-budget.py
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
  local task repo target out python

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
  python="$(mq_obsidian_python)" || return
  mq_obsidian_run "$python" scripts/generate-context-pack.py --task "$task" --repo "$repo" --target "$target" --out "$out"
  printf "\nWrote: %s\n" "$out"
  _mq_obsidian_pause_enter
}

# Opens latest generated task pack.
mq_obsidian_open_latest_task_pack() {
  mq_obsidian_open_path "$MQ_OBSIDIAN_TASK_PACK"
}

# Exports repo context when a supported script exists.
mq_obsidian_export_repo_context() {
  local python

  if command -v print_header >/dev/null 2>&1; then
    print_header
  fi

  printf "\nExport repo context\n"
  if [[ -x "$MQ_OBSIDIAN_DIR/scripts/export-repo-context.py" || -f "$MQ_OBSIDIAN_DIR/scripts/export-repo-context.py" ]]; then
    python="$(mq_obsidian_python)" || return
    mq_obsidian_run "$python" scripts/export-repo-context.py
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
  local separator
  separator="────────────────────────────────────────────────────────────"

  printf "%s\n" "$separator"
  printf " mqlaunch · Option 12 · Learning inbox triage\n"
  printf "%s\n\n" "$separator"
  printf "Status\n"
  printf "  review gated\n\n"
  printf "Scope\n"
  printf "  Read-only inbox inspection. No promote/reject action runs here.\n\n"
  printf "Memory inbox\n"
  printf "  %s/inbox\n\n" "$MQ_OBSIDIAN_DIR"
  printf "Inbox files\n"
  if [[ -d "$MQ_OBSIDIAN_DIR/inbox" ]]; then
    find "$MQ_OBSIDIAN_DIR/inbox" -maxdepth 2 -type f |
      sed "s#^$MQ_OBSIDIAN_DIR/##" |
      sort |
      awk '{ printf "%d. %s\n", NR, $0 }'
  else
    printf "  unavailable\n"
  fi
  printf "\nWhy this is gated\n"
  printf "  mqlaunch may list learning inbox items, but mq-agent must own\n"
  printf "  promotion, rejection, and review decisions.\n\n"
  printf "Available here\n"
  printf "  Enter  return to menu\n"
  printf "  x      exit mqlaunch\n\n"
  printf "Next owner\n"
  printf "  mq-agent\n"
}

# mqobsidian's view renderers, repo-relative. Each reads local memory data and
# rewrites markdown under its own views/ directory. They sit next to their data
# rather than in mqobsidian/scripts/ on purpose: scripts/ is the export surface
# other repos consume, and these render nothing anyone else reads. Rendering is
# not curation — promotion, scoring and aging stay manual passes in mqobsidian.
MQ_OBSIDIAN_VIEW_RENDERERS=(
  "memory/commands/build_views.py"
  "memory/workflows/build_workflow_views.py"
)

# Regenerates memory views by running every renderer the vault actually ships.
# Returns the first nonzero status so a broken renderer is not reported as a
# successful regeneration.
mq_obsidian_regenerate_views() {
  # `rc`, not `status`: menus run under zsh, where $status is read-only.
  local python renderer rc=0 ran=0

  for renderer in "${MQ_OBSIDIAN_VIEW_RENDERERS[@]}"; do
    [[ -f "$MQ_OBSIDIAN_DIR/$renderer" ]] || continue
    if [[ "$ran" -eq 0 ]]; then
      python="$(mq_obsidian_python)" || return 1
    fi
    ran=1
    printf "── %s\n" "$renderer"
    if ! mq_obsidian_run "$python" "$renderer"; then
      rc=1
    fi
  done

  if [[ "$ran" -eq 1 ]]; then
    return "$rc"
  fi

  printf "────────────────────────────────────────────────────────────\n"
  printf " mqlaunch · Option 13 · Regenerate memory views\n"
  printf "────────────────────────────────────────────────────────────\n\n"
  printf "Status\n"
  printf "  not implemented yet\n\n"
  printf "Current state\n"
  printf "  This vault ships no view renderer.\n\n"
  printf "Local producers\n"
  for renderer in "${MQ_OBSIDIAN_VIEW_RENDERERS[@]}"; do
    printf "  %s\n" "$renderer"
  done
  printf "\nmqlaunch role\n"
  printf "  runs the renderers; mqobsidian owns curation\n\n"
  printf "Available here\n"
  printf "  Enter  return to menu\n"
  printf "  x      exit mqlaunch\n"
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
      3|roadmap) mq_obsidian_open_manifest_view "roadmap-doc" "docs/roadmap-token-reduction.md" ;;
      4|context-docs|context) mq_obsidian_open_manifest_view "context-budget" "docs/context-budget.md" ;;
      5|checks|public-safe) mq_obsidian_public_safe_checks; _mq_obsidian_pause_enter ;;
      6|budget|token-budget) mq_obsidian_token_budget; _mq_obsidian_pause_enter ;;
      7|doctor) mq_obsidian_doctor; _mq_obsidian_pause_enter ;;
      8|pack|context-pack|generate) mq_obsidian_generate_task_pack ;;
      9|latest|task-pack) mq_obsidian_open_latest_task_pack ;;
      10|export) mq_obsidian_export_repo_context ;;
      11|inbox) mq_obsidian_show_inbox; _mq_obsidian_pause_enter ;;
      12|triage) mq_obsidian_triage_learning_inbox; _mq_obsidian_pause_enter ;;
      13|views|regenerate) mq_obsidian_regenerate_views; _mq_obsidian_pause_enter ;;
      14|open-view|navigate) mq_obsidian_open_view_picker ;;
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
