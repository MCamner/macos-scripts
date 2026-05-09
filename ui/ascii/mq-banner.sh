#!/usr/bin/env bash

: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_DIM:=\033[2m}"
: "${C_CYAN:=\033[36m}"
: "${C_MAGENTA:=\033[35m}"
: "${C_GREEN:=\033[32m}"
: "${C_YELLOW:=\033[33m}"
: "${C_RED:=\033[31m}"

# Handles mq banner.
mq_banner() {
  local title="${1:-MQLaunch}"
  local subtitle="${2:-Old School Utility}"
  local author="${3:-Mattias Camner}"

  echo -e "${C_CYAN}${C_BOLD}================================================================================${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}███╗   ███╗ ██████╗ ██╗      █████╗ ██╗   ██╗███╗   ██╗ ██████╗██╗  ██╗${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}████╗ ████║██╔═══██╗██║     ██╔══██╗██║   ██║████╗  ██║██╔════╝██║  ██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██╔████╔██║██║   ██║██║     ███████║██║   ██║██╔██╗ ██║██║     ███████║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██║╚██╔╝██║██║▄▄ ██║██║     ██╔══██║██║   ██║██║╚██╗██║██║     ██╔══██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}██║ ╚═╝ ██║╚██████╔╝███████╗██║  ██║╚██████╔╝██║ ╚████║╚██████╗██║  ██║${C_RESET}"
  echo -e "${C_MAGENTA}${C_BOLD}╚═╝     ╚═╝ ╚══▀▀═╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝ ╚═════╝╚═╝  ╚═╝${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}================================================================================${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}:: ${title}${C_RESET}"
  echo -e "${C_YELLOW}:: ${subtitle}${C_RESET}"
  echo -e "${C_DIM}:: Author: ${author}${C_RESET}"
  echo
  echo -e "${C_CYAN}              .--------.        ${C_MAGENTA}___${C_RESET}"
  echo -e "${C_CYAN}             / .------. \\       ${C_MAGENTA}| _ )  _   _   __ _${C_RESET}"
  echo -e "${C_CYAN}            / /        \\ \\      ${C_MAGENTA}| _ \\ | | | | / _\` |${C_RESET}"
  echo -e "${C_CYAN}            | |        | |      ${C_MAGENTA}|___/  \\_,_| \\__, |${C_RESET}"
  echo -e "${C_CYAN}           _| |________| |_                 ${C_MAGENTA}|___/${C_RESET}"
  echo -e "${C_CYAN}         .' |_|        |_| '.${C_RESET}"
  echo -e "${C_CYAN}         '._____ ____ _____.'${C_RESET}"
  echo -e "${C_CYAN}         |     .'____'.     |${C_RESET}"
  echo -e "${C_CYAN}         '.__.'.'    '.'.__.'${C_RESET}"
  echo -e "${C_CYAN}         '.__  |  .-.  |  __.'${C_RESET}"
  echo -e "${C_CYAN}         |   '.'.____.'.'   |${C_RESET}"
  echo -e "${C_CYAN}         '.____'.____.'____.'${C_RESET}"
  echo -e "${C_CYAN}         '.________________.'${C_RESET}"
  echo
  echo -e "${C_RED}${C_BOLD}>>> SYSTEM READY${C_RESET} ${C_DIM}:: modular terminal framework online${C_RESET}"
  echo -e "${C_CYAN}${C_BOLD}================================================================================${C_RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_banner "$@"
fi
