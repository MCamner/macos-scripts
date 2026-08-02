#!/usr/bin/env bash
# mq-agent menu module for mqlaunch

MQ_AGENT_BIN="${MQ_AGENT_BIN:-$HOME/mq-agent}"
MQ_MCP_DIR="${MQ_MCP_DIR:-$HOME/mq-mcp/mq-mcp}"
MQ_MCP_PORT="${MQ_MCP_PORT:-8765}"

# Prints mq-agent menu.
print_agent_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "AI Agent Orchestrator" "mq-agent" "$width" "$panel_color"
  surface_row "ANALYSE" "$width" "$panel_color"
  surface_split_row "1. Repo analysis" "2. Audit repository" "$width" "$panel_color"
  surface_split_row "3. Release check" "4. Diagnose CI" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "STACK  (writes to mqobsidian)" "$width" "$panel_color"
  surface_split_row "5. Review to brain" "${C_WARN}6. Stack health sweep${C_RESET}" "$width" "$panel_color"
  surface_split_row "${C_WARN}7. Stack loop plan${C_RESET}" "8. Co-change and memory" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "LOCAL" "$width" "$panel_color"
  surface_split_row "9. MCP server (:8765)" "10. Environment" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Reports a missing mq-agent checkout.
#
# Mirrors mq_hal_missing() in terminal/bridges/hal-bridge.sh: name the binary,
# name the path, give runnable next steps, exit 127. Without this the operator
# got the shell's own diagnostic — `_run_agent:cd:1: no such file or directory`
# under zsh — which names an internal function and says nothing about mq-agent
# being a separate repo that has to be installed.
_mq_agent_missing() {
  echo "ERROR: mq-agent not found: $MQ_AGENT_BIN" >&2
  echo >&2
  echo "mqlaunch delegates orchestration to mq-agent; it is a separate repo." >&2
  echo >&2
  echo "Check:" >&2
  echo "  ls -l $MQ_AGENT_BIN" >&2
  echo "  git clone https://github.com/MCamner/mq-agent $MQ_AGENT_BIN" >&2
  echo >&2
  echo "Or point mqlaunch at an existing checkout:" >&2
  echo "  export MQ_AGENT_BIN=/path/to/mq-agent" >&2
  return 127
}

# Runs an mq-agent command inside the mq-agent project dir.
_run_agent() {
  [[ -d "$MQ_AGENT_BIN" ]] || { _mq_agent_missing; return $?; }
  (cd "$MQ_AGENT_BIN" && env -u VIRTUAL_ENV UV_NO_CONFIG=1 uv --project "$MQ_AGENT_BIN" run mq-agent "$@")
}

# Runs an mq-mcp review through mq-agent's review command surface.
_run_agent_review() {
  local scope="diff"
  local mode="${MQ_MCP_REVIEW_MODE:-comment}"
  local file=""
  local passthrough=()

  # Scope is a positional word — `review diff`, `review repo`, `review file X` —
  # which is the only form docs/COMMANDS.md documents. The flag spellings
  # `--diff`, `--repo` and `--file` used to be accepted here as scope selectors
  # too, and `--repo` collided with mq-agent's own `--repo <path>` option on
  # `review file`: the external repo the file lives in. `review file X --repo /p`
  # matched the scope arm, dropped X, and ran `review repo /p` — a whole repo
  # reviewed instead of one file, silently, with the operator's path read as the
  # repo. Removing the aliases costs an undocumented spelling and makes the
  # option reachable. Anything unrecognised falls through to passthrough below,
  # so new mq-agent options work without a change here.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      diff)
        scope="diff"
        shift
        ;;
      repo)
        scope="repo"
        shift
        ;;
      file)
        scope="file"
        file="${2:-}"
        if [[ $# -gt 1 ]]; then
          shift 2
        else
          shift
        fi
        ;;
      --mode)
        mode="${2:-$mode}"
        if [[ $# -gt 1 ]]; then
          shift 2
        else
          shift
        fi
        ;;
      comment|security|architecture|risk)
        mode="$1"
        shift
        ;;
      *)
        passthrough+=("$1")
        shift
        ;;
    esac
  done

  local mode_args=()
  case "$mode" in
    comment|"")
      ;;
    security)
      mode_args+=(--security)
      ;;
    architecture)
      mode_args+=(--architecture)
      ;;
    risk)
      mode_args+=(--risk)
      ;;
    *)
      printf "Unsupported review mode: %s\n" "$mode" >&2
      return 1
      ;;
  esac

  case "$scope" in
    repo)
      _run_agent review repo "${mode_args[@]}" "${passthrough[@]}"
      ;;
    file)
      if [[ -z "$file" ]]; then
        printf "Usage: mqlaunch review file <relative-path> [mode]\n" >&2
        return 1
      fi
      _run_agent review file "$file" "${mode_args[@]}" "${passthrough[@]}"
      ;;
    diff)
      _run_agent review diff "${mode_args[@]}" "${passthrough[@]}"
      ;;
  esac
}

# Lists mq-mcp architecture memory through mq-agent.
_run_agent_architecture() {
  _run_agent run-tool list_architecture_decisions "$@"
}

# Runs repo health checks through mq-agent and mq-mcp.
_run_agent_repo_health() {
  local repo_path="${MQ_REPO_HEALTH_PATH:-$BASE_DIR}"
  _run_agent run-tool repo_signal_analyze --arg "repo_path=$repo_path" "$@" || return $?
  _run_agent run-tool validate_orchestration_contract "$@"
}

# Starts mq-mcp server in the background if not already running on MQ_MCP_PORT.
_mcp_start() {
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp already running on :%s\n" "$MQ_MCP_PORT"
    return 0
  fi
  if [[ ! -f "$MQ_MCP_DIR/server.py" ]]; then
    printf "server.py not found at %s\n" "$MQ_MCP_DIR" >&2
    return 1
  fi
  local pid="?"
  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t mq-mcp 2>/dev/null || true
    tmux new-session -d -s mq-mcp "cd '$MQ_MCP_DIR' && env -u VIRTUAL_ENV MQ_MCP_TRANSPORT=sse uv run python server.py > /tmp/mq-mcp.log 2>&1"
    pid="tmux:mq-mcp"
  else
    local pid_file="/tmp/mq-mcp.pid"
    (
      cd "$MQ_MCP_DIR" || exit 1
      env -u VIRTUAL_ENV MQ_MCP_TRANSPORT=sse nohup uv run python server.py > /tmp/mq-mcp.log 2>&1 &
      printf '%s\n' "$!" > "$pid_file"
      disown "$!" 2>/dev/null || true
    )
    pid="$(cat "$pid_file" 2>/dev/null || printf '?')"
  fi
  sleep 1
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp started on :%s (pid %s)\n" "$MQ_MCP_PORT" "$pid"
  else
    printf "mq-mcp failed to start — check /tmp/mq-mcp.log\n" >&2
    return 1
  fi
}

# Stops mq-mcp server if running on MQ_MCP_PORT.
_mcp_stop() {
  local pids
  pids="$(lsof -ti:"$MQ_MCP_PORT" 2>/dev/null)"
  if [[ -z "$pids" ]]; then
    printf "mq-mcp is not running on :%s\n" "$MQ_MCP_PORT"
    return 0
  fi
  echo "$pids" | xargs kill 2>/dev/null || true
  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t mq-mcp 2>/dev/null || true
  fi
  sleep 1
  if lsof -ti:"$MQ_MCP_PORT" >/dev/null 2>&1; then
    printf "mq-mcp still running on :%s — try kill -9\n" "$MQ_MCP_PORT" >&2
    return 1
  fi
  printf "mq-mcp stopped (port :%s is free)\n" "$MQ_MCP_PORT"
}

# Lists learn/ files and prompts for promotion. Uses fzf when available.
_brain_pick_and_promote() {
  local vault_dir="${MQ_OBSIDIAN_DIR:-$HOME/mqobsidian}"
  local learn_dir="$vault_dir/learn"

  if [[ ! -d "$learn_dir" ]]; then
    printf "learn/ not found: %s\n" "$learn_dir" >&2
    pause_enter; return 1
  fi

  local files=()
  while IFS= read -r -d '' f; do
    files+=("$(basename "$f" .md)")
  done < <(find "$learn_dir" -maxdepth 1 -name "*.md" -not -name "index.md" -print0 | sort -z)

  if [[ ${#files[@]} -eq 0 ]]; then
    printf "No files in learn/ to promote.\n"
    pause_enter; return 0
  fi

  local slug=""
  if command -v fzf >/dev/null 2>&1; then
    slug="$(printf '%s\n' "${files[@]}" | fzf --height=40% --layout=reverse --border --prompt="promote > ")"
  else
    printf "Available slugs in learn/:\n"
    printf '  %s\n' "${files[@]}"
    printf "\nSlug to promote: "
    read -r slug
  fi

  [[ -z "$slug" ]] && return 0
  _run_agent learn promote "$slug" --approve
  pause_enter
}

# Prints the `mqlaunch flow` usage. Kept here so the surface is documented in
# one place next to the delegate that owns it.
_print_flow_help() {
  cat <<'HELP'
mqlaunch flow                          list available workflow templates
mqlaunch flow list                     list available workflow templates
mqlaunch flow run <template> [repo]    plan, gate and run a workflow (read-only)
mqlaunch flow plan <template> [repo]   build and print a plan; do not run it
mqlaunch flow status <run-id>          show a run's current state
mqlaunch flow show <template>          show a template definition
mqlaunch flow resume <run-id>          resume a paused or failed run
mqlaunch flow cancel <run-id>          cancel a run

repo defaults to the current directory; pass --repo to override.
All planning, policy gating and execution happen in mq-agent / mq-mcp.
HELP
}

# True when the given args already carry an explicit --repo option.
_flow_has_repo_flag() {
  local arg
  for arg in "$@"; do
    [[ "$arg" == "--repo" || "$arg" == --repo=* ]] && return 0
  done
  return 1
}

# Runs a workflow-orchestration command through `mq-agent workflow` (Phase 7).
#
# mqlaunch owns no orchestration logic: it only forwards to mq-agent, which
# plans, applies the tool-policy + approval gates, and executes. The single
# local convenience is accepting REPO positionally (defaulting to $PWD) and
# translating it to the `--repo` option mq-agent expects.
_run_agent_flow() {
  local sub="${1:-list}"
  case "$sub" in
    ""|list)
      shift || true
      _run_agent workflow list "$@"
      ;;
    run|plan)
      shift || true
      local template="${1:-}"
      if [[ -z "$template" || "$template" == -* ]]; then
        printf "Usage: mqlaunch flow %s <template> [repo] [-- mq-agent flags]\n" "$sub" >&2
        return 1
      fi
      shift
      local repo=""
      if [[ $# -gt 0 && "$1" != -* ]]; then
        repo="$1"
        shift
      fi
      if _flow_has_repo_flag "$@"; then
        _run_agent workflow "$sub" "$template" "$@"
      else
        _run_agent workflow "$sub" "$template" --repo "${repo:-$PWD}" "$@"
      fi
      ;;
    show|status|resume|cancel)
      _run_agent workflow "$@"
      ;;
    -h|--help|help)
      _print_flow_help
      ;;
    *)
      # Forward unknown verbs verbatim so new mq-agent workflow subcommands work
      # without requiring a mqlaunch change.
      _run_agent workflow "$@"
      ;;
  esac
}

# Handles direct mqlaunch agent commands.
_print_memory_cochange_help() {
  cat <<'HELP'
mqlaunch memory cochange <repo> <file>          emit co-change evidence, score, writeback, status
  --dry-run                                     write nothing; show what would happen
  --no-writeback                                score but do not write learn files
  --vault DIR                                   mqobsidian vault (or $MQ_OBSIDIAN_DIR)
  --window N / --min-confidence F / --min-support N   co-change passthrough

Operator-triggered one-command intake (NOT auto-after-workflow). Bridget/CG-2 is
the evidence source; mq-agent is the producer/orchestrator; mqobsidian owns
scoring, quarantine, promotion-event and learn-writeback.
HELP
}

# Thin delegate: `mqlaunch memory cochange` -> `mq-agent memory inbox-cochange`.
#
# mqlaunch owns NO memory logic: emission, scoring, quarantine, promotion and
# learn-writeback all live in mq-agent / mqobsidian. This forwards verbatim.
_run_agent_memory_cochange() {
  case "${1:-}" in
    -h|--help|help)
      _print_memory_cochange_help
      return 0
      ;;
  esac
  if [[ -z "${1:-}" || -z "${2:-}" || "${1}" == -* || "${2}" == -* ]]; then
    printf "Usage: mqlaunch memory cochange <repo> <file> [--dry-run] [--no-writeback] [--vault DIR]\n" >&2
    return 1
  fi
  _run_agent memory inbox-cochange "$@"
}

# Interactive prompt for the "Co-change intake" menu row. Collects repo + file,
# then forwards to the same thin delegate the CLI uses (no local memory logic).
_agent_menu_cochange() {
  local repo file
  printf "Repo path [%s]: " "$PWD"
  read -r repo
  repo="${repo:-$PWD}"
  printf "File (repo-relative): "
  read -r file
  if [[ -z "$file" ]]; then
    printf "%b No file given — cancelled.%b\n" "${C_WARN:-}" "${C_RESET:-}"
    return 0
  fi
  _run_agent_memory_cochange "$repo" "$file"
}

# Interactive submenu for the "Co-change review" menu row. Surfaces the autonomous-loop
# review/resolution actions — all delegated through mq-agent (mqlaunch owns no memory
# logic; mq-agent is the orchestrator; mqobsidian stays the decision engine).
_agent_menu_cochange_review() {
  local choice mid ar
  while true; do
    printf "\n%b Co-change review %b\n" "${C_WARN:-}" "${C_RESET:-}"
    printf "  1) Status (tiers + held review queues)\n"
    printf "  2) Promote from review (land a held proposal)\n"
    printf "  3) Resolve supersede (accept/reject a conflict)\n"
    printf "  b) Back\n"
    printf "  review > "
    read -r choice
    case "$choice" in
      1) _run_agent memory review-status; pause_enter ;;
      2)
        printf "  memory_id to promote: "
        read -r mid
        if [[ -z "$mid" ]]; then printf "  cancelled\n"; continue; fi
        _run_agent memory promote-from-review "$mid" --apply
        pause_enter
        ;;
      3)
        printf "  memory_id to resolve: "
        read -r mid
        if [[ -z "$mid" ]]; then printf "  cancelled\n"; continue; fi
        printf "  (a)ccept new evidence or (r)eject and keep promoted? "
        read -r ar
        case "$ar" in
          a|A|accept) _run_agent memory resolve-supersede "$mid" --accept --apply ;;
          r|R|reject) _run_agent memory resolve-supersede "$mid" --reject --apply ;;
          *) printf "  cancelled\n"; continue ;;
        esac
        pause_enter
        ;;
      b|B|x|X|"") return 0 ;;
      *) printf "  Invalid selection: %s\n" "$choice" ;;
    esac
  done
}

# Runs agent command.
run_agent_command() {
  local subcmd="${1:-menu}"
  case "$subcmd" in
    menu|"")
      open_agent_menu
      ;;
    doctor)
      shift || true
      _run_agent doctor "$@"
      ;;
    score)
      shift || true
      _run_agent score "$@"
      ;;
    audit)
      shift || true
      _run_agent audit "$@"
      ;;
    release-check)
      shift || true
      _run_agent release-check "$@"
      ;;
    review)
      shift || true
      _run_agent_review "$@"
      ;;
    architecture)
      shift || true
      _run_agent_architecture "$@"
      ;;
    risk-review)
      shift || true
      _run_agent review diff --risk "$@"
      ;;
    repo-health)
      shift || true
      _run_agent_repo_health "$@"
      ;;
    stack)
      shift || true
      if [[ $# -eq 0 ]]; then
        _run_agent stack status
      else
        _run_agent stack "$@"
      fi
      ;;
    mcp-status)
      shift || true
      _run_agent mcp status "$@"
      ;;
    flow)
      shift || true
      _run_agent_flow "$@"
      ;;
    memory-cochange)
      shift || true
      _run_agent_memory_cochange "$@"
      ;;
    memory-review-status)
      shift || true
      _run_agent memory review-status "$@"
      ;;
    memory-promote-from-review)
      shift || true
      _run_agent memory promote-from-review "$@"
      ;;
    memory-resolve-supersede)
      shift || true
      _run_agent memory resolve-supersede "$@"
      ;;
    obsidian-promote)
      shift || true
      _run_agent obsidian promote "$@"
      ;;
    mcp-tools)
      shift || true
      _run_agent mcp tools "$@"
      ;;
    mcp-start)
      _mcp_start
      ;;
    mcp-stop)
      _mcp_stop
      ;;
    *)
      _run_agent "$@"
      ;;
  esac
}


# The five submenus the ten rows above open. Each keeps the actions that used to
# sit flat in the parent, so nothing became unreachable — only less shouted.

# Prints the repo analysis submenu.
print_agent_repo_analysis_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"
  print_header
  surface_panel_header "Repo Analysis" "mq-agent" "$width" "$panel_color"
  surface_row "NO API KEY REQUIRED" "$width" "$panel_color"
  surface_split_row "1. Score repository" "2. Full signal assessment" "$width" "$panel_color"
  surface_split_row "3. Repo summary" "4. List tools" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the repo analysis submenu loop.
agent_repo_analysis_menu_loop() {
  local choice
  while true; do
    print_agent_repo_analysis_menu
    read_menu_choice "" "analysis" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) _run_agent score .; pause_enter ;;
      2) _run_agent signal .; pause_enter ;;
      3) _run_agent repo-summary .; pause_enter ;;
      4) _run_agent tools; pause_enter ;;
      b|B|x|X|exit) return ;;
      *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
    esac
  done
}

# Prints the review-to-brain submenu.
print_agent_review_brain_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"
  print_header
  surface_panel_header "Review to Brain" "mq-agent" "$width" "$panel_color"
  surface_row "WRITES TO mqobsidian" "$width" "$panel_color"
  surface_split_row "1. Review repo → brain" "2. Signal + save to brain" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the review-to-brain submenu loop.
agent_review_brain_menu_loop() {
  local choice
  while true; do
    print_agent_review_brain_menu
    read_menu_choice "" "review" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) _run_agent review repo . --brain; pause_enter ;;
      2) _run_agent signal --brain .; pause_enter ;;
      b|B|x|X|exit) return ;;
      *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
    esac
  done
}

# Prints the co-change and memory submenu.
print_agent_cochange_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"
  print_header
  surface_panel_header "Co-change and Memory" "mq-agent" "$width" "$panel_color"
  surface_row "MEMORY" "$width" "$panel_color"
  surface_split_row "1. Co-change intake" "2. Co-change review" "$width" "$panel_color"
  surface_split_row "3. Promote learn pattern" "" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the co-change and memory submenu loop.
agent_cochange_menu_loop() {
  local choice
  while true; do
    print_agent_cochange_menu
    read_menu_choice "" "cochange" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) _agent_menu_cochange; pause_enter ;;
      2) _agent_menu_cochange_review ;;
      3) _brain_pick_and_promote ;;
      b|B|x|X|exit) return ;;
      *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
    esac
  done
}

# Prints the MCP submenu.
print_agent_mcp_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"
  print_header
  surface_panel_header "MCP Server" "mq-agent" "$width" "$panel_color"
  surface_row "LOCAL TOOLS  (:8765)" "$width" "$panel_color"
  surface_split_row "1. MCP status" "2. MCP tools list" "$width" "$panel_color"
  surface_split_row "3. Start MCP server" "4. Stop MCP server" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the MCP submenu loop.
agent_mcp_menu_loop() {
  local choice
  while true; do
    print_agent_mcp_menu
    read_menu_choice "" "mcp" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) _run_agent mcp status; pause_enter ;;
      2) _run_agent mcp tools; pause_enter ;;
      3) _mcp_start; pause_enter ;;
      4) _mcp_stop; pause_enter ;;
      b|B|x|X|exit) return ;;
      *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
    esac
  done
}

# Prints the environment submenu.
print_agent_environment_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  # shellcheck disable=SC2034
  MQ_SURFACE_WIDTH="$width"
  print_header
  surface_panel_header "Environment" "mq-agent" "$width" "$panel_color"
  surface_row "ENVIRONMENT" "$width" "$panel_color"
  surface_split_row "1. Doctor" "2. TUI dashboard" "$width" "$panel_color"
  surface_split_row "b. Back" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs the environment submenu loop.
agent_environment_menu_loop() {
  local choice
  while true; do
    print_agent_environment_menu
    read_menu_choice "" "environment" || return
    choice="$REPLY"
    echo
    case "$choice" in
      1) _run_agent doctor; pause_enter ;;
      2) _run_agent tui ;;
      b|B|x|X|exit) return ;;
      *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
    esac
  done
}

# Handles agent menu choice.
handle_agent_menu_choice() {
  local choice="$1"
  # Ten choices, grouped by what an operator is trying to do rather than by
  # which backend answers. The twenty-one flat rows this replaces mixed a
  # one-shot score with starting a server; the detail lives in submenus now.
  #
  # Demo flow moved to the Workflows menu, where the other full-stack runs are.
  # Learn promotion moved into Co-change and memory, which is where the rest of
  # the memory writes already were.
  case "$choice" in
    1) agent_repo_analysis_menu_loop ;;
    2) _run_agent audit .;    pause_enter ;;
    3) _run_agent release-check; pause_enter ;;
    4) _run_agent fix-ci;     pause_enter ;;
    5) agent_review_brain_menu_loop ;;
    6) _run_agent stack sweep --brain; pause_enter ;;
    7) _run_agent stack loop; pause_enter ;;
    8) agent_cochange_menu_loop ;;
    9) agent_mcp_menu_loop ;;
    10) agent_environment_menu_loop ;;
    b|B|x|X|exit) return 1 ;;
    *) printf "%b Invalid selection:%b %s\n" "${C_ERR:-}" "${C_RESET:-}" "$choice"; pause_enter ;;
  esac
  return 0
}

# Keeps the agent menu interactive until the user backs out.
agent_menu_loop() {
  local choice
  while true; do
    print_agent_menu
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "mq-agent" || break
    else
      printf "\nmq-agent > "
      read -r choice
    fi
    echo
    if ! handle_agent_menu_choice "$choice"; then
      break
    fi
  done
}


# Opens agent menu.
open_agent_menu() {
  agent_menu_loop
}
