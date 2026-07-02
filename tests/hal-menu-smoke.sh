#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/9] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/9] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/9] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/9] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/9] bridge routes audit"
grep -q "audit)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6/9] bridge routes release-brief"
grep -q "release-brief|release)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[7/9] menu shows Audit"
grep -q "Audit" "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[8/9] menu shows Release Brief"
grep -q "Release Brief" "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[9/9] hal json commands do not add launcher pause text"
tmp_hal="$(mktemp -d)"
trap 'rm -rf "$tmp_hal"' EXIT
cat > "$tmp_hal/mq-hal" <<'FAKE_HAL'
#!/usr/bin/env bash
case "${1:-}" in
  release-brief)
    printf '{"status":"ok","source":"fake-mq-hal"}\n'
    ;;
  *)
    printf 'fake mq-hal: unsupported command: %s\n' "${1:-}" >&2
    exit 2
    ;;
esac
FAKE_HAL
chmod +x "$tmp_hal/mq-hal"
MQ_HAL_BIN="$tmp_hal/mq-hal" "$ROOT/terminal/launchers/mqlaunch.sh" hal release-brief --sample --json >/tmp/mqlaunch-hal-release-brief.json
python3 -m json.tool /tmp/mqlaunch-hal-release-brief.json >/dev/null
! grep -q "Press Enter" /tmp/mqlaunch-hal-release-brief.json

echo "OK: HAL menu smoke test passed"
