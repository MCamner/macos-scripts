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
PULSE_AREA_ORDER=(system repositories stack)

pulse_area_heading() {
  case "$1" in
    system)       printf 'SYSTEM' ;;
    repositories) printf 'REPOSITORIES' ;;
    stack)        printf 'MQ STACK' ;;
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

    # The next command is printed only where the row is not already fine.
    # Telling an operator what to run about something that passed is noise, and
    # `next_command` on a PASS item is still carried in the machine document.
    if [[ -n "$next" && "$status" != "PASS" && "$status" != "SKIPPED" ]]; then
      printf '      %b→ %s%b\n' "$PULSE_C_MUTED" "$next" "$PULSE_C_RESET"
    fi
  done

  [[ $printed -eq 1 ]]
}

# Prints the whole run: every known area in order, then any area a collector
# introduced that this file has never heard of.
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

  printf '\n%b%s%b\n' "$(pulse_colour "$overall")" "Pulse: $overall" "$PULSE_C_RESET"
}
