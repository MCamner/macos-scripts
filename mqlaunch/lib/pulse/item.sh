#!/usr/bin/env bash
# Pulse item model — the one record every collector returns.
#
# The v2.1.0 P1 canonical model: five required fields, five optional ones, and
# a serialization that loses nothing. Human rendering and the machine document
# read the same items, which is what keeps the two from disagreeing about the
# state of the machine.
#
# Items live in one array of records. Each record is a run of `key=value` pairs
# separated by US (0x1f), a byte no field can contain — the alternative,
# separating with a printable character, would break the first time a summary
# held a comma or a path held a colon. Values keep whatever the collector put in
# them; escaping is JSON's problem and is done by python3 at serialization
# rather than by hand in shell.
#
# Sourced by the collectors and by tools/scripts/pulse.sh. It reads nothing
# about the machine and prints nothing on its own.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/model.sh"

PULSE_ITEM_US=$'\x1f'
# Read by the files that source this one — attention.sh sorts on it and
# document.sh joins records with it — which shellcheck cannot see from here.
# shellcheck disable=SC2034
PULSE_ITEM_RS=$'\x1e'

# The fields a collector must supply, in the order pulse_item_add takes them.
PULSE_ITEM_REQUIRED=(source area status subject summary)

# The fields it may supply, as `key=value` after the required five.
#
# `evidence` is what the collector saw, `next_command` an existing command to
# run — never a new one, per docs/PULSE_CONTRACT.md. `priority` orders the
# attention list and defaults to 0: deriving one from the status would be the
# attention engine, which is a later block and belongs to it. `freshness` and
# `duration_ms` are the optional metadata the model calls for, carried on the
# item that knows them rather than in a table beside it.
# `dedupe_key` is how two collectors say they are looking at the same thing.
# The repositories collector and the Git collector both notice that this
# checkout is dirty, from opposite ends — one walking the MQ repos, one reading
# the repo mqlaunch is running in — and the attention list should raise that
# once. The alternative is for the attention engine to guess which rows describe
# one problem, which is exactly the kind of conclusion Pulse does not get to
# reach: the collector knows what it read, so the collector says so.
PULSE_ITEM_OPTIONAL=(evidence next_command priority freshness duration_ms dedupe_key)

PULSE_ITEMS=()

# Empties the item list. Called by the entrypoint, and by every test that builds
# a run of its own.
pulse_items_reset() {
  PULSE_ITEMS=()
}

# Appends one item.
#
#   pulse_item_add SOURCE AREA STATUS SUBJECT SUMMARY [key=value ...]
#
# Refuses rather than records when a required field is empty, when the status is
# not one of the five, or when an optional key is not one this model defines. A
# collector that fabricates a field name would otherwise have it silently
# carried into the JSON document as though the contract allowed it.
pulse_item_add() {
  if [[ $# -lt 5 ]]; then
    printf 'pulse: item needs %s\n' "${PULSE_ITEM_REQUIRED[*]}" >&2
    return 1
  fi

  local -a values=("$1" "$2" "$3" "$4" "$5")
  shift 5

  local index=0 field
  for field in "${PULSE_ITEM_REQUIRED[@]}"; do
    if [[ -z "${values[$index]}" ]]; then
      printf 'pulse: item field %s is empty\n' "$field" >&2
      return 1
    fi
    index=$((index + 1))
  done

  if ! pulse_state_is_valid "${values[2]}"; then
    printf 'pulse: item status is not a Pulse state: %s\n' "${values[2]}" >&2
    return 1
  fi

  local record=""
  index=0
  for field in "${PULSE_ITEM_REQUIRED[@]}"; do
    record+="${field}=${values[$index]}${PULSE_ITEM_US}"
    index=$((index + 1))
  done

  local pair key known
  for pair in "$@"; do
    if [[ "$pair" != *=* ]]; then
      printf 'pulse: optional item field must be key=value, got: %s\n' "$pair" >&2
      return 1
    fi
    key="${pair%%=*}"
    known=0
    for field in "${PULSE_ITEM_OPTIONAL[@]}"; do
      [[ "$key" == "$field" ]] && known=1 && break
    done
    if [[ $known -eq 0 ]]; then
      printf 'pulse: unknown item field: %s\n' "$key" >&2
      return 1
    fi
    record+="${pair}${PULSE_ITEM_US}"
  done

  PULSE_ITEMS+=("$record")
}

# Prints one field of one item, empty when the item does not carry it.
pulse_item_field() {
  local record="$1" key="$2" pair
  local saved_ifs="$IFS"
  IFS="$PULSE_ITEM_US"
  # shellcheck disable=SC2206  # deliberate split on US, the record separator
  local -a pairs=($record)
  IFS="$saved_ifs"
  for pair in "${pairs[@]}"; do
    if [[ "${pair%%=*}" == "$key" ]]; then
      printf '%s' "${pair#*=}"
      return 0
    fi
  done
  printf ''
}

# Prints the status of every item, one per line — the input pulse_overall_state
# and pulse_run_exit_code take.
pulse_items_states() {
  local record
  for record in "${PULSE_ITEMS[@]}"; do
    printf '%s\n' "$(pulse_item_field "$record" status)"
  done
}

# Serialization lives in document.sh, which turns these records into the public
# `mq.pulse.v1` document.
#
# Records are joined with RS (0x1e) and their pairs with US (0x1f), so the split
# is unambiguous in both directions. Neither byte can appear in a value — the
# first alternative tried here was to infer a record boundary from seeing the
# `source` key again, which is a heuristic, and a heuristic in a serializer
# fails on the first item that omits a field.
