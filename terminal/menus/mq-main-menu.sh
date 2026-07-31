#!/usr/bin/env bash

: "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"

# Checks whether main menu is sourced.
main_menu_is_sourced() {
  if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    [[ ":$ZSH_EVAL_CONTEXT:" == *:file:* ]]
    return
  fi

  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

# Coordinates main menu direct entry behavior.
main_menu_direct_entry() {
  local base_dir launcher
  base_dir="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
  launcher="$base_dir/terminal/launchers/mqlaunch.sh"

  if [[ -x "$launcher" ]]; then
    exec "$launcher" "${1:-menu}"
  elif [[ -f "$launcher" ]]; then
    exec zsh "$launcher" "${1:-menu}"
  fi

  echo "Missing launcher: $launcher" >&2
  exit 1
}

# Prints main menu.
print_main_menu() {
  print_header
  render_main_menu_panel
  render_command_surface
}

# Formats action word for the compact terminal surface.
surface_action_word() {
  local index="$1"
  case $(( index % 10 )) in
    0) printf "routing" ;;
    1) printf "loading" ;;
    2) printf "opening" ;;
    3) printf "mapping" ;;
    4) printf "syncing" ;;
    5) printf "priming" ;;
    6) printf "launching" ;;
    7) printf "resolving" ;;
    8) printf "decoding" ;;
    *) printf "activating" ;;
  esac
}

# Gives selected submenu actions a stable, searchable terminal label.
surface_choice_summary() {
  local context="$1"
  local selected="$2"

  case "$context:$selected" in
    mqobsidian:12|mqobsidian:triage)
      printf "option 12: learning inbox triage"
      ;;
    mqobsidian:13|mqobsidian:views|mqobsidian:regenerate)
      printf "option 13: regenerate memory views"
      ;;
  esac
}

# Formats accept scramble for the compact terminal surface.
surface_accept_scramble() {
  local color="$1"
  local selected="$2"
  local summary="${3:-}"
  local frame start word
  start=$(( RANDOM % 10 ))

  for frame in 1 2 3 4 5 6; do
    word="$(surface_action_word $(( start + frame )))"
    printf "\r\033[2K%b>> %-10s %s%b" "$color" "$word" "$selected" "$C_RESET"
    sleep 0.025
  done

  if [[ -n "$summary" ]]; then
    printf "\r\033[2K%b>> %s%b" "$C_OK" "$summary" "$C_RESET"
  else
    word="$(surface_action_word $(( start + 7 )))"
    printf "\r\033[2K%b>> %-10s %s%b" "$C_OK" "$word" "$selected" "$C_RESET"
  fi
  sleep 0.04
}

# Renders the main menu panel view for terminal output.
render_main_menu_panel() {
  local width panel_color host user git_state mode
  width="$(surface_terminal_width)"

  if [[ -t 1 ]]; then
    panel_color=$'\033[0;37m'
  else
    panel_color=""
  fi

  host="$(hostname -s 2>/dev/null || echo unknown)"
  user="${USER:-unknown}"
  git_state="$(surface_git_state)"
  mode="Main"

  surface_top "Main Menu" "$width" "$panel_color"
  surface_row "Host: $host   User: $user   Mode: $mode   Git: $git_state" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "CORE" "$width" "$panel_color"
  surface_split_row "1. Workflows" "2. System" "$width" "$panel_color"
  surface_split_row "3. Git" "4. Release" "$width" "$panel_color"
  surface_split_row "5. Dev" "6. Repos" "$width" "$panel_color"
  surface_split_row "7. MQ HAL" "8. Agent" "$width" "$panel_color"
  surface_split_row "9. MQ Obsidian" "10. Recommendations" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "QUICK ACCESS" "$width" "$panel_color"
  surface_split_row "p. Performance" "n. Network" "$width" "$panel_color"
  surface_split_row "h. Health Check" "z. Restart mqlaunch" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "DISCOVER" "$width" "$panel_color"
  surface_split_row "/  Palette" "?  Help index" "$width" "$panel_color"
  surface_split_row "<command>  Run mqlaunch" "!<command>  Run shell" "$width" "$panel_color"
  surface_split_row "more: mqlaunch help" "x. Exit" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "Ready: choose number, type command, / palette, ? help" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Renders the command surface view for terminal output.
render_command_surface() {
  local USER_NAME HOST_NAME TIME SURFACE_COLOR width git_state tip activity system_state
  USER_NAME="${USER:-$(whoami)}"
  HOST_NAME="$(hostname -s)"
  TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  width="$(surface_terminal_width)"
  MQ_SURFACE_WIDTH="$width"
  git_state="$(surface_git_state)"
  system_state="System: Stable"
  activity="Activity: Ready"

  if [[ "$git_state" == Dirty* ]]; then
    tip="Review git changes"
  else
    tip="Use / for palette"
  fi

  if [[ -t 1 ]]; then
    SURFACE_COLOR=$'\033[0;37m'
  else
    SURFACE_COLOR=""
  fi

  surface_top "Command Surface" "$width" "$SURFACE_COLOR"
  surface_split_row "Mode: Interactive" "Git: $git_state" "$width" "$SURFACE_COLOR"
  surface_split_row "Host: ${HOST_NAME}" "User: ${USER_NAME}" "$width" "$SURFACE_COLOR"
  surface_split_row "Time: ${TIME}" "Tip: $tip" "$width" "$SURFACE_COLOR"
  surface_split_row "$system_state" "$activity" "$width" "$SURFACE_COLOR"
  surface_bottom "$width" "$SURFACE_COLOR"
}

# Opens the command palette when available, otherwise falls back to help.
open_command_palette_or_help() {
  if command -v run_command_palette >/dev/null 2>&1; then
    run_command_palette
  elif command -v open_help_center_menu >/dev/null 2>&1; then
    open_help_center_menu
  elif command -v show_command_index >/dev/null 2>&1; then
    show_command_index
  else
    printf 'Command palette not available. Run: mqlaunch help\n' >&2
    pause_enter
    return 1
  fi
}

# Opens the help center when available, otherwise falls back to command help.
open_help_or_index() {
  if command -v open_help_center_menu >/dev/null 2>&1; then
    open_help_center_menu
  elif command -v show_command_index >/dev/null 2>&1; then
    show_command_index
  elif command -v show_help >/dev/null 2>&1; then
    show_help
  else
    printf 'Help is not available. Run: mqlaunch help\n' >&2
    pause_enter
    return 1
  fi
}

# Routes the main menu selection to the matching action.
handle_main_menu_choice() {
  local choice="$1"
  local original normalized

  original="$choice"
  normalized="$(printf '%s' "$choice" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"

  case "$normalized" in
    # CORE — stable numbering. Do not renumber without migration notes.
    1) run_mqworkflows ;;
    2) open_system_menu ;;
    3) open_git_menu ;;
    4) open_release_menu ;;
    5) open_dev_menu ;;
    6) "$BASE_DIR/bin/mqlaunch" hub ;;
    7)
      # shellcheck source=/dev/null
      source "$BASE_DIR/terminal/bridges/hal-bridge.sh"
      mq_hal_main
      ;;
    8) open_agent_menu ;;
    9) mq_obsidian_menu_main ;;
    10) recommendations_menu_main ;;

    # QUICK ACCESS
    p) open_performance_menu ;;
    n) show_network_info ;;
    h) system_check ;;
    z) restart_mqlaunch ;;
    /|/.|/\ palette|/.\ palette) open_command_palette_or_help ;;
    \?|\?.|\?\ help|\?.\ help\ index) open_help_or_index ;;

    # Kept for muscle memory — not shown in the front panel.
    r) "$BASE_DIR/bin/mqlaunch" repl ;;
    a)
      "$BASE_DIR/tools/scripts/hal-terminal-guide.sh"
      if [[ -f "$HOME/.hal_nav" ]]; then
        local _hal_target
        _hal_target="$(cat "$HOME/.hal_nav")"
        rm -f "$HOME/.hal_nav"
        if [[ -d "$_hal_target" ]]; then
          cd "$_hal_target" || true
          printf 'HAL: navigated to %s\n' "$_hal_target"
          sleep 1
        fi
      fi
      ;;
    g) open_agent_menu ;;

    # EXIT
    x)
      echo "Exiting ${APP_TITLE}..."
      exit 0
      ;;

    *)
      if handle_main_prompt_command "$normalized" "$original"; then
        return 0
      fi
      ;;
  esac
}

# Routes main prompt command input to the matching action.
handle_main_prompt_command() {
  local normalized="$1"
  local original="$2"

  [[ -z "${normalized// }" ]] && return 0

  if [[ "$original" == "!"* ]]; then
    local shell_command
    shell_command="$(printf '%s' "${original#!}" | sed 's/^[[:space:]]*//')"

    if [[ -z "$shell_command" ]]; then
      echo "ERROR: shell command required after !"
      pause_enter
      return 2
    fi

    run_main_shell_command "$shell_command"
    return 0
  fi

  case "$normalized" in
    workflows|workflow|wf) run_mqworkflows; return 0 ;;
    system|sys) open_system_menu; return 0 ;;
    git|git-menu|gitmenu) open_git_menu; return 0 ;;
    release|rel) open_release_menu; return 0 ;;
    dev) open_dev_menu; return 0 ;;
    palette|find|/|/.|/\ palette|/.\ palette) open_command_palette_or_help; return 0 ;;
    help|h|\?|\?.|\?\ help|\?.\ help\ index|commands|index) open_help_or_index; return 0 ;;
    perf|performance) open_performance_menu; return 0 ;;
    net|network|ip) show_network_info; return 0 ;;
    check|health|system\ check) system_check; return 0 ;;
    "hal "*)
      local _hal_args="${original#hal }"
      # shellcheck source=/dev/null
      source "$BASE_DIR/terminal/bridges/hal-bridge.sh"
      mq_hal_main "$_hal_args"
      pause_enter
      return 0
      ;;
    hal)
      # shellcheck source=/dev/null
      source "$BASE_DIR/terminal/bridges/hal-bridge.sh"
      mq_hal_main
      pause_enter
      return 0
      ;;
    apps) "$BASE_DIR/tools/scripts/hal-terminal-guide.sh"; return 0 ;;
    applications) open_applications_folder; return 0 ;;
    repl|r) "$BASE_DIR/bin/mqlaunch" repl; return 0 ;;
    restart|reload|relaunch|z) restart_mqlaunch; return 0 ;;
    agent|mq-agent|g) open_agent_menu; return 0 ;;
    obsidian|mqobsidian|memory-menu|mq-memory) mq_obsidian_menu_main; return 0 ;;
    recommendations|recommend|rec) recommendations_menu_main; return 0 ;;
    agent\ score|score) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent score .); pause_enter; return 0 ;;
    agent\ signal|signal) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent signal .); pause_enter; return 0 ;;
    agent\ audit|audit) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent audit .); pause_enter; return 0 ;;
    agent\ doctor|doctor) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent doctor); pause_enter; return 0 ;;
    agent\ release-check|release-check) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent release-check); pause_enter; return 0 ;;
    agent\ mcp-status|mcp-status) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent mcp status); pause_enter; return 0 ;;
    agent\ mcp-tools|mcp-tools) (cd "$HOME/mq-agent" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$HOME/mq-agent" run mq-agent mcp tools); pause_enter; return 0 ;;
    mcp-start) _mcp_start; pause_enter; return 0 ;;
    mcp-stop) _mcp_stop; pause_enter; return 0 ;;
    docfunc|document-functions|document\ functions|docs|docs-preview) "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docfunc; return 0 ;;
    docwrite|document-functions-write|update-comments|update\ comments) "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docwrite; return 0 ;;
    workspace|snapshots|workspace\ snapshots) run_mqworkflows workspace; return 0 ;;
    clear|cls) clear; return 0 ;;
    version|ver) show_version_info || true; return 0 ;;
    notes|changelog|release\ notes) show_release_notes || true; return 0 ;;
    about|status|dashboard) show_about_dashboard || true; return 0 ;;
    bundle|debug|debug-bundle|support) run_debug_bundle || true; return 0 ;;
    repo|base|macos-scripts) open_base_dir; return 0 ;;
    guide|terminal-guide) open_terminal_guide; return 0 ;;
    ask\ *|/ask\ *)
      local _ask_args="${original#* }"
      "$BASE_DIR/tools/scripts/ask.sh" "$_ask_args"
      pause_enter
      return 0
      ;;
    ask|/ask)
      "$BASE_DIR/tools/scripts/ask.sh"
      pause_enter
      return 0
      ;;
    chat|/chat)
      "$BASE_DIR/tools/scripts/chat.sh"
      return 0
      ;;
    skills|skill|skills\ audit)
      "$BASE_DIR/tools/scripts/mq-skills.py" audit
      pause_enter
      return 0
      ;;
    skills\ validate|skill\ validate)
      "$BASE_DIR/tools/scripts/mq-skills.py" validate
      pause_enter
      return 0
      ;;
    skills\ ecosystem|skill\ ecosystem|skills\ validate\ ecosystem)
      "$BASE_DIR/tools/scripts/mq-skills.py" validate --ecosystem
      pause_enter
      return 0
      ;;
    repos\ list|repo\ list)
      "$BASE_DIR/tools/scripts/mq-repos.py" list
      pause_enter
      return 0
      ;;
    repos\ status|repo\ status)
      "$BASE_DIR/tools/scripts/mq-repos.py" status
      pause_enter
      return 0
      ;;
    repos\ diff|repos\ diff-summary|repo\ diff-summary)
      "$BASE_DIR/tools/scripts/mq-repos.py" diff-summary
      pause_enter
      return 0
      ;;
  esac

  if command -v dispatch_cli_command >/dev/null 2>&1; then
    # zsh-style splitting is intentional when this menu is sourced by mqlaunch.
    # shellcheck disable=SC2086
    if dispatch_cli_command ${=normalized}; then
      return 0
    fi
  fi

  if command -v print_unknown_command_error >/dev/null 2>&1; then
    print_unknown_command_error "$original"
  else
    printf 'ERROR: Unknown command: %s\n' "$original" >&2
    printf 'Run: mqlaunch help\n' >&2
  fi

  pause_enter
  return 127
}

# Runs main shell command. Shell execution is explicit: prefix input with !.
run_main_shell_command() {
  local command_line="$1"
  local shell_bin="${SHELL:-/bin/zsh}"

  echo
  printf "%b[shell]%b %s\n" "$C_INFO" "$C_RESET" "$command_line"
  echo
  "$shell_bin" -lc "$command_line"
  pause_enter
}

# Reads main choice from user input or stdin.
read_main_choice() {
  local label="${1:-mqlaunch}"
  local prompt_line prompt_hint prompt_color prompt_width prompt_text summary
  prompt_width="${MQ_SURFACE_WIDTH:-$(surface_terminal_width)}"
  prompt_line="$(repeat_char "$prompt_width" "─")"
  prompt_hint=">> option, command, / palette, ? help, !shell, x exit"
  prompt_text="${label} > "

  if [[ -t 1 ]]; then
    prompt_color=$'\033[0;37m'
  else
    prompt_color=""
  fi

  if [[ -t 0 && -t 1 ]]; then
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b\n" "$C_TITLE" "$prompt_text" "$C_RESET"
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b\n" "$C_OK" "$prompt_hint" "$C_RESET"
    printf "\033[3A\r\033[2K%b%s%b" "$C_TITLE" "$prompt_text" "$C_RESET"
    if ! IFS= read -r choice; then
      printf "\033[2B\r"
      return 1
    fi
    printf "\033[2B\r"
  else
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b" "$C_TITLE" "$prompt_text" "$C_RESET"
    if ! IFS= read -r choice; then
      return 1
    fi
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b\n" "$C_OK" "$prompt_hint" "$C_RESET"
  fi

  summary="$(surface_choice_summary "$label" "${choice:-menu}")"
  if [[ -n "$choice" ]]; then
    surface_accept_scramble "$C_WARN" "$choice" "$summary"
    printf "\n"
  fi
}

# Coordinates main loop behavior.
main_loop() {
  local choice

  while true; do
    print_main_menu
    read_main_choice || return
    echo
    handle_main_menu_choice "$choice"
  done
}

if ! main_menu_is_sourced; then
  main_menu_direct_entry "$@"
fi
