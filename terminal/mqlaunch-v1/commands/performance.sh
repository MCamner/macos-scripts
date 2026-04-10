#!/usr/bin/env bash

performance_reports_dir() {
  local dir="$PROJECT_ROOT/backups/performance-reports"
  mkdir -p "$dir"
  printf "%s\n" "$dir"
}

perf_trim() {
  echo "$1" | awk '{$1=$1; print}'
}

perf_cpu_count() {
  sysctl -n hw.logicalcpu 2>/dev/null || echo "1"
}

perf_load_1m() {
  uptime | awk -F'load averages?: ' '{print $2}' | awk -F', ' '{print $1}' | tr -d ' '
}

perf_disk_percent_root() {
  df -h / | tail -1 | awk '{print $5}' | tr -d '%'
}

perf_battery_percent() {
  pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 | tr -d '%' || true
}

perf_memory_pressure_level() {
  local mp
  mp="$(memory_pressure 2>/dev/null || true)"

  if echo "$mp" | grep -qi "System-wide memory free percentage"; then
    local free_pct
    free_pct="$(echo "$mp" | awk -F': ' '/System-wide memory free percentage/ {print $2}' | tr -d '%')"

    if [[ -n "${free_pct:-}" ]]; then
      if (( free_pct < 5 )); then
        echo "critical"
        return
      elif (( free_pct < 10 )); then
        echo "high"
        return
      elif (( free_pct < 20 )); then
        echo "medium"
        return
      else
        echo "normal"
        return
      fi
    fi
  fi

  echo "unknown"
}

perf_network_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

perf_score_status() {
  local score="$1"
  if (( score >= 90 )); then
    echo "Excellent"
  elif (( score >= 75 )); then
    echo "Good"
  elif (( score >= 55 )); then
    echo "Warning"
  else
    echo "Critical"
  fi
}

perf_score_color() {
  local score="$1"
  if (( score >= 90 )); then
    printf "%b" "$C_GREEN"
  elif (( score >= 75 )); then
    printf "%b" "$C_CYAN"
  elif (( score >= 55 )); then
    printf "%b" "$C_YELLOW"
  else
    printf "%b" "$C_RED"
  fi
}

perf_health_score() {
  local score=100
  local warnings=()

  local disk_pct
  local batt_pct
  local load_1m
  local cpu_count
  local mem_level
  local net_ip

  disk_pct="$(perf_disk_percent_root)"
  batt_pct="$(perf_battery_percent)"
  load_1m="$(perf_load_1m)"
  cpu_count="$(perf_cpu_count)"
  mem_level="$(perf_memory_pressure_level)"
  net_ip="$(perf_network_ip)"

  if [[ -n "${disk_pct:-}" ]]; then
    if (( disk_pct >= 95 )); then
      score=$((score - 40))
      warnings+=("Disk usage on / is critical (${disk_pct}%)")
    elif (( disk_pct >= 90 )); then
      score=$((score - 25))
      warnings+=("Disk usage on / is very high (${disk_pct}%)")
    elif (( disk_pct >= 80 )); then
      score=$((score - 12))
      warnings+=("Disk usage on / is elevated (${disk_pct}%)")
    fi
  fi

  if [[ -n "${batt_pct:-}" ]]; then
    if (( batt_pct <= 10 )); then
      score=$((score - 20))
      warnings+=("Battery is critically low (${batt_pct}%)")
    elif (( batt_pct <= 20 )); then
      score=$((score - 10))
      warnings+=("Battery is low (${batt_pct}%)")
    fi
  fi

  if [[ -n "${load_1m:-}" && -n "${cpu_count:-}" ]]; then
    local load_ratio
    load_ratio="$(awk -v load="$load_1m" -v cpu="$cpu_count" 'BEGIN { if (cpu <= 0) cpu=1; printf "%.2f", load/cpu }')"

    if awk -v r="$load_ratio" 'BEGIN { exit !(r >= 2.0) }'; then
      score=$((score - 25))
      warnings+=("CPU load is critical (load/core ratio ${load_ratio})")
    elif awk -v r="$load_ratio" 'BEGIN { exit !(r >= 1.2) }'; then
      score=$((score - 12))
      warnings+=("CPU load is elevated (load/core ratio ${load_ratio})")
    fi
  fi

  case "$mem_level" in
    critical)
      score=$((score - 30))
      warnings+=("Memory pressure is critical")
      ;;
    high)
      score=$((score - 18))
      warnings+=("Memory pressure is high")
      ;;
    medium)
      score=$((score - 8))
      warnings+=("Memory pressure is elevated")
      ;;
  esac

  if [[ -z "${net_ip:-}" ]]; then
    score=$((score - 8))
    warnings+=("No active primary network IP found")
  fi

  (( score < 0 )) && score=0
  (( score > 100 )) && score=100

  printf "%s\n" "$score"
  printf "%s\n" "---WARNINGS---"
  if (( ${#warnings[@]} == 0 )); then
    printf "%s\n" "No major issues detected"
  else
    printf "%s\n" "${warnings[@]}"
  fi
}

command_perf_health_score() {
  print_header
  print_section "Performance Health Score"

  local output
  local score
  local status
  local color
  local warnings
  local batt_display
  local net_display

  output="$(perf_health_score)"
  score="$(echo "$output" | sed -n '1p')"
  warnings="$(echo "$output" | sed '1d' | sed '1d')"
  status="$(perf_score_status "$score")"
  color="$(perf_score_color "$score")"

  batt_display="$(perf_battery_percent)"
  [[ -z "$batt_display" ]] && batt_display="N/A"

  net_display="$(perf_network_ip)"
  [[ -z "$net_display" ]] && net_display="Unavailable"

  echo -e "Score: ${color}${score}/100${C_RESET}"
  echo "Status: $status"
  echo

  print_section "Warnings"
  echo "$warnings"
  echo

  print_section "Signals"
  echo "Load (1m):       $(perf_load_1m)"
  echo "CPU cores:       $(perf_cpu_count)"
  echo "Disk (/):        $(perf_disk_percent_root)%"
  echo "Battery:         $batt_display%"
  echo "Memory pressure: $(perf_memory_pressure_level)"
  echo "Network IP:      $net_display"

  pause_enter
}

command_perf_overview() {
  print_header
  print_section "Performance Overview"

  local cpu_line
  local mem_pressure
  local disk_line
  local ip_addr
  local battery_line
  local score_output
  local score
  local status
  local color
  local warnings

  cpu_line="$(uptime)"
  mem_pressure="$(memory_pressure 2>/dev/null | tail -5 || true)"
  disk_line="$(df -h / | tail -1)"
  ip_addr="$(perf_network_ip)"
  battery_line="$(pmset -g batt 2>/dev/null | tail -1 || echo "Battery info unavailable")"

  score_output="$(perf_health_score)"
  score="$(echo "$score_output" | sed -n '1p')"
  warnings="$(echo "$score_output" | sed '1d' | sed '1d')"
  status="$(perf_score_status "$score")"
  color="$(perf_score_color "$score")"

  echo -e "Health score: ${color}${score}/100${C_RESET} ($status)"
  echo

  echo "Uptime / Load:"
  echo "$cpu_line"
  echo

  echo "Disk (/):"
  echo "$disk_line"
  echo

  echo "Network IP:"
  echo "${ip_addr:-No active Wi-Fi/Ethernet IP found}"
  echo

  echo "Battery:"
  echo "$battery_line"
  echo

  echo "Memory pressure:"
  if [[ -n "$mem_pressure" ]]; then
    echo "$mem_pressure"
  else
    echo "Memory pressure data unavailable"
  fi
  echo

  print_section "Warnings"
  echo "$warnings"

  pause_enter
}

command_perf_cpu_top() {
  print_header
  print_section "Top CPU Processes"

  ps -Ao pid,ppid,%cpu,%mem,etime,comm | sort -k3 -nr | head -n 15

  pause_enter
}

command_perf_mem_top() {
  print_header
  print_section "Top Memory Processes"

  ps -Ao pid,ppid,%mem,%cpu,etime,comm | sort -k3 -nr | head -n 15

  pause_enter
}

command_perf_disk_usage() {
  print_header
  print_section "Disk Usage"

  df -h
  echo

  print_section "Largest folders in project root"
  du -sh "$PROJECT_ROOT"/* 2>/dev/null | sort -hr | head -n 20

  pause_enter
}

command_perf_network() {
  print_header
  print_section "Network Overview"

  echo "Active IP:"
  perf_network_ip || echo "No active interface IP found"
  echo

  echo "Routes:"
  netstat -rn | head -n 20
  echo

  echo "Listening ports:"
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | head -n 20

  pause_enter
}

command_perf_battery() {
  print_header
  print_section "Battery Status"

  pmset -g batt 2>/dev/null || echo "Battery data unavailable"
  echo
  pmset -g ps 2>/dev/null || true

  pause_enter
}

command_perf_snapshot() {
  print_header
  print_section "Create Performance Snapshot"

  local reports_dir
  local ts
  local outfile
  local score_output
  local score
  local warnings

  reports_dir="$(performance_reports_dir)"
  ts="$(date +"%Y-%m-%d_%H-%M-%S")"
  outfile="$reports_dir/perf-snapshot-$ts.txt"

  score_output="$(perf_health_score)"
  score="$(echo "$score_output" | sed -n '1p')"
  warnings="$(echo "$score_output" | sed '1d' | sed '1d')"

  {
    echo "macOS Performance Snapshot"
    echo "Generated: $(date)"
    echo "Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
    echo "User: $(whoami)"
    echo

    echo "=== HEALTH SCORE ==="
    echo "Score: $score/100"
    echo "Status: $(perf_score_status "$score")"
    echo "Warnings:"
    echo "$warnings"
    echo

    echo "=== UPTIME / LOAD ==="
    uptime
    echo

    echo "=== DISK ==="
    df -h
    echo

    echo "=== MEMORY PRESSURE ==="
    memory_pressure 2>/dev/null || echo "memory_pressure unavailable"
    echo

    echo "=== VM STAT ==="
    vm_stat
    echo

    echo "=== TOP CPU ==="
    ps -Ao pid,ppid,%cpu,%mem,etime,comm | sort -k3 -nr | head -n 20
    echo

    echo "=== TOP MEMORY ==="
    ps -Ao pid,ppid,%mem,%cpu,etime,comm | sort -k3 -nr | head -n 20
    echo

    echo "=== NETWORK ==="
    perf_network_ip || echo "No active interface IP found"
    echo
    netstat -rn | head -n 40
    echo
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | head -n 40
    echo

    echo "=== BATTERY ==="
    pmset -g batt 2>/dev/null || echo "Battery data unavailable"
    echo

    echo "=== PROJECT SIZE ==="
    du -sh "$PROJECT_ROOT"/* 2>/dev/null | sort -hr | head -n 50
    echo
  } > "$outfile"

  ok "Snapshot created:"
  echo "$outfile"
  echo

  if command_exists open; then
    open -R "$outfile" 2>/dev/null || true
  fi

  pause_enter
}

command_perf_quick_watch() {
  print_header
  print_section "Quick Watch"

  echo "Refreshing every 2 seconds. Press Ctrl+C to stop."
  echo

  while true; do
    local score_output
    local score
    local status

    score_output="$(perf_health_score)"
    score="$(echo "$score_output" | sed -n '1p')"
    status="$(perf_score_status "$score")"

    clear
    print_section "Quick Watch"
    echo "Time: $(date)"
    echo "Health: $score/100 ($status)"
    echo
    uptime
    echo
    df -h / | tail -1
    echo
    pmset -g batt 2>/dev/null | tail -1 || echo "Battery data unavailable"
    echo
    echo "Top CPU:"
    ps -Ao %cpu,comm | sort -nr | head -n 6
    echo
    echo "Top Memory:"
    ps -Ao %mem,comm | sort -nr | head -n 6
    sleep 2
  done
}
