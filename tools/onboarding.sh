#!/usr/bin/env bash
set -euo pipefail

APP_TITLE="macos-scripts"
CMD="mqlaunch"

print_line() {
  printf '%s\n' "$1"
}

main() {
  clear || true
  print_line "============================================================"
  print_line " ${APP_TITLE} — onboarding complete"
  print_line "============================================================"
  print_line ""
  print_line "Installed command:"
  print_line "  ${CMD}"
  print_line ""
  print_line "Recommended first commands:"
  print_line "  mqlaunch demo"
  print_line "  mqlaunch theme"
  print_line "  mqlaunch theme-current"
  print_line "  mqlaunch dev"
  print_line ""
  print_line "Theme:"
  print_line "  Default theme is set to: macos"
  print_line ""
  print_line "If 'mqlaunch' is not found, add this to your ~/.zshrc:"
  print_line '  export PATH="$HOME/bin:$PATH"'
  print_line ""
  print_line "Then reload your shell:"
  print_line "  source ~/.zshrc"
  print_line ""
}
main "$@"
