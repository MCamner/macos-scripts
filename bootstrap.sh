#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/MCamner/macos-scripts.git"
INSTALL_DIR="${INSTALL_DIR:-$HOME/macos-scripts}"
BRANCH="${BRANCH:-main}"

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

main() {
  require_cmd git
  require_cmd bash

  info "Installing macos-scripts"
  info "Repository: $REPO_URL"
  info "Target: $INSTALL_DIR"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Existing repo found, updating..."
    git -C "$INSTALL_DIR" fetch origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH"
  else
    if [[ -e "$INSTALL_DIR" && ! -d "$INSTALL_DIR/.git" ]]; then
      die "Target exists but is not a git repo: $INSTALL_DIR"
    fi
    info "Cloning repository..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
  fi

  info "Running local installer..."
  bash "$INSTALL_DIR/install.sh" --install-dir "$INSTALL_DIR" --yes

  ok "Done"
  printf '\nRun:\n  mqlaunch\n'
}

main "$@"
