#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

DEFAULT_INSTALL_DIR="$PROJECT_ROOT"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
BIN_DIR="/usr/local/bin"
STATE_DIR="${HOME}/.local/state/macos-scripts"
STATE_FILE="${STATE_DIR}/install-state.env"
MANAGED_BEGIN="# >>> macos-scripts >>>"
MANAGED_END="# <<< macos-scripts <<<"

DRY_RUN=0
UNINSTALL=0
AUTO_YES=0

LAUNCHER_REL="terminal/launchers/mqlaunch.sh"
ONBOARDING_REL="tools/onboarding.sh"
TARGET_LINK_NAME="mqlaunch"

log()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<EOF
macos-scripts installer

Usage:
  ./install.sh [options]

Options:
  --install-dir PATH   Set repo/install directory reference (default: current repo)
  --bin-dir PATH       Install symlink into this bin dir (default: /usr/local/bin)
  --dry-run            Show actions without changing anything
  --uninstall          Remove symlink and managed shell block
  --yes                Skip confirmation prompts
  -h, --help           Show help

Examples:
  ./install.sh
  ./install.sh --dry-run
  ./install.sh --install-dir "\$HOME/macos-scripts"
  ./install.sh --uninstall
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

realpath_fallback() {
  python3 - <<'PY' "$1"
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

abs_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  else
    realpath_fallback "$p"
  fi
}

run_cmd() {
  if (( DRY_RUN )); then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

confirm() {
  local prompt="${1:-Continue? [y/N]}"
  if (( AUTO_YES )); then
    return 0
  fi
  read -r -p "$prompt " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

ensure_repo_layout() {
  [[ -f "$INSTALL_DIR/$LAUNCHER_REL" ]] || \
    die "Missing $LAUNCHER_REL under $INSTALL_DIR. Run from a full repo checkout or use bootstrap.sh."
  [[ -f "$INSTALL_DIR/$ONBOARDING_REL" ]] || \
    warn "Missing $ONBOARDING_REL under $INSTALL_DIR. Onboarding step will be skipped."
}

ensure_dirs() {
  run_cmd mkdir -p "$STATE_DIR"
}

target_launcher() {
  printf '%s\n' "$INSTALL_DIR/$LAUNCHER_REL"
}

target_link() {
  printf '%s\n' "$BIN_DIR/$TARGET_LINK_NAME"
}

shell_rc_file() {
  if [[ -n "${ZDOTDIR:-}" ]]; then
    printf '%s\n' "$ZDOTDIR/.zshrc"
  else
    printf '%s\n' "$HOME/.zshrc"
  fi
}

write_state() {
  local launcher_path link_path
  launcher_path="$(target_launcher)"
  link_path="$(target_link)"

  if (( DRY_RUN )); then
    log "Would write install state to $STATE_FILE"
    return 0
  fi

  cat > "$STATE_FILE" <<EOF
INSTALL_DIR='$INSTALL_DIR'
BIN_DIR='$BIN_DIR'
TARGET_LINK='$link_path'
TARGET_LAUNCHER='$launcher_path'
EOF
}

read_state_if_present() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

install_symlink() {
  local launcher_path link_path
  launcher_path="$(target_launcher)"
  link_path="$(target_link)"

  [[ -f "$launcher_path" ]] || die "Launcher not found: $launcher_path"

  run_cmd mkdir -p "$BIN_DIR"

  if [[ -L "$link_path" || -e "$link_path" ]]; then
    if [[ "$(abs_path "$link_path" 2>/dev/null || true)" == "$(abs_path "$launcher_path")" ]]; then
      ok "Symlink already correct: $link_path"
      return 0
    fi

    if ! confirm "Replace existing $link_path ? [y/N]"; then
      die "Aborted"
    fi

    run_cmd rm -f "$link_path"
  fi

  run_cmd ln -s "$launcher_path" "$link_path"
  ok "Installed symlink: $link_path -> $launcher_path"
}

managed_block_content() {
  local install_dir_escaped
  install_dir_escaped="$INSTALL_DIR"

  cat <<EOF
$MANAGED_BEGIN
# Added by macos-scripts installer
export MACOS_SCRIPTS_HOME="$install_dir_escaped"
if [ -d "\$MACOS_SCRIPTS_HOME/bin" ] && [[ ":\$PATH:" != *":\$MACOS_SCRIPTS_HOME/bin:"* ]]; then
  export PATH="\$MACOS_SCRIPTS_HOME/bin:\$PATH"
fi
$MANAGED_END
EOF
}

remove_managed_block() {
  local rc_file tmp_file
  rc_file="$(shell_rc_file)"
  [[ -f "$rc_file" ]] || return 0

  tmp_file="$(mktemp)"
  awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
    $0 == begin { skip=1; next }
    $0 == end   { skip=0; next }
    !skip { print }
  ' "$rc_file" > "$tmp_file"

  if (( DRY_RUN )); then
    log "Would remove managed shell block from $rc_file"
    rm -f "$tmp_file"
  else
    mv "$tmp_file" "$rc_file"
    ok "Removed managed shell block from $rc_file"
  fi
}

append_managed_block() {
  local rc_file
  rc_file="$(shell_rc_file)"

  if [[ ! -f "$rc_file" ]]; then
    if (( DRY_RUN )); then
      log "Would create shell rc file: $rc_file"
    else
      : > "$rc_file"
    fi
  fi

  remove_managed_block

  if (( DRY_RUN )); then
    log "Would append managed shell block to $rc_file"
  else
    {
      printf '\n'
      managed_block_content
      printf '\n'
    } >> "$rc_file"
    ok "Updated shell config: $rc_file"
  fi
}

run_onboarding_if_present() {
  local onboarding="$INSTALL_DIR/$ONBOARDING_REL"
  if [[ -x "$onboarding" ]]; then
    if (( DRY_RUN )); then
      log "Would run onboarding: $onboarding"
    else
      "$onboarding" || warn "Onboarding returned non-zero status"
    fi
  else
    warn "Onboarding script not executable or missing: $onboarding"
  fi
}

do_install() {
  ensure_repo_layout
  ensure_dirs

  log "Install dir: $INSTALL_DIR"
  log "Bin dir:     $BIN_DIR"

  install_symlink
  append_managed_block
  write_state
  run_onboarding_if_present

  ok "Installation complete"
  printf '\nNext steps:\n'
  printf '  source "%s"\n' "$(shell_rc_file)"
  printf '  mqlaunch\n'
}

remove_symlink() {
  local link_path
  link_path="${TARGET_LINK:-$(target_link)}"

  if [[ -L "$link_path" || -e "$link_path" ]]; then
    run_cmd rm -f "$link_path"
    ok "Removed: $link_path"
  else
    warn "Nothing to remove at: $link_path"
  fi
}

remove_state() {
  if [[ -f "$STATE_FILE" ]]; then
    run_cmd rm -f "$STATE_FILE"
    ok "Removed state file"
  fi
}

do_uninstall() {
  read_state_if_present
  remove_symlink
  remove_managed_block
  remove_state
  ok "Uninstall complete"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-dir)
        [[ $# -ge 2 ]] || die "Missing value for --install-dir"
        INSTALL_DIR="$2"
        shift 2
        ;;
      --bin-dir)
        [[ $# -ge 2 ]] || die "Missing value for --bin-dir"
        BIN_DIR="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --uninstall)
        UNINSTALL=1
        shift
        ;;
      --yes)
        AUTO_YES=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

main() {
  require_cmd bash
  require_cmd mkdir
  require_cmd ln
  require_cmd rm
  require_cmd awk

  parse_args "$@"

  INSTALL_DIR="$(abs_path "$INSTALL_DIR")"
  BIN_DIR="$(abs_path "$BIN_DIR")"

  if (( UNINSTALL )); then
    do_uninstall
  else
    do_install
  fi
}

main "$@"
