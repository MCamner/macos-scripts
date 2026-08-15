#!/usr/bin/env bash
# Pulse human renderer.
#
# Reads items and prints them. It decides nothing: the glyph comes from the
# item's status and the ordering from the order collectors ran in. The exit
# gate for the canonical model is that rendering contains no independent health
# logic, and the way to keep that true is for this file to hold no comparison
# more interesting than a case on the state name.
#
# Colour is gated on the shared condition — a TTY and no NO_COLOR — so
# `mqlaunch pulse > file` and `NO_COLOR=1 mqlaunch pulse` write the same plain
# text, per docs/RUNTIME_AUTHORITY.md.

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/attention.sh"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  PULSE_C_PASS='\033[0;32m'
  PULSE_C_WARN='\033[1;33m'
  PULSE_C_FAIL='\033[0;31m'
  PULSE_C_MUTED='\033[0;36m'
  PULSE_C_RESET='\033[0m'
else
  PULSE_C_PASS=''
  PULSE_C_WARN=''
  PULSE_C_FAIL=''
  PULSE_C_MUTED=''
  PULSE_C_RESET=''
fi

# The glyph for a state. ASCII where the meaning is a warning or a gap, because
# those are the rows an operator scans for.
pulse_glyph() {
  case "$1" in
    PASS)        printf '✔' ;;
    WARN)        printf '⚠' ;;
    FAIL)        printf '✖' ;;
    UNAVAILABLE) printf '?' ;;
    SKIPPED)     printf '–' ;;
    *)           printf ' ' ;;
  esac
}

# The colour for a state.
pulse_colour() {
  case "$1" in
    PASS)        printf '%b' "$PULSE_C_PASS" ;;
    WARN)        printf '%b' "$PULSE_C_WARN" ;;
    FAIL)        printf '%b' "$PULSE_C_FAIL" ;;
    UNAVAILABLE) printf '%b' "$PULSE_C_WARN" ;;
    *)           printf '%b' "$PULSE_C_MUTED" ;;
  esac
}

# The heading for an area, in the order the areas are printed.
#
# Areas an item may carry but this list does not name still print, under their
# own name uppercased — a collector added later shows up rather than vanishing.
PULSE_AREA_ORDER=(system repositories stack memory git quality)

pulse_area_heading() {
  case "$1" in
    system)       printf 'SYSTEM' ;;
    repositories) printf 'REPOSITORIES' ;;
    stack)        printf 'MQ STACK' ;;
    memory)       printf 'MEMORY' ;;
    git)          printf 'GIT / GITHUB' ;;
    quality)      printf 'QUALITY' ;;
    *)            printf '%s' "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" ;;
  esac
}

# Prints every item in one area. Returns 1 when the area held none, so the
# caller can skip the heading rather than print an empty section.
pulse_render_area() {
  local wanted="$1" record area status subject summary next printed=0

  for record in "${PULSE_ITEMS[@]}"; do
    area="$(pulse_item_field "$record" area)"
    [[ "$area" != "$wanted" ]] && continue

    if [[ $printed -eq 0 ]]; then
      printf '\n%b%s%b\n' "$PULSE_C_MUTED" "$(pulse_area_heading "$wanted")" "$PULSE_C_RESET"
      printed=1
    fi

    status="$(pulse_item_field "$record" status)"
    subject="$(pulse_item_field "$record" subject)"
    summary="$(pulse_item_field "$record" summary)"
    next="$(pulse_item_field "$record" next_command)"

    printf '  %b%s%b %-22s %s\n' \
      "$(pulse_colour "$status")" "$(pulse_glyph "$status")" "$PULSE_C_RESET" \
      "$subject" "$summary"

    # --verbose prints what the collector saw. It is off by default because the
    # default screen is for scanning, and on when asked because "why does it say
    # that" is the next question — answered without a second command.
    if [[ "${PULSE_VERBOSE:-0}" == "1" ]]; then
      local evidence duration
      evidence="$(pulse_item_field "$record" evidence)"
      duration="$(pulse_item_field "$record" duration_ms)"
      [[ -n "$evidence" ]] && printf '      %b· %s%b\n' "$PULSE_C_MUTED" "$evidence" "$PULSE_C_RESET"
      [[ -n "$duration" ]] && printf '      %b· %s ms%b\n' "$PULSE_C_MUTED" "$duration" "$PULSE_C_RESET"
    fi

    # The next command is printed only where the row is not already fine.
    # Telling an operator what to run about something that passed is noise, and
    # `next_command` on a PASS item is still carried in the machine document.
    if [[ -n "$next" && "$status" != "PASS" && "$status" != "SKIPPED" ]]; then
      printf '      %b→ %s%b\n' "$PULSE_C_MUTED" "$next" "$PULSE_C_RESET"
    fi
  done

  [[ $printed -eq 1 ]]
}

# Prints the ATTENTION section: the run's findings, most important first.
#
# Prints nothing at all when there are none — a heading over an empty list reads
# as a section that failed to load. The engine decides the order and the
# deduplication; this only draws what it hands over, and repeats the
# `next_command` the item already carried.
pulse_render_attention() {
  local -a findings=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && findings+=("$line")
  done < <(pulse_attention_list)

  [[ "${#findings[@]}" -eq 0 ]] && return 0

  printf '\n%b%s%b\n' "$PULSE_C_MUTED" "ATTENTION" "$PULSE_C_RESET"

  local shown=0 record status subject summary next
  for record in "${findings[@]}"; do
    [[ $shown -ge $PULSE_ATTENTION_LIMIT ]] && break
    status="$(pulse_item_field "$record" status)"
    subject="$(pulse_item_field "$record" subject)"
    summary="$(pulse_item_field "$record" summary)"
    next="$(pulse_item_field "$record" next_command)"

    printf '  %b%s%b %-22s %s\n' \
      "$(pulse_colour "$status")" "$(pulse_glyph "$status")" "$PULSE_C_RESET" \
      "$subject" "$summary"
    [[ -n "$next" ]] && printf '      %b→ %s%b\n' "$PULSE_C_MUTED" "$next" "$PULSE_C_RESET"
    shown=$((shown + 1))
  done

  local remaining=$(( ${#findings[@]} - shown ))
  if [[ $remaining -gt 0 ]]; then
    # The count is the whole point of the limit: five rows an operator will read
    # beats twenty they will not, but a hidden remainder would be the screen
    # withholding what the run found.
    printf '  %b+ %d more%b\n' "$PULSE_C_MUTED" "$remaining" "$PULSE_C_RESET"
  fi
}

# Prints only the attention list — `mqlaunch pulse attention`.
#
# The whole run is still collected: attention is a view over every area, and
# scoping the collection instead of the rendering would make the most important
# screen the least informed. When nothing needs attention it says so, rather
# than printing an empty screen an operator would read as a broken command.
pulse_render_attention_only() {
  local overall="$1" rendered

  rendered="$(pulse_render_attention)"
  if [[ -z "$rendered" ]]; then
    printf '\n%bNothing needs attention.%b\n' "$PULSE_C_PASS" "$PULSE_C_RESET"
  else
    printf '%s\n' "$rendered"
  fi

  printf '\n%b%s%b\n' "$(pulse_colour "$overall")" "Pulse: $overall" "$PULSE_C_RESET"
}

# Prints the run as one line per item — `mqlaunch pulse --plain`.
#
# For the operator who is piping, not reading: no panel, no colour, no glyph, no
# box drawing, and one shape that will not move when the screen layout does.
# Five tab-separated fields per line:
#
#   area  status  subject  summary  next_command
#
# The verdict is a `#` comment line, which is the only ambiguity worth spending:
# a bare `pulse WARN` line would be indistinguishable from an item in an area
# called `pulse`, and `grep -v '^#'` leaves exactly the item rows.
#
# The items are the run's items, in collection order — the same items the JSON
# document and the panel are built from. Under `attention` the caller passes the
# attention list instead, so the scope decides which items and this decides the
# shape.
pulse_render_plain() {
  local overall="$1"
  shift

  local record
  for record in "$@"; do
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(pulse_item_field "$record" area)" \
      "$(pulse_item_field "$record" status)" \
      "$(pulse_item_field "$record" subject)" \
      "$(pulse_item_field "$record" summary)" \
      "$(pulse_item_field "$record" next_command)"
  done

  printf '# pulse\t%s\n' "$overall"
}

# Prints the whole run: every known area in order, then any area a collector
# introduced that this file has never heard of, then the attention list.
pulse_render() {
  local overall="$1" area record seen known

  for area in "${PULSE_AREA_ORDER[@]}"; do
    pulse_render_area "$area" || true
  done

  seen=""
  for record in "${PULSE_ITEMS[@]}"; do
    area="$(pulse_item_field "$record" area)"
    known=0
    for name in "${PULSE_AREA_ORDER[@]}"; do
      [[ "$area" == "$name" ]] && known=1 && break
    done
    [[ $known -eq 1 ]] && continue
    case " $seen " in
      *" $area "*) continue ;;
    esac
    seen="$seen $area"
    pulse_render_area "$area" || true
  done

  pulse_render_attention

  printf '\n%b%s%b\n' "$(pulse_colour "$overall")" "Pulse: $overall" "$PULSE_C_RESET"
}
