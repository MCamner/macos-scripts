#!/usr/bin/env bash

source "$HOME/macos-scripts/tools/cli/mq-ui.sh"

# ==================================================
# FUNCTIONS
# ==================================================

suggest_fallback() {
  echo
  echo "Suggested actions:"
  echo "- Close heavy apps"
  echo "- Restart session"
}

insight_v2() {
  echo
  echo "Analysis:"
  ps -Ao pcpu,comm | sort -nr | awk 'NR>1 && NR<=4 {print "- " $2}'
}

memory_insight() {
  echo
  section "MEMORY (Top consumers)"

  ps -Ao pid,pmem,rss,comm \
    | sort -k2 -nr \
    | head -n 6 \
    | awk '
      NR==1 {printf "%-8s %-6s %-10s %s\n", "PID", "MEM%", "RSS(MB)", "PROCESS"}
      NR>1  {printf "%-8s %-6s %-10.1f %s\n", $1, $2, $3/1024, $4}
    '
}

combined_insight_v2() {
  echo
  section "COMBINED INSIGHT"

  read CPU_PID CPU CPU_NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')

  read MEM_PID MEM MEM_RSS MEM_NAME <<< \
  $(ps -Ao pid,pmem,rss,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3, $4}')

  echo "Top CPU: $CPU_NAME ($CPU%)"
  echo "Top Memory: $MEM_NAME ($(awk "BEGIN {print $MEM_RSS/1024}") MB)"
}

severity_score() {
  echo
  section "HEALTH SCORE"

  CORES=$(sysctl -n hw.ncpu)
  LOAD=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr ',' '.')

  CPU_RATIO=$(echo "$LOAD / $CORES" | bc -l 2>/dev/null)
  [ -z "$CPU_RATIO" ] && CPU_RATIO=0

  if (( $(echo "$CPU_RATIO < 0.7" | bc -l) )); then
    CPU_SCORE=10
  elif (( $(echo "$CPU_RATIO < 1.2" | bc -l) )); then
    CPU_SCORE=20
  else
    CPU_SCORE=30
  fi

  MEM_SCORE=20
  DISK_SCORE=5

  SCORE=$((100 - CPU_SCORE - MEM_SCORE - DISK_SCORE))

  if [ "$SCORE" -gt 80 ]; then
    STATUS="HEALTHY"
  elif [ "$SCORE" -gt 60 ]; then
    STATUS="MODERATE"
  else
    STATUS="CRITICAL"
  fi

  echo "Score: $SCORE / 100"
  echo "Status: $STATUS"
}

suggest_kill() {
  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')

  echo
  echo "Top offender:"
  echo "PID: $PID | CPU: $CPU | PROCESS: $NAME"

  case "$NAME" in
    *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
      echo "⚠ Protected system process"
      suggest_fallback
      return
      ;;
  esac

  read -p "Kill this process? [y/N]: " choice
  [[ "$choice" == "y" ]] && kill -15 "$PID" && echo "✔ killed"
}

smart_kill() {
  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')

  CPU_INT=${CPU%.*}

  if [ "$CPU_INT" -lt 15 ]; then
    return
  fi

  case "$NAME" in
    *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
      return
      ;;
  esac

  echo
  echo "Smart suggestion:"
  echo "$NAME ($CPU%)"

  read -p "Kill recommended [y/N]: " choice
  [[ "$choice" == "y" ]] && kill -15 "$PID" && echo "✔ killed"
}

track_offender() {
  LOG="$HOME/.mq/offenders.log"
  mkdir -p "$HOME/.mq"

  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')

  echo "$NAME" >> "$LOG"

  COUNT=$(grep -c "$NAME" "$LOG" 2>/dev/null)

  # limit log size
  tail -n 50 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

  # only escalate if non-system
  case "$NAME" in
    *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
      return
      ;;
  esac

  if [ "$COUNT" -ge 3 ]; then
    echo
    echo "Repeat offender detected:"
    echo "$NAME seen $COUNT times"

    echo
    echo "Escalation:"
    echo "- Consistent CPU usage"

    echo
    read -p "Kill strongly recommended [y/N]: " choice

    case "$choice" in
      y|Y)
        kill -15 "$PID" && echo "✔ killed"
        ;;
      *)
        echo "Skipped"
        ;;
    esac
  fi
}

# ==================================================
# MAIN
# ==================================================

header "MQ SCAN"

section "SYSTEM"
ok "CPU: $(uptime | awk -F'load averages:' '{print $2}')"

section "MEMORY"
err "Memory PRESSURE: check system"

section "STORAGE"
ok "Disk: $(df -h / | awk 'NR==2 {print $5}')"

section "TOP PROCESSES"

ps -Ao pid,pcpu,comm \
  | sort -k2 -nr \
  | head -n 6 \
  | awk '
    NR==1 {printf "%-8s %-6s %s\n", "PID", "CPU%", "PROCESS"}
    NR>1  {printf "%-8s %-6s %s\n", $1, $2, $3}
  '

suggest_kill
smart_kill
track_offender
memory_insight
combined_insight_v2
severity_score

section "SUMMARY"
ok "Scan complete"

