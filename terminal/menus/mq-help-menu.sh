#!/usr/bin/env bash

show_command_index() {
  print_header
  row_bold "COMMAND INDEX"
  empty_row

  row "CORE"
  row " mqlaunch              Open main menu"
  row " mqlaunch help         Show help"
  row " mqlaunch commands     Show command index"

  empty_row
  row "WORKFLOWS"
  row " mqlaunch perf         Open Performance module"
  row " mqlaunch dev          Open Dev module"
  row " mqlaunch git          Open Git menu"
  row " mqlaunch tools        Open Tools module"
  row " mqlaunch workflows    Open Workflows menu"
  row " mqlaunch release      Open Release Menu"
  row " mqlaunch login        Open Login / Session menu"
  row " mqlaunch shortcuts    Open Shortcuts menu"
  row " mqlaunch workflows boot       Run project boot"
  row " mqlaunch login menu   Start full session boot"
  row " mqlaunch login about  Start session in about mode"
  row " mqlaunch login check  Start session in self-check mode"
  row " mqlaunch shortcuts list        List shortcuts directly"
  row " mqlaunch shortcuts search clip Search shortcuts by name"

  empty_row
  row "STATUS / SUPPORT"
  row " mqlaunch about        About / status dashboard"
  row " mqlaunch version      Version information"
  row " mqlaunch notes        Release notes / changelog"
  row " mqlaunch check        Run self-check"
  row " mqlaunch bundle       Create debug bundle"

  empty_row
  row "UTILITY"
  row " mqlaunch repo         Open repo root"
  row " mqlaunch guide        Open terminal guide"

  empty_row
  row "ALIASES"
  row " mqlaunch health       Alias for check"
  row " mqlaunch support      Alias for bundle"
  row " mqlaunch changelog    Alias for notes"
  row " mqlaunch dashboard    Alias for about"
  row " mqlaunch index        Alias for commands"
  row " mqlaunch palette      Alias for commands"

  print_footer
  pause_enter
}

show_help() {
  cat <<HELP

mqlaunch — modular terminal workflow hub

CORE
  mqlaunch                Open main menu
  mqlaunch help           Show help
  mqlaunch commands       Show command index

WORKFLOWS
  mqlaunch perf           Open Performance module
  mqlaunch dev            Open Dev module
  mqlaunch git            Open Git menu
  mqlaunch tools          Open Tools module
  mqlaunch workflows      Open Workflows menu
  mqlaunch release        Open Release Menu
  mqlaunch login          Open Login / Session menu
  mqlaunch shortcuts      Open Shortcuts menu
  mqlaunch workflows boot Run project boot
  mqlaunch shortcuts list
  mqlaunch shortcuts search clip
  mqlaunch login menu     Session boot + full menu
  mqlaunch login about    Session boot + about screen
  mqlaunch login check    Session boot + self-check

STATUS / SUPPORT
  mqlaunch about          Show about / status dashboard
  mqlaunch version        Show version information
  mqlaunch notes          Show release notes / changelog
  mqlaunch check          Run self-check
  mqlaunch bundle         Create debug bundle

UTILITY
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide

ALIASES
  mqlaunch health         Alias for check
  mqlaunch support        Alias for bundle
  mqlaunch changelog      Alias for notes
  mqlaunch dashboard      Alias for about
  mqlaunch index          Alias for commands
  mqlaunch palette        Alias for commands

POPULAR FLOWS
  mqlaunch git
  mqlaunch workflows
  mqlaunch release
  mqlaunch login
  mqlaunch shortcuts

HELP
}
