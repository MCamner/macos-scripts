#!/usr/bin/env bash
# Read the supported-views manifest (config/mqobsidian/views.json). jq-based,
# read-only. The manifest is the single source for supported views. Depends on
# errors.sh.

# Resolved here, at source time, and not inside the function below.
#
# bin/mqlaunch is bash but the interactive launcher is zsh, and zsh has no
# BASH_SOURCE — so reading it per call made command mode work and the menu
# fail. Source time is the only moment either shell can still say where this
# file lives: inside a zsh function $0 holds the function name, not the path.
# Same idiom as ui/terminal-ui/mq-ui.sh; `-` rather than `:-` so it survives a
# caller running under `set -u`.
_mqobs_manifest_self="${BASH_SOURCE[0]-}"
[ -n "$_mqobs_manifest_self" ] || _mqobs_manifest_self="$0"
_MQOBS_MANIFEST_DIR="$(cd "$(dirname "$_mqobs_manifest_self")/../../config/mqobsidian" 2>/dev/null && pwd)"
unset _mqobs_manifest_self

# Gets mqobsidian manifest path.
get_mqobsidian_manifest_path() {
  if [[ -z "${_MQOBS_MANIFEST_DIR:-}" ]]; then
    mqobsidian_error "Manifest directory not found: expected mqlaunch/config/mqobsidian next to the consumer lib"
    return 1
  fi
  printf '%s\n' "$_MQOBS_MANIFEST_DIR/views.json"
}

# jq reads the manifest, so a missing jq means no view resolves at all. Without
# this the failure surfaced two steps later as "view key is not defined", which
# sends the operator to inspect views.json instead of their PATH.
_mqobs_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  mqobsidian_error "jq is required to read views.json. Install: brew install jq"
  return 1
}

# Coordinates list supported views behavior.
list_supported_views() {
  local mf
  _mqobs_require_jq || return 1
  mf="$(get_mqobsidian_manifest_path)" || return 1
  jq -r '.[].key' "$mf"
}

# Resolves view relative path.
resolve_view_relative_path() {
  local key="$1" mf out
  _mqobs_require_jq || return 1
  mf="$(get_mqobsidian_manifest_path)" || return 1
  out="$(jq -r --arg k "$key" '.[] | select(.key==$k) | .relative_path' "$mf")"
  if [[ -z "$out" ]]; then
    mqobsidian_error "Requested view key is not defined in views.json: $key"
    return 1
  fi
  printf '%s\n' "$out"
}

# Resolves view type.
resolve_view_type() {
  local key="$1" mf out
  _mqobs_require_jq || return 1
  mf="$(get_mqobsidian_manifest_path)" || return 1
  out="$(jq -r --arg k "$key" '.[] | select(.key==$k) | .type' "$mf")"
  if [[ -z "$out" ]]; then
    mqobsidian_error "Requested view key is not defined in views.json: $key"
    return 1
  fi
  printf '%s\n' "$out"
}

# Resolves view label.
resolve_view_label() {
  local key="$1" mf
  _mqobs_require_jq || return 1
  mf="$(get_mqobsidian_manifest_path)" || return 1
  jq -r --arg k "$key" '.[] | select(.key==$k) | .label' "$mf"
}
