#!/usr/bin/env bash
set -euo pipefail

# tools/scripts/comfyui.sh starts ComfyUI from the MQ-AI drive in the
# background and stops it again. These checks run against a fake ComfyUI
# directory whose .venv/bin/python serves HTTP on a spare port, so no drive,
# model or GPU is needed. `open` is stubbed so no browser starts.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/tools/scripts/comfyui.sh"

echo "SMOKE: comfyui start/stop"

TMP="$(mktemp -d)"
STRAY_PID=""
cleanup() {
  COMFYUI_DIR="$TMP/comfy" COMFYUI_PORT="${PORT:-0}" "$SCRIPT" stop >/dev/null 2>&1 || true
  [[ -n "$STRAY_PID" ]] && kill "$STRAY_PID" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

free_port() {
  python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'
}

mkdir -p "$TMP/bin" "$TMP/comfy/.venv/bin" "$TMP/logs"
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/open"
chmod +x "$TMP/bin/open"
touch "$TMP/comfy/main.py"
# Fake interpreter: picks --port out of the ComfyUI arguments and serves HTTP.
cat >"$TMP/comfy/.venv/bin/python" <<'EOF'
#!/usr/bin/env bash
port=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "--port" ]] && port="$2"
  shift
done
exec python3 -m http.server "$port" --bind 127.0.0.1
EOF
chmod +x "$TMP/comfy/.venv/bin/python"

PORT="$(free_port)"
export PATH="$TMP/bin:$PATH" COMFYUI_PORT="$PORT" COMFYUI_LOG_DIR="$TMP/logs"

echo "[1/7] syntax check"
bash -n "$SCRIPT"

echo "[2/7] missing drive fails with exit 1"
set +e
out="$(COMFYUI_DIR="$TMP/nope" "$SCRIPT" start 2>&1)"
rc=$?
set -e
[[ $rc -eq 1 ]] || { echo "  expected exit 1, got $rc" >&2; exit 1; }
grep -q 'MQ-AI' <<<"$out" || { echo "  message does not name the drive: $out" >&2; exit 1; }

echo "[3/7] unknown subcommand fails with exit 2"
set +e
COMFYUI_DIR="$TMP/comfy" "$SCRIPT" nonsense >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 2 ]] || { echo "  expected exit 2, got $rc" >&2; exit 1; }

export COMFYUI_DIR="$TMP/comfy"

echo "[4/7] start returns once the server answers, and does not block"
"$SCRIPT" start >/dev/null
curl -fsS "http://127.0.0.1:$PORT/" >/dev/null
"$SCRIPT" status | grep -q 'running' || { echo "  status does not report running" >&2; exit 1; }
# A second start reuses the running server.
"$SCRIPT" start | grep -q 'already running' || { echo "  second start did not reuse" >&2; exit 1; }

echo "[5/7] stop frees the port"
"$SCRIPT" stop >/dev/null
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "  port $PORT still listening after stop" >&2
  exit 1
fi
"$SCRIPT" status | grep -q 'not running' || { echo "  status after stop is wrong" >&2; exit 1; }
"$SCRIPT" stop | grep -q 'not running' || { echo "  stop when stopped is not a no-op" >&2; exit 1; }

echo "[6/7] stop refuses a listener that is not ComfyUI"
(cd "$TMP" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
STRAY_PID=$!
for _ in {1..50}; do
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  sleep 0.1
done
set +e
"$SCRIPT" stop >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] || { echo "  expected exit 1, got $rc" >&2; exit 1; }
kill -0 "$STRAY_PID" 2>/dev/null || { echo "  stop killed a foreign process" >&2; exit 1; }
set +e
"$SCRIPT" start >/dev/null 2>&1
rc=$?
set -e
[[ $rc -eq 1 ]] || { echo "  start over a foreign listener: expected exit 1, got $rc" >&2; exit 1; }

echo "[7/7] the menu path main 5 -> Dev 10 -> Menus 5/6 reaches comfyui"
MAIN="$ROOT/terminal/menus/mq-main-menu.sh"
DEV="$ROOT/terminal/menus/mq-dev-menu.sh"
grep -qE '^[[:space:]]+5\) open_dev_menu ;;' "$MAIN" || { echo "  main 5 does not open Dev" >&2; exit 1; }
grep -qE '^[[:space:]]+10\) dev_menus_menu_loop ;;' "$DEV" || { echo "  Dev 10 does not open Menus" >&2; exit 1; }
menus="$(sed -n '/^dev_menus_menu_loop()/,/^}/p' "$DEV")"
for n in "5:start" "6:stop"; do
  grep -qE "^[[:space:]]+${n%%:*}\) \"\\\$BASE_DIR/bin/mqlaunch\" comfyui ${n##*:};" <<<"$menus" || {
    echo "  Menus ${n%%:*} does not run comfyui ${n##*:}" >&2; exit 1; }
done
grep -q '"5. Start ComfyUI" "6. Stop ComfyUI"' <<<"$menus" || { echo "  Menus panel does not draw the ComfyUI rows" >&2; exit 1; }

echo "OK: comfyui smoke test passed"
