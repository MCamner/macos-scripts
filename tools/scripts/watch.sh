#!/usr/bin/env bash

INTERVAL="${1:-2}"
BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
SCAN="$BASE_DIR/tools/scripts/scan.sh"

# init screen
tput civis  # hide cursor
clear

# Draws header.
draw_header() {
  tput cup 0 0
  echo "MQ LIVE DASHBOARD (refresh: ${INTERVAL}s)   [Ctrl+C=exit, r=refresh, +/-=speed]"
  printf "%*s\n" "$(tput cols)" '' | tr ' ' '═'
}

trap 'tput cnorm; clear; exit' INT TERM

while true; do
  # header
  draw_header

  # body start at line 2
  tput cup 2 0

  # run scan
  "$SCAN"

  # non-blocking key read (0.1s steps)
  for _ in $(seq 1 $((INTERVAL*10))); do
    read -rsn1 -t 0.1 key
    case "$key" in
      r|R) break ;;                  # force refresh
      +) INTERVAL=$((INTERVAL+1)) ;;
      -) [ "$INTERVAL" -gt 1 ] && INTERVAL=$((INTERVAL-1)) ;;
      q|Q) tput cnorm; clear; exit ;;
    esac
  done
done
