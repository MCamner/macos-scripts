#!/usr/bin/env bash
# Single source of truth for locating the mqobsidian vault. Read-only.
# The ONLY place that knows how mqobsidian is found. Depends on errors.sh.

resolve_mqobsidian_dir() {
  if [[ -n "${MQ_OBSIDIAN_DIR:-}" ]]; then
    printf '%s\n' "$MQ_OBSIDIAN_DIR"
  else
    printf '%s\n' "$HOME/mqobsidian"   # single fallback in v1 — no path sprawl
  fi
}

is_valid_mqobsidian_root() {
  local dir="$1"
  [[ -d "$dir/systems" && -d "$dir/memory" ]]
}

assert_mqobsidian_dir() {
  local dir
  dir="$(resolve_mqobsidian_dir)"
  if [[ -z "${MQ_OBSIDIAN_DIR:-}" ]]; then
    mqobsidian_warn "MQ_OBSIDIAN_DIR is not set; using fallback: $dir"
  fi
  if [[ ! -d "$dir" ]]; then
    mqobsidian_error "Resolved mqobsidian root does not exist: $dir"
    return 1
  fi
  if ! is_valid_mqobsidian_root "$dir"; then
    mqobsidian_error "Resolved mqobsidian root is missing expected directories (systems/, memory/): $dir"
    return 1
  fi
  printf '%s\n' "$dir"
}
