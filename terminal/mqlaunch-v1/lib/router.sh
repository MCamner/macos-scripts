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
    health|check)
      command_health_check
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

Usage:
  mqlaunch                Open main menu
  mqlaunch menu           Open main menu
  mqlaunch system         Open system menu
  mqlaunch tools          Open tools menu
  mqlaunch automation     Open automation menu
  mqlaunch dev            Open dev menu
  mqlaunch git            Open dev menu
  mqlaunch perf           Open performance menu
  mqlaunch health         Run health check
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide
  mqlaunch help           Show this help

HELP
}
