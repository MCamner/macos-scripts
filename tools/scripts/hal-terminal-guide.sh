#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
GUIDE_HTML="$BASE_DIR/docs/mac-terminal-guide.html"
GUIDE_FALLBACK="$BASE_DIR/tools/mac-terminal-guide/mac-terminal-guide.html"
VECTOR_STORE_ID="${MQ_TERMINAL_GUIDE_VECTOR_STORE_ID:-vs_69f93de12f508191bd6a36ea3b825beb}"
REPO_URL="${MQ_REPO_URL:-https://github.com/MCamner/macos-scripts}"

hal_width() {
  local cols
  cols="$(tput cols 2>/dev/null || echo 80)"
  (( cols < 64 )) && cols=64
  (( cols > 80 )) && cols=80
  printf '%s\n' "$cols"
}

hal_repeat() {
  local count="$1"
  local char="${2:- }"
  local out=""

  while (( count > 0 )); do
    out+="$char"
    (( count-- ))
  done

  printf '%s' "$out"
}

hal_pad() {
  local text="$1"
  local width="$2"
  local len pad
  len="${#text}"

  if (( len > width )); then
    printf '%s' "${text:0:width}"
    return
  fi

  pad=$(( width - len ))
  printf '%s%s' "$text" "$(hal_repeat "$pad" " ")"
}

hal_top() {
  local title="$1"
  local width="$2"
  local inner rest
  inner=$(( width - 4 ))
  rest=$(( inner - ${#title} - 1 ))
  (( rest < 0 )) && rest=0

  printf '┌─ %s %s┐\n' "$title" "$(hal_repeat "$rest" "─")"
}

hal_row() {
  local text="$1"
  local width="$2"
  local inner
  inner=$(( width - 4 ))
  printf '│ %s │\n' "$(hal_pad "$text" "$inner")"
}

hal_split_row() {
  local left="$1"
  local right="$2"
  local width="$3"
  local inner left_width right_width
  inner=$(( width - 4 ))
  left_width=$(( inner / 2 ))
  right_width=$(( inner - left_width ))

  printf '│ %s%s │\n' "$(hal_pad "$left" "$left_width")" "$(hal_pad "$right" "$right_width")"
}

hal_bottom() {
  local width="$1"
  printf '└%s┘\n' "$(hal_repeat "$(( width - 2 ))" "─")"
}

load_env_file() {
  local file="$1"
  local line key value

  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# || -z "${line// }" ]] && continue
    line="${line#export }"
    key="${line%%=*}"
    value="${line#*=}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    case "$key" in
      OPENAI_API_KEY)
        : "${OPENAI_API_KEY:=$value}"
        ;;
      MQ_TERMINAL_GUIDE_VECTOR_STORE_ID)
        VECTOR_STORE_ID="$value"
        ;;
    esac
  done < "$file"
}

load_env_file "$HOME/.env"
load_env_file "$BASE_DIR/.env"

usage() {
  cat <<'USAGE'
hal-terminal-guide.sh - ask or run commands grounded in the mac terminal guide

Usage:
  tools/scripts/hal-terminal-guide.sh
  tools/scripts/hal-terminal-guide.sh ask "question"
  tools/scripts/hal-terminal-guide.sh run "open Google Chrome"
  tools/scripts/hal-terminal-guide.sh open-guide

Examples:
  tools/scripts/hal-terminal-guide.sh ask "how do I open an app from Terminal?"
  tools/scripts/hal-terminal-guide.sh run "open Google Chrome"
USAGE
}

guide_file() {
  if [[ -f "$GUIDE_HTML" ]]; then
    printf '%s\n' "$GUIDE_HTML"
  else
    printf '%s\n' "$GUIDE_FALLBACK"
  fi
}

open_guide() {
  local guide
  guide="$(guide_file)"

  if [[ -f "$guide" ]]; then
    open "$guide"
  else
    printf 'Guide file not found: %s\n' "$guide" >&2
    return 1
  fi
}

lower_text() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

safe_intent_command() {
  local query app path lower
  query="$1"
  lower="$(lower_text "$query")"

  case "$lower" in
    1|finder|*"öppna finder"*|*"open finder"*|*"starta finder"*)
      app="Finder"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    2|safari|*"öppna safari"*|*"open safari"*|*"starta safari"*)
      app="Safari"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    3|chrome|google\ chrome|*"öppna google chrome"*|*"open google chrome"*|*"starta google chrome"*|*"öppna chrome"*|*"open chrome"*)
      app="Google Chrome"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    4|spotify|*"öppna spotify"*|*"open spotify"*|*"starta spotify"*)
      app="Spotify"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    5|xcode|*"öppna xcode"*|*"open xcode"*|*"starta xcode"*)
      app="Xcode"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    6|system\ settings|settings|*"öppna system settings"*|*"open system settings"*|*"öppna systeminställningar"*)
      app="System Settings"
      printf 'app|%s|open -a "%s"\n' "$app" "$app"
      return 0
      ;;
    7|downloads|download|*"öppna downloads"*|*"open downloads"*|*"öppna hämtade filer"*)
      path="$HOME/Downloads"
      printf 'path|%s|open "%s"\n' "$path" "$path"
      return 0
      ;;
    8|home|home\ folder|*"open home folder"*|*"öppna home"*|*"open home"*)
      path="$HOME"
      printf 'path|%s|open "%s"\n' "$path" "$path"
      return 0
      ;;
    9|utilities|utilities\ folder|*"open utilities folder"*|*"öppna utilities"*|*"open utilities"*)
      path="/Applications/Utilities"
      printf 'path|%s|open "%s"\n' "$path" "$path"
      return 0
      ;;
    10|applications|applications\ folder|*"open applications folder"*|*"öppna applications"*|*"open applications"*)
      path="/Applications"
      printf 'path|%s|open "%s"\n' "$path" "$path"
      return 0
      ;;
    11|lock|lock\ screen|*"lås skärm"*|*"lock screen"*|*"lock mac"*)
      printf 'lock|Lock screen|CGSession -suspend\n'
      return 0
      ;;
    12|sleep|sleep\ display|*"sleep display"*|*"turn off display"*|*"släck skärm"*)
      printf 'sleep|Sleep display|pmset displaysleepnow\n'
      return 0
      ;;
    13|restart\ finder|*"restart finder"*|*"starta om finder"*)
      printf 'restart_finder|Restart Finder|killall Finder\n'
      return 0
      ;;
    14|repo|repo\ browser|repo\ in\ browser|*"repo in browser"*|*"open repo"*|*"öppna repo"*)
      printf 'url|Repo in browser|open "%s"\n' "$REPO_URL"
      return 0
      ;;
    guide|open\ guide|*"öppna guide"*|*"open guide"*|*"terminal guide"*|*"terminalguiden"*)
      printf 'guide|mac terminal guide|open guide\n'
      return 0
      ;;
  esac

  return 1
}

execute_safe_intent() {
  local intent="$1"
  local kind label command confirm
  IFS='|' read -r kind label command <<< "$intent"

  printf 'HAL: I found a safe guide action.\n'
  printf 'Target:  %s\n' "$label"
  printf 'Command: %s\n' "$command"
  printf 'Run it now? [y/N] '
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || {
    printf 'Cancelled.\n'
    return 0
  }

  case "$kind" in
    app)
      open -a "$label"
      ;;
    path)
      open "$label"
      ;;
    guide)
      open_guide
      ;;
    url)
      open "$REPO_URL"
      ;;
    lock)
      if [[ -x "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" ]]; then
        "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
      else
        osascript -e 'tell application "System Events" to keystroke "q" using {control down, command down}' >/dev/null 2>&1
      fi
      ;;
    sleep)
      pmset displaysleepnow
      ;;
    restart_finder)
      killall Finder >/dev/null 2>&1
      ;;
    *)
      printf 'Unsupported safe action: %s\n' "$kind" >&2
      return 1
      ;;
  esac
}

print_hal_menu() {
  local width
  width="$(hal_width)"

  hal_top "HAL" "$width"
  hal_row "Terminal Guide and Safe macOS Actions" "$width"
  hal_row "" "$width"
  hal_row "APPS" "$width"
  hal_split_row " 1. Finder" " 2. Safari" "$width"
  hal_split_row " 3. Google Chrome" " 4. Spotify" "$width"
  hal_split_row " 5. Xcode" " 6. System Settings" "$width"
  hal_row "" "$width"
  hal_row "FOLDERS" "$width"
  hal_split_row " 7. Downloads" " 8. Home" "$width"
  hal_split_row " 9. Utilities" "10. Applications" "$width"
  hal_row "" "$width"
  hal_row "QUICK ACTIONS" "$width"
  hal_split_row "11. Lock screen" "12. Sleep display" "$width"
  hal_split_row "13. Restart Finder" "14. Repo in browser" "$width"
  hal_row "" "$width"
  hal_row "Type a number, a command, or a question." "$width"
  hal_row "Commands: /guide, /quit" "$width"
  hal_bottom "$width"
}

local_guide_search() {
  local query guide term
  query="$1"
  guide="$(guide_file)"
  term="$(printf '%s' "$query" | tr ' ' '\n' | grep -E '.{4,}' | head -1 || true)"

  [[ -f "$guide" && -n "$term" ]] || return 0

  printf '\nLocal guide matches:\n'
  rg -i -m 5 "$term" "$guide" \
    | sed -E 's/^[^:]+:[0-9]+:[[:space:]]*//' \
    | sed -E 's/&quot;/"/g; s/&#39;/'"'"'/g; s/<[^>]+>//g' \
    | sed -n '1,5p'
}

ask_vector_store() {
  local question="$1"
  local payload response text

  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    printf 'OPENAI_API_KEY is not set. Falling back to local guide search.\n'
    local_guide_search "$question"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is missing. Falling back to local guide search.\n'
    local_guide_search "$question"
    return 0
  fi

  payload="$(jq -n \
    --arg q "$question" \
    --arg vs "$VECTOR_STORE_ID" \
    '{
      model: "gpt-4.1-mini",
      input: (
        "You are HAL Terminal Guide for mqlaunch. Use file search from the mac terminal guide. " +
        "Answer in English unless the user explicitly asks for another language. Be concise and practical. " +
        "Prefer safe macOS terminal commands from the guide. " +
        "If a command is potentially destructive or uses sudo, warn before showing it. " +
        "Question: " + $q
      ),
      tools: [{ type: "file_search", vector_store_ids: [$vs] }]
    }')"

  printf 'HAL thinking... '
  response="$(curl -s https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload" || true)"
  printf '\r\033[2K'

  text="$(printf '%s' "$response" | jq -r '
    first(
      .output[]
      | select(.type == "message")
      | .content[]
      | select(.type == "output_text")
      | .text
    ) // .error.message // ""
  ' 2>/dev/null)"

  if [[ -z "$text" || "$text" == "null" ]]; then
    printf 'No AI response. Local guide fallback:\n'
    local_guide_search "$question"
    return 0
  fi

  printf '%s\n' "$text"
}

handle_query() {
  local mode="$1"
  local query="$2"
  local intent

  if intent="$(safe_intent_command "$query")"; then
    execute_safe_intent "$intent"
    return
  fi

  if [[ "$mode" == "run" ]]; then
    printf 'HAL: I do not have a safe executable action for that yet.\n'
    ask_vector_store "$query"
    return
  fi

  ask_vector_store "$query"
}

prompt_loop() {
  local query

  while true; do
    print_hal_menu
    printf '────────────────────────────────────────────────────────────────────────────────\n'
    printf '>> option, command, question, or /quit\n'
    printf 'hal > '
    read -r query || return

    case "$query" in
      "" ) continue ;;
      /quit|quit|exit|q) break ;;
      /guide) open_guide ;;
      *) handle_query "ask" "$query" ;;
    esac
  done
}

main() {
  local cmd="${1:-menu}"
  shift || true

  case "$cmd" in
    menu) prompt_loop ;;
    ask) handle_query "ask" "$*" ;;
    run) handle_query "run" "$*" ;;
    open-guide|guide) open_guide ;;
    help|-h|--help) usage ;;
    *)
      handle_query "ask" "$cmd $*"
      ;;
  esac
}

main "$@"
