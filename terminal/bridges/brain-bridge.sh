#!/usr/bin/env bash

# MQ Brain bridge
# Thin bridge from mqlaunch to the mqobsidian second brain vault.
#
# Rule:
#   mqlaunch owns UX.
#   mq-mcp/obsidian_writer owns writes.
#   This bridge only opens vault views — it never writes.

if [[ -z "${BASE_DIR:-}" ]]; then
  BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
fi

MQ_OBSIDIAN_DIR="${MQ_OBSIDIAN_DIR:-$HOME/mqobsidian}"
MQ_OBSIDIAN_VAULT_NAME="${MQ_OBSIDIAN_VAULT_NAME:-mqobsidian}"

mq_brain_available() {
  [[ -d "$MQ_OBSIDIAN_DIR" ]]
}

_brain_open_file() {
  local rel="$1"
  local abs="$MQ_OBSIDIAN_DIR/$rel"

  if [[ ! -f "$abs" && ! -d "$abs" ]]; then
    echo "[brain] Not found: $rel" >&2
    return 1
  fi

  # Try Obsidian URI first; fall back to open
  local uri_path
  uri_path="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$rel" 2>/dev/null || echo "$rel")"

  if open "obsidian://open?vault=${MQ_OBSIDIAN_VAULT_NAME}&file=${uri_path}" 2>/dev/null; then
    return 0
  fi

  open "$abs"
}

_brain_open_folder() {
  local rel="$1"
  local abs="$MQ_OBSIDIAN_DIR/$rel"

  if [[ ! -d "$abs" ]]; then
    echo "[brain] Folder not found: $rel" >&2
    return 1
  fi

  open "$abs"
}

mq_brain_usage() {
  cat <<'USAGE'
MQ Brain — second brain vault commands

Usage:
  mqlaunch brain                   # open vault dashboard
  mqlaunch brain note              # open inbox (drop notes here)
  mqlaunch brain sessions          # open sessions folder
  mqlaunch brain decisions         # open decisions / ADRs folder
  mqlaunch brain reviews           # open reviews folder
  mqlaunch brain learn             # open learned patterns folder (inbox)
  mqlaunch brain verified          # open learn/verified/ (curated patterns)
  mqlaunch brain systems           # open systems/ (per-repo knowledge hubs)
  mqlaunch brain vault             # open vault root in Finder
  mqlaunch stack                   # open mq-stack release status (05_RELEASE_STATUS.md)
  mqlaunch roadmap                 # open mq-stack roadmap (01_ROADMAP.md)

Vault: ~/mqobsidian
Owner: mq-mcp writes — mqlaunch only reads/opens
USAGE
}

mq_brain_run() {
  if ! mq_brain_available; then
    echo "[brain] Vault not found: $MQ_OBSIDIAN_DIR" >&2
    echo "        Create it or set MQ_OBSIDIAN_DIR." >&2
    return 1
  fi

  local subcmd="${1:-}"
  shift || true

  case "$subcmd" in
    ""|dashboard)
      _brain_open_file "home/dashboard.md"
      ;;
    note|inbox)
      _brain_open_folder "inbox"
      ;;
    sessions|session)
      _brain_open_folder "sessions"
      ;;
    decisions|decision)
      _brain_open_folder "decisions"
      ;;
    reviews|review)
      _brain_open_folder "reviews"
      ;;
    learn|patterns)
      _brain_open_folder "learn"
      ;;
    verified)
      _brain_open_folder "learn/verified"
      ;;
    systems|system)
      _brain_open_folder "systems"
      ;;
    stack|mq-stack)
      _brain_open_file "mq-stack/05_RELEASE_STATUS.md"
      ;;
    roadmap)
      _brain_open_file "mq-stack/01_ROADMAP.md"
      ;;
    vault|root)
      open "$MQ_OBSIDIAN_DIR"
      ;;
    help|-h|--help)
      mq_brain_usage
      ;;
    *)
      echo "[brain] Unknown subcommand: $subcmd" >&2
      mq_brain_usage >&2
      return 1
      ;;
  esac
}
