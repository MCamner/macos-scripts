#!/usr/bin/env bash
# Presentation for the recommendations consumer. Read-only — renders to stdout,
# opens/executes nothing. Depends on: errors.sh, parse.sh.

# Compact, rank-ordered list of default-visible patterns.
render_recommendations_list() {
  local path="$1"
  printf 'Recommended command patterns — %s, by rank (read-only)\n' "$(rec_default_visible_risk "$path")"
  printf -- '-------------------------------------------------------------\n'
  jq -r '
    .default_visible_risk as $vr
    | [ .patterns[] | select(.risk_class as $r | $vr | index($r)) ]
    | sort_by(.rank)
    | .[]
    | "  #\(.rank)  \(.id)  ·  score \(.score)\n       \(.name)\n       use when: \(.use_when)"
  ' "$path"

  local total visible hidden
  total="$(rec_total_count "$path")"
  visible="$(rec_visible_count "$path")"
  hidden=$(( total - visible ))
  printf -- '-------------------------------------------------------------\n'
  printf '%s of %s shown' "$visible" "$total"
  if [[ "$hidden" -gt 0 ]]; then
    printf ' · %s hidden (non-default risk, e.g. mutating)' "$hidden"
  fi
  printf '\n'
  printf 'detail: recommendations-show.sh <pattern_id>   (actions: %s)\n' "$(rec_allowed_actions "$path")"
}

# Full detail for one pattern. Renders the command_template for show/copy only —
# it is never executed by this consumer.
render_recommendation_detail() {
  local path="$1" id="$2"
  jq -r --arg id "$id" '
    .patterns[] | select(.id == $id) |
    "Pattern:    \(.id)",
    "Name:       \(.name)",
    "Risk:       \(.risk_class)        Scope: \(.repo_scope)",
    "Rank/score: #\(.rank)  ·  \(.score)        Tags: \(.task_tags | join(", "))",
    "",
    .description,
    "",
    "Use when:   \(.use_when)",
    "Avoid when: \(.avoid_when)",
    (if .preconditions then "Preconditions: \(.preconditions)" else empty end),
    (if .recovery then "Recovery:   \(.recovery)" else empty end),
    "",
    "Command template (show / copy only — not executed by mqlaunch):",
    "  \(.command_template)",
    "",
    "Signals: frequency=\(.signals.frequency)  success=\(.signals.success // "n/a")  reuse=\(.signals.reuse)  prior_n=\(.signals.prior_n)"
  ' "$path"
}

# Deliberate empty state — distinguishes "no recommendations yet" from "broken".
render_empty_recommendations_state() {
  local path="$1"
  printf 'No recommended patterns are currently visible.\n'
  printf 'The file resolved and parsed cleanly — there just is nothing to show.\n'
  printf '  source: %s\n' "$path"
  printf '  next:   add observations + run build_views.py in the vault to populate it.\n'
}
