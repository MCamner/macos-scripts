#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Config
# ============================================================

APP_NAME="macos-scripts"
STATE_FILE="$HOME/.macos-scripts-install-state"
DEFAULT_INSTALL_DIR="$HOME/macos-scripts"
DEFAULT_BIN_DIR="$HOME/bin"
LAUNCHER_SOURCE_REL="terminal/launchers/mqlaunch.sh"
LAUNCHER_NAME="mqlaunch"
ZSHRC="$HOME/.zshrc"

DRY_RUN=0
UNINSTALL=0
ASSUME_YES=0
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
BIN_DIR="${BIN_DIR:-$DEFAULT_BIN_DIR}"
LAUNCHER_LINK="$BIN_DIR/$LAUNCHER_NAME"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATED_INSTALL_DIR=0
MANAGED_ZSHRC=0

# ============================================================
# Logging
# ============================================================

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

die() {
  err "$*"
  exit 1
}

# ============================================================
# Usage
# ============================================================

show_help() {
  cat <<'HELP'
Usage: ./install.sh [options]

Options:
  --dry-run               Show what would be done without changing anything
  --install-dir PATH      Install repo into PATH
  --uninstall             Remove installed launcher and managed shell config
  --yes                   Skip confirmation prompts
  --help                  Show this help
HELP
}

# ============================================================
# CLI args
# ============================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --install-dir)
        [[ $# -ge 2 ]] || die "--install-dir requires a path"
        INSTALL_DIR="$2"
        shift 2
        ;;
      --uninstall)
        UNINSTALL=1
        shift
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

# ============================================================
# Helpers
# ============================================================

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " reply || true
  [[ "${reply:-}" =~ ^[Yy]$ ]]
}

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

ensure_dir() {
  run_cmd mkdir -p "$1"
}

ensure_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] touch %q\n' "$file"
    else
      touch "$file"
    fi
  fi
}

ensure_launcher_exists() {
  local launcher="$PROJECT_ROOT/$LAUNCHER_SOURCE_REL"
  [[ -f "$launcher" ]] || die "Launcher not found: $launcher"
}

# ============================================================
# State management
# ============================================================

write_state() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] write state file %q\n' "$STATE_FILE"
    return
  fi

  cat > "$STATE_FILE" <<STATE
INSTALL_DIR=$INSTALL_DIR
LAUNCHER_LINK=$LAUNCHER_LINK
MANAGED_ZSHRC=$MANAGED_ZSHRC
CREATED_INSTALL_DIR=$CREATED_INSTALL_DIR
STATE
  ok "Wrote install state"
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

remove_state() {
  if [[ -f "$STATE_FILE" ]]; then
    run_cmd rm -f "$STATE_FILE"
    ok "Removed state file"
  fi
}

# ============================================================
# Repo sync / install location
# ============================================================

sync_repo_if_needed() {
  if [[ "$PROJECT_ROOT" == "$INSTALL_DIR" ]]; then
    info "Repo already in target location: $INSTALL_DIR"
    return
  fi

  if [[ -e "$INSTALL_DIR" ]]; then
    warn "Target install dir already exists: $INSTALL_DIR"
    info "Using existing directory without copying"
    PROJECT_ROOT="$INSTALL_DIR"
    return
  fi

  if confirm "Copy repo to $INSTALL_DIR?"; then
    run_cmd cp -R "$PROJECT_ROOT" "$INSTALL_DIR"
    PROJECT_ROOT="$INSTALL_DIR"
    CREATED_INSTALL_DIR=1
    ok "Copied repo to install dir"
  else
    die "Install aborted"
  fi
}

# ============================================================
# Launcher link
# ============================================================

link_launcher() {
  local launcher="$PROJECT_ROOT/$LAUNCHER_SOURCE_REL"
  ensure_dir "$BIN_DIR"
  run_cmd chmod +x "$launcher"
  run_cmd ln -sf "$launcher" "$LAUNCHER_LINK"
  ok "Linked $LAUNCHER_NAME -> $launcher"
}

remove_launcher_link() {
  if [[ -L "$LAUNCHER_LINK" || -e "$LAUNCHER_LINK" ]]; then
    run_cmd rm -f "$LAUNCHER_LINK"
    ok "Removed launcher link"
  else
    info "Launcher link not present: $LAUNCHER_LINK"
  fi
}

# ============================================================
# PATH hint
# ============================================================

ensure_bin_path_hint() {
  case ":$PATH:" in
    *":$BIN_DIR:"*)
      ok "$BIN_DIR already in PATH"
      ;;
    *)
      warn "$BIN_DIR is not in PATH"
      printf '\n'
      printf 'Add this to %s if needed:\n' "$ZSHRC"
      printf 'export PATH="$HOME/bin:$PATH"\n\n'
      ;;
  esac
}

# ============================================================
# ZSHRC managed block
# ============================================================

zshrc_block() {
  cat <<BLOCK
# >>> macos-scripts >>>
export MQ_ZSH_VARIANT="macos"
source "$INSTALL_DIR/terminal/themes/mq-zsh-theme-v3.zsh"
# <<< macos-scripts <<<
BLOCK
}

remove_managed_zshrc_block() {
  ensure_file "$ZSHRC"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] remove managed block from %q\n' "$ZSHRC"
    return
  fi

  python3 - <<PY
from pathlib import Path
import re

path = Path(r"$ZSHRC")
text = path.read_text() if path.exists() else ""
text = re.sub(
    r'\n?# >>> macos-scripts >>>.*?# <<< macos-scripts <<<\n?',
    '\n',
    text,
    flags=re.S
)
path.write_text(text.rstrip() + '\n' if text.strip() else '')
PY
}

update_managed_zshrc_block() {
  ensure_file "$ZSHRC"

  if [[ -f "$ZSHRC" ]]; then
    local backup="$ZSHRC.backup.$(date +%Y%m%d-%H%M%S)"
    run_cmd cp "$ZSHRC" "$backup"
    ok "Backed up .zshrc to $backup"
  fi

  remove_managed_zshrc_block

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] append managed block to %q\n' "$ZSHRC"
  else
    {
      printf '\n'
      zshrc_block
      printf '\n'
    } >> "$ZSHRC"
  fi

  MANAGED_ZSHRC=1
  ok "Updated managed .zshrc block"
}

# ============================================================
# Onboarding
# ============================================================

run_onboarding() {
  local onboarding="$PROJECT_ROOT/tools/onboarding.sh"

  [[ "$DRY_RUN" -eq 0 ]] || return 0
  [[ "$UNINSTALL" -eq 0 ]] || return 0

  if [[ -x "$onboarding" ]]; then
    "$onboarding"
  elif [[ -f "$onboarding" ]]; then
    chmod +x "$onboarding"
    "$onboarding"
  else
    warn "Onboarding script not found: $onboarding"
  fi
}

# ============================================================
# Uninstall
# ============================================================

remove_install_dir_if_confirmed() {
  if [[ -z "${INSTALL_DIR:-}" ]]; then
    return
  fi

  if [[ ! -d "$INSTALL_DIR" ]]; then
    info "Install dir not present: $INSTALL_DIR"
    return
  fi

  if [[ "${CREATED_INSTALL_DIR:-0}" != "1" ]]; then
    warn "Install dir was not marked as installer-created: $INSTALL_DIR"
    warn "Skipping directory removal for safety"
    return
  fi

  if confirm "Remove installed directory $INSTALL_DIR?"; then
    run_cmd rm -rf "$INSTALL_DIR"
    ok "Removed install directory"
  else
    info "Kept install directory"
  fi
}

uninstall_main() {
  load_state

  info "Uninstalling $APP_NAME"
  printf '\n'

  remove_launcher_link
  remove_managed_zshrc_block
  remove_install_dir_if_confirmed
  remove_state

  printf '\n'
  ok "Uninstall complete"
}

# ============================================================
# Install
# ============================================================

install_main() {
  info "Installing $APP_NAME"
  info "Source repo: $PROJECT_ROOT"
  info "Target dir:  $INSTALL_DIR"
  printf '\n'

  ensure_launcher_exists
  sync_repo_if_needed
  link_launcher
  update_managed_zshrc_block
  ensure_bin_path_hint
  write_state

  printf '\n'
  ok "Installation complete"
  printf '\n'

  run_onboarding
}

# ============================================================
# Main
# ============================================================

main() {
  parse_args "$@"

  if [[ "$UNINSTALL" -eq 1 ]]; then
    uninstall_main
  else
    install_main
  fi
}

main "$@"
