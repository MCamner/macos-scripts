#!/usr/bin/env bash
# Health check for the mqobsidian consumer chain. Read-only — NEVER opens
# anything. Depends on resolve.sh, manifest.sh, errors.sh.

# Coordinates doc ok behavior.
_doc_ok()      { printf '\033[0;32m[OK]\033[0m %s\n' "$*"; }
# Coordinates doc missing behavior.
_doc_missing() { printf '\033[0;31m[MISSING]\033[0m %s\n' "$*"; }
# Coordinates doc invalid behavior.
_doc_invalid() { printf '\033[0;33m[INVALID]\033[0m %s\n' "$*"; }

# Coordinates doctor mqobsidian root behavior.
doctor_mqobsidian_root() {
  local dir
  dir="$(resolve_mqobsidian_dir)"
  if [[ -n "${MQ_OBSIDIAN_DIR:-}" ]]; then
    _doc_ok "MQ_OBSIDIAN_DIR resolved: $dir"
  else
    _doc_invalid "MQ_OBSIDIAN_DIR not set; using fallback: $dir"
  fi
  if [[ ! -d "$dir" ]]; then
    _doc_missing "root does not exist: $dir"
    return 1
  fi
  if is_valid_mqobsidian_root "$dir"; then
    _doc_ok "root looks valid"
  else
    _doc_invalid "root missing expected dirs (systems/, memory/): $dir"
    return 1
  fi
}

# Coordinates doctor mqobsidian manifest behavior.
doctor_mqobsidian_manifest() {
  local mf
  mf="$(get_mqobsidian_manifest_path)"
  if [[ ! -f "$mf" ]]; then
    _doc_missing "manifest not found: $mf"
    return 1
  fi
  if ! jq empty "$mf" >/dev/null 2>&1; then
    _doc_invalid "manifest is not valid JSON: $mf"
    return 1
  fi
  _doc_ok "manifest found: $mf"
}

# Coordinates doctor mqobsidian views behavior.
doctor_mqobsidian_views() {
  local root key rel type path status=0
  root="$(resolve_mqobsidian_dir)"
  while IFS= read -r key; do
    rel="$(resolve_view_relative_path "$key" 2>/dev/null)"
    type="$(resolve_view_type "$key" 2>/dev/null)"
    path="$root/$rel"
    if { [[ "$type" == "folder" && -d "$path" ]] || [[ "$type" == "file" && -f "$path" ]]; }; then
      _doc_ok "view $key -> $rel"
    else
      _doc_missing "view $key -> $rel"
      status=1
    fi
  done < <(list_supported_views)
  return $status
}

# Coordinates doctor mqobsidian open command behavior.
doctor_mqobsidian_open_command() {
  if command -v "${MQOBS_OPENER:-open}" >/dev/null 2>&1; then
    _doc_ok "opener available: ${MQOBS_OPENER:-open}"
  else
    _doc_missing "opener not found: ${MQOBS_OPENER:-open}"
    return 1
  fi
}

# Runs mqobsidian doctor.
run_mqobsidian_doctor() {
  local rc=0
  doctor_mqobsidian_root || rc=1
  doctor_mqobsidian_manifest || rc=1
  doctor_mqobsidian_views || rc=1
  doctor_mqobsidian_open_command || rc=1
  return $rc
}
