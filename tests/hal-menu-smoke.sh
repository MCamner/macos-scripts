#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/10] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/10] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/10] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/10] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/10] bridge routes audit"
grep -q "audit)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6/10] bridge routes release-brief"
grep -q "release-brief|release)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[7/10] audit and release readiness are reachable from the menu"
# Asserted as reachable actions rather than as label text. The rows were "Audit"
# and "Release Brief" while seventeen choices sat flat on the front menu; audit
# is in the Diagnostics submenu now, with `a` and `audit` still typed straight
# into the front loop, and the release row reads "Release readiness". A grep for
# the old wording tested the layout, not whether the actions still run.
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"
for backend_cmd in audit release-brief; do
  # Matched from MQ_HAL_BIN onward: the literal `"$MQ_HAL_BIN"` cannot go into an
  # ERE as written, since `$` there is an end-of-line anchor rather than a dollar.
  grep -qE "MQ_HAL_BIN\" $backend_cmd([;[:space:]]|$)" "$MENU" || {
    echo "FAIL: no menu option runs mq-hal $backend_cmd" >&2
    exit 1
  }
done

echo "[8/10] hal json commands do not add launcher pause text"
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

echo "[9/10] unknown input is not run as a shell command"
# The front menu used to end in `*) /bin/zsh -lc "$choice" 2>/dev/null || true`,
# so mistyping at the HAL prompt executed the typo — silently, because stderr
# went to /dev/null. This drives the real menu with a command that would leave a
# file behind, and requires that it does not.
# Driven against a stub backend, not the one on this machine. `mq_hal_menu_main`
# returns 127 before reading a single line when $MQ_HAL_BIN is missing, so on a
# runner with no ~/mq-hal this step passed by never running the menu at all — it
# reported "a typo stays a typo" while proving nothing. The step below caught it
# because a vacuous run cannot create the file either.
export MQ_HAL_BIN="$tmp_hal/mq-hal"
probe="$(mktemp -u)"
printf 'touch %s\nb\n' "$probe" | timeout 30 bash "$MENU" >/dev/null 2>&1 || true
if [[ -e "$probe" ]]; then
  rm -f "$probe"
  echo "FAIL: unrecognised menu input was executed as a shell command" >&2
  exit 1
fi
echo "  ok: a typo at the HAL prompt stays a typo"

echo "[10/10] an explicit ! prefix still reaches the shell"
# The guard above is only worth having while the deliberate route still works,
# or the next person removes the prefix rather than the risk.
printf '! touch %s\nb\n' "$probe" | timeout 30 bash "$MENU" >/dev/null 2>&1 || true
if [[ ! -e "$probe" ]]; then
  echo "FAIL: '! <command>' did not run the command" >&2
  exit 1
fi
rm -f "$probe"
echo "  ok: ! runs what follows it"

echo "OK: HAL menu smoke test passed"
