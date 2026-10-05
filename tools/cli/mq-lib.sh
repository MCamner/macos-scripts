#!/usr/bin/env bash

# --------------------------------------------------
# MQ LIB (minimal stable v2)
# --------------------------------------------------

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# ----------------------------
# Commands
# ----------------------------

# Runs scan.sh.
mq_scan() {
  "$BASE_DIR/tools/scripts/scan.sh" "$@"
}

# Runs doctor.sh.
mq_doctor() {
  "$BASE_DIR/tools/scripts/doctor.sh"
}

# Prints the user and shell.
mq_sys() {
  echo "User: $USER"
  echo "Shell: $SHELL"
}

# Changes to ~/.config/mq-shell.
mq_config() {
  cd "$HOME/.config/mq-shell" || exit
}

# Replaces the shell with a login zsh.
mq_reload() {
  if command -v zsh >/dev/null 2>&1; then
    echo "Reloading shell with zsh..."
    exec zsh -l
  fi

  echo "zsh not found; run: exec zsh -l" >&2
  return 1
}

# Handles mq netpulse.
mq_pulse() {
  "$BASE_DIR/tools/scripts/netpulse.sh"
}

# Lists the mq commands.
mq_help() {
  echo "mq commands:"
  echo "  doctor"
  echo "  sys"
  echo "  config"
  echo "  reload"
  echo "  scan"
  echo "  netpulse"
  echo "  test"
}

# Runs watch.sh.
mq_watch() {
  "$BASE_DIR/tools/scripts/watch.sh"
}
