#!/usr/bin/env bash

BASE_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

source "$BASE_DIR/tools/cli/mq-ui.sh"

# ==================================================
# FUNCTIONS
# ==================================================

# Function: Implements the `suggest_fallback` shell routine.
suggest_fallback() {
  echo
  echo "Suggested actions:"
  echo "- Close heavy apps"
  echo "- Restart session"
}

# Function: Implements the `insight_v2` shell routine.
insight_v2() {
  echo
  echo "Analysis:"
  ps -Ao pcpu,comm | sort -nr | awk 'NR>1 && NR<=4 {print "- " $2}'
}

# Function: Implements the `memory_insight` shell routine.
memory_insight() {
  echo
  section "MEMORY (Top consumers)"

  ps -Ao pid,pmem,rss,comm \
    | sort -k2 -nr \
    | head -n 6 \
    | awk '
      NR==1 {printf "%-8s %-6s %-10s %s\n", "PID", "MEM%", "RSS(MB)", "PROCESS"}
      NR>1  {n=split($4,a,"/"); printf "%-8s %-6s %-10.1f %s\n", $1, $2, $3/1024, a[n]}
	    '
}

# Function: Implements the `memory_pressure_v4` shell routine.
memory_pressure_v4() {
  read AVAILABLE_MB COMPRESSED_MB PAGEOUTS <<< \
  $(vm_stat | awk '
    NR==1 {
      page_size=$8
      gsub(/[^0-9]/, "", page_size)
    }
    /Pages free:/ {free=$3}
    /Pages speculative:/ {speculative=$3}
    /Pages purgeable:/ {purgeable=$3}
    /Pages occupied by compressor:/ {compressor=$5}
    /Pageouts:/ {pageouts=$2}
    END {
      gsub(/\./, "", free)
      gsub(/\./, "", speculative)
      gsub(/\./, "", purgeable)
      gsub(/\./, "", compressor)
      gsub(/\./, "", pageouts)

      available=(free + speculative + purgeable) * page_size / 1024 / 1024
      compressed=compressor * page_size / 1024 / 1024

      printf "%.0f %.0f %d\n", available, compressed, pageouts
    }
  ')

  if [ -z "$AVAILABLE_MB" ] || [ -z "$COMPRESSED_MB" ]; then
    MQ_MEM_SCORE=20
    MEM_STATUS="UNKNOWN"
    warn "Memory: unable to read vm_stat"
    return
  fi

  if [ "$COMPRESSED_MB" -lt 1024 ]; then
    MQ_MEM_SCORE=10
    MEM_STATUS="OK"
    ok "Memory OK: ${AVAILABLE_MB} MB available, ${COMPRESSED_MB} MB compressed"
  elif [ "$COMPRESSED_MB" -lt 3000 ]; then
    MQ_MEM_SCORE=20
    MEM_STATUS="PRESSURE"
    warn "Memory PRESSURE: ${AVAILABLE_MB} MB available, ${COMPRESSED_MB} MB compressed"
  else
    MQ_MEM_SCORE=30
    MEM_STATUS="CRITICAL"
    err "Memory CRITICAL: ${AVAILABLE_MB} MB available, ${COMPRESSED_MB} MB compressed"
  fi
}

# Function: Implements the `combined_insight_v2` shell routine.
combined_insight_v2() {
  echo
  section "COMBINED INSIGHT"

  read CPU_PID CPU CPU_NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')
  CPU_NAME=$(basename "$CPU_NAME")

  read MEM_PID MEM MEM_RSS MEM_NAME <<< \
  $(ps -Ao pid,pmem,rss,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3, $4}')
  MEM_NAME=$(basename "$MEM_NAME")

  echo "Top CPU: $CPU_NAME ($CPU%)"
  echo "Top Memory: $MEM_NAME ($(awk "BEGIN {print $MEM_RSS/1024}") MB)"
}

# Function: Implements the `severity_score` shell routine.
severity_score() {
  echo
  section "HEALTH SCORE"

  CORES=$(sysctl -n hw.ncpu)
  LOAD=$(uptime | awk -F'load averages:' '{print $2}' | awk '{print $1}' | tr ',' '.')
  CPU_LOAD="$LOAD"

  CPU_RATIO=$(echo "$LOAD / $CORES" | bc -l 2>/dev/null)
  [ -z "$CPU_RATIO" ] && CPU_RATIO=0

  if (( $(echo "$CPU_RATIO < 0.7" | bc -l) )); then
    CPU_SCORE=10
  elif (( $(echo "$CPU_RATIO < 1.2" | bc -l) )); then
    CPU_SCORE=20
  else
    CPU_SCORE=30
  fi

  MEM_SCORE=${MQ_MEM_SCORE:-20}
  DISK_SCORE=5

  SCORE=$((100 - CPU_SCORE - MEM_SCORE - DISK_SCORE))
  HEALTH_SCORE="$SCORE"

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

# Function: Implements the `no_action_mode` shell routine.
no_action_mode() {
  [ -n "$HEALTH_SCORE" ] || return 1
  [ -n "$MEM_STATUS" ] || return 1
  [ -n "$CPU_LOAD" ] || return 1

  CPU_LOW=$(awk "BEGIN {print ($CPU_LOAD < 4) ? 1 : 0}")

  if [ "$HEALTH_SCORE" -ge 70 ] && [ "$MEM_STATUS" = "OK" ] && [ "$CPU_LOW" -eq 1 ]; then
    echo
    section "SYSTEM STATUS"

    echo "Healthy - no action required"
    echo

    if [ -n "$ROOT_CAUSE_NAME" ]; then
      echo "Note:"
      echo "- $ROOT_CAUSE_NAME is the primary load (normal usage)"
    fi

    return 0
  fi

  return 1
}

# Function: Implements the `suggest_kill` shell routine.
suggest_kill() {
  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')
  NAME=$(basename "$NAME")

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

# Function: Implements the `smart_kill` shell routine.
smart_kill() {
  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')
  NAME=$(basename "$NAME")
  CPU_INT=${CPU%%[.,]*}

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

# Function: Implements the `track_offender` shell routine.
track_offender() {
  LOG="$HOME/.mq/offenders.log"
  mkdir -p "$HOME/.mq"

  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')
  NAME=$(basename "$NAME")

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

# Function: Implements the `score_offenders` shell routine.
score_offenders() {
  echo
  section "OFFENDER RANKING"

  LOG="$HOME/.mq/offenders.log"
  mkdir -p "$HOME/.mq"

  ps -Ao pid,pcpu,pmem,comm \
    | sort -k2 -nr \
    | head -n 6 \
    | awk 'NR>1 {print $1, $2, $3, $4}' | while read PID CPU MEM NAME
  do
    case "$NAME" in
      *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
        continue
        ;;
    esac
    NAME=$(basename "$NAME")
    CPU_INT=${CPU%%[.,]*}
    MEM_INT=${MEM%%[.,]*}

    # repeat count
    COUNT=$(recent_count "$NAME")

    SCORE=$((CPU_INT * 5 + MEM_INT * 3 + COUNT * 2))

    printf "%-20s score: %s\n" "$NAME" "$SCORE"
  done | sort -k3 -nr

  echo
}

# Function: Implements the `top_weighted_action` shell routine.
top_weighted_action() {
  read PID CPU MEM NAME <<< \
  $(ps -Ao pid,pcpu,pmem,comm \
    | sort -k2 -nr \
    | awk 'NR==2 {print $1, $2, $3, $4}')
  NAME=$(basename "$NAME")
  CPU_INT=${CPU%%[.,]*}

  case "$NAME" in
    *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
      return
      ;;
  esac

  if [ "$CPU_INT" -lt 15 ]; then
    return
  fi

  echo "Top offender (weighted):"
  echo "$NAME → Kill recommended"

  read -p "[y/N]: " choice
  [[ "$choice" == "y" ]] && kill -15 "$PID" && echo "✔ killed"
}

# ----------------------------
# DECAY MODEL v1
# ----------------------------

# Function: Implements the `track_offender_decay` shell routine.
track_offender_decay() {
  LOG="$HOME/.mq/offenders.log"
  mkdir -p "$HOME/.mq"

  read PID CPU NAME <<< \
  $(ps -Ao pid,pcpu,comm | sort -k2 -nr | awk 'NR==2 {print $1, $2, $3}')

  NOW=$(date +%s)

  echo "$NOW|$NAME" >> "$LOG"

  # Keep the latest 100 rows.
  tail -n 100 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
}

# Function: Implements the `recent_count` shell routine.
recent_count() {
  LOG="$HOME/.mq/offenders.log"
  NOW=$(date +%s)
  TARGET="$1"

  COUNT=0
  [ -f "$LOG" ] || { echo "$COUNT"; return; }

  while IFS='|' read TS PROC; do
    [[ "$TS" =~ ^[0-9]+$ ]] || continue

    AGE=$((NOW - TS))

    if [ "$AGE" -lt 300 ]; then   # 5 minutes
      if [[ "$(basename "$PROC")" == "$TARGET" ]]; then
        COUNT=$((COUNT + 1))
      fi
    fi
  done < "$LOG"

  echo "$COUNT"
}

# ----------------------------
# MEMORY-WEIGHTED SCORING v3
# ----------------------------

# Function: Implements the `score_offenders_v3` shell routine.
score_offenders_v3() {
  echo
  section "OFFENDER RANKING (v3)"

  LOG="$HOME/.mq/offenders.log"
  mkdir -p "$HOME/.mq"

  ps -Ao pid,pcpu,pmem,rss,comm \
    | sort -k2 -nr \
    | head -n 8 \
    | awk 'NR>1 {print $1, $2, $3, $4, $5}' \
    | while read PID CPU MEM RSS NAME
  do
    CPU_INT=${CPU%%[.,]*}
    MEM_MB=$(awk "BEGIN {printf \"%.0f\", $RSS/1024}")

    # Recent count when decay data exists.
    if command -v recent_count >/dev/null 2>&1; then
      COUNT=$(recent_count "$(basename "$NAME")")
    else
      COUNT=$(grep -c "$NAME" "$LOG" 2>/dev/null)
    fi

    # score: memory-heavy
    SCORE=$(awk "BEGIN {
      print ($MEM_MB * 0.08) + ($CPU_INT * 2) + ($COUNT * 3)
    }")

    printf "%-18s score: %-6.1f  (mem: %4s MB  cpu: %2s%%  seen: %s)\n" \
      "$(basename "$NAME")" "$SCORE" "$MEM_MB" "$CPU_INT" "$COUNT"
  done | sort -k3 -nr

  echo
}

# Function: Implements the `top_weighted_action_v3` shell routine.
top_weighted_action_v3() {
  # Select the highest score from the same calculation.
  TOP_LINE=$(ps -Ao pid,pcpu,pmem,rss,comm \
    | sort -k2 -nr \
    | head -n 8 \
    | awk 'NR>1 {print $0}' \
    | while read PID CPU MEM RSS NAME
      do
        CPU_INT=${CPU%%[.,]*}
        MEM_MB=$(awk "BEGIN {printf \"%.0f\", $RSS/1024}")

        if command -v recent_count >/dev/null 2>&1; then
          COUNT=$(recent_count "$(basename "$NAME")")
        else
          COUNT=0
        fi

        SCORE=$(awk "BEGIN {
          print ($MEM_MB * 0.08) + ($CPU_INT * 2) + ($COUNT * 3)
        }")

        echo "$SCORE|$PID|$CPU|$NAME"
      done | sort -t'|' -k1 -nr | head -n1)

  SCORE=$(echo "$TOP_LINE" | cut -d'|' -f1)
  PID=$(echo "$TOP_LINE" | cut -d'|' -f2)
  CPU=$(echo "$TOP_LINE" | cut -d'|' -f3)
  NAME=$(echo "$TOP_LINE" | cut -d'|' -f4)

  # skydda systemprocesser
  case "$NAME" in
    *"/System/"*|*"coreaudiod"*|*"WindowServer"*)
      return
      ;;
  esac

  CPU_INT=${CPU%%[.,]*}

  # Act only when there is real impact.
  if [ "$CPU_INT" -lt 10 ]; then
    return
  fi

  echo "Top offender (weighted v3):"
  printf "%s  (score %.1f)\n" "$(basename "$NAME")" "$SCORE"

  read -p "Kill recommended [y/N]: " choice
  [[ "$choice" == "y" ]] && kill -15 "$PID" && echo "✔ killed"
}

# ----------------------------
# AUDIO FILTERING v2
# ----------------------------

# Function: Implements the `audio_insight` shell routine.
audio_insight() {
  # Trigger only when coreaudiod appears high in the process list.
  if ! ps -Ao pcpu,comm | sort -nr | head -n 5 | grep -qi coreaudiod; then
    return
  fi

  echo
  section "AUDIO INSIGHT"

  echo "coreaudiod active"

  # Skip noisy output when no likely candidates are found.
  CANDIDATES=$(ps -Ao comm | grep -E "ChatGPT|Chrome|Safari|Spotify|Music|VLC|zoom|Teams|Discord" | wc -l)
  if [ "$CANDIDATES" -eq 0 ]; then
    echo "No clear audio source detected"
    return
  fi

  echo
  echo "Likely audio sources:"

  # Allowlist apps that commonly use audio.
  ps -Ao pid,pcpu,rss,comm \
    | sort -k2 -nr \
    | head -n 20 \
    | awk '
      NR>1 {
        name=$4

        # Normalize to basename.
        n=name
        sub(".*/","",n)

        # Allowlist, extend when needed.
        if (n ~ /(ChatGPT|Chrome|Safari|Firefox|Spotify|Music|QuickTime|VLC|zoom|Teams|Discord|Slack)/) {
          printf "%-18s cpu:%-5s mem:%5.0fMB\n", n, $2, $3/1024
        }
      }
    ' \
    | sort -u

  echo
  echo "Recommendation:"
  echo "- Close tabs/apps playing audio"
  echo "- Check browser (video/music)"
  echo "- Restart audio if glitching: sudo killall coreaudiod"
}

# ----------------------------
# GUI-AWARE INSIGHT v1
# ----------------------------

# Function: Implements the `gui_insight` shell routine.
gui_insight() {
  # Trigger only when WindowServer is a top CPU process.
  if ! ps -Ao pcpu,comm | sort -nr | head -n 5 | grep -qi WindowServer; then
    return
  fi

  echo
  section "GUI INSIGHT"

  echo "WindowServer active"
  echo

  echo "Likely GUI-heavy apps:"

  ps -Ao pid,pcpu,rss,comm \
    | sort -k3 -nr \
    | head -n 15 \
    | awk '
      NR>1 {
        name=$4

        # Remove path and keep only the app name.
        n=name
        sub(".*/","",n)

        # Filter to relevant app processes.
        if (n ~ /(Visual|Code|Chrome|Safari|Firefox|ChatGPT|Slack|Discord|Electron)/) {
          printf "%-18s cpu:%-5s mem:%5.0fMB\n", n, $2, $3/1024
        }
      }
    ' | sort -u

  echo
  echo "Reason:"
  echo "- High memory usage drives rendering"
  echo "- WindowServer reflects UI load"
}

# ----------------------------
# ROOT CAUSE ENGINE v1
# ----------------------------

# Function: Implements the `root_cause_engine` shell routine.
root_cause_engine() {
  echo
  section "ROOT CAUSE"

  TMP="$HOME/.mq/rc.tmp"
  mkdir -p "$HOME/.mq"
  : > "$TMP"

  # Aggregera per app: max RSS, top 3 RSS, max CPU, antal processer
  ps -Ao pid,pcpu,rss,comm \
    | awk '
      NR>1 {
        full_cmd=$0
        sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9.]+[[:space:]]+[0-9]+[[:space:]]+/, "", full_cmd)

        cmd=full_cmd
        gsub(".*/","",cmd)

        # -------- NORMALIZATION --------
        if (full_cmd ~ /ChatGPT/) cmd="ChatGPT"
        else if (full_cmd ~ /Electron/) cmd="Electron"
        else if (full_cmd ~ /Google/) cmd="Google"
        else if (full_cmd ~ /Chrome/) cmd="Chrome"
        else if (full_cmd ~ /Code|Visual Studio Code/) cmd="Visual"

        cpu=($2+0)
        rss_mb=($3/1024)

        # ChatGPT Atlas renderers can report inflated shared RSS.
        # Keep them from dominating app-impact scoring over heavier local apps.
        if (full_cmd ~ /ChatGPT Atlas.*\(Renderer\)/ && rss_mb > 120) rss_mb=120

        if (rss_mb > top1[cmd]) {
          top3[cmd]=top2[cmd]
          top2[cmd]=top1[cmd]
          top1[cmd]=rss_mb
        } else if (rss_mb > top2[cmd]) {
          top3[cmd]=top2[cmd]
          top2[cmd]=rss_mb
        } else if (rss_mb > top3[cmd]) {
          top3[cmd]=rss_mb
        }

        if (rss_mb > max_mem[cmd]) max_mem[cmd]=rss_mb
        if (cpu > max_cpu[cmd]) max_cpu[cmd]=cpu
        count[cmd]++
      }
      END {
        for (k in count) {
          top3_sum=top1[k] + top2[k] + top3[k]
          if (top3_sum > 1500) top3_sum=1500

          printf "%s|%.0f|%.0f|%.0f|%d\n", k, max_mem[k], top3_sum, max_cpu[k], count[k]
        }
      }
    ' > "$TMP"

  # Select the top candidate after filtering system and symptom processes.
  TOP_LINE=$(awk -F'|' '
    {
      name=$1; max_mem=$2+0; top3_mem=$3+0; cpu=$4+0; cnt=$5+0

      # Filter symptom and system processes.
      if (name ~ /(WindowServer|coreaudiod|trustd|syspolicyd|kernel|launchd|loginwindow)/) next

      # impact scoring v4: max process + top 3 processes + CPU
      score = (max_mem * 0.6) + (top3_mem * 0.3) + (cpu * 0.1)

      printf "%f|%s|%d|%d|%d|%d\n", score, name, max_mem, top3_mem, cpu, cnt
    }
  ' "$TMP" | sort -t'|' -k1 -nr | head -n1)

  if [ -z "$TOP_LINE" ]; then
    echo "No clear root cause detected"
    return
  fi

  SCORE=$(echo "$TOP_LINE" | cut -d'|' -f1)
  NAME=$(echo "$TOP_LINE" | cut -d'|' -f2)
  ROOT_CAUSE_NAME="$NAME"
  MAX_MEM=$(echo "$TOP_LINE" | cut -d'|' -f3)
  TOP3_MEM=$(echo "$TOP_LINE" | cut -d'|' -f4)
  ROOT_MEM_TOP3="$TOP3_MEM"
  CPU=$(echo "$TOP_LINE" | cut -d'|' -f5)
  CNT=$(echo "$TOP_LINE" | cut -d'|' -f6)

  # Confidence heuristik
  CONF="MEDIUM"
  if [ "$MAX_MEM" -gt 450 ]; then CONF="HIGH"; fi
  if [ "$TOP3_MEM" -gt 1000 ]; then CONF="HIGH"; fi
  if [ "$CPU" -gt 20 ]; then CONF="HIGH"; fi
  INST=$( [ "$CNT" -gt 5 ] && echo "5+" || echo "$CNT" )

  echo "$NAME"
  echo
  echo "Confidence: $CONF"
  echo
  echo "Reason:"
  echo "- Max process memory: ${MAX_MEM} MB"
  echo "- Top 3 memory: ${TOP3_MEM} MB"
  echo "- Peak CPU: ${CPU}%"
  echo "- Instances: $INST"

  no_action_mode && return

  echo
  echo "Recommended action:"
  echo "- Close or restart $NAME"
}

# Function: Implements the `trend_engine_v1` shell routine.
trend_engine_v1() {
  [ -n "$ROOT_CAUSE_NAME" ] || return
  [ -n "$ROOT_MEM_TOP3" ] || return

  echo
  section "TREND"

  LOG="$HOME/.mq/trend.log"
  mkdir -p "$HOME/.mq"

  NOW=$(date +%s)
  echo "$NOW|$ROOT_CAUSE_NAME|$ROOT_MEM_TOP3" >> "$LOG"
  tail -n 50 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

  LAST=$(tail -n 5 "$LOG")

  if [ "$(echo "$LAST" | wc -l | tr -d ' ')" -lt 3 ]; then
    echo "Not enough data yet"
    return
  fi

  APP_HISTORY=$(echo "$LAST" | awk -F'|' -v app="$ROOT_CAUSE_NAME" '$2 == app')

  if [ "$(echo "$APP_HISTORY" | sed '/^$/d' | wc -l | tr -d ' ')" -lt 2 ]; then
    echo "$ROOT_CAUSE_NAME stable"
    echo
    echo "Pattern:"
    echo "- New primary load; collecting trend data"
    return
  fi

  PREV_MEM=$(echo "$APP_HISTORY" | head -n 1 | cut -d'|' -f3)
  CURR_MEM=$(echo "$APP_HISTORY" | tail -n 1 | cut -d'|' -f3)
  DIFF=$((CURR_MEM - PREV_MEM))

  if [ "$DIFF" -gt 200 ]; then
    echo "$ROOT_CAUSE_NAME increasing load"
    PATTERN="Rising memory usage detected"
  elif [ "$DIFF" -lt -200 ]; then
    echo "$ROOT_CAUSE_NAME decreasing load"
    PATTERN="Memory usage is easing"
  else
    echo "$ROOT_CAUSE_NAME stable"
    PATTERN="Load is stable"
  fi

  echo
  echo "Memory change: ${DIFF} MB"
  echo
  echo "Pattern:"
  echo "- $PATTERN"
}

# ==================================================
# MAIN
# ==================================================

header "MQ SCAN"

track_offender_decay

section "SYSTEM"
ok "CPU: $(uptime | awk -F'load averages:' '{print $2}')"

section "MEMORY"
memory_pressure_v4

section "STORAGE"
ok "Disk: $(df -h / | awk 'NR==2 {print $5}')"

section "TOP PROCESSES"

ps -Ao pid,pcpu,comm \
  | sort -k2 -nr \
  | head -n 6 \
  | awk '
    NR==1 {printf "%-8s %-6s %s\n", "PID", "CPU%", "PROCESS"}
    NR>1  {n=split($3,a,"/"); printf "%-8s %-6s %s\n", $1, $2, a[n]}
  '

suggest_kill
smart_kill
track_offender
memory_insight
score_offenders_v3
top_weighted_action_v3
combined_insight_v2
audio_insight
gui_insight
severity_score
root_cause_engine
trend_engine_v1

section "SUMMARY"
ok "Scan complete"
