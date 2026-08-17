#!/usr/bin/env bash
# `mqlaunch next` human renderer.
#
# Draws one `mq.next.v1` document. It decides nothing: the glyph and the colour
# come from the item's state, and the state came from Pulse. The one comparison
# in this file is a case on the status word.
#
# The glyph and colour functions are Pulse's, sourced rather than redefined. A
# second table mapping WARN to a symbol would be a second vocabulary, and the two
# would drift the first time one of them gained a state — an operator reading
# `⚠` in one command and `!` in another has to learn the product twice.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/../pulse/render.sh"

# Prints a `mq.next.v1` document as the human screen.
#
#   next_render PATH
#
# Three shapes, one per status, and the differences between them are the whole
# point of the contract in docs/NEXT_CONTRACT.md: "here is the thing to do",
# "there is nothing to do", and "I could not find out" must not look alike.
next_render() {
  local path="$1"
  local status item_status subject summary next_command scope collected reason

  # One python3 call, one field per line, in a fixed order. Reading the document
  # with a real parser rather than a grep is the same rule the selector follows:
  # a summary holding a tab or a quote must not be able to move a field.
  local -a fields=()
  while IFS= read -r line; do
    fields+=("$line")
  done < <(python3 - "$path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)

item = doc.get("item") or {}
collected = doc.get("collected") or []

for value in (
    doc.get("status") or "",
    item.get("status") or "",
    item.get("subject") or "",
    item.get("summary") or "",
    item.get("next_command") or "",
    doc.get("scope") or "",
    " ".join(str(area) for area in collected),
    doc.get("reason") or "",
):
    # Newlines inside a field would shift every field after it. No item field is
    # multi-line today; collapsing rather than trusting that is one line.
    print(str(value).replace("\n", " "))
PY
  )

  status="${fields[0]:-}"
  item_status="${fields[1]:-}"
  subject="${fields[2]:-}"
  summary="${fields[3]:-}"
  next_command="${fields[4]:-}"
  scope="${fields[5]:-}"
  collected="${fields[6]:-}"
  reason="${fields[7]:-}"

  case "$status" in
    SELECTED)
      printf '\n%bNEXT%b\n' "$PULSE_C_MUTED" "$PULSE_C_RESET"
      printf '  %b%s%b %-22s %s\n' \
        "$(pulse_colour "$item_status")" "$(pulse_glyph "$item_status")" \
        "$PULSE_C_RESET" "$subject" "$summary"
      [[ -n "$next_command" ]] \
        && printf '      %b→ %s%b\n' "$PULSE_C_MUTED" "$next_command" "$PULSE_C_RESET"
      ;;
    NONE)
      printf '\n%bNothing needs attention.%b\n' "$PULSE_C_PASS" "$PULSE_C_RESET"
      ;;
    UNAVAILABLE)
      # Never the NONE wording. "Nothing needs attention" about a run that
      # measured nothing is the one sentence this command must not print.
      printf '\n%b?%b %s\n' "$PULSE_C_WARN" "$PULSE_C_RESET" \
        "Next unavailable: ${reason:-could not read the pulse document}"
      ;;
    *)
      printf '\n%b?%b %s\n' "$PULSE_C_WARN" "$PULSE_C_RESET" \
        "Next unavailable: unrecognized document"
      ;;
  esac

  # The scope line, on every status. A NONE from a scoped run is a different
  # claim from a NONE from a full one, and the human screen has the same duty
  # the document does to say which it is.
  if [[ -n "$scope" ]]; then
    printf '\n%bScope: %s%b\n' "$PULSE_C_MUTED" "$scope" "$PULSE_C_RESET"
  elif [[ -n "$collected" ]]; then
    printf '\n%bCollected: %s%b\n' "$PULSE_C_MUTED" "$collected" "$PULSE_C_RESET"
  fi
}

# Prints a `mq.next.v1` document as one tab-separated row — `mqlaunch next
# --plain`.
#
# For the operator who is piping, not reading. Six fields, always six, in one
# shape that will not move when the screen layout does:
#
#   status  item_status  area  subject  summary  next_command
#
# Field 1 is the selection status and the reason it is on the row rather than on
# a `#` comment line the way `pulse --plain` carries its verdict. Pulse's shape
# is the better precedent in every respect but one: with the status on a comment
# line, `NONE` and `UNAVAILABLE` both produce zero rows, so `grep -v '^#'` makes
# "nothing needs attention" and "nothing was measured" the same empty output.
# That is the one distinction this command exists to keep, and it outranks
# matching the sibling format exactly.
#
# The field count is constant for the same class of reason. `cut -f6` on a bare
# `NONE` line prints `NONE`, because cut passes through lines that hold no
# delimiter — a consumer reading the last column would see a status word where a
# command should be. Empty trailing fields cost five bytes and remove that.
#
# For `UNAVAILABLE` the reason takes the `summary` column, which is where a
# human-readable explanation already belongs.
next_render_plain() {
  local path="$1"

  python3 - "$path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    doc = json.load(handle)

item = doc.get("item") or {}
status = doc.get("status") or ""
collected = doc.get("collected") or []


def clean(value):
    # A tab inside a field would add a column; a newline would add a row. No
    # item field carries either today, and collapsing rather than trusting that
    # is what keeps the shape a contract.
    return str(value).replace("\t", " ").replace("\n", " ")


summary = item.get("summary") or ""
if status == "UNAVAILABLE":
    summary = doc.get("reason") or "could not read the pulse document"

row = [
    status,
    item.get("status") or "",
    item.get("area") or "",
    item.get("subject") or "",
    summary,
    item.get("next_command") or "",
]
print("\t".join(clean(field) for field in row))

# The scope comment mirrors pulse --plain: `grep -v '^#'` leaves exactly the
# row. It is a comment and not a column because it describes the run, not the
# finding, and a consumer reading columns should not have to skip two of them.
print("# next\tscope=%s\tcollected=%s" % (
    doc.get("scope") or "",
    ",".join(str(area) for area in collected),
))
PY
}
