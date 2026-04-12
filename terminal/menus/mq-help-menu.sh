#!/usr/bin/env bash

show_command_index() {
  print_header
  row_bold "COMMAND INDEX"
  empty_row

  row "CORE"
  row " mqlaunch              Open main menu"
  row " mqlaunch demo         Run guided demo mode"
  row " mqlaunch help         Show help"
  row " mqlaunch commands     Show command index"
  row " mqlaunch palette      Open fuzzy command palette"
  row " mqlaunch system       Open System menu"

  empty_row
  row "WORKFLOWS"
  row " mqlaunch perf         Open Performance module"
  row " mqlaunch system check Run system check"
  row " mqlaunch system debug Create debug bundle"
  row " mqlaunch dev          Open Prompt Tools menu"
  row " mqlaunch git          Open Git workspace"
  row " mqlaunch tools        Open Tools menu"
  row " mqlaunch workflows    Open Workflows menu"
  row " mqlaunch release      Open Release Menu"
  row " mqlaunch login        Open Login menu"
  row " mqlaunch shortcuts    Open Shortcuts menu"
  row " mqlaunch workflows boot       Run project boot"
  row " mqlaunch workflows check      Run project check"
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
  row " mqlaunch fzf          Alias for palette"
  row " mqlaunch search       Alias for palette"

  print_footer
  pause_enter
}

show_help() {
  cat <<HELP

mqlaunch — modular terminal workflow hub

CORE
  mqlaunch                Open main menu
  mqlaunch demo           Run guided demo mode
  mqlaunch help           Show help
  mqlaunch commands       Show command index
  mqlaunch palette        Open fuzzy command palette

WORKFLOWS
  mqlaunch perf           Open Performance module
  mqlaunch dev            Open Prompt Tools menu
  mqlaunch git            Open Git workspace
  mqlaunch tools          Open Tools menu
  mqlaunch workflows      Open Workflows menu
  mqlaunch release        Open Release Menu
  mqlaunch login          Open Login menu
  mqlaunch shortcuts      Open Shortcuts menu
  mqlaunch workflows boot Run project boot
  mqlaunch workflows check Run project check
  mqlaunch shortcuts list
  mqlaunch shortcuts search clip
  mqlaunch login menu     Session boot + full menu
  mqlaunch login about    Session boot + about screen
  mqlaunch login check    Session boot + self-check

STATUS / SUPPORT
  mqlaunch about          Show about / status dashboard
  mqlaunch version        Show version information
  mqlaunch notes          Show release notes / changelog
  mqlaunch check          Run system check
  mqlaunch self-check     Run smoke self-check
  mqlaunch bundle         Create debug bundle

UTILITY
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide
  mqlaunch system time    Show date and time

ALIASES
  mqlaunch health         Alias for system check
  mqlaunch support        Alias for bundle
  mqlaunch changelog      Alias for notes
  mqlaunch dashboard      Alias for about
  mqlaunch index          Alias for commands
  mqlaunch fzf            Alias for palette
  mqlaunch search         Alias for palette

POPULAR FLOWS
  mqlaunch git
  mqlaunch workflows
  mqlaunch release
  mqlaunch login
  mqlaunch shortcuts

HELP
}
