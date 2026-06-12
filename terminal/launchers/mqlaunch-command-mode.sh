#!/usr/bin/env bash

# Normalizes cli word.
normalize_cli_word() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

# Returns true when any cli arg requests machine-readable JSON output.
has_json_flag() {
  local arg
  for arg in "$@"; do
    [[ "$arg" == "--json" ]] && return 0
  done
  return 1
}

# AI prompt helpers
BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
AI_PROMPTS="$BASE_DIR/terminal/ai-prompts/mq-ai-prompts.sh"
# shellcheck disable=SC1090
[[ -f "$AI_PROMPTS" ]] && source "$AI_PROMPTS"

# Prints command help.
print_command_help() {
  local topic="${1:-}"

  case "$topic" in
    system)
      cat <<'HELP'
mqlaunch system
mqlaunch system perf
mqlaunch system network
mqlaunch system check
mqlaunch system self-check
mqlaunch system debug
mqlaunch system repo
mqlaunch system browser
mqlaunch system time
HELP
      ;;
    release)
      cat <<'HELP'
mqlaunch release
mqlaunch release notes
mqlaunch release version
HELP
      ;;
    dev)
      cat <<'HELP'
mqlaunch dev
mqlaunch dev ai
mqlaunch dev tools
HELP
      ;;
    help)
      cat <<'HELP'
mqlaunch help
mqlaunch help index
mqlaunch help about
mqlaunch help version
mqlaunch help notes
mqlaunch help repo
mqlaunch help browser
HELP
      ;;
    git)
      cat <<'HELP'
mqlaunch git
HELP
      ;;
    *)
      cat <<'HELP'
Usage:
  mqlaunch
  mqlaunch demo
  mqlaunch workflows
  mqlaunch system
  mqlaunch git
  mqlaunch release
  mqlaunch dev
  mqlaunch help

Quick commands:
  mqlaunch demo
  mqlaunch perf
  mqlaunch network
  mqlaunch check
  mqlaunch self-check
  mqlaunch debug
  mqlaunch hal
  mqlaunch theme
  mqlaunch theme-macos
  mqlaunch review
  mqlaunch architecture
  mqlaunch risk-review
  mqlaunch repo-health
  mqlaunch mcp-status
  mqlaunch ui
  mqlaunch ask "your question"
  mqlaunch srm ask "your question"
  mqlaunch agent
  mqlaunch agent doctor
  mqlaunch agent score .
  mqlaunch agent audit .
  mqlaunch agent release-check --dry-run
  mqlaunch agent mcp-status
  mqlaunch agent mcp-tools
  mqlaunch skills audit
  mqlaunch skills validate
  mqlaunch skills validate --ecosystem
  mqlaunch repos list
  mqlaunch repos status
  mqlaunch repos diff-summary
  mqlaunch release-check
  mqlaunch selftest
  mqlaunch version
  mqlaunch notes
  mqlaunch about
  mqlaunch index
  mqlaunch docfunc
  mqlaunch docwrite
  mqlaunch workspace
  mqlaunch workspace save
  mqlaunch workspace restore
  mqlaunch hal
  mqlaunch hal "open Google Chrome"

Subcommands:
  mqlaunch system perf
  mqlaunch system network
  mqlaunch system check
  mqlaunch system self-check
  mqlaunch system debug
  mqlaunch system repo
  mqlaunch system browser
  mqlaunch system time

  mqlaunch release notes
  mqlaunch release version

  mqlaunch help index
  mqlaunch help about
  mqlaunch help version
  mqlaunch help notes
  mqlaunch help repo
  mqlaunch help browser

  mqlaunch dev ai
  mqlaunch dev tools

Compatibility routes still work:
  mqlaunch login menu
  mqlaunch shortcuts list
  mqlaunch palette
HELP
      ;;
  esac
}

# Routes cli command to the matching command handler.
dispatch_cli_command() {
  local area sub
  area="$(normalize_cli_word "${1:-}")"
  sub="$(normalize_cli_word "${2:-}")"

  case "$area" in
    ""|menu)
      return 1
      ;;

    workflows|workflow)
      if [[ -n "$sub" && "$sub" != "menu" ]]; then
        run_mqworkflows "$sub"
      else
        run_mqworkflows
      fi
      return 0
      ;;

    workspace|snapshots)
      case "$sub" in
        ""|menu)
          run_mqworkflows workspace
          ;;
        save)
          run_mqworkflows save
          ;;
        list)
          "$BASE_DIR/automation/workflows/workspace.sh" list
          ;;
        latest|show)
          "$BASE_DIR/automation/workflows/workspace.sh" show "${3:-latest}"
          ;;
        restore)
          "$BASE_DIR/automation/workflows/workspace.sh" restore "${3:-latest}"
          ;;
        *)
          "$BASE_DIR/automation/workflows/workspace.sh" "$sub" "${3:-}"
          ;;
      esac
      return 0
      ;;

    demo)
      run_demo_mode
      return 0
      ;;

    review|/review)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command review "$@"
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    architecture|/architecture)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command architecture "$@"
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    risk-review|/risk-review)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command risk-review "$@"
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    repo-health|/repo-health)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command repo-health "$@"
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    mcp-status|/mcp-status)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command mcp-status "$@"
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    ui|/ui)
      if declare -f mq_ai_prompt_ui >/dev/null; then
        mq_ai_prompt_ui
      else
        echo "Missing helper: mq_ai_prompt_ui"
        echo "Expected: $AI_PROMPTS"
      fi
      pause_enter
      return 0
      ;;

    ask|/ask)
      shift
      "$BASE_DIR/tools/scripts/ask.sh" "$@"
      return 0
      ;;

    srm|memory|repo-memory)
      shift
      "$BASE_DIR/tools/scripts/srm.sh" "$@"
      return 0
      ;;

    skills|skill)
      shift
      "$BASE_DIR/tools/scripts/mq-skills.py" "$@"
      [[ "${1:-}" != "--json" ]] && pause_enter
      return 0
      ;;

    repos)
      shift
      case "${1:-}" in
        ""|menu|hub)
          "$BASE_DIR/bin/mqlaunch" hub
          ;;
        list|roadmaps|skills|status|diff-summary)
          "$BASE_DIR/tools/scripts/mq-repos.py" "$@"
          pause_enter
          ;;
        *)
          "$BASE_DIR/tools/scripts/mq-repos.py" "$@"
          pause_enter
          ;;
      esac
      return 0
      ;;

    fix|/fix)
      shift
      "$BASE_DIR/tools/scripts/fix.sh" "$@"
      return 0
      ;;

    chat|/chat)
      "$BASE_DIR/tools/scripts/chat.sh"
      return 0
      ;;

    release-check|/release-check|check-release)
      "$BASE_DIR/terminal/release/mq-release-check.sh" "${@:2}"
      pause_enter
      return 0
      ;;

    review-brain|/review-brain)
      if ! declare -f _run_agent >/dev/null; then
        echo "ERROR: mq-agent-menu not loaded" >&2; return 1
      fi
      local _rb_path="${2:-.}"
      _run_agent review repo "$_rb_path" --brain
      pause_enter
      return 0
      ;;

    signal-brain|/signal-brain)
      if ! declare -f _run_agent >/dev/null; then
        echo "ERROR: mq-agent-menu not loaded" >&2; return 1
      fi
      local _sb_path="${2:-.}"
      _run_agent signal --brain "$_sb_path"
      pause_enter
      return 0
      ;;

    learn-promote|/learn-promote|promote-pattern)
      if ! declare -f _run_agent >/dev/null; then
        echo "ERROR: mq-agent-menu not loaded" >&2; return 1
      fi
      local _slug="${2:-}"
      if [[ -z "$_slug" ]]; then
        echo "Usage: mqlaunch learn-promote <slug>" >&2
        pause_enter
        return 1
      fi
      _run_agent learn promote "$_slug" --approve
      pause_enter
      return 0
      ;;

    selftest|/selftest|test-all)
      "$BASE_DIR/tools/scripts/test-all.sh"
      pause_enter
      return 0
      ;;

    doctor|/doctor)
      "$BASE_DIR/tools/scripts/doctor.sh" "${@:2}"
      [[ "${2:-}" != "--json" && -z "${MQ_NO_TUI:-}" ]] && pause_enter
      return 0
      ;;

    scan|/scan)
      "$BASE_DIR/tools/scripts/scan.sh"
      pause_enter
      return 0
      ;;

    atlas|/atlas)
      shift
      mq_ai_run_atlas "$@"
      return 0
      ;;

    system)
      case "$sub" in
        ""|menu)
          open_system_menu
          ;;
        perf|performance)
          open_performance_menu
          ;;
        net|network)
          show_network_info
          ;;
        doctor)
      "$BASE_DIR/tools/scripts/doctor.sh" "${@:3}"
      ;;
    check|health)
          system_check
          ;;
        self-check|selfcheck)
          run_self_check || true
          ;;
        debug|debug-bundle|bundle)
          run_debug_bundle || true
          ;;
        repo|folder)
          open_base_dir
          ;;
        browser|web)
          open_repo_browser
          ;;
        time|date)
          show_date_time
          ;;
        *)
          print_command_help "system"
          return 2
          ;;
      esac
      return 0
      ;;

    git)
      case "$sub" in
        ""|menu)
          open_git_menu "${3:-}"
          ;;
        *)
          open_git_menu "${2:-}"
          ;;
      esac
      return 0
      ;;

    release)
      case "$sub" in
        ""|menu)
          open_release_menu
          ;;
        notes|release-notes)
          show_release_notes || true
          ;;
        version)
          show_version_info || true
          ;;
        status)
          "$BASE_DIR/terminal/menus/mq-release-menu.sh" status
          ;;
        *)
          print_command_help "release"
          return 2
          ;;
      esac
      return 0
      ;;

    dev)
      case "$sub" in
        ""|menu)
          open_dev_menu
          ;;
        ai)
          ai_menu_loop
          ;;
        tools)
          open_tools_menu
          ;;
        current)
          open_dev_menu
          ;;
        *)
          print_command_help "dev"
          return 2
          ;;
      esac
      return 0
      ;;

    help|-h|--help)
      case "$sub" in
        "")
          show_help
          ;;
        menu)
          open_help_center_menu
          ;;
        index|commands)
          show_command_index || true
          ;;
        about|status)
          show_about_dashboard || true
          ;;
        version)
          show_version_info || true
          ;;
        notes|release-notes)
          show_release_notes || true
          ;;
        repo|folder)
          open_base_dir
          ;;
        browser|web)
          open_repo_browser
          ;;
        *)
          print_command_help "help"
          return 2
          ;;
      esac
      return 0
      ;;

    perf|performance)
      open_performance_menu
      return 0
      ;;

    net|network)
      show_network_info
      return 0
      ;;

    check|health)
      system_check
      return 0
      ;;

    self-check|selfcheck)
      run_self_check || true
      return 0
      ;;

    debug|bundle|debug-bundle|support)
      run_debug_bundle || true
      return 0
      ;;

    apps|guide-ai|terminal-guide-ai)
      if [[ -n "${2:-}" ]]; then
        shift
        "$BASE_DIR/tools/scripts/hal-terminal-guide.sh" ask "$@"
      else
        "$BASE_DIR/tools/scripts/hal-terminal-guide.sh"
      fi
      return 0
      ;;

    docfunc|document-functions)
      MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docfunc
      return 0
      ;;

    docwrite|document-functions-write|update-comments)
      MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docwrite
      return 0
      ;;

    version)
      show_version_info || true
      return 0
      ;;

    notes|release-notes)
      show_release_notes || true
      return 0
      ;;

    about|status)
      show_about_dashboard || true
      return 0
      ;;

    index|commands)
      show_command_index || true
      return 0
      ;;

    hal)
      shift
      if declare -f mq_hal_run >/dev/null; then
        mq_hal_run "$@"
      else
        echo "ERROR: mq-hal bridge not loaded" >&2
        return 1
      fi
      has_json_flag "$@" || pause_enter
      return 0
      ;;

    agent|mq-agent)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command "$@"
        return $?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      ;;

    mqlaunch)
      # Strip "mqlaunch" prefix typed from inside the menu and re-dispatch.
      shift
      if [[ $# -gt 0 ]]; then
        dispatch_cli_command "$@"
      fi
      return 0
      ;;

    10|github|hub|ghub|gh-search|gh-pick)
      if declare -f run_github_repo_picker >/dev/null; then
        run_github_repo_picker
      else
        "$BASE_DIR/bin/mqlaunch" hub
      fi
      return 0
      ;;

    git-log|gitlog|glog)
      declare -f fzf_git_log >/dev/null && fzf_git_log || "$BASE_DIR/bin/mqlaunch" git-log
      return 0
      ;;

    git-branch|branch-switch|gbranch)
      declare -f fzf_git_branch >/dev/null && fzf_git_branch || "$BASE_DIR/bin/mqlaunch" git-branch
      return 0
      ;;

    kill-process|killp|pkill-fzf)
      declare -f fzf_kill_process >/dev/null && fzf_kill_process || "$BASE_DIR/bin/mqlaunch" kill-process
      return 0
      ;;

    kill-port|killport|port-kill)
      declare -f fzf_kill_port >/dev/null && fzf_kill_port || "$BASE_DIR/bin/mqlaunch" kill-port
      return 0
      ;;

    snippets|snippet|scripts)
      declare -f fzf_run_snippet >/dev/null && fzf_run_snippet || "$BASE_DIR/bin/mqlaunch" snippets
      return 0
      ;;

    recent|recent-files|rf)
      declare -f fzf_recent_files >/dev/null && fzf_recent_files || "$BASE_DIR/bin/mqlaunch" recent
      return 0
      ;;

    brain)
      if declare -f mq_brain_run >/dev/null; then
        mq_brain_run "${@:2}"
      else
        echo "ERROR: brain-bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    note|sessions|decisions|reviews|learn|verified|systems|memory)
      if declare -f mq_brain_run >/dev/null; then
        mq_brain_run "$area" "${@:2}"
      else
        echo "ERROR: brain-bridge not loaded" >&2
        return 1
      fi
      return 0
      ;;

    b2tui|b2)
      PYTHONPATH="${BASE_DIR}" python3 -m mqlaunch.b2_tui.main "${@:2}"
      return 0
      ;;

    *)
      if declare -f mq_ai_prompt_ask >/dev/null; then
        echo "Unknown command → routing to /ask"
        mq_ai_prompt_ask "$@"
        return 0
      fi
      return 1
      ;;
  esac
}
