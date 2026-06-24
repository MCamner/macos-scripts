#!/usr/bin/env bash
# Single source of truth for locating the producer's recommended.json. Read-only.
#
# The recommendations file is PRODUCED by mqobsidian (build_views.py) and only
# CONSUMED here. We do not generate, rank, or rewrite it. To avoid path sprawl
# we reuse the vault resolver (lib/mqobsidian/resolve.sh) and append the one
# stable relative path the producer writes to.
#
# Override order:
#   1. $MQ_RECOMMENDED_JSON   — explicit absolute path wins
#   2. $MQ_OBSIDIAN_DIR/<rel> — resolved via the shared vault resolver
#   3. clear error            — never guess
#
# Depends on: errors.sh (rec_*), lib/mqobsidian/{errors,resolve}.sh.

_REC_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../mqobsidian/errors.sh
source "$_REC_LIB/../mqobsidian/errors.sh"
# shellcheck source=../mqobsidian/resolve.sh
source "$_REC_LIB/../mqobsidian/resolve.sh"   # provides resolve_mqobsidian_dir

# The single stable output path build_views.py writes to, relative to vault root.
REC_RELATIVE_PATH="memory/commands/mqlaunch/recommended.json"
REC_SCHEMA="command-recommendations.v1"

resolve_recommended_json_path() {
  if [[ -n "${MQ_RECOMMENDED_JSON:-}" ]]; then
    printf '%s\n' "$MQ_RECOMMENDED_JSON"
    return 0
  fi
  local dir
  dir="$(resolve_mqobsidian_dir)"
  printf '%s\n' "$dir/$REC_RELATIVE_PATH"
}

# Guarantee a usable jq, independent of how mqlaunch was launched. Prefer one on
# PATH; otherwise adopt jq from a known absolute location and prepend its dir to
# PATH so every downstream bare `jq` call in this consumer works. This makes the
# feature immune to a stripped launch environment (GUI, non-login shell, a
# wrapper that sanitizes PATH) without relying on the launcher's PATH bootstrap.
# Returns non-zero only if no jq exists in any location we know to look.
rec_ensure_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  local d
  for d in /opt/homebrew/bin /usr/local/bin /usr/bin /bin; do
    if [[ -x "$d/jq" ]]; then
      PATH="$d:$PATH"
      export PATH
      return 0
    fi
  done
  return 1
}

# Ensure jq, or emit the precise error. Call this in an entry point's MAIN shell
# (a command wrapper or the menu) BEFORE any jq use — not inside $(...), or the
# PATH repair dies with the subshell and downstream jq calls still fail.
rec_require_jq() {
  rec_ensure_jq && return 0
  rec_error "jq is required to read recommended.json but was not found"
  rec_info "looked on PATH and in /opt/homebrew/bin, /usr/local/bin, /usr/bin, /bin"
  rec_info "current PATH: ${PATH}"
  return 1
}

# Validate source presence, readability, JSON validity, and schema. Echoes the
# resolved path on success; non-zero with a precise error on any failure. Calls
# rec_require_jq as a self-heal for direct callers, but entry points should call
# rec_require_jq themselves first (in the main shell) so the PATH repair survives.
assert_recommended_json() {
  rec_require_jq || return 1
  local path
  path="$(resolve_recommended_json_path)"
  if [[ ! -f "$path" ]]; then
    rec_error "recommended.json not found: $path"
    rec_info "set MQ_RECOMMENDED_JSON, or MQ_OBSIDIAN_DIR, or run build_views.py in the vault"
    return 1
  fi
  if [[ ! -r "$path" ]]; then
    rec_error "recommended.json is not readable: $path"
    return 1
  fi
  if ! jq -e . "$path" >/dev/null 2>&1; then
    rec_error "recommended.json is not valid JSON: $path"
    return 1
  fi
  local schema
  schema="$(jq -r '.schema // empty' "$path")"
  if [[ "$schema" != "$REC_SCHEMA" ]]; then
    rec_error "unexpected schema: ${schema:-<missing>} (expected $REC_SCHEMA): $path"
    return 1
  fi
  printf '%s\n' "$path"
}
