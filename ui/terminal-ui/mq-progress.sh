#!/usr/bin/env bash
# Shared step-progress and result-panel primitives for MQLaunch terminal UI.
# Sourceable from bash or zsh. If mq-ui.sh is not loaded yet, this module loads
# the canonical UI authority from the same directory before defining helpers.

_mq_progress_self="${BASH_SOURCE[0]-}"
[ -n "$_mq_progress_self" ] || _mq_progress_self="$0"
_MQ_PROGRESS_DIR="$(cd "$(dirname "$_mq_progress_self")" 2>/dev/null && pwd)"
unset _mq_progress_self

if ! command -v surface_row >/dev/null 2>&1; then
  # shellcheck source=ui/terminal-ui/mq-ui.sh
  source "$_MQ_PROGRESS_DIR/mq-ui.sh"
fi

_ui_progress_style() {
  case "${1:-pending}" in
    done|pass|success) printf '%s|%s' '✓' "${C_OK:-}" ;;
    active|running)    printf '%s|%s' '■' "${C_INFO:-}" ;;
    warn|warning)      printf '%s|%s' '!' "${C_WARN:-}" ;;
    fail|failed|error) printf '%s|%s' '✗' "${C_ERR:-}" ;;
    skipped)           printf '%s|%s' '–' "${C_DIM:-}" ;;
    pending|*)         printf '%s|%s' '□' "${C_DIM:-}" ;;
  esac
}

# Render a deterministic multi-step progress snapshot.
#
#   ui_progress_steps \
#     'done|Scan repository' \
#     'active|Build review context' \
#     'pending|Send to model' \
#     'pending|Save to brain'
#
# This never invents a percentage. Re-render only when the workflow owner knows
# a real phase transition. ui_spinner remains the primitive for one opaque wait.
ui_progress_steps() {
  local spec state label styled glyph color

  for spec in "$@"; do
    state="${spec%%|*}"
    if [[ "$spec" == *'|'* ]]; then
      label="${spec#*|}"
    else
      state="pending"
      label="$spec"
    fi

    styled="$(_ui_progress_style "$state")"
    glyph="${styled%%|*}"
    color="${styled#*|}"

    if mq_wants_plain_output; then
      printf '%s %s\n' "$glyph" "$label"
    else
      printf '%b%s%b %s\n' "$color" "$glyph" "${C_RESET:-}" "$label"
    fi
  done
}

_ui_result_style() {
  case "${1:-INFO}" in
    PASS|OK|SUCCESS)      printf '%s|%s' '✓' "${C_OK:-}" ;;
    WARN|WARNING)         printf '%s|%s' '!' "${C_WARN:-}" ;;
    FAIL|FAILED|ERROR)    printf '%s|%s' '✗' "${C_ERR:-}" ;;
    SKIPPED|UNAVAILABLE)  printf '%s|%s' '–' "${C_WARN:-}" ;;
    INFO|*)               printf '%s|%s' 'i' "${C_INFO:-}" ;;
  esac
}

# Render a compact result footer/panel.
#
#   ui_result_panel PASS 'Review complete' \
#     'Brain: mqobsidian' \
#     'Next: mqlaunch memory review-status'
#
# Interactive terminals get the canonical surface box. Piped/headless output is
# plain text: no panel furniture and no ANSI control sequences.
ui_result_panel() {
  local result_status="${1:-INFO}"
  local title="${2:-Result}"
  shift 2 || true

  local styled glyph status_color width panel_color line
  styled="$(_ui_result_style "$result_status")"
  glyph="${styled%%|*}"
  status_color="${styled#*|}"

  if mq_wants_plain_output; then
    printf '%s %s\n' "$glyph" "$title"
    for line in "$@"; do
      printf '%s\n' "$line"
    done
    return 0
  fi

  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"
  surface_top "Result" "$width" "$panel_color"
  surface_row "${status_color}${glyph} ${title}${C_RESET:-}" "$width" "$panel_color"
  for line in "$@"; do
    surface_row "$line" "$width" "$panel_color"
  done
  surface_bottom "$width" "$panel_color"
}
