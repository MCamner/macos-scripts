#!/usr/bin/env bash

# --------------------------------------------------
# MQ LIB (minimal stable v2)
# --------------------------------------------------

BASE_DIR="$HOME/macos-scripts"

# ----------------------------
# Commands
# ----------------------------

mq_scan() {
  "$BASE_DIR/tools/scripts/scan.sh" "$@"
}

mq_doctor() {
  "$BASE_DIR/tools/scripts/doctor.sh"
}

mq_sys() {
  echo "User: $USER"
  echo "Shell: $SHELL"
}

mq_config() {
  cd "$HOME/.config/mq-shell" || exit
}

mq_reload() {
  if command -v zsh >/dev/null 2>&1; then
    echo "Reloading shell with zsh..."
    exec zsh -l
  fi

  echo "zsh not found; run: exec zsh -l" >&2
  return 1
}

mq_pulse() {
  "$BASE_DIR/tools/scripts/pulse.sh"
}

mq_help() {
  echo "mq commands:"
  echo "  doctor"
  echo "  sys"
  echo "  config"
  echo "  reload"
  echo "  scan"
  echo "  pulse"
  echo "  test"
}

mq_watch() {
  "$HOME/macos-scripts/tools/scripts/watch.sh"
}
