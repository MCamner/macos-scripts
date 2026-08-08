#!/usr/bin/env bash
# Open a manifest-defined target. Read-only navigation only. Depends on
# resolve.sh, manifest.sh, errors.sh.

# Builds view absolute path for later command execution.
build_view_absolute_path() {
  local key="$1" root rel
  root="$(assert_mqobsidian_dir)" || return 1
  rel="$(resolve_view_relative_path "$key")" || return 1
  printf '%s/%s\n' "$root" "$rel"
}

# `target`, never `path`: in zsh $path is a special array tied to $PATH, so a
# `local path` blanks PATH for the whole call tree. That is what made menu
# option 3 report "command not found: jq" on a machine with jq installed —
# resolve_view_relative_path ran inside a function that had shadowed PATH.
# Same family as the read-only $status trap.
assert_view_target_exists() {
  local key="$1" target type
  target="$(build_view_absolute_path "$key")" || return 1
  type="$(resolve_view_type "$key")" || return 1
  if [[ "$type" == "folder" && ! -d "$target" ]]; then
    mqobsidian_error "Target path from manifest does not exist (folder): $target"
    return 1
  fi
  if [[ "$type" == "file" && ! -f "$target" ]]; then
    mqobsidian_error "Target path from manifest does not exist (file): $target"
    return 1
  fi
  printf '%s\n' "$target"
}

# The single place that invokes the OS opener. Override MQOBS_OPENER (e.g. to
# `echo`) for tests, or to route to an editor later.
open_mqobsidian_path() {
  local target="$1"
  "${MQOBS_OPENER:-open}" "$target"
}

# Opens mqobsidian target.
open_mqobsidian_target() {
  local key="$1" target
  target="$(assert_view_target_exists "$key")" || return 1
  mqobsidian_info "Opening $key → $target"
  open_mqobsidian_path "$target"
}
