#!/usr/bin/env bash

route_command() {
  local cmd="${1:-menu}"

  case "$cmd" in
    menu|main)
      menu_main
      ;;
    system)
      menu_system
      ;;
    tools|tools-v1|menu-tools-v1)
      menu_tools
      ;;
    automation|auto)
      menu_automation
      ;;
    dev|git|dev-v1)
      menu_dev
      ;;
    ai)
      menu_ai
      ;;
    performance|perf)
      menu_performance
      ;;
    version|ver|about-version)
      command_show_version
      ;;
    about|status|dashboard)
      command_show_about_dashboard
      ;;
    check|health)
      command_run_self_check
      ;;
    bundle|debug-bundle|support)
      command_run_debug_bundle
      ;;
    notes|changelog|release-notes)
      command_show_changelog
      ;;
    commands|index|palette)
      command_show_command_index
      ;;
    repo)
      command_open_repo
      ;;
    guide|terminal-guide)
      command_open_terminal_guide
      ;;
    help|-h|--help)
      show_help
      ;;
    x|exit|quit)
      return 0
      ;;
    *)
      err "Unknown command: $cmd"
      echo
      show_help
      return 1
      ;;
  esac
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
  mqlaunch git            Alias for Dev
  mqlaunch tools          Open Tools module

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

HELP
}
