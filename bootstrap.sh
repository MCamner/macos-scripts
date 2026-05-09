#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/MCamner/macos-scripts.git}"
BRANCH="${BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/macos-scripts}"

# Handles log.
log()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
# Handles ok.
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
# Handles warn.
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
# Handles err.
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }
# Handles die.
die()  { err "$*"; exit 1; }

# Handles require cmd.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# Runs the main entry point.
main() {
  require_cmd git
  require_cmd bash

  log "Installing macos-scripts"
  log "Repository: $REPO_URL"
  log "Branch:     $BRANCH"
  log "Target:     $INSTALL_DIR"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "Existing git checkout found. Updating..."
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      die "Target path exists but is not a git repo: $INSTALL_DIR"
    fi

    log "Cloning repository..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi

  log "Running local installer..."
  bash "$INSTALL_DIR/install.sh" --install-dir "$INSTALL_DIR" --yes

  ok "macos-scripts installed"
  printf '\nRun:\n  mqlaunch\n'
}

main "$@"
