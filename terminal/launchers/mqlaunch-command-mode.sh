#!/usr/bin/env bash

normalize_cli_word() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

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
  mqlaunch perf
  mqlaunch network
  mqlaunch check
  mqlaunch self-check
  mqlaunch debug
  mqlaunch apps
  mqlaunch version
  mqlaunch notes
  mqlaunch about
  mqlaunch index

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

Legacy commands still work:
  mqlaunch login menu
  mqlaunch shortcuts list
  mqlaunch palette
HELP
      ;;
  esac
}

dispatch_cli_command() {
  local area sub
  area="$(normalize_cli_word "${1:-}")"
  sub="$(normalize_cli_word "${2:-}")"

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

    demo)
      run_demo_mode
      return 0
      ;;

    system)
      case "$sub" in
        ""|menu)
          open_system_menu
          ;;
        perf|performance)
          open_v1_performance_menu
          ;;
        net|network)
          show_network_info
          ;;
        check|doctor|health)
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
      return 0
      ;;

    git)
      case "$sub" in
        ""|menu)
          open_git_menu
          ;;
        *)
          print_command_help "git"
          return 2
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
      return 0
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
          open_v1_tools_menu
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
      open_v1_performance_menu
      return 0
      ;;

    net|network)
      show_network_info
      return 0
      ;;

    check|doctor|health)
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

    apps)
      open_apps_menu
      return 0
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
      show_about_dashboard || true
      return 0
      ;;

    index|commands)
      show_command_index || true
      return 0
      ;;

    *)
      return 1
      ;;
  esac
}
