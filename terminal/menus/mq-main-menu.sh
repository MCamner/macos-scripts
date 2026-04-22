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
  row_bold "MAIN MENU"
  empty_row

  row "CORE"
  row2 " 1. Workflows" " 2. System"
  row2 " 3. Git" " 4. Release"
  row2 " 5. Dev" " 6. Help"

  empty_row
  row "QUICK ACCESS"
  row2 " p. Performance" " n. Network"
  row2 " h. Health Check" " a. Apps"

  empty_row
  render_command_surface
}

surface_terminal_width() {
  local cols width
  cols="$(tput cols 2>/dev/null || true)"
  [[ "$cols" =~ ^[0-9]+$ ]] || cols="${BOX_INNER:-88}"

  width=$(( cols - 2 ))
  (( width > 112 )) && width=112
  (( width < 32 )) && width=32
  printf "%s" "$width"
}

surface_pad() {
  local text="$1"
  local width="$2"
  printf "%-*.*s" "$width" "$width" "$text"
}

surface_top() {
  local title="$1"
  local width="$2"
  local color="$3"
  local fill=$(( width - 5 - ${#title} ))
  (( fill < 0 )) && fill=0
  printf "%b┌─ %s %s┐%b\n" "$color" "$title" "$(repeat_char "$fill" "─")" "$C_RESET"
}

surface_bottom() {
  local width="$1"
  local color="$2"
  printf "%b└%s┘%b\n" "$color" "$(repeat_char $(( width - 2 )) "─")" "$C_RESET"
}

surface_row() {
  local text="$1"
  local width="$2"
  local color="$3"
  local inner=$(( width - 4 ))
  printf "%b│ %s │%b\n" "$color" "$(surface_pad "$text" "$inner")" "$C_RESET"
}

surface_split_row() {
  local left="$1"
  local right="$2"
  local width="$3"
  local color="$4"
  local inner left_width right_width
  inner=$(( width - 4 ))
  left_width=$(( inner / 2 ))
  right_width=$(( inner - left_width - 1 ))
  printf "%b│ %s %s │%b\n" \
    "$color" \
    "$(surface_pad "$left" "$left_width")" \
    "$(surface_pad "$right" "$right_width")" \
    "$C_RESET"
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
    surface_dual_figure_row "▄▄████▄▄" " ▄▄██▄▄ " "" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "████████" "█▀████▀█" "$system_state" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row "██▄██▄██" "██▀██▀██" "Repo: macos-scripts" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_dual_figure_row " ▄█▀▀█▄ " " ▀▄██▄▀ " "$activity" "$width" "$SURFACE_COLOR" "$FIGURE_COLOR" "$ALT_FIGURE_COLOR"
    surface_split_row "Host: ${HOST_NAME}" "User: ${USER_NAME}" "$width" "$SURFACE_COLOR"
    surface_split_row "Time: ${TIME}" "X. Exit launcher" "$width" "$SURFACE_COLOR"
  fi
  surface_bottom "$width" "$SURFACE_COLOR"
}

handle_main_menu_choice() {
  local choice="$1"

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

    # EXIT
    x|X)
      echo "Exiting ${APP_TITLE}..."
      exit 0
      ;;

    *)
      echo "${C_ERR}Invalid selection:${C_RESET} $choice"
      pause_enter
      ;;
  esac
}

read_main_choice() {
  local prompt_line prompt_hint prompt_color prompt_width
  prompt_width="$(surface_terminal_width)"
  prompt_line="$(repeat_char "$prompt_width" "─")"
  prompt_hint=">> choose an option, command alias, or x to exit"
  if [[ -t 1 ]]; then
    prompt_color=$'\033[0;37m'
  else
    prompt_color=""
  fi

  if [[ -n "${ZSH_VERSION:-}" && -t 0 && -t 1 ]]; then
    local prompt input cursor key old_stty
    prompt="mqlaunch > "
    input=""
    cursor=0

    printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%s" "$prompt"
    printf "\n%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
    printf "%b%s%b\n\n" "$C_OK" "$prompt_hint" "$C_RESET"
    printf "\033[4A"

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
    printf "\r\033[2K%s%s\n\033[3B" "$prompt" "$input"
    choice="$input"
    return 0
  fi

  printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
  read_prompt "${C_TITLE}mqlaunch > ${C_RESET}" "mqlaunch > "
  printf "%b%s%b\n" "$prompt_color" "$prompt_line" "$C_RESET"
  printf "%b%s%b\n\n" "$C_OK" "$prompt_hint" "$C_RESET"
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
