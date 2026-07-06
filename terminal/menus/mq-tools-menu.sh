#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-${HOME}/macos-scripts}"
WORK_DIR="${MQ_WORK_DIR:-$PWD}"

if repo_root="$(git -C "$WORK_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  WORK_DIR="$repo_root"
fi

UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"

# shellcheck disable=SC2034
APP_TITLE="MQ Tools Menu"
# shellcheck disable=SC2034
APP_SUBTITLE="Reusable Terminal Module"
# shellcheck disable=SC2034
APP_AUTHOR="Author Mattias Camner"
# shellcheck disable=SC2034
BOX_INNER=88
# shellcheck disable=SC2034
MQ_USE_DASHBOARD_HEADER=1

if [[ -f "$UI_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

SYSTEM_CHECK="$BASE_DIR/tools/scripts/system-check.sh"
DOCUMENT_FUNCTIONS="$BASE_DIR/tools/scripts/document-functions.sh"
OLLAMA_DOCUMENT_REVIEW="$BASE_DIR/tools/scripts/ollama-document-review.py"
MQ_MCP_REVIEW="$BASE_DIR/tools/scripts/mq-mcp-review.py"
MQ_SKILLS="$BASE_DIR/tools/scripts/mq-skills.py"
MQ_REPOS="$BASE_DIR/tools/scripts/mq-repos.py"
MQ_MCP_HOME="${MQ_MCP_HOME:-$HOME/mq-mcp}"
DOCUMENT_FUNCTION_TARGETS=("$WORK_DIR")
DOCUMENT_FUNCTION_ARGS=(--summary --exclude '*.bak.*' --exclude '*.bak' --exclude '*/.git/*' --exclude '*/backups/*')
MQLAUNCH="$BASE_DIR/terminal/launchers/mqlaunch.sh"
DASHBOARD="$BASE_DIR/ui/dashboards/mq-dashboard.sh"
THEMES_DIR="$BASE_DIR/terminal/themes"
LAUNCHERS_DIR="$BASE_DIR/terminal/launchers"
MENUS_DIR="$BASE_DIR/terminal/menus"
GUIDE_HTML="$BASE_DIR/tools/mac-terminal-guide/mac-terminal-guide.html"
GUIDE_URL="https://mcamner.github.io/macos-scripts/"

# Normalizes document function target.
normalize_document_function_target() {
  local target="$1"

  if [[ "$target" = /* ]]; then
    printf '%s\n' "$target"
  else
    printf '%s/%s\n' "$WORK_DIR" "$target"
  fi
}

# Runs system check.
run_system_check() {
  if [[ -x "$SYSTEM_CHECK" ]]; then
    "$SYSTEM_CHECK"
  else
    print_header
    row "SYSTEM CHECK"
    empty_row
    row "system-check.sh not found or not executable:"
    row " $SYSTEM_CHECK"
    print_footer
    pause_enter
  fi
}

# Opens repo.
open_repo() {
  open "$BASE_DIR"
}

# Opens launchers.
open_launchers() {
  open "$LAUNCHERS_DIR"
}

# Opens themes.
open_themes() {
  open "$THEMES_DIR"
}

# Opens menus.
open_menus() {
  open "$MENUS_DIR"
}

# Opens dashboard.
open_dashboard() {
  if [[ -x "$DASHBOARD" ]]; then
    bash "$DASHBOARD" menu
  elif [[ -f "$DASHBOARD" ]]; then
    chmod +x "$DASHBOARD" 2>/dev/null || true
    bash "$DASHBOARD" menu
  else
    print_header
    row "DASHBOARD"
    empty_row
    row "Dashboard script missing:"
    row " $DASHBOARD"
    print_footer
    pause_enter
  fi
}

# Opens guide.
open_guide() {
  if [[ -f "$GUIDE_HTML" ]]; then
    open "$GUIDE_HTML"
  else
    open "$GUIDE_URL"
  fi
}

# Shows paths.
show_paths() {
  print_header
  row_bold "KEY PATHS"
  empty_row

  row "BASE_DIR"
  row " $BASE_DIR"
  empty_row

  row "WORK_DIR"
  row " $WORK_DIR"
  empty_row

  row "MQLAUNCH"
  row " $MQLAUNCH"
  empty_row

  row "DASHBOARD"
  row " $DASHBOARD"
  empty_row

  row "THEMES DIR"
  row " $THEMES_DIR"
  empty_row

  row "MENUS DIR"
  row " $MENUS_DIR"

  print_footer
  pause_enter
}

# Shows git status.
show_git_status() {
  print_header
  row_bold "GIT STATUS"
  empty_row

  if [[ -d "$BASE_DIR/.git" ]]; then
    git -C "$BASE_DIR" status --short --branch || true
  else
    row "Not a git repository:"
    row " $BASE_DIR"
  fi

  print_footer
  pause_enter
}

# Runs document functions preview.
run_document_functions_preview() {
  print_header
  row_bold "DOCUMENT FUNCTIONS"
  empty_row

  if [[ -x "$DOCUMENT_FUNCTIONS" ]]; then
    run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${DOCUMENT_FUNCTION_TARGETS[@]}"
  elif [[ -f "$DOCUMENT_FUNCTIONS" ]]; then
    run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${DOCUMENT_FUNCTION_TARGETS[@]}"
  else
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
  fi

  print_footer
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Runs document functions command.
run_document_functions_command() {
  if [[ -x "$DOCUMENT_FUNCTIONS" ]]; then
    MACOS_SCRIPTS_HOME="$WORK_DIR" "$DOCUMENT_FUNCTIONS" "$@"
  else
    MACOS_SCRIPTS_HOME="$WORK_DIR" bash "$DOCUMENT_FUNCTIONS" "$@"
  fi
}

# Coordinates pause if interactive behavior.
pause_if_interactive() {
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Runs a bundled tools script with a clear missing-file fallback.
run_tool_script() {
  local label="$1"
  local script="$2"
  shift 2

  if [[ -x "$script" ]]; then
    "$script" "$@"
  elif [[ -f "$script" ]]; then
    bash "$script" "$@"
  else
    print_header
    row_bold "$label"
    empty_row
    row "Script missing:"
    row " $script"
    print_footer
  fi

  pause_enter
}

# Coordinates select document function targets behavior.
select_document_function_targets() {
  local action="${1:-update}"
  local selection custom target

  SELECTED_DOCUMENT_FUNCTION_TARGETS=()

  row "Choose what to $action:"
  row " a. Current repo/path (default)"
  row " 1. tools/scripts in current path"
  row " 2. terminal/menus in current path"
  row " 3. terminal/launchers in current path"
  row " 4. One script/path"
  row " c. Custom list"
  row " q. Cancel"
  empty_row

  printf 'Target [a,1-4,c,q] > '
  read -r selection
  selection="${selection:-a}"

  case "$selection" in
    a|A)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("${DOCUMENT_FUNCTION_TARGETS[@]}")
      ;;
    1)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "tools/scripts")")
      ;;
    2)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "terminal/menus")")
      ;;
    3)
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "terminal/launchers")")
      ;;
    4)
      printf 'Script/path > '
      read -r custom
      if [[ -z "${custom// }" ]]; then
        ui_warn "No path entered."
        return 1
      fi
      SELECTED_DOCUMENT_FUNCTION_TARGETS=("$(normalize_document_function_target "$custom")")
      ;;
    c|C)
      row "Enter space-separated files or directories."
      printf 'Paths > '
      read -r custom
      if [[ -z "${custom// }" ]]; then
        ui_warn "No paths entered."
        return 1
      fi
      for target in $custom; do
        SELECTED_DOCUMENT_FUNCTION_TARGETS+=("$(normalize_document_function_target "$target")")
      done
      ;;
    q|Q|n|N)
      ui_warn "Cancelled."
      return 1
      ;;
    *)
      ui_err "Unknown target selection: $selection"
      return 1
      ;;
  esac

  return 0
}

# Prints document function targets.
print_document_function_targets() {
  local target

  for target in "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"; do
    row " $target"
  done
}

# Runs document functions preview selected.
run_document_functions_preview_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS PREVIEW"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "preview"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  run_document_functions_command "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  pause_if_interactive
}

# Runs document functions diff selected.
run_document_functions_diff_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS DIFF"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "diff"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  run_document_functions_command --diff "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  pause_if_interactive
}

# Runs document functions check selected.
run_document_functions_check_selected() {
  print_header
  row_bold "DOCUMENT FUNCTIONS CHECK"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "check"; then
    print_footer
    pause_if_interactive
    return 0
  fi

  empty_row
  if run_document_functions_command --check "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"; then
    ui_ok "All selected function comments are current."
  else
    ui_warn "Selected files need function comment updates."
  fi

  print_footer
  pause_if_interactive
}

# Runs document comment quality check selected.
run_document_functions_quality_selected() {
  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    print_header
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    pause_if_interactive
    return 1
  fi

  if ! select_document_function_targets "quality-check"; then
    return 0
  fi

  print_header
  row_bold "FUNCTION COMMENT QUALITY"
  empty_row
  if run_document_functions_command --quality --check --summary "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"; then
    ui_ok "Selected function comments are specific enough."
  else
    ui_warn "Selected files have generic comments to review."
  fi
  print_footer
  pause_if_interactive
}

# Runs auto comment flow: check → update → commit.
auto_document_functions() {
  local confirm check_status

  print_header
  row_bold "AUTO COMMENT — PREVIEW"
  empty_row
  row "Repo: $WORK_DIR"
  empty_row
  row "Steps:"
  row " 1. Select target"
  row " 2. Check which files need updates"
  row " 3. Update function comments"
  row " 4. Optionally commit changes"
  empty_row
  print_footer

  printf "%bProceed with auto comment? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { ui_warn "Cancelled."; pause_enter; return 1; }

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    ui_err "document-functions.sh not found: $DOCUMENT_FUNCTIONS"
    pause_enter
    return 1
  fi

  # Select target
  print_header
  row_bold "AUTO COMMENT — SELECT TARGET"
  empty_row
  if ! select_document_function_targets "auto-comment"; then
    print_footer
    pause_enter
    return 0
  fi
  print_footer

  # Check which files need updates
  print_header
  row_bold "AUTO COMMENT — CHECK"
  empty_row
  check_status=0
  run_document_functions_command --check "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}" || check_status=$?

  if [[ $check_status -eq 0 ]]; then
    empty_row
    ui_ok "All function comments are current. Nothing to update."
    print_footer
    pause_enter
    return 0
  fi

  empty_row
  row "Files need function comment updates."
  print_footer

  printf "%bRun update? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { ui_warn "Cancelled."; pause_enter; return 1; }

  # Update
  print_header
  row_bold "AUTO COMMENT — UPDATE"
  empty_row
  run_document_functions_command --write --backup "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"
  empty_row
  ui_ok "Function comments updated."
  print_footer

  # Optionally commit
  if git -C "$WORK_DIR" diff --quiet 2>/dev/null && git -C "$WORK_DIR" diff --cached --quiet 2>/dev/null; then
    ui_warn "No git changes detected after update."
    pause_enter
    return 0
  fi

  printf "%bCommit changes? [y/N]: %b" "$C_TITLE" "$C_RESET"
  read -r confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    printf "%bCommit message [docs: update function comments]: %b" "$C_TITLE" "$C_RESET"
    read -r msg
    msg="${msg:-docs: update function comments}"
    (cd "$WORK_DIR" && git add -A && git commit -m "$msg") || {
      ui_err "Commit failed."
      pause_enter
      return 1
    }
    ui_ok "Committed."
  fi

  pause_enter
}

# Runs document functions update.
run_document_functions_update() {
  local confirm

  print_header
  row_bold "UPDATE FUNCTION COMMENTS"
  empty_row

  if [[ ! -f "$DOCUMENT_FUNCTIONS" ]]; then
    row "document-functions.sh not found:"
    row " $DOCUMENT_FUNCTIONS"
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 1
  fi

  if ! select_document_function_targets "update"; then
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 0
  fi

  empty_row
  row "This will add missing generated function comments in:"
  print_document_function_targets
  empty_row
  row "Backups will be saved under backups/scripts before files are changed."
  empty_row

  printf 'Update comments now? [y/N] '
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    ui_warn "Cancelled."
    print_footer
    if [[ -t 0 ]]; then
      pause_enter
    fi
    return 0
  fi

  empty_row
  run_document_functions_command --write --backup "${DOCUMENT_FUNCTION_ARGS[@]}" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"

  print_footer
  if [[ -t 0 ]]; then
    pause_enter
  fi
}

# Runs Ollama document review (read-only, never writes files).
run_ollama_document_review() {
  local model entered_model

  print_header
  row_bold "OLLAMA DOCUMENT REVIEW"
  empty_row
  row "Review-only: no files will be modified."
  row "Requires local Ollama (ollama serve)."
  row "Default model: ${MQ_OLLAMA_REVIEW_MODEL:-qwen3:4b-instruct}"
  empty_row

  if ! command -v ollama >/dev/null 2>&1; then
    ui_err "Ollama not found. Install or start Ollama first."
    pause_enter
    return 1
  fi

  if [[ ! -f "$OLLAMA_DOCUMENT_REVIEW" ]]; then
    ui_err "Review script missing: $OLLAMA_DOCUMENT_REVIEW"
    pause_enter
    return 1
  fi

  if ! select_document_function_targets "review with Ollama"; then
    return 0
  fi

  empty_row
  row "Targets:"
  print_document_function_targets
  empty_row

  model="${MQ_OLLAMA_REVIEW_MODEL:-qwen3:4b-instruct}"
  printf '%bModel (Enter to keep %s): %b' "${C_TITLE:-}" "$model" "${C_RESET:-}"
  read -r entered_model
  # Ignore single-character input — likely accidental (e.g. "y" as confirmation).
  if [[ "${#entered_model}" -gt 1 ]]; then
    model="$entered_model"
  fi

  empty_row
  row "Running Ollama review — model: $model"
  print_footer

  if [[ -x "$OLLAMA_DOCUMENT_REVIEW" ]]; then
    "$OLLAMA_DOCUMENT_REVIEW" --model "$model" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"
  else
    python3 "$OLLAMA_DOCUMENT_REVIEW" --model "$model" "${SELECTED_DOCUMENT_FUNCTION_TARGETS[@]}"
  fi

  pause_enter
}

# Runs mq-mcp review through mq-agent orchestration.
run_mq_mcp_review() {
  local mode entered_mode scope

  print_header
  row_bold "MQ-MCP REVIEW VIA MQ-AGENT"
  empty_row
  row "Review-only: no files will be modified."
  row "mqlaunch delegates to mq-agent; mq-agent calls mq-mcp."
  row "Default mode: ${MQ_MCP_REVIEW_MODE:-comment}"
  empty_row

  if ! declare -f run_agent_command >/dev/null; then
    local _agent_menu="$BASE_DIR/terminal/menus/mq-agent-menu.sh"
    if [[ -f "$_agent_menu" ]]; then
      # shellcheck disable=SC1090
      source "$_agent_menu"
    fi
  fi
  if ! declare -f run_agent_command >/dev/null; then
    ui_err "mq-agent bridge not loaded."
    pause_enter
    return 1
  fi

  mode="${MQ_MCP_REVIEW_MODE:-comment}"
  printf '%bMode (comment/security/architecture) [%s]: %b' "${C_TITLE:-}" "$mode" "${C_RESET:-}"
  read -r entered_mode
  if [[ "${#entered_mode}" -gt 1 ]]; then
    mode="$entered_mode"
  fi

  scope="diff"

  empty_row
  row "Running mq-agent review $scope $mode"
  print_footer

  run_agent_command review "$mode"

  pause_enter
}

# Runs MQ skills audit.
run_mq_skills_audit() {
  if [[ -x "$MQ_SKILLS" ]]; then
    "$MQ_SKILLS" audit
  else
    python3 "$MQ_SKILLS" audit
  fi
  pause_enter
}

# Runs MQ skills validation.
run_mq_skills_validate() {
  if [[ -x "$MQ_SKILLS" ]]; then
    "$MQ_SKILLS" validate
  else
    python3 "$MQ_SKILLS" validate
  fi
  pause_enter
}

# Runs MQ ecosystem skills validation.
run_mq_skills_ecosystem_validate() {
  if [[ -x "$MQ_SKILLS" ]]; then
    "$MQ_SKILLS" validate --ecosystem
  else
    python3 "$MQ_SKILLS" validate --ecosystem
  fi
  pause_enter
}

# Runs MQ repos summary.
run_mq_repos_summary() {
  if [[ -x "$MQ_REPOS" ]]; then
    "$MQ_REPOS" skills
    printf '\n'
    "$MQ_REPOS" roadmaps
  else
    python3 "$MQ_REPOS" skills
    printf '\n'
    python3 "$MQ_REPOS" roadmaps
  fi
  pause_enter
}

# Runs MQ repos diff summary.
run_mq_repos_diff_summary() {
  if [[ -x "$MQ_REPOS" ]]; then
    "$MQ_REPOS" diff-summary
  else
    python3 "$MQ_REPOS" diff-summary
  fi
  pause_enter
}

# Runs MQ repos status.
run_mq_repos_status() {
  if [[ -x "$MQ_REPOS" ]]; then
    "$MQ_REPOS" status
  else
    python3 "$MQ_REPOS" status
  fi
  pause_enter
}

# Prints document functions menu.
print_document_functions_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  MQ_SURFACE_WIDTH="$width"

  clear_screen
  surface_panel_header "Document Functions" "Docs" "$width" "$panel_color"
  surface_row "PREVIEW" "$width" "$panel_color"
  surface_split_row "1. Preview active areas" "2. Preview selected" "$width" "$panel_color"
  surface_split_row "3. Diff selected" "4. Check selected" "$width" "$panel_color"
  surface_split_row "5. Quality selected" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "UPDATE" "$width" "$panel_color"
  surface_split_row "6. Update selected" "7. Auto comment" "$width" "$panel_color"
  surface_split_row "8. Ollama review" "9. mq-agent review" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Documents functions menu loop.
document_functions_menu_loop() {
  local choice

  while true; do
    print_document_functions_menu
    read_menu_choice "" "docs"
    choice="$REPLY"
    echo

    case "$choice" in
      1) run_document_functions_preview ;;
      2) run_document_functions_preview_selected ;;
      3) run_document_functions_diff_selected ;;
      4) run_document_functions_check_selected ;;
      5) run_document_functions_quality_selected ;;
      6) run_document_functions_update ;;
      7) auto_document_functions ;;
      8) run_ollama_document_review ;;
      9) run_mq_mcp_review ;;
      b|B|x|X|exit) ui_ok "Back."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints menu.
print_tools_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "Tools Menu" "Tools" "$width" "$panel_color"
  surface_row "PLACES" "$width" "$panel_color"
  surface_split_row "1. Run system check" "2. Open repo folder" "$width" "$panel_color"
  surface_split_row "3. Open launchers folder" "4. Open themes folder" "$width" "$panel_color"
  surface_split_row "5. Open menus folder" "6. Open dashboard" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "REFERENCE" "$width" "$panel_color"
  surface_split_row "7. Open terminal guide" "8. Show key paths" "$width" "$panel_color"
  surface_split_row "9. Show git status" "10. Boot Maker" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "WORKBENCH" "$width" "$panel_color"
  surface_split_row "11. Focus Timer" "12. Document functions" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "VERIFY" "$width" "$panel_color"
  surface_split_row "13. Doctor check" "14. Doctor --json" "$width" "$panel_color"
  surface_split_row "15. Selftest" "16. Smoke test" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "ECOSYSTEM" "$width" "$panel_color"
  surface_split_row "17. Skills audit" "18. Skills validate" "$width" "$panel_color"
  surface_split_row "19. Repos summary" "20. Repos diff" "$width" "$panel_color"
  surface_split_row "21. Skills ecosystem" "22. Repos status" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the menu loop.
tools_menu_loop() {
  local choice

  while true; do
    print_tools_menu
    read_menu_choice "" "tools"
    choice="$REPLY"
    echo

    case "$choice" in
      1) run_system_check ;;
      2) open_repo ;;
      3) open_launchers ;;
      4) open_themes ;;
      5) open_menus ;;
      6) open_dashboard ;;
      7) open_guide ;;
      8) show_paths ;;
      9) show_git_status ;;
    10) run_tool_script "BOOT MAKER" "$BASE_DIR/tools/cli/boot-maker.sh" ;;
    11) run_tool_script "FOCUS TIMER" "$BASE_DIR/tools/scripts/focus.sh" ;;
    12) document_functions_menu_loop ;;
    13) run_tool_script "DOCTOR CHECK" "$BASE_DIR/tools/scripts/doctor.sh" ;;
    14)
      if [[ -x "$BASE_DIR/tools/scripts/doctor.sh" || -f "$BASE_DIR/tools/scripts/doctor.sh" ]]; then
        bash "$BASE_DIR/tools/scripts/doctor.sh" --json \
          | (command -v jq >/dev/null 2>&1 && jq . || cat)
        pause_enter
      else
        run_tool_script "DOCTOR JSON" "$BASE_DIR/tools/scripts/doctor.sh" --json
      fi
      ;;
    15)
      if command -v run_self_check >/dev/null 2>&1; then
        run_self_check
      else
        bash "$BASE_DIR/tools/scripts/test-all.sh" 2>/dev/null \
          || ui_warn "test-all.sh not found or failed"
        pause_enter
      fi
      ;;
    16) run_tool_script "SMOKE TEST" "$BASE_DIR/tools/scripts/install-smoke.sh" ;;
    17) run_mq_skills_audit ;;
    18) run_mq_skills_validate ;;
    19) run_mq_repos_summary ;;
    20) run_mq_repos_diff_summary ;;
    21) run_mq_skills_ecosystem_validate ;;
    22) run_mq_repos_status ;;
      b|B|x|X|exit) ui_ok "Exiting."; break ;;
      *) ui_err "Invalid option."; pause_enter ;;
    esac
  done
}

# Prints usage information.
usage() {
  cat <<USAGE
mq-tools-menu.sh - reusable tools menu

Usage:
  mq-tools-menu.sh [command]

Commands:
  menu        Open menu (default)
  check       Run system check
  dashboard   Open dashboard
  guide       Open terminal guide
  paths       Show key paths
  git         Show git status
  docfunc     Open function documentation menu
  docpreview  Preview missing shell function comments
  docwrite    Add/update shell function comments with backups
  skills      Audit local MQ ecosystem skills
  skills-ecosystem
              Validate skills across all known MQ repos
  repos       Summarize local MQ ecosystem repos
  repos-status
              Show branch, upstream and dirty state for known MQ repos
USAGE
}

# Runs the main entry point.
main() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu) tools_menu_loop ;;
    check) run_system_check ;;
    dashboard) open_dashboard ;;
    guide) open_guide ;;
    paths) show_paths ;;
    git) show_git_status ;;
    docfunc|document-functions|docs) document_functions_menu_loop ;;
    docpreview|document-functions-preview) run_document_functions_preview ;;
    docwrite|document-functions-write) run_document_functions_update ;;
    skills|skills-audit) run_mq_skills_audit ;;
    skills-validate) run_mq_skills_validate ;;
    skills-ecosystem|skills-validate-ecosystem) run_mq_skills_ecosystem_validate ;;
    repos|repos-summary) run_mq_repos_summary ;;
    repos-diff|diff-summary) run_mq_repos_diff_summary ;;
    repos-status|status) run_mq_repos_status ;;
    help|-h|--help) usage ;;
    *)
      ui_err "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]] || [[ -z "${ZSH_VERSION:-}" && "${0}" == *mq-tools-menu* ]]; then
  main "${1:-menu}"
fi
