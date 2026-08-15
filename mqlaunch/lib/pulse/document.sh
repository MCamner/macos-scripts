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
# python3 does the escaping, for the reason given in item.sh: a summary holding
# a quote must not be able to turn a status command into invalid output.
pulse_document() {
  local overall="$1" scope="$2"
  shift 2

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
    "summary": summary,
    "sections": sections,
    "attention": attention,
}

print(json.dumps(document, indent=2))
'
}
