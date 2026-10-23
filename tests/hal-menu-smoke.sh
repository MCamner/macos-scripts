#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: HAL menu"

echo "[1/13] menu file exists"
test -f "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[2/13] menu is executable"
test -x "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[3/13] menu syntax check"
bash -n "$ROOT/terminal/menus/mq-hal-menu.sh"

echo "[4/13] bridge syntax check"
bash -n "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[5/13] bridge routes audit"
grep -q "audit)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6/13] bridge routes release-brief"
grep -q "release-brief|release)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[6b/13] bridge routes HAL intelligence commands explicitly"
grep -q "route)" "$ROOT/terminal/bridges/hal-bridge.sh"
grep -q "provenance)" "$ROOT/terminal/bridges/hal-bridge.sh"
grep -q "compatibility)" "$ROOT/terminal/bridges/hal-bridge.sh"
grep -q "code-plan)" "$ROOT/terminal/bridges/hal-bridge.sh"

echo "[7/13] audit and release readiness are reachable from the menu"
# Asserted as reachable actions rather than as label text. The rows were "Audit"
# and "Release Brief" while seventeen choices sat flat on the front menu; audit
# is in the Diagnostics submenu now, with `a` and `audit` still typed straight
# into the front loop, and the release row reads "Release readiness". A grep for
# the old wording tested the layout, not whether the actions still run.
MENU="$ROOT/terminal/menus/mq-hal-menu.sh"
for backend_cmd in audit release-brief provenance compatibility; do
  # Matched from MQ_HAL_BIN onward: the literal `"$MQ_HAL_BIN"` cannot go into an
  # ERE as written, since `$` there is an end-of-line anchor rather than a dollar.
  grep -qE "MQ_HAL_BIN\" $backend_cmd([;[:space:]]|$)" "$MENU" || {
    echo "FAIL: no menu option runs mq-hal $backend_cmd" >&2
    exit 1
  }
done
for route_view in status readiness divergence; do
  grep -q "MQ_HAL_BIN\" route $route_view" "$MENU" || {
    echo "FAIL: routing submenu does not call mq-hal route $route_view" >&2
    exit 1
  }
done
grep -q 'MQ_HAL_BIN" code-plan --provider "$provider" --repo "$repo" "$goal"' "$MENU" || {
  echo "FAIL: cloud code-plan dialog does not delegate to mq-hal code-plan" >&2
  exit 1
}

echo "[8/13] hal json commands do not add launcher pause text"
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

echo "[8b/13] HAL route evidence views forward losslessly"
cat > "$tmp_hal/mq-hal" <<'FAKE_HAL'
#!/usr/bin/env bash
printf 'mq-hal'
printf ' <%s>' "$@"
printf '\n'
FAKE_HAL
chmod +x "$tmp_hal/mq-hal"
[[ "$(MQ_HAL_BIN="$tmp_hal/mq-hal" "$ROOT/terminal/launchers/mqlaunch.sh" hal route readiness --json)" ==   'mq-hal <route> <readiness> <--json>' ]]
[[ "$(MQ_HAL_BIN="$tmp_hal/mq-hal" "$ROOT/terminal/launchers/mqlaunch.sh" hal route divergence --task-class docs-review --era execution-completeness --json)" ==   'mq-hal <route> <divergence> <--task-class> <docs-review> <--era> <execution-completeness> <--json>' ]]

echo "[9/13] unknown input is not run as a shell command"
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

echo "[10/13] an explicit ! prefix still reaches the shell"
# The guard above is only worth having while the deliberate route still works,
# or the next person removes the prefix rather than the risk.
printf '! touch %s\nb\n' "$probe" | timeout 30 bash "$MENU" >/dev/null 2>&1 || true
if [[ ! -e "$probe" ]]; then
  echo "FAIL: '! <command>' did not run the command" >&2
  exit 1
fi
rm -f "$probe"
echo "  ok: ! runs what follows it"

echo "[11/13] the menu uses no bash 4 case expansion"
# Static, because the render check below is only as strong as the shells the
# machine happens to have. A Linux runner has bash 5 — where `${x^^}` works —
# and usually no zsh at all, so on CI that check would have passed on the very
# code that broke here. This one fails the same commit anywhere it runs.
# Comment lines are blanked first, keeping the line count so numbers stay true.
# Without that this rule failed the fixed file: the comment on the fix names the
# expansion it replaced, and a gate that trips on its own explanation is one the
# next person deletes rather than reads.
if sed 's/^[[:space:]]*#.*//' "$MENU" \
  | grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(\^\^|,,)\}'; then
  echo "FAIL: ^^ / ,, is bash 4; /bin/bash on macOS is 3.2 and zsh lacks it" >&2
  exit 1
fi
echo "  ok: no ^^ or ,, in the menu code"

echo "[12/13] submenu panels render under the shells this machine actually has"
# The grouped menu shipped with `${title^^}` in the submenu panel. That is a
# bash 4 expansion, and this is macOS: /bin/bash is 3.2, and the menu is sourced
# into whatever shell mqlaunch is running under. CI runs bash 5, where it works,
# so a green pipeline said nothing about the machine the menu is written for —
# the first person to open Memory got `bad substitution` and a half-drawn panel.
#
# Steps 1-10 drove the front loop only, so nothing ever entered a submenu. This
# renders all three under every shell present, and requires the heading to come
# out: a panel that fails to render prints no heading either, so the check
# cannot pass by rendering nothing.
for hal_shell in /bin/bash /bin/zsh; do
  [[ -x "$hal_shell" ]] || continue
  while read -r hal_fn hal_heading; do
    hal_out="$("$hal_shell" -c "
      MQ_NO_TUI=1
      export MQ_HAL_BIN='$tmp_hal/mq-hal'
      . '$MENU' >/dev/null 2>&1
      printf 'b\n' | $hal_fn
    " 2>&1 || true)"
    if printf '%s' "$hal_out" | grep -qiE 'bad substitution|parse error|not found'; then
      echo "FAIL: $hal_fn breaks under $hal_shell:" >&2
      printf '%s\n' "$hal_out" | grep -iE 'bad substitution|parse error|not found' | head -2 >&2
      exit 1
    fi
    if ! printf '%s' "$hal_out" | grep -q "$hal_heading"; then
      echo "FAIL: $hal_fn drew no $hal_heading heading under $hal_shell" >&2
      exit 1
    fi
  done <<'SUBMENUS'
hal_menu_memory_loop MEMORY
hal_menu_diagnostics_loop DIAGNOSTICS
hal_menu_routing_loop ROUTING
hal_menu_prompt_loop PROMPT
SUBMENUS
done
echo "  ok: every submenu renders under /bin/bash and /bin/zsh"

echo "[13/13] slow, silent HAL reads show a spinner and keep the report off its row"
# doctor-summary and fix-doctor print nothing for 8-9 s and then the whole
# report at once. The rows wait behind a spinner, and the report is printed
# after the spinner has cleared its line: printed while the spinner held the
# row, its first line landed after the spinner's label.
for hal_arm in '6)  _hal_run_wait "Reading doctor" "$MQ_HAL_BIN" doctor-summary' \
               '7)  _hal_run_wait "Planning fixes" "$MQ_HAL_BIN" fix-doctor'; do
  grep -qF "$hal_arm" "$MENU" || { echo "FAIL: menu arm missing: $hal_arm" >&2; exit 1; }
done
cat > "$tmp_hal/mq-hal" <<'FAKE_HAL'
#!/usr/bin/env bash
sleep 0.4
printf 'HAL Fix Planner\nstep one\n'
exit 3
FAKE_HAL
chmod +x "$tmp_hal/mq-hal"
PYTHONPATH="$ROOT/tests/lib" python3 - "$ROOT" "$tmp_hal/mq-hal" <<'PY'
import os, sys
from pty_capture import run_pty
root, hal = sys.argv[1:]
for var in ("MQ_NO_TUI", "MQ_NO_SPINNER", "NO_COLOR"):
    os.environ.pop(var, None)
script = (f"export BASE_DIR='{root}'; source '{root}/ui/terminal-ui/mq-ui.sh'; "
          f"source '{root}/terminal/menus/mq-hal-menu.sh'; "
          f"_hal_run_wait 'Planning fixes' '{hal}' fix-doctor; echo rc=$?")
status, seen = run_pty(script)
text = seen.decode("utf-8", errors="replace")
assert "Planning fixes" in text, "no spinner label was drawn"
report = text.index("HAL Fix Planner")
line_start = max(text.rfind("\n", 0, report), text.rfind("\r", 0, report))
before = text[line_start + 1:report]
assert "Planning" not in before, f"report shares the spinner's row: {before!r}"
assert "step one" in text, "report body was lost"
assert "rc=3" in text, "the delegate's exit status was not returned"
PY
echo "  ok: spinner while waiting, report on its own line, exit status kept"

echo "OK: HAL menu smoke test passed"
