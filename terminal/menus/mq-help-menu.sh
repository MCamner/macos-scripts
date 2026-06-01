#!/usr/bin/env bash

CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

# Standalone-only helpers — skipped when sourced into mqlaunch (mq-ui.sh already defines these).
if ! command -v surface_panel_header >/dev/null 2>&1; then
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

  print_footer() {
    local now host user_name
    now="$(date '+%Y-%m-%d %H:%M:%S')"
    host="$(hostname -s 2>/dev/null || hostname)"
    user_name="${USER:-$(whoami)}"

    printf '\n'
    printf "Host: %s   User: %s\n" "$host" "$user_name"
    printf "Time: %s\n" "$now"
  }

  row() {
    printf "%s\n" "$1"
  }

  row_bold() {
    echo -e "${PURPLE}$1${NC}"
  }

  empty_row() {
    printf "\n"
  }

  pause_enter() {
    printf "\nPress Enter to continue..."
    read -r
  }
fi

# Shows command index.
show_command_index() {
  print_header
  row_bold "START"
  row " mqlaunch              Open main menu"
  row " mqlaunch demo         Run guided demo mode"
  row " mqlaunch help         Show help"
  row " mqlaunch commands     Show command index"
  row " mqlaunch palette      Open fuzzy command palette"

  empty_row
  row_bold "WORKFLOWS"
  row " mqlaunch system       Open System menu"
  row " mqlaunch perf         Open Performance menu"
  row " mqlaunch dev          Open Dev menu"
  row " mqlaunch git          Open Git menu"
  row " mqlaunch tools        Open Tools menu"
  row " mqlaunch workflows    Open Workflows menu"
  row " mqlaunch release      Open Release menu"
  row " mqlaunch login        Open Login menu"
  row " mqlaunch shortcuts    Open Shortcuts menu"

  empty_row
  row_bold "PROJECT FLOWS"
  row " mqlaunch workflows boot        Run project boot"
  row " mqlaunch workflows check       Run project check"
  row " mqlaunch login menu            Session boot + full menu"
  row " mqlaunch login about           Session boot + about screen"
  row " mqlaunch login check           Session boot + self-check"
  row " mqlaunch shortcuts list        List shortcuts directly"
  row " mqlaunch shortcuts search clip Search shortcuts by name"

  empty_row
  row_bold "SECURITY & OPS"
  row " mqlaunch ghost        Run network cloaking (MAC/DNS spoof)"
  row " mqlaunch pulse        Diagnostic for network latency & WiFi"
  row " mqlaunch scan         Matrix-style system & port scan"
  row " mqlaunch reap         Overseer process reaper (CPU/MEM focus)"
  row " mqlaunch guard        Perimeter watchdog (USB/Power monitor)"
  row " mqlaunch mc           Open advanced system dashboard"

  empty_row
  row_bold "CHECKS & SUPPORT"
  row " mqlaunch doctor       Run environment and dependency check"
  row " mqlaunch doctor --json  Machine-readable JSON report"
  row " mqlaunch selftest     Run internal smoke tests"
  row " mqlaunch check        Run environment check"
  row " mqlaunch bundle       Create debug bundle"
  row " mqlaunch about        Open About / Status"
  row " mqlaunch version      Show version information"
  row " mqlaunch notes        Show release notes / changelog"

  empty_row
  row_bold "UTILITY"
  row " mqlaunch repo         Open repo root"
  row " mqlaunch guide        Open terminal guide"
  row " mqlaunch system time  Show date and time"
  row " mqlaunch theme        Open Themes menu"
  row " mqlaunch theme-macos  Apply macOS theme"
  row " mqlaunch theme-reset  Reset theme"

  empty_row
  row_bold "AI"
  row " mqlaunch ask \"din fråga\"       Fråga om repot — svar direkt i terminalen"
  row " mqlaunch ask quick \"fråga\"     Kort svar utan repo-kontext"
  row " mqlaunch atlas                 Interaktiv AI-session (senior systems engineer)"
  row " mqlaunch fix \"error message\"   Få körbara shell-kommandon för fel/uppgifter"
  row " mqlaunch chat                  Konversationsläge med minne"
  row " mqlaunch review                Review via mq-agent → mq-mcp"
  row " mqlaunch risk-review           Risk review via mq-agent → mq-mcp"
  row " mqlaunch mcp-status            Visa mq-mcp status och contract health"
  row " mqlaunch ui                    Kopiera UI-prompt till clipboard"

  print_footer
  pause_enter
}

# Shows help.
show_help() {
  cat <<'HELP'
mqlaunch — modular terminal workflow hub

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
  mqlaunch review                Review via mq-agent → mq-mcp
  mqlaunch risk-review           Risk review via mq-agent → mq-mcp
  mqlaunch mcp-status            Visa mq-mcp status och contract health
  mqlaunch ui                    Kopiera UI-prompt till clipboard

POPULAR FLOWS
  mqlaunch
  mqlaunch perf
  mqlaunch system check
  mqlaunch doctor
  mqlaunch ask "vad gör scan?"
  mqlaunch review
HELP
}
