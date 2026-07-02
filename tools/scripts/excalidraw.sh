#!/usr/bin/env bash
set -euo pipefail

EXCALIDRAW_DIR="${EXCALIDRAW_DIR:-$HOME/excalidraw}"
PROXY_DIR="${EXCALIDRAW_PROXY_DIR:-$HOME/excalidraw-ai-proxy}"
FRONTEND_URL="${EXCALIDRAW_URL:-http://localhost:3003}"
PROXY_URL="${EXCALIDRAW_PROXY_URL:-http://127.0.0.1:3016}"
LOG_DIR="${EXCALIDRAW_LOG_DIR:-$HOME/Library/Logs/mqlaunch}"

mkdir -p "$LOG_DIR"

die() {
  printf 'excalidraw: %s\n' "$*" >&2
  exit 1
}

need_dir() {
  [[ -d "$1" ]] || die "missing directory: $1"
}

port_listening() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

wait_for_url() {
  local url="$1"
  local label="$2"
  local i

  for i in {1..45}; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      printf 'OK: %s ready at %s\n' "$label" "$url"
      return 0
    fi
    sleep 1
  done

  die "$label did not become ready at $url"
}

ensure_yarn() {
  if command -v yarn >/dev/null 2>&1; then
    return 0
  fi

  command -v corepack >/dev/null 2>&1 || die "yarn not found and corepack is unavailable"
  corepack enable >/dev/null 2>&1 || true
  corepack prepare yarn@1.22.22 --activate >/dev/null
}

start_proxy() {
  need_dir "$PROXY_DIR"

  if port_listening 3016; then
    printf 'OK: proxy already listening on 3016\n'
    return 0
  fi

  [[ -f "$PROXY_DIR/.env" ]] || die "missing proxy .env: $PROXY_DIR/.env"
  if grep -q '^OPENAI_API_KEY=sk-your-key-here$' "$PROXY_DIR/.env"; then
    die "proxy .env still contains the placeholder OPENAI_API_KEY"
  fi

  printf 'Starting Excalidraw AI proxy...\n'
  (
    cd "$PROXY_DIR"
    nohup npm start >"$LOG_DIR/excalidraw-ai-proxy.log" 2>&1 &
  )
}

start_frontend() {
  need_dir "$EXCALIDRAW_DIR"

  if port_listening 3003; then
    printf 'OK: frontend already listening on 3003\n'
    return 0
  fi

  ensure_yarn

  printf 'Starting Excalidraw frontend...\n'
  (
    cd "$EXCALIDRAW_DIR"
    nohup yarn start >"$LOG_DIR/excalidraw-frontend.log" 2>&1 &
  )
}

main() {
  start_proxy
  wait_for_url "$PROXY_URL/health" "proxy"

  start_frontend
  wait_for_url "$FRONTEND_URL" "frontend"

  printf 'Opening %s\n' "$FRONTEND_URL"
  open "$FRONTEND_URL" >/dev/null 2>&1 || true

  printf '\nLogs:\n'
  printf '  %s\n' "$LOG_DIR/excalidraw-ai-proxy.log"
  printf '  %s\n' "$LOG_DIR/excalidraw-frontend.log"
}

main "$@"
