#!/usr/bin/env bash
# Visible-set-only selection for the recommendations menu. The menu must never
# surface hidden/mutating patterns, so every selection resolves against the
# default-visible set — the same set recommendations-list.sh shows — and a typed
# id that is not visible is refused. Read-only. Depends on: errors.sh, parse.sh.

# Echo the selectable (default-visible) pattern ids, in the producer's rank order.
list_selectable_recommendations() {
  rec_visible_ids "$1"   # parse.sh — visible, rank-ordered
}

# Render a numbered index of the selectable patterns:
#   " N. <id>   score S   <name>"
render_selection_index() {
  local path="$1" id i=0
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    i=$((i + 1))
    printf '  %2d. %-28s score %-7s %s\n' \
      "$i" "$id" "$(rec_field "$path" "$id" score)" "$(rec_field "$path" "$id" name)"
  done < <(list_selectable_recommendations "$path")
}

# Refuse a pattern that is not in the default-visible set — guards the menu flow
# against a hidden/mutating id being smuggled in by literal entry.
assert_selected_pattern_is_visible() {
  local path="$1" id="$2"
  if ! rec_pattern_exists "$path" "$id"; then
    rec_error "no such recommendation: $id"
    rec_info "list valid ids with: recommendations-list.sh"
    return 1
  fi
  if ! rec_pattern_visible "$path" "$id"; then
    rec_error "pattern is hidden (non-default risk) and not selectable from the menu: $id"
    rec_info "inspect it directly with: recommendations-show.sh $id"
    return 1
  fi
}

# Map a selection — a 1-based number over the visible set, or a literal id — to a
# pattern id. Echoes the id on success. Non-zero on blank input (silent cancel),
# an out-of-range number, or a non-visible/unknown id (with a precise error).
resolve_selected_pattern_id() {
  local path="$1" sel="$2" ids=() id idx
  [[ -z "${sel// }" ]] && return 1
  while IFS= read -r id; do
    [[ -n "$id" ]] && ids+=("$id")
  done < <(list_selectable_recommendations "$path")

  if [[ "$sel" =~ ^[0-9]+$ ]]; then
    idx=$((sel - 1))
    if (( idx < 0 || idx >= ${#ids[@]} )); then
      rec_error "selection out of range: $sel (1..${#ids[@]})"
      return 1
    fi
    printf '%s\n' "${ids[$idx]}"
    return 0
  fi

  # Literal id — must be in the visible set.
  assert_selected_pattern_is_visible "$path" "$sel" || return 1
  printf '%s\n' "$sel"
}
