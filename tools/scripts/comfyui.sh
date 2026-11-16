#!/usr/bin/env bash
set -euo pipefail

# Starts and stops ComfyUI from the MQ-AI drive. It runs in the background on
# 127.0.0.1 with its own venv, so the MQ stack and Ollama are untouched; stop
# frees the RAM after image generation.

COMFYUI_DIR="${COMFYUI_DIR:-/Volumes/MQ-AI/AI-Apps/ComfyUI}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"
COMFYUI_WAIT="${COMFYUI_WAIT:-120}"
LOG_DIR="${COMFYUI_LOG_DIR:-$HOME/Library/Logs/mqlaunch}"
LOG_FILE="$LOG_DIR/comfyui.log"
URL="http://127.0.0.1:$COMFYUI_PORT"

# Prints an error and exits 1.
die() {
  printf 'comfyui: %s\n' "$*" >&2
  exit 1
}

# Prints usage.
usage() {
  cat <<EOF
Usage: mqlaunch comfyui [start|stop|status|log]

  start   Start ComfyUI from the MQ-AI drive and open $URL (default)
  stop    Stop the ComfyUI server and free its memory
  status  Report whether ComfyUI is running
  log     Follow the ComfyUI output live (Ctrl-C stops following, not ComfyUI)

Environment: COMFYUI_DIR (default /Volumes/MQ-AI/AI-Apps/ComfyUI), COMFYUI_PORT
Log: $LOG_FILE
EOF
}

# Prints the PID listening on the ComfyUI port, or nothing.
listener_pid() {
  lsof -nP -t -iTCP:"$COMFYUI_PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

# True when the PID runs with the ComfyUI directory as its working directory.
# That is what separates our server from anything else on the port.
is_comfyui_pid() {
  local pid="$1" cwd want
  want="$(cd "$COMFYUI_DIR" 2>/dev/null && pwd -P)" || return 1
  cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1)"
  [[ -n "$cwd" && "$cwd" == "$want" ]]
}

# Starts the server in the background and waits until it answers.
cmd_start() {
  if [[ ! -f "$COMFYUI_DIR/main.py" || ! -x "$COMFYUI_DIR/.venv/bin/python" ]]; then
    die "ComfyUI not found at $COMFYUI_DIR — is the MQ-AI drive connected?"
  fi

  local pid
  pid="$(listener_pid)"
  if [[ -n "$pid" ]]; then
    is_comfyui_pid "$pid" || die "port $COMFYUI_PORT is used by another process (PID $pid)"
    printf 'OK: ComfyUI already running at %s (PID %s)\n' "$URL" "$pid"
    open "$URL" >/dev/null 2>&1 || true
    return 0
  fi

  mkdir -p "$LOG_DIR"
  printf 'Starting ComfyUI from %s...\n' "$COMFYUI_DIR"
  (
    cd "$COMFYUI_DIR"
    nohup .venv/bin/python main.py \
      --listen 127.0.0.1 \
      --port "$COMFYUI_PORT" \
      --lowvram \
      --reserve-vram 2 \
      --preview-method none >"$LOG_FILE" 2>&1 &
  )

  local i
  for ((i = 0; i < COMFYUI_WAIT; i++)); do
    if curl -fsS "$URL" >/dev/null 2>&1; then
      printf 'OK: ComfyUI ready at %s\n' "$URL"
      printf 'Follow its output: mqlaunch comfyui log\n'
      open "$URL" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 1
  done

  die "ComfyUI did not answer at $URL within ${COMFYUI_WAIT}s — see $LOG_FILE"
}

# Stops the server; refuses to touch a process that is not ComfyUI.
cmd_stop() {
  local pid
  pid="$(listener_pid)"
  if [[ -z "$pid" ]]; then
    printf 'OK: ComfyUI not running\n'
    return 0
  fi

  is_comfyui_pid "$pid" || die "port $COMFYUI_PORT is used by another process (PID $pid); not stopping it"

  printf 'Stopping ComfyUI (PID %s)...\n' "$pid"
  kill "$pid" 2>/dev/null || true

  local i
  for ((i = 0; i < 100; i++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      printf 'OK: ComfyUI stopped\n'
      return 0
    fi
    sleep 0.1
  done

  kill -9 "$pid" 2>/dev/null || true
  printf 'OK: ComfyUI stopped (forced after 10s)\n'
}

# Reports whether the server is running.
cmd_status() {
  local pid
  pid="$(listener_pid)"
  if [[ -z "$pid" ]]; then
    printf 'ComfyUI: not running\n'
  elif is_comfyui_pid "$pid"; then
    printf 'ComfyUI: running at %s (PID %s)\n' "$URL" "$pid"
  else
    printf 'ComfyUI: not running (port %s used by PID %s)\n' "$COMFYUI_PORT" "$pid"
  fi
}

# Follows the server output. Ctrl-C ends tail only; ComfyUI keeps running.
cmd_log() {
  [[ -f "$LOG_FILE" ]] || die "no log yet at $LOG_FILE — start ComfyUI first"
  printf '%s (Ctrl-C stops following; ComfyUI keeps running)\n' "$LOG_FILE"
  exec tail -n 50 -f "$LOG_FILE"
}

# Runs the main entry point.
main() {
  case "${1:-start}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    status) cmd_status ;;
    log) cmd_log ;;
    -h|--help|help) usage ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
