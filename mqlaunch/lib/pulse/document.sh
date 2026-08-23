#!/usr/bin/env bash
# `mq.pulse.v1` — the machine document.
#
# One serializer for the whole product. The human screen, `--plain` and this
# document all read the same items, so the three cannot disagree about the state
# of the machine; a second place that assembled JSON would be a second answer to
# the same question, which is the failure docs/PULSE_CONTRACT.md exists to
# prevent.
#
# Two things this file is careful about, both of them the contract's "absence"
# rule expressed in a data structure:
#
#   `collected` says which areas actually ran. A section missing from `sections`
#   means the collector did not run, never that the area was fine — a scoped run
#   must not read as five healthy areas plus one interesting one.
#
#   `attention` carries the same item objects that are in `sections`, not a
#   parallel data kind. It is the attention engine's ordering of items that are
#   already in the document, and tests/pulse-machine-surface-smoke.sh holds every
#   entry to being an item that appears in a section.
#
# `SKIPPED` and `UNAVAILABLE` items are serialized like any other. Dropping them
# would make a skipped run and a healthy run the same document.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/attention.sh"

PULSE_SCHEMA="mq.pulse.v1"

# The schema stays `v1` across this addition, deliberately.
#
# `collected_at` and `conditions` are additive and optional to read: every
# consumer written against the original document keeps working untouched, and
# mqlaunch/lib/next/select.sh — the only reader in the stack — reaches every
# field through `.get`, so it was verified rather than assumed. A `v2` here
# would charge every consumer a migration for fields none of them are obliged
# to read, which is a cost paid for tidiness. What a new version is for is a key
# whose *meaning* changed, and none did.

# The moment collection began, as RFC 3339 with an explicit offset.
#
# Seconds precision, because the subject of the claim is a run that takes
# seconds, and an offset always, because a stamp without one is only readable by
# someone who already knows which machine produced it.
#
# `date` rather than python3: this is called once per run, not twice per
# collector, so the reason pulse_now_ms avoids a process does not apply — and
# `date` is the one clock both bash 3.2 and a stripped PATH already have.
pulse_timestamp() {
  local stamp
  stamp="$(date +%Y-%m-%dT%H:%M:%S%z)" || return 1
  [[ ${#stamp} -ge 5 ]] || return 1
  # `%z` prints +0200 on every platform this runs on; RFC 3339 wants +02:00.
  # `date --rfc-3339` would do it, and is GNU-only.
  printf '%s:%s' "${stamp:0:${#stamp}-2}" "${stamp: -2}"
}

# Group separator: splits the items blob from the attention blob on one stdin.
# The records inside each blob are already separated by RS and their fields by
# US, so this is the next byte up and no value can contain it.
PULSE_DOC_GS=$'\x1d'

# Prints the run as one `mq.pulse.v1` document on stdout.
#
#   pulse_document OVERALL SCOPE [AREA ...]
#
# SCOPE is the scope word or empty for a full run. The AREA list is what the
# entrypoint actually collected — it is passed in rather than derived from the
# items, because an area whose collector ran and produced nothing is not the
# same as an area that never ran, and only the caller knows which happened.
#
# Three properties of the run come in as globals the entrypoint sets, beside
# PULSE_VERBOSE which the renderer already reads that way: PULSE_COLLECTED_AT,
# PULSE_NO_STACK and PULSE_NO_NETWORK. They describe the invocation rather than
# any item, and threading them through five positional parameters would put the
# scope word and a boolean next to each other at every call site.
#
# An unstamped run is refused rather than published with a null. A document
# whose age cannot be evaluated is not a document with one field missing — it is
# a freshness claim nobody can check, and emitting it would hand a consumer the
# guess this field exists to remove.
#
# python3 does the escaping, for the reason given in item.sh: a summary holding
# a quote must not be able to turn a status command into invalid output.
pulse_document() {
  local overall="$1" scope="$2"
  shift 2

  if [[ -z "${PULSE_COLLECTED_AT:-}" ]]; then
    printf 'pulse: refusing to serialize a run with no collected_at stamp\n' >&2
    return 1
  fi

  local record blob=""
  for record in "${PULSE_ITEMS[@]}"; do
    blob+="${record}${PULSE_ITEM_RS}"
  done

  blob+="$PULSE_DOC_GS"

  while IFS= read -r record; do
    [[ -n "$record" ]] && blob+="${record}${PULSE_ITEM_RS}"
  done < <(pulse_attention_list)

  printf '%s' "$blob" | \
    PULSE_OVERALL="$overall" \
    PULSE_SCOPE="$scope" \
    PULSE_COLLECTED="$*" \
    PULSE_COLLECTED_AT="$PULSE_COLLECTED_AT" \
    PULSE_NO_STACK="${PULSE_NO_STACK:-0}" \
    PULSE_NO_NETWORK="${PULSE_NO_NETWORK:-0}" \
    PULSE_SCHEMA="$PULSE_SCHEMA" \
    python3 -c '
import json, os, sys

GS, RS, US = "\x1d", "\x1e", "\x1f"


def parse(blob):
    """The records of one blob, as item dicts."""
    items = []
    for record in blob.split(RS):
        if not record:
            continue
        item = {}
        for pair in record.split(US):
            if not pair:
                continue
            key, _, value = pair.partition("=")
            item[key] = value
        # Carried as text through shell and restored here, so a consumer sorting
        # on priority compares numbers rather than strings — where "9" would
        # sort above "80".
        for numeric in ("priority", "duration_ms"):
            if numeric in item and item[numeric].lstrip("-").isdigit():
                item[numeric] = int(item[numeric])
        item.setdefault("priority", 0)
        items.append(item)
    return items


raw = sys.stdin.read()
items_blob, _, attention_blob = raw.partition(GS)
items = parse(items_blob)
attention = parse(attention_blob)

summary = {"pass": 0, "warn": 0, "fail": 0, "unavailable": 0, "skipped": 0}
sections = {}
for item in items:
    key = item["status"].lower()
    if key in summary:
        summary[key] += 1
    # The section key is the area verbatim. A translation table here would drop
    # the first area a new collector introduces, which is the one case where
    # silence is most expensive.
    sections.setdefault(item["area"], []).append(item)

document = {
    "schema": os.environ["PULSE_SCHEMA"],
    "status": os.environ["PULSE_OVERALL"],
    "scope": os.environ["PULSE_SCOPE"] or None,
    "collected": os.environ["PULSE_COLLECTED"].split(),
    # When collection began, not when this line ran. A run takes seconds, and a
    # stamp taken here would understate the age of the document by exactly the
    # time it spent collecting — the one direction this field must never err in,
    # since a consumer deciding whether to reuse the document reads this number.
    #
    # No apostrophes in these comments: the whole program is one single-quoted
    # shell argument, and one would end it. item.sh records the same trap.
    "collected_at": os.environ["PULSE_COLLECTED_AT"],
    # The flags the operator declared, not what the run turned out to touch.
    # `pulse system` reaches neither the stack nor the network, and recording
    # the effect would make its document indistinguishable from one collected
    # under both skip flags — so a reused document could read as more complete
    # than it is.
    "conditions": {
        "no_stack": os.environ["PULSE_NO_STACK"] == "1",
        "no_network": os.environ["PULSE_NO_NETWORK"] == "1",
    },
    "summary": summary,
    "sections": sections,
    "attention": attention,
}

print(json.dumps(document, indent=2))
'
}
