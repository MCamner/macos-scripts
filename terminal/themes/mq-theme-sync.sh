#!/usr/bin/env bash
# Exact-match theme sync between the zsh prompt and the terminal UI palette.
#
# The two surfaces are separate systems with overlapping but unequal
# vocabularies:
#
#   prompt (mq-zsh-theme-switcher.sh)  amber green ice  minimal macos
#   UI     (mq-theme-manager.sh)       amber green ice  classic synth
#
# Sync is exact-match ONLY. A name both sides know changes both. A name only
# one side knows changes only that side, and the other is left exactly as the
# user set it.
#
# Nothing is translated. `minimal -> classic` and `macos -> ice` are the
# obvious-looking mappings, and both are product decisions wearing the clothes
# of an implementation detail: `macos -> ice` would make two prompt themes
# indistinguishable in the UI, and `minimal -> classic` asserts a visual
# relationship nobody has established. `synth` stays legitimately UI-only
# rather than being pressed into a prompt it has no form for.
#
# If the taxonomies should converge, that is a product decision to make once —
# not a table of aliases that grows one plausible guess at a time.

# The names both surfaces know. tests/theme-exact-sync-smoke.sh fails if this
# is not exactly the overlap of the two `list` outputs, so adding a theme to
# one side alone cannot silently change what syncs.
MQ_THEME_SHARED="amber green ice"

# Answers whether a theme name exists on both surfaces.
mq_theme_shared() {
  local name="$1" candidate
  for candidate in $MQ_THEME_SHARED; do
    [[ "$candidate" == "$name" ]] && return 0
  done
  return 1
}

# Applies the counterpart surface for a shared name, and says what happened.
#
# MQ_THEME_SYNC_ACTIVE marks a run that is itself the result of a sync. Both
# surfaces call each other, so without it `apply amber` on either side would
# bounce between the two scripts forever.
#
# A counterpart that is missing or fails does not fail the caller: the change
# the user actually asked for has already been written, and a sync that could
# not run is reported rather than swallowed.
mq_theme_sync_counterpart() { # NAME SCRIPT LABEL
  local name="$1" script="$2" label="$3"

  [[ -z "${MQ_THEME_SYNC_ACTIVE:-}" ]] || return 0
  mq_theme_shared "$name" || return 0

  if [[ ! -x "$script" ]]; then
    printf '%s theme not synced: %s is missing\n' "$label" "$script"
    return 0
  fi

  if MQ_THEME_SYNC_ACTIVE=1 "$script" apply "$name" >/dev/null 2>&1; then
    printf 'Also applied %s theme: %s\n' "$label" "$name"
  else
    printf '%s theme not synced: %s apply %s failed\n' "$label" "$script" "$name"
  fi
  return 0
}

# Resets the counterpart surface, under the same rule that governs apply: touch
# the other surface only where the two are actually coupled.
#
# Coupled means both currently hold the same shared name — the state `apply`
# leaves behind. Reset then undoes what apply did. When the two hold different
# themes the user set them separately, and clearing a UI theme they chose on its
# own would be this command reaching outside what it was asked to undo.
mq_theme_reset_counterpart() { # MINE THEIRS SCRIPT LABEL
  local mine="$1" theirs="$2" script="$3" label="$4"

  [[ -z "${MQ_THEME_SYNC_ACTIVE:-}" ]] || return 0
  [[ -n "$mine" && "$mine" == "$theirs" ]] || return 0
  mq_theme_shared "$mine" || return 0

  if [[ ! -x "$script" ]]; then
    printf '%s theme not reset: %s is missing\n' "$label" "$script"
    return 0
  fi

  if MQ_THEME_SYNC_ACTIVE=1 "$script" reset >/dev/null 2>&1; then
    printf 'Also reset %s theme\n' "$label"
  else
    printf '%s theme not reset: %s reset failed\n' "$label" "$script"
  fi
  return 0
}
