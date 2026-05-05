#!/usr/bin/env bash

performance_reports_dir() {
  local dir="$PROJECT_ROOT/backups/performance-reports"
  mkdir -p "$dir"
  printf "%s\n" "$dir"
}

perf_has_command() {
  command -v "$1" >/dev/null 2>&1
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

perf_disk_line_root() {
  df -h / | tail -1
}

perf_battery_percent() {
  if perf_has_command pmset; then
    pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 | tr -d '%' || true
  fi
}

perf_battery_line() {
  if perf_has_command pmset; then
    pmset -g batt 2>/dev/null | tail -1 || echo "Battery info unavailable"
  else
    echo "Battery info unavailable"
  fi
}

perf_memory_pressure_raw() {
  if perf_has_command memory_pressure; then
    memory_pressure 2>/dev/null || true
  fi
}

perf_memory_pressure_tail() {
  local mp
  mp="$(perf_memory_pressure_raw)"
  if [[ -n "$mp" ]]; then
    echo "$mp" | tail -5
  else
    echo "Memory pressure data unavailable"
  fi
}

perf_memory_pressure_level() {
  local mp
  mp="$(perf_memory_pressure_raw)"

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

perf_network_display() {
  local ip
  ip="$(perf_network_ip)"
  [[ -z "$ip" ]] && ip="Unavailable"
  echo "$ip"
}

perf_battery_display() {
  local batt
  batt="$(perf_battery_percent)"
  [[ -z "$batt" ]] && batt="N/A"
  echo "$batt"
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
    printf "%b" "${C_GREEN:-$'\033[32m'}"
  elif (( score >= 75 )); then
    printf "%b" "${C_CYAN:-$'\033[36m'}"
  elif (( score >= 55 )); then
    printf "%b" "${C_YELLOW:-$'\033[33m'}"
  else
    printf "%b" "${C_RED:-$'\033[31m'}"
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
  local output score perf_status color warnings width
  width="$(surface_terminal_width)"
  
  output="$(perf_health_score)"
  score="$(echo "$output" | sed -n '1p')"
  warnings="$(echo "$output" | sed '1d' | sed '1d')"
  perf_status="$(perf_score_status "$score")"
  color="$(perf_score_color "$score")"

  print_header
  surface_top "Performance Health Score" "$width" "$C_INFO"
  surface_row "Score:  ${color}${score}/100${C_RESET} ($perf_status)" "$width" ""
  surface_row "" "$width" ""
  
  surface_row "SIGNALS" "$width" "$C_INFO"
  surface_split_row "Load (1m): $(perf_load_1m)" "CPU cores: $(perf_cpu_count)" "$width" ""
  surface_split_row "Disk (/): $(perf_disk_percent_root)%" "Battery: $(perf_battery_display)%" "$width" ""
  surface_split_row "Memory: $(perf_memory_pressure_level)" "Network: $(perf_network_display)" "$width" ""
  
  if [[ -n "$warnings" && "$warnings" != "No major issues detected" ]]; then
    surface_row "" "$width" ""
    surface_row "WARNINGS" "$width" "$C_WARN"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      surface_row "! $line" "$width" ""
    done <<< "$warnings"
  fi
  
  surface_bottom "$width" "$C_INFO"
  pause_enter
}

command_perf_overview() {
  local cpu_line mem_pressure disk_line ip_addr battery_line score_output score perf_status color warnings width
  width="$(surface_terminal_width)"

  cpu_line="$(uptime)"
  mem_pressure="$(perf_memory_pressure_level)"
  disk_line="$(perf_disk_percent_root)%"
  ip_addr="$(perf_network_display)"
  battery_line="$(perf_battery_display)%"

  score_output="$(perf_health_score)"
  score="$(echo "$score_output" | sed -n '1p')"
  warnings="$(echo "$score_output" | sed '1d' | sed '1d')"
  perf_status="$(perf_score_status "$score")"
  color="$(perf_score_color "$score")"

  print_header
  surface_top "Performance Overview" "$width" "$C_INFO"
  surface_row "Health score: ${color}${score}/100${C_RESET} ($perf_status)" "$width" ""
  surface_row "" "$width" ""
  
  surface_row "SYSTEM STATE" "$width" "$C_INFO"
  surface_row "Load: $cpu_line" "$width" ""
  surface_row "Disk: $disk_line   Memory: $mem_pressure   Battery: $battery_line" "$width" ""
  surface_row "Network IP: $ip_addr" "$width" ""
  
  if [[ -n "$warnings" && "$warnings" != "No major issues detected" ]]; then
    surface_row "" "$width" ""
    surface_row "WARNINGS" "$width" "$C_WARN"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      surface_row "! $line" "$width" ""
    done <<< "$warnings"
  fi
  
  surface_bottom "$width" "$C_INFO"
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
  echo "$(perf_network_display)"
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

  if perf_has_command pmset; then
    pmset -g batt 2>/dev/null || echo "Battery data unavailable"
    echo
    pmset -g ps 2>/dev/null || true
  else
    echo "Battery data unavailable"
  fi

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
    perf_memory_pressure_raw || echo "memory_pressure unavailable"
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
    perf_network_display
    echo
    netstat -rn | head -n 40
    echo
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | head -n 40
    echo

    echo "=== BATTERY ==="
    perf_battery_line
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
    local perf_status
    local disk_line
    local batt_line

    score_output="$(perf_health_score)"
    score="$(echo "$score_output" | sed -n '1p')"
    perf_status="$(perf_score_status "$score")"
    disk_line="$(perf_disk_line_root)"
    batt_line="$(perf_battery_line)"

    clear
    print_section "Quick Watch"
    print_kv "Time:" "$(date)"
    print_kv "Health:" "$score/100 ($perf_status)"
    echo
    print_divider
    echo
    uptime
    echo
    echo "$disk_line"
    echo
    echo "$batt_line"
    echo
    echo "Top CPU:"
    ps -Ao %cpu,comm | sort -nr | head -n 6
    echo
    echo "Top Memory:"
    ps -Ao %mem,comm | sort -nr | head -n 6
    sleep 2
  done
}
