#!/usr/bin/env bash
# Open a manifest-defined target. Read-only navigation only. Depends on
# resolve.sh, manifest.sh, errors.sh.

build_view_absolute_path() {
  local key="$1" root rel
  root="$(assert_mqobsidian_dir)" || return 1
  rel="$(resolve_view_relative_path "$key")" || return 1
  printf '%s/%s\n' "$root" "$rel"
}

assert_view_target_exists() {
  local key="$1" path type
  path="$(build_view_absolute_path "$key")" || return 1
  type="$(resolve_view_type "$key")" || return 1
  if [[ "$type" == "folder" && ! -d "$path" ]]; then
    mqobsidian_error "Target path from manifest does not exist (folder): $path"
    return 1
  fi
  if [[ "$type" == "file" && ! -f "$path" ]]; then
    mqobsidian_error "Target path from manifest does not exist (file): $path"
    return 1
  fi
  printf '%s\n' "$path"
}

# The single place that invokes the OS opener. Override MQOBS_OPENER (e.g. to
# `echo`) for tests, or to route to an editor later.
open_mqobsidian_path() {
  local path="$1"
  "${MQOBS_OPENER:-open}" "$path"
}

open_mqobsidian_target() {
  local key="$1" path
  path="$(assert_view_target_exists "$key")" || return 1
  mqobsidian_info "Opening $key → $path"
  open_mqobsidian_path "$path"
}
