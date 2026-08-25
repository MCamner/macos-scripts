#!/usr/bin/env bash
# `mq.next.v1` — one deterministic next action, selected from `mq.pulse.v1`.
#
# This file is a selector and nothing else. It reads the machine document Pulse
# publishes and returns one item from it. It performs no scanning, holds no
# signals, and — the rule the whole design rests on — applies no ordering of its
# own:
#
#   Pulse observes -> Attention prioritizes -> Next selects
#
# The tempting bug is a re-rank. An operator asking "what do I do next" wants
# something concrete, and `attention[0]` is sometimes UNAVAILABLE — a gap in the
# observation rather than a broken subject — while a real FAIL sits below it.
# Skipping past it looks like helpfulness and is a second operator model: two
# commands in one repo would then disagree about what matters most, and the one
# with the shorter name would win the argument by being typed more often. If
# Pulse ranks an observation gap first, that gap is the next thing to look at.
#
# What this file does decide is the difference between three absences, which is
# the same distinction docs/PULSE_CONTRACT.md is built to keep, one level up:
#
#   attention empty, run measured something  = nothing actionable   NONE
#   attention empty, run measured nothing    = could not measure    UNAVAILABLE
#   document missing or malformed            = could not reach      UNAVAILABLE
#
# The middle case is the one that hides. A run where every check was SKIPPED
# (`--no-stack --no-network`) publishes a valid, well-formed document with an
# empty attention list, so a selector reading only `attention` reports "no next
# action" about a machine it never looked at. `status` is what separates them.

NEXT_SCHEMA="mq.next.v1"

# Whether the document at PATH may stand in for a run this command would
# otherwise make, and how old it is if so.
#
#   next_reusable_age PATH MAX_AGE_SECONDS
#
# Prints the age in whole seconds and returns 0 when the document may be reused;
# prints nothing and returns 1 otherwise. Silent on both paths: a cache miss is
# not a diagnostic, it is the ordinary case on a machine where nobody has run
# Pulse lately.
#
# This is the reader half of the freshness contract, and it is here rather than
# in Pulse for the reason docs/PULSE_CONTRACT.md gives: Pulse can state the age
# of an observation but cannot know what the answer is for, so the tolerance is
# declared by whoever is about to answer something with it.
#
# Four conditions, and three of them are about completeness rather than time:
#
#   a full scope      a scoped run measured one area, not six
#   no --no-stack     a run that skipped the stack cannot report on it
#   no --no-network   the same, one delegate over
#   young enough      the caller declares how young
#
# The asymmetry is deliberate. A complete document can answer a narrower question
# and a narrow one cannot answer a complete question, so completeness is checked
# against what this command always asks for: everything.
#
# The document is re-checked here even though only a complete run is stored. What
# reached the slot is the writer's claim; what is safe to answer with is this
# side, and a document that arrived by some other route still has to answer for
# itself.
next_reusable_age() {
  local path="${1:-}" max_age="${2:-0}"

  [[ -f "$path" ]] || return 1

  MAX_AGE="$max_age" python3 - "$path" <<'PY_REUSE'
import datetime
import json
import os
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        doc = json.load(handle)
except (OSError, json.JSONDecodeError):
    # A half-written or foreign file is a miss, not an error. The caller
    # collects, which is what it would have done with no file at all.
    sys.exit(1)

if not isinstance(doc, dict) or doc.get("schema") != "mq.pulse.v1":
    sys.exit(1)

if doc.get("scope") is not None:
    sys.exit(1)

conditions = doc.get("conditions")
if not isinstance(conditions, dict):
    # A document from before the freshness contract carries no conditions and no
    # stamp. It cannot be aged or vouched for, so it is not reused.
    sys.exit(1)
if conditions.get("no_stack") or conditions.get("no_network"):
    sys.exit(1)

stamp = doc.get("collected_at")
if not isinstance(stamp, str):
    sys.exit(1)
try:
    collected = datetime.datetime.fromisoformat(stamp)
except ValueError:
    sys.exit(1)
if collected.utcoffset() is None:
    sys.exit(1)

age = (datetime.datetime.now().astimezone() - collected).total_seconds()
# A document stamped in the future is a clock that moved, not a fresh run.
# Treating it as young would make the reuse window unbounded in one direction.
if age < 0 or age > float(os.environ["MAX_AGE"]):
    sys.exit(1)

print(int(age))
PY_REUSE
}

# Prints one `mq.next.v1` document on stdout for the `mq.pulse.v1` document at
# PATH, and returns the exit code that describes the selection.
#
#   next_select PATH
#
# The exit codes are the Pulse table, not a new one, so a script reading `$?`
# from `mqlaunch next` gets the same answer it would get from `mqlaunch pulse`
# about the same finding:
#
#   0  NONE          nothing needs attention in what was collected
#   1  SELECTED      the selected item is WARN or UNAVAILABLE
#   2  SELECTED      the selected item is FAIL
#   3  UNAVAILABLE   the document could not be read, or measured nothing
#
# Diagnostics go to stderr. stdout is one JSON document and nothing else, which
# is the output contract every other mqlaunch command is held to.
next_select() {
  local path="${1:-}"

  if [[ -z "$path" ]]; then
    printf 'next: no pulse document given\n' >&2
    next_unavailable "no pulse document given"
    return 3
  fi

  if [[ ! -f "$path" ]]; then
    printf 'next: pulse document not found: %s\n' "$path" >&2
    next_unavailable "pulse document not found"
    return 3
  fi

  # python3 parses, for the reason document.sh gives for using it to serialize:
  # a summary holding a quote or a newline must not be able to turn a status
  # command into invalid output. It also means a malformed document is caught by
  # a real parser rather than by a grep that happened to match.
  local out rc=0
  out="$(NEXT_SCHEMA="$NEXT_SCHEMA" python3 - "$path" <<'PY'
import json
import os
import sys

SCHEMA = os.environ["NEXT_SCHEMA"]
PULSE_SCHEMA = "mq.pulse.v1"

# The states an item may carry, from docs/PULSE_CONTRACT.md. A document whose
# selected item has a state outside this set is not a document this selector
# understands, and guessing its severity would be inventing one.
SEVERITY = {"FAIL": 2, "WARN": 1, "UNAVAILABLE": 1}


def emit(status, item, scope, collected, reason, code, collected_at=None):
    doc = {
        "schema": SCHEMA,
        "status": status,
        "item": item,
        "scope": scope,
        "collected": collected,
        # Echoed for the same reason scope and collected are: a consumer must be
        # able to tell what the answer is a statement about. Reuse makes it load
        # bearing — without it, an answer from a document collected two minutes
        # ago is indistinguishable from one measured just now.
        "collected_at": collected_at,
    }
    if reason is not None:
        doc["reason"] = reason
    print(json.dumps(doc, indent=2, sort_keys=False))
    return code


def unavailable(reason):
    return emit("UNAVAILABLE", None, None, [], reason, 3)


try:
    with open(sys.argv[1], "r", encoding="utf-8") as handle:
        doc = json.load(handle)
except json.JSONDecodeError as exc:
    print("next: pulse document is not valid JSON: %s" % exc, file=sys.stderr)
    sys.exit(unavailable("pulse document is not valid JSON"))
except OSError as exc:
    print("next: cannot read pulse document: %s" % exc, file=sys.stderr)
    sys.exit(unavailable("cannot read pulse document"))

if not isinstance(doc, dict) or doc.get("schema") != PULSE_SCHEMA:
    # A document of some other schema is not a Pulse document that happens to be
    # older. Reading it would mean guessing which keys mean what.
    print(
        "next: not an %s document: %r" % (PULSE_SCHEMA, (doc or {}).get("schema")
                                          if isinstance(doc, dict) else None),
        file=sys.stderr,
    )
    sys.exit(unavailable("not an %s document" % PULSE_SCHEMA))

# scope and collected are echoed rather than recomputed. A NONE from a scoped
# run is not the same claim as a NONE from a full one, and a consumer that
# cannot tell them apart reads "nothing needs attention in the four areas I
# collected" as "nothing needs attention".
scope = doc.get("scope")
collected = doc.get("collected")
if not isinstance(collected, list):
    collected = []
collected_at = doc.get("collected_at")
if not isinstance(collected_at, str):
    collected_at = None

attention = doc.get("attention")
if not isinstance(attention, list):
    print("next: pulse document has no attention list", file=sys.stderr)
    sys.exit(unavailable("pulse document has no attention list"))

status = doc.get("status")

if not attention:
    if status == "INCOMPLETE":
        # The case that hides behind an empty list: the run contributed nothing,
        # so there is no finding to report and no all-clear to give either.
        print("next: pulse run measured nothing (INCOMPLETE)", file=sys.stderr)
        sys.exit(
            emit("UNAVAILABLE", None, scope, collected,
                 "pulse run measured nothing", 3, collected_at)
        )
    sys.exit(emit("NONE", None, scope, collected, None, 0, collected_at))

# attention[0], verbatim. Not the first item this selector likes.
item = attention[0]
item_status = item.get("status") if isinstance(item, dict) else None

if item_status not in SEVERITY:
    print(
        "next: selected item has unusable status: %r" % (item_status,),
        file=sys.stderr,
    )
    sys.exit(unavailable("selected item has unusable status"))

sys.exit(emit("SELECTED", item, scope, collected, None, SEVERITY[item_status],
              collected_at))
PY
  )" || rc=$?

  printf '%s\n' "$out"
  return "$rc"
}

# Prints a bare `mq.next.v1` UNAVAILABLE document.
#
# Used for the failures that happen before python3 is reached — no path, no
# file — so those answer with the same shape as every other outcome rather than
# with an empty stdout a caller would have to special-case.
next_unavailable() {
  local reason="$1"
  cat <<EOF
{
  "schema": "$NEXT_SCHEMA",
  "status": "UNAVAILABLE",
  "item": null,
  "scope": null,
  "collected": [],
  "collected_at": null,
  "reason": "$reason"
}
EOF
}
