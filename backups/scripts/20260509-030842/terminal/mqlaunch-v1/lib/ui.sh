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

print_divider() {
  printf '%*s\n' 52 '' | tr ' ' '-'
}

print_kv() {
  local key="$1"
  local value="$2"
  printf "%-18s %s\n" "$key" "$value"
}

print_warning_block() {
  local warnings="$1"

  print_section "Warnings"

  if [[ -z "$warnings" || "$warnings" == "No major issues detected" ]]; then
    echo "✓ No major issues detected"
    return
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "! $line"
  done <<< "$warnings"
}
