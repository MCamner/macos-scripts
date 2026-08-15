#!/usr/bin/env bash

CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

# Standalone-only helpers — skipped when sourced into mqlaunch (mq-ui.sh already defines these).
if ! command -v surface_panel_header >/dev/null 2>&1; then
# Prints header.
  print_header() {
    clear
    echo -e "${PURPLE}"
    echo "  __  __  ____  _             _    _   _   _____ _    _ "
    echo " |  \/  |/ __ \| |           / \  | | | | / ____| |  | |"
    echo " | \  / | |  | | |          / _ \ | | | || |    | |__| |"
    echo " | |\/| | |  | | |         / ___ \| | | || |    |  __  |"
    echo " | |  | | |__| | |____    / /   \ \ |_| || |____| |  | |"
    echo " |_|  |_|\___\_\______|  /_/     \_\___/  \_____|_|  |_|"
    echo -e "          -- S Y S T E M   H U B   v1.0 --${NC}\n"
    echo -e "${CYAN}COMMAND INDEX${NC}"
    echo -e "${BLUE}----------------------------------------------------------------------------------------${NC}"
  }

# Prints footer.
  print_footer() {
    local now host user_name
    now="$(date '+%Y-%m-%d %H:%M:%S')"
    host="$(hostname -s 2>/dev/null || hostname)"
    user_name="${USER:-$(whoami)}"

    printf '\n'
    printf "Host: %s   User: %s\n" "$host" "$user_name"
    printf "Time: %s\n" "$now"
  }

# Prints a plain menu row.
  row() {
    printf "%s\n" "$1"
  }

# Prints a bold menu row.
  row_bold() {
    echo -e "${PURPLE}$1${NC}"
  }

# Prints a blank menu row.
  empty_row() {
    printf "\n"
  }

# Pauses until Enter is pressed.
  pause_enter() {
    printf "\nPress Enter to continue..."
    read -r
  }
fi

# The command list, written once.
#
# `mqlaunch help` prints these lines plain; `mqlaunch commands` prints the same
# lines inside the index panel. They used to be two hand-maintained copies, and
# they had already drifted apart: `chat` reached the index and never reached
# help.
#
# Section headings start at column 0, entries are indented two spaces. Both
# renderers below rely on that, and so does the extraction in
# tests/registry-consumer-parity-smoke.sh.
command_list() {
  cat <<'LIST'
POPULAR FLOWS
  mqlaunch
  mqlaunch doctor
  mqlaunch stack
  mqlaunch perf
  mqlaunch ask
  mqlaunch review

CORE
  mqlaunch about          Status dashboard for the launcher and the repo
  mqlaunch demo           Run the guided demo
  mqlaunch help           Help, the command index, and namespace help
  mqlaunch notes          Show the changelog
  mqlaunch palette        Fuzzy search across every command
  mqlaunch version        Show launcher and repo versions

MENUS
  mqlaunch dev            AI helpers, tools, and current-project actions
  mqlaunch git            Git menu and git workflows
  mqlaunch login          Session boot and the login menu
  mqlaunch perf           Open the performance menu
  mqlaunch release        Release menu, notes, version, and status
  mqlaunch shortcuts      Open the macOS Shortcuts menu
  mqlaunch system         Performance, network, doctor, checks, utilities
  mqlaunch theme          Show, apply, or reset the terminal theme
  mqlaunch tools          Open the tools menu
  mqlaunch workflows      Project boot, surface validation, snapshots

CHECKS
  mqlaunch check          Run the system check
  mqlaunch doctor         Check the environment and dependencies
  mqlaunch pulse          Operator cockpit: system, repos and MQ stack
  mqlaunch selftest       Run the smoke suite and shell lint

OPS
  mqlaunch ghost          Network cloaking (MAC and DNS spoof)
  mqlaunch guard          Watch USB and power events
  mqlaunch mc             Open mission control
  mqlaunch netpulse       Network latency and WiFi overview
  mqlaunch reap           Find and kill heavy processes
  mqlaunch scan           System and port scan

AI
  mqlaunch ask            Ask a question about the repo
  mqlaunch atlas          Open an interactive AI session
  mqlaunch chat           Chat with memory of the conversation
  mqlaunch fix            Get runnable commands for an error
  mqlaunch ui             Copy the UI prompt to the clipboard

AGENT  (owner: mq-agent)
  mqlaunch agent          Run orchestration commands
  mqlaunch architecture   Analyse the repository architecture
  mqlaunch flow           Run a guided flow
  mqlaunch learn-promote  Promote a learned pattern
  mqlaunch mcp-status     Show mq-mcp server status
  mqlaunch repo-health    Report on repository health
  mqlaunch review         Review a diff
  mqlaunch review-brain   Review a repo and save it to the brain
  mqlaunch risk-review    Review a diff for risk
  mqlaunch route          Inspect model routing through mq-agent
  mqlaunch signal-brain   Repo signal report saved to the brain
  mqlaunch stack          Show stack status and the read-only release cockpit

OBSIDIAN  (owner: mqobsidian)
  mqlaunch obsidian       Durable memory and notes

SRM  (owner: mq-agent)
  mqlaunch srm            Semantic repo memory, delegated to mq-agent

SKILLS
  mqlaunch skills         List and inspect installed skills

REPOS
  mqlaunch repos          Repo status, roadmaps, skills, diff summaries

HAL  (owner: mq-hal)
  mqlaunch hal            Operator summaries and audits

UTILITY
  mqlaunch focus          Pomodoro focus timer with a session log
  mqlaunch guide          Open the terminal guide
  mqlaunch repo           Open the repository in the browser
LIST
}

# Shows command index.
show_command_index() {
  print_header
  while IFS= read -r line; do
    case "$line" in
      "")    empty_row ;;
      [!\ ]*) row_bold "$line" ;;
      *)     row "$line" ;;
    esac
  done < <(command_list)
  print_footer
  pause_enter
}

# Shows help.
show_help() {
  printf '%s\n\n' "mqlaunch — modular terminal workflow hub"
  command_list
}
