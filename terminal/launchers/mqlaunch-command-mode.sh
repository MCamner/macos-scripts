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

# Escapes a value for use inside a JSON double-quoted string.
json_escape_value() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

# Prints the machine-readable form of the about/status dashboard.
#
# Output contract (docs/RUNTIME_AUTHORITY.md): stdout is exactly one JSON
# document — no banner, no ANSI, no prose, no prompt. Diagnostics belong on
# stderr.
#
# This deliberately does not reuse show_about_dashboard's smoke-test field: that
# renderer shells out to the full test suite, so a machine-readable status call
# would cost a complete test run — and it recurses when the suite itself runs
# this path. Smoke status stays where it belongs, in test-all.sh and doctor.
print_status_json() {
  local version="unknown" repo_state="unknown" latest_bundle="none"
  local version_file="$BASE_DIR/VERSION"
  local bundle_dir="$BASE_DIR/backups/debug-bundles"

  [[ -f "$version_file" ]] && version="$(head -n 1 "$version_file")"

  # "dirty" must mean a dirty worktree, not "git is missing" or "not a repo" —
  # a machine consumer cannot tell those apart from the dashboard's wording.
  if command -v git >/dev/null 2>&1 &&
    git -C "$BASE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$BASE_DIR" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
      repo_state="clean"
    else
      repo_state="dirty"
    fi
  fi

  if [[ -d "$bundle_dir" ]]; then
    latest_bundle="$(ls -1t "$bundle_dir" 2>/dev/null | head -n 1)"
    [[ -z "$latest_bundle" ]] && latest_bundle="none"
  fi

  printf '{"project":"macos-scripts","version":"%s","release_stage":"baseline","repo_state":"%s","latest_bundle":"%s"}\n' \
    "$(json_escape_value "$version")" \
    "$repo_state" \
    "$(json_escape_value "$latest_bundle")"
}

# Prints a side-effect-free usage error for an unknown top-level command.
nearest_cli_command() {
  local unknown="${1:-}"

  printf '%s\n' \
    about agent architecture ask brain bundle check commands demo dev doctor \
    excalidraw fix flow ghost git guard hal help index learn mc mcp-status \
    memory network notes obsidian palette perf pulse release release-check \
    repo-health repos review risk-review scan selftest skills srm stack system \
    theme tools ui version workflows workspace | awk -v target="$unknown" '
      function distance(a, b, d, i, j, cost, deletion, insertion, substitution) {
        delete d
        for (i = 0; i <= length(a); i++) d[i, 0] = i
        for (j = 0; j <= length(b); j++) d[0, j] = j
        for (i = 1; i <= length(a); i++) {
          for (j = 1; j <= length(b); j++) {
            cost = (substr(a, i, 1) == substr(b, j, 1)) ? 0 : 1
            deletion = d[i - 1, j] + 1
            insertion = d[i, j - 1] + 1
            substitution = d[i - 1, j - 1] + cost
            d[i, j] = deletion < insertion ? deletion : insertion
            if (substitution < d[i, j]) d[i, j] = substitution
          }
        }
        return d[length(a), length(b)]
      }
      {
        score = distance(target, $0)
        if (best == "" || score < best_score) {
          best = $0
          best_score = score
        }
      }
      END { print best }
    '
}

print_unknown_command_error() {
  local command_name="${1:-}"
  local nearest
  nearest="$(nearest_cli_command "$command_name")"

  printf 'ERROR: Unknown command: %s\n' "$command_name" >&2
  [[ -n "$nearest" ]] && printf 'Did you mean: mqlaunch %s\n' "$nearest" >&2
  printf 'For AI help, run explicitly: mqlaunch ask "What does %s mean?"\n' \
    "$command_name" >&2
}

# Prints dependency-light help for public mqlaunch namespaces.
print_namespace_help() {
  case "${1:-}" in
    agent)
      cat <<'HELP'
Usage: mqlaunch agent <command> [args]

Commands: doctor, score, audit, release-check, review, architecture,
          risk-review, repo-health, stack, mcp-status, mcp-tools, flow
HELP
      ;;
    hal)
      cat <<'HELP'
Usage: mqlaunch hal <command> [args]

Commands: brief, release-brief, context, audit, doctor, fix-doctor,
          timeline, session, last, remember, repos, raw
HELP
      ;;
    obsidian)
      cat <<'HELP'
Usage: mqlaunch obsidian <command> [args]

Commands: status, inbox, views, promote
HELP
      ;;
    repos)
      cat <<'HELP'
Usage: mqlaunch repos <command> [args]

Commands: list, status, roadmaps, skills, wiki-status, diff-summary
HELP
      ;;
    skills)
      cat <<'HELP'
Usage: mqlaunch skills <command> [args]

Commands: audit, validate, new
HELP
      ;;
    srm)
      cat <<'HELP'
Usage: mqlaunch srm <command> [args]

Commands: ask, search, inspect, cochange, review-status,
          promote-from-review, resolve-supersede
HELP
      ;;
    stack)
      cat <<'HELP'
Usage: mqlaunch stack <command> [args]

Commands: status, contract-check, truth-export
HELP
      ;;
    *)
      return 2
      ;;
  esac
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
  mqlaunch excalidraw
  mqlaunch perf
  mqlaunch network
  mqlaunch check
  mqlaunch self-check
  mqlaunch debug
  mqlaunch markdownlint
  mqlaunch markdownlint --fix ROADMAP.md
  mqlaunch hal
  mqlaunch theme
  mqlaunch theme-macos
  mqlaunch review
  mqlaunch architecture
  mqlaunch risk-review
  mqlaunch repo-health
  mqlaunch stack status
  mqlaunch mcp-status
  mqlaunch flow
  mqlaunch flow run repo-preflight ~/macos-scripts
  mqlaunch ui
  mqlaunch ask "your question"
  mqlaunch srm ask "your question"
  mqlaunch agent
  mqlaunch obsidian
  mqlaunch obsidian status
  mqlaunch obsidian inbox
  mqlaunch obsidian views
  mqlaunch obsidian promote --dry-run
  mqlaunch mqobsidian
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
  mqlaunch repos wiki-status
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
  local area sub namespace command_status
  area="$(normalize_cli_word "${1:-}")"
  sub="$(normalize_cli_word "${2:-}")"

  namespace="$area"
  case "$namespace" in
    mq-agent) namespace="agent" ;;
    mqobsidian|memory-menu|mq-memory) namespace="obsidian" ;;
    skill) namespace="skills" ;;
    memory|repo-memory) namespace="srm" ;;
  esac

  case "$namespace" in
    agent|hal|obsidian|repos|skills|srm|stack)
      case "$sub" in
        -h|--help|help)
          if [[ $# -ne 2 ]]; then
            printf 'ERROR: mqlaunch %s help accepts no additional arguments\n' \
              "$namespace" >&2
            return 2
          fi
          print_namespace_help "$namespace"
          return 0
          ;;
      esac
      ;;
  esac

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
      command_status=$?
      return "$command_status"
      ;;

    demo)
      run_demo_mode
      return 0
      ;;

    excalidraw|draw)
      "$BASE_DIR/tools/scripts/excalidraw.sh"
      return $?
      ;;

    review|/review)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command review "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    architecture|/architecture)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command architecture "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    risk-review|/risk-review)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command risk-review "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    repo-health|/repo-health)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command repo-health "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    stack|/stack)
      shift
      if declare -f run_agent_command >/dev/null; then
        if [[ $# -eq 0 ]]; then
          run_agent_command stack status
        else
          run_agent_command stack "$@"
        fi
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    mcp-status|/mcp-status)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command mcp-status "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
      ;;

    flow|/flow)
      shift
      if declare -f run_agent_command >/dev/null; then
        run_agent_command flow "$@"
        command_status=$?
      else
        echo "ERROR: mq-agent bridge not loaded" >&2
        return 1
      fi
      return "$command_status"
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
      command_status=$?
      return "$command_status"
      ;;

    srm|memory|repo-memory)
      shift
      # The co-change memory loop is delegated to mq-agent (the orchestrator); mqlaunch
      # owns no memory logic and never reaches mqobsidian directly. `cochange` is intake;
      # review-status / promote-from-review / resolve-supersede action the review queues.
      # Everything else stays the local SRM surface.
      local _mem_verb=""
      # Route on the normalised word, not the raw one: every other namespace is
      # case-insensitive. Only the verb is matched here — whatever follows is a
      # question owned by srm.sh and is forwarded untouched.
      case "$sub" in
        cochange)            _mem_verb="memory-cochange" ;;
        review-status)       _mem_verb="memory-review-status" ;;
        promote-from-review) _mem_verb="memory-promote-from-review" ;;
        resolve-supersede)   _mem_verb="memory-resolve-supersede" ;;
      esac
      if [[ -n "$_mem_verb" ]]; then
        shift
        if declare -f run_agent_command >/dev/null; then
          run_agent_command "$_mem_verb" "$@"
          command_status=$?
        else
          echo "ERROR: mq-agent bridge not loaded" >&2
          return 1
        fi
        return "$command_status"
      fi
      "$BASE_DIR/tools/scripts/srm.sh" "$@"
      command_status=$?
      return "$command_status"
      ;;

    skills|skill)
      shift
      "$BASE_DIR/tools/scripts/mq-skills.py" "$@"
      command_status=$?
      [[ "${1:-}" != "--json" ]] && pause_enter
      return "$command_status"
      ;;

    repos)
      shift
      case "$sub" in
        ""|menu|hub)
          "$BASE_DIR/bin/mqlaunch" hub
          command_status=$?
          ;;
        list|roadmaps|skills|status|wiki-status|diff-summary)
          # mq-repos.py matches its command word exactly, so forward the
          # normalised one. Arguments after it keep the case the user typed.
          "$BASE_DIR/tools/scripts/mq-repos.py" "$sub" "${@:2}"
          command_status=$?
          pause_enter
          ;;
        *)
          # Unknown: forward verbatim so the delegate's error names the word the
          # user actually typed.
          "$BASE_DIR/tools/scripts/mq-repos.py" "$@"
          command_status=$?
          pause_enter
          ;;
      esac
      return "$command_status"
      ;;

    fix|/fix)
      shift
      "$BASE_DIR/tools/scripts/fix.sh" "$@"
      command_status=$?
      return "$command_status"
      ;;

    chat|/chat)
      "$BASE_DIR/tools/scripts/chat.sh"
      command_status=$?
      return "$command_status"
      ;;

    release-check|/release-check|check-release)
      "$BASE_DIR/terminal/release/mq-release-check.sh" "${@:2}"
      command_status=$?
      pause_enter
      return "$command_status"
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
      local _selftest_rc=$?
      [[ -z "${MQ_NO_TUI:-}" ]] && pause_enter
      return "$_selftest_rc"
      ;;

    doctor|/doctor)
      "$BASE_DIR/tools/scripts/doctor.sh" "${@:2}"
      command_status=$?
      [[ "${2:-}" != "--json" && -z "${MQ_NO_TUI:-}" ]] && pause_enter
      return "$command_status"
      ;;

    scan|/scan)
      "$BASE_DIR/tools/scripts/scan.sh"
      command_status=$?
      pause_enter
      return "$command_status"
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
      command_status=$?
      return "$command_status"
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
      command_status=$?
      return "$command_status"
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

    palette|fzf|search)
      run_command_palette
      return 0
      ;;

    markdownlint|mdlint)
      "$BASE_DIR/tools/scripts/markdownlint.sh" "${@:2}"
      return $?
      ;;

    ghost)
      "$BASE_DIR/tools/scripts/network-ghost.sh"
      return $?
      ;;

    pulse)
      "$BASE_DIR/tools/scripts/pulse.sh"
      return $?
      ;;

    reap)
      "$BASE_DIR/tools/scripts/overseer.sh"
      return $?
      ;;

    guard)
      "$BASE_DIR/tools/scripts/blackout.sh"
      return $?
      ;;

    mc)
      "$BASE_DIR/tools/scripts/mission-control.sh"
      return $?
      ;;

    nickname-set|nick-set|nick)
      shift
      if [[ -n "${1:-}" ]]; then
        printf '%s\n' "$*" > "$HOME/.mqlaunch_nickname"
        echo "Smeknamn sparat: $*"
      else
        echo "Nuvarande smeknamn: $(get_nickname)"
        echo "Ändra: mqlaunch nickname-set <smeknamn>"
      fi
      return 0
      ;;

    theme-macos)
      theme_cmd apply macos
      return 0
      ;;

    theme-reset)
      theme_cmd reset
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
      command_status=$?
      return "$command_status"
      ;;

    docfunc|document-functions)
      MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docfunc
      command_status=$?
      return "$command_status"
      ;;

    docwrite|document-functions-write|update-comments)
      MQ_WORK_DIR="$PWD" "$BASE_DIR/terminal/menus/mq-tools-menu.sh" docwrite
      command_status=$?
      return "$command_status"
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
      if has_json_flag "$@"; then
        print_status_json
        return 0
      fi
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
        command_status=$?
      else
        echo "ERROR: mq-hal bridge not loaded" >&2
        return 1
      fi
      has_json_flag "$@" || pause_enter
      return "$command_status"
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

    obsidian|mqobsidian|memory-menu|mq-memory)
      case "$sub" in
        ""|menu)
          if declare -f mq_obsidian_menu_main >/dev/null; then
            mq_obsidian_menu_main
          else
            echo "ERROR: mqobsidian menu not loaded" >&2
            return 1
          fi
          ;;
        status|doctor)
          "$BASE_DIR/mqlaunch/commands/mqobsidian/mqobsidian-doctor.sh"
          ;;
        inbox)
          if declare -f mq_obsidian_show_inbox >/dev/null; then
            mq_obsidian_show_inbox
          else
            echo "ERROR: mqobsidian menu not loaded" >&2
            return 1
          fi
          ;;
        views|open-view|navigate)
          if declare -f mq_obsidian_open_view_picker >/dev/null; then
            mq_obsidian_open_view_picker
          else
            echo "ERROR: mqobsidian view picker not loaded" >&2
            return 1
          fi
          ;;
        promote)
          shift 2 || true
          if declare -f run_agent_command >/dev/null; then
            run_agent_command obsidian-promote "$@"
          else
            echo "ERROR: mq-agent bridge not loaded" >&2
            return 1
          fi
          ;;
        *)
          echo "ERROR: unknown mqobsidian command: $sub" >&2
          echo "usage: mqlaunch obsidian [status|inbox|views|promote]" >&2
          return 1
          ;;
      esac
      command_status=$?
      return "$command_status"
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
      command_status=$?
      return "$command_status"
      ;;

    git-log|gitlog|glog)
      declare -f fzf_git_log >/dev/null && fzf_git_log || "$BASE_DIR/bin/mqlaunch" git-log
      command_status=$?
      return "$command_status"
      ;;

    git-branch|branch-switch|gbranch)
      declare -f fzf_git_branch >/dev/null && fzf_git_branch || "$BASE_DIR/bin/mqlaunch" git-branch
      command_status=$?
      return "$command_status"
      ;;

    kill-process|killp|pkill-fzf)
      declare -f fzf_kill_process >/dev/null && fzf_kill_process || "$BASE_DIR/bin/mqlaunch" kill-process
      command_status=$?
      return "$command_status"
      ;;

    kill-port|killport|port-kill)
      declare -f fzf_kill_port >/dev/null && fzf_kill_port || "$BASE_DIR/bin/mqlaunch" kill-port
      command_status=$?
      return "$command_status"
      ;;

    snippets|snippet|scripts)
      declare -f fzf_run_snippet >/dev/null && fzf_run_snippet || "$BASE_DIR/bin/mqlaunch" snippets
      command_status=$?
      return "$command_status"
      ;;

    recent|recent-files|rf)
      declare -f fzf_recent_files >/dev/null && fzf_recent_files || "$BASE_DIR/bin/mqlaunch" recent
      command_status=$?
      return "$command_status"
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

    # `memory` is deliberately absent here: the srm|memory|repo-memory branch
    # above claims it first, so listing it again never matched.
    note|sessions|decisions|reviews|learn|verified|systems)
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
      print_unknown_command_error "$area"
      return 2
      ;;
  esac
}
