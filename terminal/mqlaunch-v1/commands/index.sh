#!/usr/bin/env bash

command_show_command_index() {
  print_header
  print_section "Command Index"

  echo "CORE"
  echo " mqlaunch              Open main menu"
  echo " mqlaunch help         Show help"
  echo " mqlaunch commands     Show command index"
  echo

  echo "WORKFLOWS"
  echo " mqlaunch perf         Performance module"
  echo " mqlaunch dev          Dev module"
  echo " mqlaunch git          Alias for Dev"
  echo " mqlaunch tools        Tools module"
  echo " mqlaunch login        Start session boot"
  echo " mqlaunch shortcuts    Open Shortcuts menu"
  echo " mqlaunch shortcuts list"
  echo " mqlaunch shortcuts search clip"
  echo " mqlaunch login menu   Session boot + full menu"
  echo " mqlaunch login about  Session boot + about screen"
  echo " mqlaunch login check  Session boot + self-check"
  echo

  echo "STATUS / SUPPORT"
  echo " mqlaunch about        About / status dashboard"
  echo " mqlaunch version      Version information"
  echo " mqlaunch notes        Release notes / changelog"
  echo " mqlaunch check        Run self-check"
  echo " mqlaunch bundle       Create debug bundle"
  echo

  echo "UTILITY"
  echo " mqlaunch repo         Open repo root"
  echo " mqlaunch guide        Open terminal guide"
  echo

  echo "ALIASES"
  echo " mqlaunch health       Alias for check"
  echo " mqlaunch support      Alias for bundle"
  echo " mqlaunch changelog    Alias for notes"
  echo " mqlaunch dashboard    Alias for about"
  echo " mqlaunch index        Alias for commands"
  echo " mqlaunch palette      Alias for commands"

  pause_enter
}
