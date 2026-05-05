#!/usr/bin/env bash

main_menu_is_sourced() {
  if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    [[ ":$ZSH_EVAL_CONTEXT:" == *:file:* ]]
    return
  fi

  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

main_menu_direct_entry() {
  local base_dir launcher
  base_dir="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
  launcher="$base_dir/terminal/launchers/mqlaunch.sh"

  if [[ -x "$launcher" ]]; then
    exec "$launcher" "${1:-menu}"
  elif [[ -f "$launcher" ]]; then
    exec zsh "$launcher" "${1:-menu}"
  fi

  echo "Missing launcher: $launcher" >&2
  exit 1
}

print_main_menu() {
  print_header
  render_main_menu_panel
  render_command_surface
  MQ_MAIN_MENU_RENDERED_LINES=66
}

surface_action_word() {
  local index="$1"
  case $(( index % 10 )) in
    0) printf "routing" ;;
    1) printf "loading" ;;
    2) printf "opening" ;;
    3) printf "mapping" ;;
    4) printf "syncing" ;;
    5) printf "priming" ;;
    6) printf "launching" ;;
    7) printf "resolving" ;;
    8) printf "decoding" ;;
    *) printf "activating" ;;
  esac
}

surface_accept_scramble() {
  local color="$1"
  local selected="$2"
  local frame start word
  start=$(( RANDOM % 10 ))

  for frame in 1 2 3 4 5 6; do
    word="$(surface_action_word $(( start + frame )))"
    printf "\r\033[2K%b>> %-10s %s%b" "$color" "$word" "$selected" "$C_RESET"
    sleep 0.025
  done

  word="$(surface_action_word $(( start + 7 )))"
  printf "\r\033[2K%b>> %-10s %s%b" "$C_OK" "$word" "$selected" "$C_RESET"
  sleep 0.04
}

render_main_menu_panel() {
  local width panel_color host user git_state mode
  width="$(surface_terminal_width)"

  if [[ -t 1 ]]; then
    panel_color=$'\033[0;37m'
  else
    panel_color=""
  fi

  host="$(hostname -s 2>/dev/null || echo unknown)"
  user="${USER:-unknown}"
  git_state="$(surface_git_state)"
  mode="Main"

  surface_top "Main Menu" "$width" "$panel_color"
  surface_row "Host: $host   User: $user   Mode: $mode   Git: $git_state" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"

  surface_row "CORE" "$width" "$panel_color"
  surface_split_row "1. Workflows" "2. System" "$width" "$panel_color"
  surface_split_row "3. Git" "4. Release" "$width" "$panel_color"
  surface_split_row "5. Dev" "6. Help" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "QUICK ACCESS" "$width" "$panel_color"
  surface_split_row "p. Performance" "n. Network" "$width" "$panel_color"
  surface_split_row "h. Health Check" "a. Apps" "$width" "$panel_color"
  surface_split_row "r. REPL" "" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "COMMANDS" "$width" "$panel_color"
  surface_split_row "/review" "/ui" "$width" "$panel_color"
  surface_split_row "/ask" "/release-check" "$width" "$panel_color"
  surface_split_row "/doctor" "/scan   /atlas" "$width" "$panel_color"

  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

surface_dual_figure_row() {
  local left_art="$1"
  local right_art="$2"
  local right="$3"
  local width="$4"
  local surface_color="$5"
  local left_color="$6"
  local right_color="$7"
  local inner left_width right_width art_width art_col right_pad gap
  inner=$(( width - 4 ))
  left_width=$(( inner / 2 ))
  right_width=$(( inner - left_width - 1 ))
  gap="  "
  art_width=$(( ${#left_art} + ${#gap} + ${#right_art} ))
  art_col=$(( (left_width - art_width) / 2 ))
  (( art_col < 1 )) && art_col=1
  right_pad=$(( left_width - art_col - art_width ))
  (( right_pad < 0 )) && right_pad=0

  printf "%b│ %s%b%s%b%s%b%s%b%s %s │%b\n" \
    "$surface_color" \
    "$(repeat_char "$art_col" " ")" \
    "$left_color" \
    "$left_art" \
    "$surface_color" \
    "$gap" \
    "$right_color" \
    "$right_art" \
    "$surface_color" \
    "$(repeat_char "$right_pad" " ")" \
    "$(surface_pad "$right" "$right_width")" \
    "$C_RESET"
}

surface_compact_dual_figure_row() {
  local left_art="$1"
  local right_art="$2"
  local width="$3"
  local surface_color="$4"
  local left_color="$5"
  local right_color="$6"
  local inner art_width art_col right_pad gap
  inner=$(( width - 4 ))
  gap="  "
  art_width=$(( ${#left_art} + ${#gap} + ${#right_art} ))
  art_col=$(( (inner - art_width) / 2 ))
  (( art_col < 1 )) && art_col=1
  right_pad=$(( inner - art_col - art_width ))
  (( right_pad < 0 )) && right_pad=0

  printf "%b│ %s%b%s%b%s%b%s%b%s │%b\n" \
    "$surface_color" \
    "$(repeat_char "$art_col" " ")" \
    "$left_color" \
    "$left_art" \
    "$surface_color" \
    "$gap" \
    "$right_color" \
    "$right_art" \
    "$surface_color" \
    "$(repeat_char "$right_pad" " ")" \
    "$C_RESET"
}

surface_git_state() {
  local count
  count="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  if [[ -z "$count" || "$count" == "0" ]]; then
    printf "Clean"
  else
    printf "Dirty (%s)" "$count"
  fi
}

render_command_surface() {
  local USER_NAME HOST_NAME TIME SURFACE_COLOR FIGURE_COLOR ALT_FIGURE_COLOR width git_state tip activity system_state
  USER_NAME="${USER:-$(whoami)}"
  HOST_NAME="$(hostname -s)"
  TIME="$(date '+%Y-%m-%d %H:%M:%S')"
  width="$(surface_terminal_width)"
  MQ_SURFACE_WIDTH="$width"
  git_state="$(surface_git_state)"
  system_state="System: Stable"
  activity="Activity: Monitoring"
  if [[ "$git_state" == Dirty* ]]; then
    tip="Review git changes"
  else
    tip="Run help to see index"
  fi

  if [[ -t 1 ]]; then
    SURFACE_COLOR=$'\033[0;37m'
    FIGURE_COLOR="$C_OK"
    ALT_FIGURE_COLOR="$C_WARN"
  else
    SURFACE_COLOR=""
    FIGURE_COLOR=""
    ALT_FIGURE_COLOR=""
  fi

  surface_top "Command Surface v3" "$width" "$SURFACE_COLOR"
  if (( width < 56 )); then
    surface_row "Welcome back ${USER_NAME}!" "$width" "$SURFACE_COLOR"
    if (( width >= 44 )); then
      surface_compact_dual_figure_row "▄▄████▄▄" " ▄▄██▄▄ " "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
      surface_compact_dual_figure_row "████████" "█▀████▀█" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
      surface_compact_dual_figure_row "██▄██▄██" "██▀██▀██" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
      surface_compact_dual_figure_row " ▄█▀▀█▄ " " ▀▄██▄▀ " "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    fi
    surface_row "$system_state | Git: $git_state" "$width" "$SURFACE_COLOR"
    surface_row "$activity" "$width" "$SURFACE_COLOR"
    surface_row "Host: ${HOST_NAME} | User: ${USER_NAME}" "$width" "$SURFACE_COLOR"
    surface_row "Time: ${TIME} | X. Exit launcher" "$width" "$SURFACE_COLOR"
    surface_row "Tip: $tip" "$width" "$SURFACE_COLOR"
  else
    surface_split_row "Welcome back ${USER_NAME}!" "Tips: $tip" "$width" "$SURFACE_COLOR"
    surface_split_row "Mode: Interactive" "Git: $git_state" "$width" "$SURFACE_COLOR"
    surface_row "" "$width" "$SURFACE_COLOR"
    surface_dual_figure_row "▄▄████▄▄" " ▄▄██▄▄ " "" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "████████" "█▀████▀█" "$system_state" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "██▄██▄██" "██▀██▀██" "Repo: macos-scripts" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row " ▄█▀▀█▄ " " ▀▄██▄▀ " "$activity" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_row "" "$width" "$SURFACE_COLOR"
    surface_split_row "Host: ${HOST_NAME}" "User: ${USER_NAME}" "$width" "$SURFACE_COLOR"
    surface_split_row "Time: ${TIME}" "X. Exit launcher" "$width" "$SURFACE_COLOR"
  fi
  surface_bottom "$width" "$SURFACE_COLOR"
}

handle_main_menu_choice() {
  local choice="$1"
  local normalized

  normalized="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"
  case "$choice" in
    # CORE
    1) run_mqworkflows ;;
    2) open_system_menu ;;
    3) open_git_menu ;;
    4) open_release_menu ;;
    5) open_dev_menu ;;
    6) open_help_center_menu ;;

    # QUICK ACCESS
    p|P) open_performance_menu ;;
    n|N) show_network_info ;;
    h|H) system_check ;;
    a|A) open_apps_menu ;;
    r|R) "$BASE_DIR/bin/mqlaunch" repl ;;

    # EXIT
    x|X)
      echo "Exiting ${APP_TITLE}..."
      exit 0
      ;;

    *)
      if handle_main_prompt_command "$normalized" "$choice"; then
        return 0
      fi
      ;;
  esac
}

handle_main_prompt_command() {
  local normalized="$1"
  local original="$2"

  [[ -z "${normalized// }" ]] && return 0

  case "$normalized" in
    workflows|workflow|wf) run_mqworkflows; return 0 ;;
    system|sys) open_system_menu; return 0 ;;
    git|git-menu|gitmenu) open_git_menu; return 0 ;;
    release|rel) open_release_menu; return 0 ;;
    dev) open_dev_menu; return 0 ;;
    help|h|?|commands|index) open_help_center_menu; return 0 ;;
    perf|performance) open_performance_menu; return 0 ;;
    net|network|ip) show_network_info; return 0 ;;
    check|health|system\ check) system_check; return 0 ;;
    apps|applications) open_apps_menu; return 0 ;;
    repl|r) "$BASE_DIR/bin/mqlaunch" repl; return 0 ;;
    clear|cls) clear; return 0 ;;
    version|ver) show_version_info || true; return 0 ;;
    notes|changelog|release\ notes) show_release_notes || true; return 0 ;;
    about|status|dashboard) show_about_dashboard || true; return 0 ;;
    bundle|debug|debug-bundle|support) run_debug_bundle || true; return 0 ;;
    repo|base|macos-scripts) open_base_dir; return 0 ;;
    guide|terminal-guide) open_terminal_guide; return 0 ;;
  esac

  if command -v dispatch_cli_command >/dev/null 2>&1; then
    if dispatch_cli_command $normalized; then
      return 0
    fi
  fi

  run_main_shell_command "$original"
}

run_main_shell_command() {
  local command_line="$1"
  local shell_bin="${SHELL:-/bin/zsh}"

  echo
  printf "%b[shell]%b %s\n" "$C_INFO" "$C_RESET" "$command_line"
  echo
  "$shell_bin" -lc "$command_line"
  pause_enter
}

read_main_choice() {
  local prompt_line prompt_hint prompt_color prompt_width term_lines prompt_row input_row pin_prompt
  prompt_width="${MQ_SURFACE_WIDTH:-$(surface_terminal_width)}"
  prompt_line="$(repeat_char "$prompt_width" "─")"
  prompt_hint=">> option, mqlaunch command, shell command, or x to exit"
  if [[ -t 1 ]]; then
    prompt_color=$'\033[0;37m'
  else
    prompt_color=""
  fi

  # Pin prompt area to the bottom of the visible terminal window.
  # Layout (4 rows): separator / input / separator / hint
  term_lines="$(tput lines 2>/dev/null || echo 24)"
  prompt_row=$(( term_lines - 3 ))   # row of first separator (1-indexed)
  input_row=$(( prompt_row + 1 ))    # row of "mqlaunch > " input
  (( prompt_row < 2 )) && prompt_row=2
  (( input_row < 3 )) && input_row=3
  pin_prompt=0
  if (( term_lines > ${MQ_MAIN_MENU_RENDERED_LINES:-64} + 4 )); then
    pin_prompt=1
  fi

  if [[ -n "${ZSH_VERSION:-}" && -t 0 && -t 1 && "$pin_prompt" -eq 1 ]]; then
    local prompt input cursor key old_stty
    prompt="mqlaunch > "
    input=""
    cursor=0

    # Clear from prompt_row to end of screen, then draw fixed prompt block
    printf "\033[%d;1H\033[J" "$prompt_row"
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%s" "$prompt"
    printf "\n%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b" "$C_OK" "$prompt_hint" "$C_RESET"
    # Move cursor to the input line
    printf "\033[%d;1H" "$input_row"

    old_stty="$(stty -g)"
    stty -echo -icanon min 1 time 0 2>/dev/null || true

    while true; do
      printf "\033[%d;1H" "$input_row"
      printf "\r\033[2K%s%s" "$prompt" "$input"
      printf "\033[%d;%dH" "$input_row" $(( ${#prompt} + cursor + 1 ))

      IFS= read -r -k 1 key || {
        stty "$old_stty" 2>/dev/null || true
        return 1
      }

      case "$key" in
        $'\n'|$'\r')
          break
          ;;
        $'\177'|$'\b')
          if (( cursor > 0 )); then
            input="${input[1,cursor-1]}${input[cursor+1,-1]}"
            (( cursor-- ))
          fi
          ;;
        $'\033')
          IFS= read -r -k 1 key || key=""
          if [[ "$key" == "[" ]]; then
            IFS= read -r -k 1 key || key=""
            case "$key" in
              C) (( cursor < ${#input} )) && (( cursor++ )) ;;
              D) (( cursor > 0 )) && (( cursor-- )) ;;
            esac
          fi
          ;;
        *)
          input="${input[1,cursor]}${key}${input[cursor+1,-1]}"
          (( cursor++ ))
          ;;
      esac
    done

    stty "$old_stty" 2>/dev/null || true
    printf "\033[%d;1H\r\033[2K" "$input_row"
    surface_accept_scramble "$C_WARN" "${input:-menu}"
    printf "\n"
    choice="$input"
    return 0
  fi

  # Fallback for normal Terminal heights: keep the prompt in flow so it never
  # clears the lower part of the rendered menu.
  if [[ -n "${ZSH_VERSION:-}" && -t 0 && -t 1 ]]; then
    local prompt input cursor key old_stty
    prompt="mqlaunch > "
    input=""
    cursor=0

    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%s\n" "$prompt"
    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b\n" "$C_OK" "$prompt_hint" "$C_RESET"
    printf "\033[3A"

    old_stty="$(stty -g)"
    stty -echo -icanon min 1 time 0 2>/dev/null || true

    while true; do
      printf "\r\033[2K%s%s" "$prompt" "$input"
      printf "\r\033[%dC" $(( ${#prompt} + cursor ))

      IFS= read -r -k 1 key || {
        stty "$old_stty" 2>/dev/null || true
        return 1
      }

      case "$key" in
        $'\n'|$'\r')
          break
          ;;
        $'\177'|$'\b')
          if (( cursor > 0 )); then
            input="${input[1,cursor-1]}${input[cursor+1,-1]}"
            (( cursor-- ))
          fi
          ;;
        $'\033')
          IFS= read -r -k 1 key || key=""
          if [[ "$key" == "[" ]]; then
            IFS= read -r -k 1 key || key=""
            case "$key" in
              C) (( cursor < ${#input} )) && (( cursor++ )) ;;
              D) (( cursor > 0 )) && (( cursor-- )) ;;
            esac
          fi
          ;;
        *)
          input="${input[1,cursor]}${key}${input[cursor+1,-1]}"
          (( cursor++ ))
          ;;
      esac
    done

    stty "$old_stty" 2>/dev/null || true
    printf "\r\033[2K"
    surface_accept_scramble "$C_WARN" "${input:-menu}"
    printf "\033[3B\r"
    choice="$input"
    return 0
  fi

  printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
  printf "%b%s%b\n" "$C_OK" "$prompt_hint" "$C_RESET"
  read_prompt "${C_TITLE}mqlaunch > ${C_RESET}" "mqlaunch > "
  printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
  choice="$REPLY"
}

main_loop() {
  local choice

  while true; do
    print_main_menu
    read_main_choice || return
    echo
    handle_main_menu_choice "$choice"
  done
}

if ! main_menu_is_sourced; then
  main_menu_direct_entry "$@"
fi
