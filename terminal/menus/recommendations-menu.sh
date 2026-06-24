#!/usr/bin/env bash

# Recommendations Menu — mqlaunch surface for the read-only recommended.json
# consumer.
#
# Rule: dedicated and SEPARATE from mq-obsidian-menu.sh (vault navigation) by
# design. This menu only lists, shows, and copies the producer's recommended
# command patterns. The producer's recommended.json is read-only here.
#
# Contract honored end to end:
#   - allowed actions are FILE-WIDE (show, copy) — nothing is ever executed
#   - mutating patterns are hidden and NOT selectable from this menu
#   - templates are shown/copied verbatim; placeholders are the user's to fill

# Checks whether this menu is sourced (vs executed directly).
recommendations_menu_is_sourced() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ ":${ZSH_EVAL_CONTEXT:-}:" == *:file:* ]]
    return
  fi
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

# Optional shared UI (surface_*). The menu degrades to plain printf without it.
if ! command -v surface_top >/dev/null 2>&1; then
  : "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

# Recommendations consumer libs (PR1 + Steg A + Steg B). Required for this menu;
# it reports cleanly if they are absent.
: "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
_REC_MENU_LIB="$BASE_DIR/mqlaunch/lib/recommendations"
for _rec_lib in errors resolve parse actions clipboard render select doctor; do
  [[ -f "$_REC_MENU_LIB/$_rec_lib.sh" ]] && source "$_REC_MENU_LIB/$_rec_lib.sh"
done
unset _rec_lib

# Pauses safely after a menu action.
_rec_menu_pause_enter() {
  if command -v pause_enter >/dev/null 2>&1; then
    pause_enter
  else
    printf "\nPress Enter to continue..."
    read -r _
  fi
}

# True once the consumer libs have loaded.
_rec_menu_ready() { command -v assert_recommended_json >/dev/null 2>&1; }

# Renders the recommendations menu panel.
render_recommendations_panel() {
  if command -v surface_panel_header >/dev/null 2>&1; then
    local width panel_color
    width="$(surface_terminal_width)"
    panel_color="$(surface_panel_color)"
    command -v print_header >/dev/null 2>&1 && print_header
    surface_panel_header "Recommendations (read-only)" "RECOMMEND" "$width" "$panel_color"
    surface_row "show / copy only — nothing is executed" "$width" "$panel_color"
    surface_row "" "$width" "$panel_color"
    surface_split_row "1. List recommendations" "2. Show pattern detail" "$width" "$panel_color"
    surface_split_row "3. Show pattern template" "4. Copy pattern template" "$width" "$panel_color"
    surface_split_row "5. Doctor" "" "$width" "$panel_color"
    surface_row "" "$width" "$panel_color"
    surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
    surface_bottom "$width" "$panel_color"
    printf "\n"
  else
    printf "\n=== Recommendations (read-only) — show / copy only, nothing executed ===\n"
    printf "  1. List recommendations     2. Show pattern detail\n"
    printf "  3. Show pattern template    4. Copy pattern template\n"
    printf "  5. Doctor\n"
    printf "  b. Back                     x. Exit launcher\n\n"
  fi
}

# Prompts for a visible pattern and stores its id in REC_PICKED. Returns non-zero
# on cancel / invalid / empty visible set (the prompt itself reports why).
REC_PICKED=""
_rec_menu_pick_visible() {
  local path="$1" sel
  REC_PICKED=""
  if [[ "$(rec_visible_count "$path")" -eq 0 ]]; then
    render_empty_recommendations_state "$path"
    return 1
  fi
  printf "Select a recommendation (visible set only):\n"
  render_selection_index "$path"
  printf "pattern [number or id, blank to cancel]> "
  read -r sel
  REC_PICKED="$(resolve_selected_pattern_id "$path" "$sel")" || return 1
  [[ -n "$REC_PICKED" ]]
}

# 1 — list the default-visible recommendations.
_rec_menu_list() {
  local path
  path="$(assert_recommended_json)" || return 1
  if [[ "$(rec_visible_count "$path")" -eq 0 ]]; then
    render_empty_recommendations_state "$path"
  else
    render_recommendations_list "$path"
  fi
}

# 2 — full detail for a chosen visible pattern.
_rec_menu_detail() {
  local path
  path="$(assert_recommended_json)" || return 1
  _rec_menu_pick_visible "$path" || return 1
  echo
  render_recommendation_detail "$path" "$REC_PICKED"
}

# 3 — the command template (show) for a chosen visible pattern.
_rec_menu_template() {
  local path
  path="$(assert_recommended_json)" || return 1
  assert_action_allowed "$path" show || return 1
  _rec_menu_pick_visible "$path" || return 1
  echo
  render_pattern_template "$path" "$REC_PICKED"
}

# 4 — copy the template (copy) for a chosen visible pattern to the clipboard.
_rec_menu_copy() {
  local path
  path="$(assert_recommended_json)" || return 1
  assert_action_allowed "$path" copy || return 1
  assert_clipboard_available || return 1
  _rec_menu_pick_visible "$path" || return 1
  echo
  copy_pattern_template_to_clipboard "$path" "$REC_PICKED" || return 1
  render_copy_success "$path" "$REC_PICKED"
}

# 5 — consumer health check.
_rec_menu_doctor() { run_recommendations_doctor; }

# Runs the recommendations menu loop.
recommendations_menu_main() {
  local choice
  if ! _rec_menu_ready; then
    printf "Recommendations consumer lib not found under %s\n" "$_REC_MENU_LIB"
    _rec_menu_pause_enter
    return 127
  fi

  # Ensure jq once, in this (launcher) process, so every flow below has it even
  # when mqlaunch was started from a stripped PATH. Repairs PATH for the session.
  if ! rec_require_jq; then
    _rec_menu_pause_enter
    return 1
  fi

  while true; do
    render_recommendations_panel

    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "recommend" || break
    else
      printf "recommend> "
      read -r choice
    fi
    echo

    case "$choice" in
      1|list)        _rec_menu_list;     _rec_menu_pause_enter ;;
      2|detail|show) _rec_menu_detail;   _rec_menu_pause_enter ;;
      3|template)    _rec_menu_template; _rec_menu_pause_enter ;;
      4|copy)        _rec_menu_copy;     _rec_menu_pause_enter ;;
      5|doctor)      _rec_menu_doctor;   _rec_menu_pause_enter ;;
      h|help)        render_recommendations_panel; _rec_menu_pause_enter ;;
      b|B|back)      break ;;
      x|X)           exit 0 ;;
      *)
        if [[ -n "$choice" ]]; then
          printf "Unknown recommendations action: %s\n" "$choice"
          _rec_menu_pause_enter
        fi
        ;;
    esac
  done
}

if ! recommendations_menu_is_sourced; then
  recommendations_menu_main "$@"
fi
