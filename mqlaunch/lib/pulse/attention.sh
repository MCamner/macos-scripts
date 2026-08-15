#!/usr/bin/env bash
# Pulse attention engine — which of the run's findings to put in front of the
# operator, and in what order.
#
# It reads Pulse items and nothing else. No command, no file, no probe of its
# own: every state it orders was already collected, normalized and gated one
# level down. That restriction is the point. PR 2 and PR 3 each turned up a
# defect of the same family — a command failed, its output was empty, and empty
# read as healthy — and an engine that did its own reading would be a fresh
# place for that to happen, one level further from the collectors the contract
# holds.
#
# It also decides nothing about the world. It orders findings and repeats the
# `next_command` an item already carried; it never turns a technical state into
# a course of action nobody published. "Stack truth is stale, run
# `mqlaunch stack truth-export`" is ordering plus a command the item supplied.
# "Merge PR #184 now" would be this file deciding something, and it cannot: it
# has no verb for it.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/item.sh"

# How many findings the default view shows before it starts counting.
PULSE_ATTENTION_LIMIT="${PULSE_ATTENTION_LIMIT:-5}"

# The rank of a finding, lowest first — the roadmap's priority order, expressed
# as the only thing the engine can read: an item's status, area and subject.
#
#   10  FAIL, wherever it came from
#   15  security or destructive risk
#   20  broken runtime
#   30  failing CI
#   40  repo divergence
#   50  stale state
#   60  maintenance
#
# Rank 15 is real and unreachable. No collector reports a security or
# destructive-risk signal today, and inventing one to fill the row would be the
# engine deciding something. The rank stays because the order is the contract;
# when a collector starts publishing that signal it has a place to land, and
# until then nothing sorts into it.
pulse_attention_rank() {
  local status="$1" area="$2" subject="$3"

  [[ "$status" == "FAIL" ]] && { printf '10'; return 0; }

  case "$area" in
    system)
      printf '20' ;;
    git)
      case "$subject" in
        CI)        printf '30' ;;
        *)         printf '40' ;;
      esac
      ;;
    repositories)
      printf '40' ;;
    memory|stack)
      printf '50' ;;
    *)
      printf '60' ;;
  esac
}

# The findings of a run, in the order they should be read.
#
# Prints one item record per line, most important first. WARN, FAIL and
# UNAVAILABLE qualify; PASS and SKIPPED do not.
#
# UNAVAILABLE is here although the roadmap's task says "all WARN and FAIL". A
# run holding one unreachable collector and nothing else reports WARN, so an
# attention list without it would be empty under a heading that says something
# needs attention — the screen contradicting its own verdict. The model already
# ranks UNAVAILABLE with WARN; this follows it rather than the sentence.
#
# Deterministic to the last comparison: rank, then the item's own `priority`
# (higher first, and nothing sets it yet), then area, then subject. Two runs
# over the same items produce the same list in the same order.
pulse_attention_list() {
  local record status area subject priority rank
  local -a lines=()

  for record in "${PULSE_ITEMS[@]}"; do
    status="$(pulse_item_field "$record" status)"
    case "$status" in
      WARN|FAIL|UNAVAILABLE) ;;
      *) continue ;;
    esac

    area="$(pulse_item_field "$record" area)"
    subject="$(pulse_item_field "$record" subject)"
    priority="$(pulse_item_field "$record" priority)"
    [[ -z "$priority" ]] && priority=0
    rank="$(pulse_attention_rank "$status" "$area" "$subject")"

    # Sort key first, record second, separated by the record separator so the
    # key cannot collide with anything inside the record.
    lines+=("$(printf '%03d\t%03d\t%s\t%s%s%s' \
      "$rank" "$((999 - priority))" "$area" "$subject" "$PULSE_ITEM_RS" "$record")")
  done

  [[ "${#lines[@]}" -eq 0 ]] && return 0

  # LC_ALL=C so the ordering does not change with the operator's locale, which
  # would make "deterministic" true only on one machine.
  local sorted seen key
  sorted="$(printf '%s\n' "${lines[@]}" | LC_ALL=C sort)"

  seen=""
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    record="${line#*"$PULSE_ITEM_RS"}"

    # Deduplication happens on the key a collector supplied, never on a
    # resemblance this engine noticed. An item with no key is always kept: two
    # findings that look alike are not evidence that they are the same finding,
    # and dropping one on that basis would hide a real problem.
    key="$(pulse_item_field "$record" dedupe_key)"
    if [[ -n "$key" ]]; then
      case "$seen" in
        *"${PULSE_ITEM_RS}${key}${PULSE_ITEM_RS}"*) continue ;;
      esac
      seen="${seen}${PULSE_ITEM_RS}${key}${PULSE_ITEM_RS}"
    fi

    printf '%s\n' "$record"
  done <<< "$sorted"
}

# How many findings the run holds, after deduplication.
pulse_attention_count() {
  local count=0
  while IFS= read -r line; do
    [[ -n "$line" ]] && count=$((count + 1))
  done < <(pulse_attention_list)
  printf '%d' "$count"
}
