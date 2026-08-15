#!/usr/bin/env bash
# Pulse menu — one screen for choosing which part of the operator cockpit to
# look at.
#
# Every row runs `mqlaunch pulse <scope>` through the dispatcher. The menu holds
# no status logic of its own: it does not read a repo, call a delegate, or decide
# what anything means. Adding a reading here would put a second definition of
# "healthy" one level above the collectors the contract gates, which is the
# failure docs/PULSE_CONTRACT.md exists to prevent.
#
# Through `bin/mqlaunch`, not `tools/scripts/pulse.sh` directly — a menu row and
# a typed command must be the same thing, per docs/RUNTIME_AUTHORITY.md.

# The scope the operator looked at last, so Refresh has something to repeat.
# Empty means the full view.
MQ_PULSE_LAST_SCOPE=""

# Prints pulse menu.
print_pulse_menu() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  print_header
  surface_panel_header "MQ Pulse" "Operator Status" "$width" "$panel_color"
  surface_row "OVERVIEW" "$width" "$panel_color"
  surface_split_row "1. Full Pulse" "2. Attention" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "ENVIRONMENT" "$width" "$panel_color"
  surface_split_row "3. System" "4. Repositories" "$width" "$panel_color"
  surface_split_row "5. MQ Stack" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "STATE" "$width" "$panel_color"
  surface_split_row "6. Memory" "7. Git / GitHub" "$width" "$panel_color"
  surface_split_row "8. Quality" "" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "TOOLS" "$width" "$panel_color"
  surface_split_row "9. Refresh" "b. Back" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Read-only. Every row runs mqlaunch pulse." "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

# Runs one Pulse view and remembers it, so Refresh repeats what was last read
# rather than always returning to the full view.
#
# The exit status is deliberately dropped: Pulse exits 1 whenever anything needs
# attention, which is the normal case and not a reason for the menu to look like
# something went wrong. A caller who wants the status types the command.
run_pulse_view() {
  local scope="${1:-}"
  MQ_PULSE_LAST_SCOPE="$scope"

  if [[ -n "$scope" ]]; then
    "$BASE_DIR/bin/mqlaunch" pulse "$scope" || true
  else
    "$BASE_DIR/bin/mqlaunch" pulse || true
  fi
  pause_enter
}

# Routes the pulse menu selection to the matching view.
handle_pulse_menu_choice() {
  local choice="$1"

  case "$choice" in
    1) run_pulse_view "" ;;
    2) run_pulse_view attention ;;
    3) run_pulse_view system ;;
    4) run_pulse_view repos ;;
    5) run_pulse_view stack ;;
    6) run_pulse_view memory ;;
    7) run_pulse_view git ;;
    8) run_pulse_view quality ;;
    9) run_pulse_view "$MQ_PULSE_LAST_SCOPE" ;;
    b|B|x|X|exit) return 1 ;;
    *) echo "${C_ERR}Invalid pulse selection:${C_RESET} $choice"; pause_enter ;;
  esac

  return 0
}

# Keeps the pulse menu interactive until the user backs out.
pulse_menu_loop() {
  local choice

  while true; do
    print_pulse_menu
    read_menu_choice "" "pulse" || return
    choice="$REPLY"
    echo

    if ! handle_pulse_menu_choice "$choice"; then
      break
    fi
  done
}

# Opens pulse menu.
open_pulse_menu() {
  pulse_menu_loop
}
