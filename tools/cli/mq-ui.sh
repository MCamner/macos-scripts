#!/usr/bin/env bash

# ----------------------------
# Theme system
# ----------------------------

MQ_THEME="${MQ_THEME:-green}"

case "$MQ_THEME" in
  green)
    C_OK="\033[1;32m"
    C_WARN="\033[1;33m"
    C_ERR="\033[1;31m"
    C_TITLE="\033[1;36m"
    ;;
  amber)
    C_OK="\033[38;5;214m"
    C_WARN="\033[38;5;222m"
    C_ERR="\033[38;5;196m"
    C_TITLE="\033[38;5;220m"
    ;;
  ice)
    C_OK="\033[38;5;51m"
    C_WARN="\033[38;5;117m"
    C_ERR="\033[38;5;39m"
    C_TITLE="\033[38;5;123m"
    ;;
  *)
    C_OK="\033[1;32m"
    C_WARN="\033[1;33m"
    C_ERR="\033[1;31m"
    C_TITLE="\033[1;36m"
    ;;
esac

C_RESET="\033[0m"

# ----------------------------
# Layout
# ----------------------------

# Handles hr.
hr() {
  printf "%*s\n" "$(tput cols)" '' | tr ' ' '─'
}

# Handles header.
header() {
  echo -e "${C_TITLE}$1${C_RESET}"
  hr
}

# Handles section.
section() {
  echo
  echo -e "${C_TITLE}$1${C_RESET}"
  hr
}

# Handles ok.
ok()   { printf "${C_OK}✔ %-30s${C_RESET}\n" "$1"; }
# Handles warn.
warn() { printf "${C_WARN}⚠ %-30s${C_RESET}\n" "$1"; }
# Handles err.
err()  { printf "${C_ERR}✖ %-30s${C_RESET}\n" "$1"; }

# Blink helper (used for CRITICAL)
blink_err() {
  printf "\033[5m${C_ERR}✖ %-30s${C_RESET}\n" "$1"
}
