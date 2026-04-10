#!/usr/bin/env bash

print_header() {
  clear
  printf "%b\n" "${C_BOLD}${C_BLUE}mqlaunch v1${C_RESET}"
  printf "%b\n" "${C_DIM}Modular macOS workflow launcher${C_RESET}"
  printf "\n"
}

print_section() {
  printf "\n%b\n" "${C_BOLD}$1${C_RESET}"
}

print_menu_item() {
  local key="$1"
  local label="$2"
  printf "  ${C_CYAN}%-4s${C_RESET} %s\n" "$key" "$label"
}

print_footer_hint() {
  printf "\n%b\n" "${C_DIM}Type a command, number, or x to exit.${C_RESET}"
}
