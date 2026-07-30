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
  mqlaunch perf
  mqlaunch system check
  mqlaunch doctor
  mqlaunch ask "vad gör scan?"
  mqlaunch review

START
  mqlaunch                Open main menu
  mqlaunch demo           Run guided demo mode
  mqlaunch help           Show help
  mqlaunch commands       Show command index
  mqlaunch palette        Open fuzzy command palette

WORKFLOWS
  mqlaunch system         Open System menu
  mqlaunch perf           Open Performance menu
  mqlaunch dev            Open Dev menu
  mqlaunch git            Open Git menu
  mqlaunch tools          Open Tools menu
  mqlaunch workflows      Open Workflows menu
  mqlaunch release        Open Release menu
  mqlaunch login          Open Login menu
  mqlaunch shortcuts      Open Shortcuts menu

PROJECT FLOWS
  mqlaunch workflows boot        Run project boot
  mqlaunch workflows check       Run project check
  mqlaunch login menu            Session boot + full menu
  mqlaunch login about           Session boot + about screen
  mqlaunch login check           Session boot + self-check
  mqlaunch shortcuts list        List shortcuts directly
  mqlaunch shortcuts search clip Search shortcuts by name

SECURITY & OPS
  mqlaunch ghost          Run network cloaking (MAC/DNS spoof)
  mqlaunch pulse          Diagnostic for network latency & WiFi
  mqlaunch scan           Matrix-style system & port scan
  mqlaunch reap           Overseer process reaper (CPU/MEM focus)
  mqlaunch guard          Perimeter watchdog (USB/Power monitor)
  mqlaunch mc             Open advanced system dashboard

CHECKS & SUPPORT
  mqlaunch doctor         Run environment and dependency check
  mqlaunch doctor --json  Machine-readable JSON report
  mqlaunch selftest       Run internal smoke tests
  mqlaunch check          Run environment check
  mqlaunch bundle         Create debug bundle
  mqlaunch about          Open About / Status
  mqlaunch version        Show version information
  mqlaunch notes          Show release notes / changelog

UTILITY
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide
  mqlaunch system time    Show date and time
  mqlaunch theme          Open Themes menu
  mqlaunch theme-macos    Apply macOS theme
  mqlaunch theme-reset    Reset theme

AI
  mqlaunch ask "din fråga"       Fråga om repot — svar direkt i terminalen
  mqlaunch ask quick "fråga"     Kort svar utan repo-kontext
  mqlaunch atlas                 Interaktiv AI-session (senior systems engineer)
  mqlaunch fix "error message"   Få körbara shell-kommandon för fel/uppgifter
  mqlaunch chat                  Konversationsläge med minne
  mqlaunch review                Review via mq-agent → mq-mcp
  mqlaunch risk-review           Risk review via mq-agent → mq-mcp
  mqlaunch review-brain [path]   Granska repo + spara till brain → reviews/
  mqlaunch signal-brain [path]   repo-signal + spara till brain → reviews/
  mqlaunch learn-promote <slug>  Kuraterar learn/<slug> → learn/verified/
  mqlaunch mcp-status            Visa mq-mcp status och contract health
  mqlaunch ui                    Kopiera UI-prompt till clipboard
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
