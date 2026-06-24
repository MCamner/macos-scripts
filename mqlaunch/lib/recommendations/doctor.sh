#!/usr/bin/env bash
# Health check for the recommendations consumer. Read-only — opens/executes
# nothing, never writes. Non-zero exit on any hard problem (missing/unreadable/
# invalid/wrong-schema source). Depends on: errors.sh, resolve.sh, parse.sh.
: "${REC_JQ:=jq}"

run_recommendations_doctor() {
  local path
  if ! path="$(assert_recommended_json)"; then
    return 1   # assert_* already emitted the precise reason
  fi
  rec_ok "recommended.json found: $path"
  rec_ok "schema: $("$REC_JQ" -r '.schema' "$path")  (generated_at: $("$REC_JQ" -r '.generated_at // "?"' "$path"))"
  rec_ok "allowed actions: $(rec_allowed_actions "$path")"

  local total visible hidden
  total="$(rec_total_count "$path")"
  visible="$(rec_visible_count "$path")"
  hidden=$(( total - visible ))
  rec_ok "$total patterns total"
  rec_ok "$visible visible (risk: $(rec_default_visible_risk "$path"))"
  if [[ "$hidden" -gt 0 ]]; then
    rec_warn "$hidden hidden (non-default risk, e.g. mutating) — opt-in only"
  fi
  if [[ "$visible" -eq 0 ]]; then
    rec_warn "no visible recommendations — list will show the empty state"
  fi
  return 0
}
