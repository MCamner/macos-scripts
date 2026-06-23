#!/usr/bin/env bash
# Read-only accessors over recommended.json. All queries go through jq — we do
# NOT re-implement ranking or scoring here; the producer already baked rank,
# score, signals, and ordered slices into the file. We only read them.
#
# Visibility honors the file's own contract: only patterns whose risk_class is
# in .default_visible_risk are listed by default (mutating patterns are hidden,
# exactly as the producer intends). Depends on: errors.sh.

# Echo default-visible pattern ids, ordered by the producer's rank.
rec_visible_ids() {
  local path="$1"
  jq -r '
    .default_visible_risk as $vr
    | [ .patterns[] | select(.risk_class as $r | $vr | index($r)) ]
    | sort_by(.rank)
    | .[].id
  ' "$path"
}

# Count of default-visible patterns.
rec_visible_count() {
  local path="$1"
  jq '[ .default_visible_risk as $vr | .patterns[] | select(.risk_class as $r | $vr | index($r)) ] | length' "$path"
}

# Total pattern count (including hidden / non-default risk).
rec_total_count() { jq '.patterns | length' "$1"; }

# True if a pattern_id exists in the file at all (visible or not).
rec_pattern_exists() {
  local path="$1" id="$2"
  jq -e --arg id "$id" 'any(.patterns[]; .id == $id)' "$path" >/dev/null 2>&1
}

# Echo a single scalar field for a pattern (empty if absent).
rec_field() {
  local path="$1" id="$2" field="$3"
  jq -r --arg id "$id" --arg f "$field" '
    .patterns[] | select(.id == $id) | .[$f] // empty
  ' "$path"
}

# Echo the contract's allowed actions, comma-joined (e.g. "show, copy").
rec_allowed_actions() { jq -r '.allowed_actions | join(", ")' "$1"; }

# Echo the contract's default-visible risk classes, comma-joined.
rec_default_visible_risk() { jq -r '.default_visible_risk | join(", ")' "$1"; }
