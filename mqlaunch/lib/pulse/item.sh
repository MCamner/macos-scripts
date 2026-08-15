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
PULSE_ITEM_OPTIONAL=(evidence next_command priority freshness duration_ms)

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

# Prints the run as one JSON document on stdout.
#
# python3 does the escaping. Building JSON by hand in shell is where a summary
# containing a quote turns a status command into invalid output, and this repo
# already requires JSON mode to print exactly one valid document.
#
# Records are joined with RS (0x1e) and their pairs with US (0x1f), so the split
# is unambiguous in both directions. Neither byte can appear in a value — the
# first alternative tried here was to infer a record boundary from seeing the
# `source` key again, which is a heuristic, and a heuristic in a serializer
# fails on the first item that omits a field.
#
# The `--json` flag itself belongs to a later block; this is here now because
# the model has to be provably lossless before collectors start filling it.
pulse_items_json() {
  local overall
  overall="$(pulse_overall_state < <(pulse_items_states))" || return 3

  local record joined=""
  for record in "${PULSE_ITEMS[@]}"; do
    joined+="${record}${PULSE_ITEM_RS}"
  done

  printf '%s' "$joined" | PULSE_OVERALL="$overall" python3 -c '
import json, os, sys

RS, US = "\x1e", "\x1f"
raw = sys.stdin.read()

items = []
for record in raw.split(RS):
    if not record:
        continue
    item = {}
    for pair in record.split(US):
        if not pair:
            continue
        key, _, value = pair.partition("=")
        item[key] = value
    # The two numeric fields are carried as text through shell and restored
    # here, so a consumer sorting on priority compares numbers rather than
    # strings — where "9" would sort above "80".
    for numeric in ("priority", "duration_ms"):
        if numeric in item and item[numeric].lstrip("-").isdigit():
            item[numeric] = int(item[numeric])
    item.setdefault("priority", 0)
    items.append(item)

print(json.dumps({"overall": os.environ["PULSE_OVERALL"], "items": items}, indent=2))
'
}
