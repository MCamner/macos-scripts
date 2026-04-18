#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MISSION CONTROL"
WIDTH=68

line() {
  printf '═%.0s' $(seq 1 "$WIDTH")
  printf '\n'
}

subline() {
  printf '─%.0s' $(seq 1 "$WIDTH")
  printf '\n'
}

section() {
  printf '\n%s\n' "$1"
  subline
}

kv() {
  printf '%-20s %s\n' "$1" "$2"
}

safe_cmd() {
  command -v "$1" >/dev/null 2>&1
}

get_hostname() {
  scutil --get ComputerName 2>/dev/null || hostname
}

get_user() {
  whoami
}

get_shell_name() {
  basename "${SHELL:-unknown}"
}

get_now() {
  date '+%Y-%m-%d %H:%M:%S'
}

get_uptime_pretty() {
  uptime | sed 's/^.*up *//; s/, *[0-9]* users.*$//'
}

get_cpu_load() {
  uptime | awk -F'load averages?: ' '{print $2}' | sed 's/^ *//'
}

get_mem_info() {
  if ! safe_cmd vm_stat; then
    echo "vm_stat unavailable"
    return
  fi

  local page_size pages_free pages_active pages_inactive pages_speculative pages_wired
  page_size="$(vm_stat | awk '/page size of/ {gsub("\\.","",$8); print $8}')"
  pages_free="$(vm_stat | awk '/Pages free/ {gsub("\\.","",$3); print $3}')"
  pages_active="$(vm_stat | awk '/Pages active/ {gsub("\\.","",$3); print $3}')"
  pages_inactive="$(vm_stat | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')"
  pages_speculative="$(vm_stat | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')"
  pages_wired="$(vm_stat | awk '/Pages wired down/ {gsub("\\.","",$4); print $4}')"

  python3 - <<PY
page_size = int("${page_size:-4096}")
free = int("${pages_free:-0}")
active = int("${pages_active:-0}")
inactive = int("${pages_inactive:-0}")
speculative = int("${pages_speculative:-0}")
wired = int("${pages_wired:-0}")

used_bytes = (active + inactive + speculative + wired) * page_size
free_bytes = free * page_size
total_gb = (used_bytes + free_bytes) / (1024**3)
used_gb = used_bytes / (1024**3)
free_gb = free_bytes / (1024**3)

print(f"Used {used_gb:.1f} GB / Total {total_gb:.1f} GB / Free {free_gb:.1f} GB")
PY
}

get_disk_info() {
  df -h / | awk 'NR==2 {print "Used " $3 " / Size " $2 " / Free " $4 " (" $5 " used)"}'
}

get_primary_ip() {
  local ip
  ip="$(ipconfig getifaddr en0 2>/dev/null || true)"
  if [[ -z "$ip" ]]; then
    ip="$(ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$ip" ]]; then
    echo "No primary IP detected"
  else
    echo "$ip"
  fi
}

get_default_route() {
  route -n get default 2>/dev/null | awk '/gateway:/{print $2}' || true
}

get_wifi_name() {
  local airport
  airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
  if [[ -x "$airport" ]]; then
    "$airport" -I 2>/dev/null | awk -F': ' '/ SSID/ {print $2}'
  fi
}

get_battery_info() {
  if safe_cmd pmset; then
    local raw
    raw="$(pmset -g batt 2>/dev/null | tail -1 | sed 's/^ *//')"
    [[ -n "$raw" ]] && echo "$raw" || echo "Battery info unavailable"
  else
    echo "Battery info unavailable"
  fi
}

get_git_info() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local branch dirty
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
      dirty="dirty"
    else
      dirty="clean"
    fi
    echo "Repo: $(basename "$(git rev-parse --show-toplevel 2>/dev/null)") | Branch: $branch | State: $dirty"
  else
    echo "Not in a git repository"
  fi
}

top_processes() {
  ps -Ao pid,comm,%cpu,%mem -r | head -n 6
}

print_header() {
  clear || true
  line
  printf '%*s\n' $(( (WIDTH + ${#APP_NAME}) / 2 )) "$APP_NAME"
  line
}

main() {
  print_header

  section "SYSTEM"
  kv "Host" "$(get_hostname)"
  kv "User" "$(get_user)"
  kv "Shell" "$(get_shell_name)"
  kv "Time" "$(get_now)"
  kv "Uptime" "$(get_uptime_pretty)"

  section "PERFORMANCE"
  kv "CPU Load" "$(get_cpu_load)"
  kv "Memory" "$(get_mem_info)"
  kv "Disk /" "$(get_disk_info)"

  section "NETWORK"
  kv "Primary IP" "$(get_primary_ip)"
  kv "Gateway" "$(get_default_route)"
  kv "Wi-Fi" "$(get_wifi_name:-Not connected)"

  section "POWER"
  kv "Battery" "$(get_battery_info)"

  section "GIT"
  kv "Status" "$(get_git_info)"

  section "TOP PROCESSES"
  printf '%-8s %-28s %-8s %-8s\n' "PID" "COMMAND" "%CPU" "%MEM"
  subline
  top_processes

  printf '\n'
  line
  printf 'Press Enter to return...'
  read -r _
}

main "$@"
