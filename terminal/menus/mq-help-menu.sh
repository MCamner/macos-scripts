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
  mqlaunch ask "vad gör scan?"
  mqlaunch review

CORE
  mqlaunch help           Help, the command index, and namespace help
  mqlaunch palette        Fuzzy palette over the dispatchable surface
  mqlaunch about          Status dashboard; --json emits one document
  mqlaunch version        Launcher and repo version information
  mqlaunch notes          Show the changelog
  mqlaunch demo           Run the launcher demo mode

MENUS
  mqlaunch system         Performance, network, doctor, checks, utilities
  mqlaunch perf           Performance menu
  mqlaunch dev            AI helpers, tools, current-project actions
  mqlaunch git            Git menu and git workflows
  mqlaunch tools          Tools menu
  mqlaunch workflows      Project boot, surface validation, snapshots
  mqlaunch release        Release menu, notes, version, status
  mqlaunch login          Login / session menu
  mqlaunch shortcuts      macOS Shortcuts menu
  mqlaunch theme          Themes menu

CHECKS
  mqlaunch doctor         Environment and dependency check
  mqlaunch doctor --json  The same verdict as one machine document
  mqlaunch check          Run the system check
  mqlaunch selftest       Smoke suite and shell lint

OPS
  mqlaunch pulse          Network latency and WiFi overview
  mqlaunch scan           System and port scan
  mqlaunch ghost          Network cloaking (MAC/DNS spoof)
  mqlaunch reap           Overseer process reaper
  mqlaunch guard          Blackout guard (USB/Power monitor)
  mqlaunch mc             Mission control dashboard

AI
  mqlaunch ask "fråga"    Fråga om repot — svar i terminalen
  mqlaunch fix "fel"      Körbara shell-kommandon för fel
  mqlaunch chat           Konversationsläge med minne
  mqlaunch atlas          Interaktiv AI-session
  mqlaunch ui             Kopiera UI-prompt till clipboard

AGENT
  mqlaunch stack          Stack status and stack operations
  mqlaunch review         Diff review
  mqlaunch risk-review    Risk review
  mqlaunch architecture   Architecture analysis
  mqlaunch repo-health    Repo health report
  mqlaunch flow           Guided flow
  mqlaunch mcp-status     mq-mcp server status
  mqlaunch review-brain   Brain-backed review
  mqlaunch signal-brain   Brain-backed signal report
  mqlaunch learn-promote  Promote a learned pattern
  mqlaunch agent          Everything else mq-agent orchestrates

OBSIDIAN
  mqlaunch obsidian       Durable memory, backed by mqobsidian

SRM
  mqlaunch srm            Semantic repo memory and the co-change loop

SKILLS
  mqlaunch skills         List and inspect installed skills

REPOS
  mqlaunch repos          Repo status, roadmaps, skills, diff summaries

HAL
  mqlaunch hal            Operator summaries and audits, via mq-hal

UTILITY
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
