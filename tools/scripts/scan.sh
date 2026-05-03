#!/usr/bin/env bash

source "$HOME/macos-scripts/tools/cli/mq-ui.sh"

header "MQ SCAN"

# ----------------------------
# SYSTEM
# ----------------------------

section "SYSTEM"

CPU=$(sysctl -n hw.ncpu)
LOAD_RAW=$(uptime | awk -F'load averages:' '{print $2}' | xargs)
LOAD1=$(echo "$LOAD_RAW" | awk '{print $1}' | tr ',' '.')

LOW_T=$(echo "$CPU * 0.7" | bc -l)
HIGH_T=$(echo "$CPU * 1.2" | bc -l)

if (( $(echo "$LOAD1 < $LOW_T" | bc -l) )); then
  ok "CPU: $LOAD_RAW"
elif (( $(echo "$LOAD1 < $HIGH_T" | bc -l) )); then
  warn "CPU elevated: $LOAD_RAW"
else
  blink_err "CPU HIGH: $LOAD_RAW"
fi

# ----------------------------
# MEMORY
# ----------------------------

read -r FREE ACTIVE INACTIVE SPEC WIRED COMP SWAPIN SWAPOUT <<< \
$(vm_stat | awk '
/Pages free/ {free=$3}
/Pages active/ {active=$3}
/Pages inactive/ {inactive=$3}
/Pages speculative/ {spec=$3}
/Pages wired down/ {wired=$4}
/Pages occupied by compressor/ {comp=$5}
/Swapins/ {si=$2}
/Swapouts/ {so=$2}
END {
  gsub("\\.","",free); gsub("\\.","",active); gsub("\\.","",inactive);
  gsub("\\.","",spec); gsub("\\.","",wired); gsub("\\.","",comp);
  gsub("\\.","",si); gsub("\\.","",so);
  printf "%s %s %s %s %s %s %s %s", free, active, inactive, spec, wired, comp, si, so
}')

TOTAL=$((FREE+ACTIVE+INACTIVE+SPEC))
USED=$((ACTIVE+INACTIVE))
PCT=$(awk "BEGIN { printf \"%.1f\", ($USED/$TOTAL)*100 }")

if [ "$SWAPOUT" -gt 0 ]; then
  blink_err "Memory PRESSURE: ${PCT}%"
elif [ "$COMP" -gt 500000 ]; then
  warn "Memory compressed: ${PCT}%"
else
  ok "Memory: ${PCT}%"
fi

# ----------------------------
# STORAGE
# ----------------------------

section "STORAGE"

DISK=$(df -h / | awk 'NR==2 {print $5}')
USAGE=$(echo "$DISK" | tr -d '%')

if [ "$USAGE" -lt 70 ]; then
  ok "Disk: $DISK"
elif [ "$USAGE" -lt 85 ]; then
  warn "Disk filling: $DISK"
else
  blink_err "Disk CRITICAL: $DISK"
fi

# ----------------------------
# SUGGEST + SAFE KILL
# ----------------------------

suggest_kill() {
  read TOP_PID TOP_CPU TOP_NAME <<< \
  $(ps -Ao pid,pcpu,comm \
    | sort -k2 -nr \
    | awk 'NR==2 {print $1, $2, $3}')

  echo
  echo "Top offender:"
  printf "PID: %s | CPU: %s | PROCESS: %s\n" "$TOP_PID" "$TOP_CPU" "$TOP_NAME"

  case "$TOP_NAME" in
    *"/System/"*|*"kernel"*|*"launchd"*|*"WindowServer"*|*"coreaudiod"*)
      echo "⚠ Protected system process — kill blocked"
      return
      ;;
  esac

  echo
  read -p "Kill this process? [y/N]: " choice

  case "$choice" in
    y|Y)
      kill -15 "$TOP_PID" && echo "✔ Process killed" || echo "✖ Failed"
      ;;
    *)
      echo "Skipped"
      ;;
  esac
}

# ----------------------------
# TOP PROCESSES + ACTION
# ----------------------------

section "TOP PROCESSES"

ps -Ao pid,pcpu,comm \
  | sort -k2 -nr \
  | head -n 6 \
  | awk '
    NR==1 {printf "%-8s %-6s %s\n", "PID", "CPU%", "PROCESS"}
    NR>1  {printf "%-8s %-6s %s\n", $1, $2, $3}
  '

suggest_kill

# ----------------------------
# SUMMARY
# ----------------------------

section "SUMMARY"
ok "Scan complete"

echo

suggest_fallback() {
  echo
  echo "Suggested actions:"
  echo "- Close heavy apps (ChatGPT, browser, etc)"
  echo "- Restart session (logout/login)"
  echo "- Check Activity Monitor → Memory tab"
  echo "- Reboot if pressure persists"
}

# ----------------------------
# INSIGHT LAYER v1
# ----------------------------

insight_layer() {
  local name="$1"

  echo
  echo "Likely cause:"

  case "$name" in
    *coreaudiod*)
      echo "- Audio subsystem load"
      echo "- Apps using audio (browser, Spotify, Zoom)"
      ;;
    *WindowServer*)
      echo "- GUI / rendering load"
      echo "- Many windows, high resolution, animations"
      ;;
    *ChatGPT*|*Electron*)
      echo "- Electron app memory usage"
      ;;
    *)
      echo "- General system load"
      ;;
  esac

  echo
  echo "Suggested actions:"

  case "$name" in
    *coreaudiod*)
      echo "- Close apps using audio"
      echo "- Restart audio service: sudo killall coreaudiod"
      ;;
    *WindowServer*)
      echo "- Close heavy GUI apps"
      echo "- Logout/login"
      ;;
    *ChatGPT*|*Electron*)
      echo "- Restart the app"
      echo "- Reduce tabs / sessions"
      ;;
    *)
      echo "- Close heavy apps"
      echo "- Restart session if needed"
      ;;
  esac
}
