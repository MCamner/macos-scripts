# Shell Helper Snippets

Reusable shell helpers for polished terminal output.

```bash
#!/usr/bin/env bash

# Basic ANSI colors with NO_COLOR support
if [[ -n "${NO_COLOR:-}" ]]; then
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_OK=""
  C_WARN=""
  C_ERR=""
  C_TITLE=""
else
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_DIM="\033[2m"
  C_OK="\033[32m"
  C_WARN="\033[33m"
  C_ERR="\033[31m"
  C_TITLE="\033[36;1m"
fi

term_width() {
  local w
  w="$(tput cols 2>/dev/null || echo 80)"
  [[ "$w" =~ ^[0-9]+$ ]] || w=80
  (( w < 50 )) && w=50
  (( w > 120 )) && w=120
  echo "$w"
}

rule() {
  local w
  w="$(term_width)"
  printf '%*s\n' "$w" '' | tr ' ' '─'
}

title() {
  printf '%b%s%b\n' "$C_TITLE" "$1" "$C_RESET"
  rule
}

section() {
  printf '\n%b%s%b\n' "$C_BOLD" "$1" "$C_RESET"
}

ok() {
  printf '  %b✔%b %s\n' "$C_OK" "$C_RESET" "$1"
}

warn() {
  printf '  %b⚠%b %s\n' "$C_WARN" "$C_RESET" "$1"
}

err() {
  printf '  %b✖%b %s\n' "$C_ERR" "$C_RESET" "$1"
}

status_line() {
  printf '\n%bStatus:%b %s\n' "$C_DIM" "$C_RESET" "$1"
}
```
