#!/usr/bin/env bash
# Read the supported-views manifest (config/mqobsidian/views.json). jq-based,
# read-only. The manifest is the single source for supported views. Depends on
# errors.sh.

# Gets mqobsidian manifest path.
get_mqobsidian_manifest_path() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config/mqobsidian" && pwd)"
  printf '%s\n' "$dir/views.json"
}

# Coordinates list supported views behavior.
list_supported_views() {
  local mf
  mf="$(get_mqobsidian_manifest_path)"
  jq -r '.[].key' "$mf"
}

# Resolves view relative path.
resolve_view_relative_path() {
  local key="$1" mf out
  mf="$(get_mqobsidian_manifest_path)"
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
  mf="$(get_mqobsidian_manifest_path)"
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
  mf="$(get_mqobsidian_manifest_path)"
  jq -r --arg k "$key" '.[] | select(.key==$k) | .label' "$mf"
}
