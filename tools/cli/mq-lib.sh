#!/usr/bin/env bash

# --------------------------------------------------
# MQ LIB (minimal stable v2)
# --------------------------------------------------

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# ----------------------------
# Commands
# ----------------------------

# Handles mq scan.
mq_scan() {
  "$BASE_DIR/tools/scripts/scan.sh" "$@"
}

# Handles mq doctor.
mq_doctor() {
  "$BASE_DIR/tools/scripts/doctor.sh"
}

# Handles mq sys.
mq_sys() {
  echo "User: $USER"
  echo "Shell: $SHELL"
}

# Handles mq config.
mq_config() {
  cd "$HOME/.config/mq-shell" || exit
}

# Handles mq reload.
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

# Handles mq help.
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

# Handles mq watch.
mq_watch() {
  "$BASE_DIR/tools/scripts/watch.sh"
}
