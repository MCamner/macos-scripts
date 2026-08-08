#!/usr/bin/env bash
set -euo pipefail

# Option 13 used to look for scripts/regenerate-memory-views.py, a file mqobsidian
# never shipped, so the option was a permanent placeholder. The renderers that do
# exist live next to the data they render: memory/commands/build_views.py and
# memory/workflows/build_workflow_views.py. This locks the option to those, and
# keeps the placeholder for a vault that has neither.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

export BASE_DIR="$ROOT"
export MQ_OBSIDIAN_DIR="$TMP_ROOT/mqobsidian"

# shellcheck source=../terminal/menus/mq-main-menu.sh
source "$ROOT/terminal/menus/mq-main-menu.sh"
# shellcheck source=../terminal/menus/mq-obsidian-menu.sh
source "$ROOT/terminal/menus/mq-obsidian-menu.sh"

echo "SMOKE: mqobsidian regenerate memory views"

# A stub python that records what it was asked to run, so the test asserts
# routing without depending on mqobsidian's real renderers.
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/python3" <<'STUB'
#!/usr/bin/env bash
printf 'RAN %s\n' "$1"
STUB
chmod +x "$TMP_ROOT/bin/python3"
export PATH="$TMP_ROOT/bin:$PATH"

echo "[1/6] both renderers present: both run"
mkdir -p "$MQ_OBSIDIAN_DIR/memory/commands" "$MQ_OBSIDIAN_DIR/memory/workflows"
touch "$MQ_OBSIDIAN_DIR/memory/commands/build_views.py"
touch "$MQ_OBSIDIAN_DIR/memory/workflows/build_workflow_views.py"
output="$(mq_obsidian_regenerate_views)"
grep -q "RAN memory/commands/build_views.py" <<<"$output"
grep -q "RAN memory/workflows/build_workflow_views.py" <<<"$output"

echo "[2/6] only the command renderer present: the other is not invented"
rm "$MQ_OBSIDIAN_DIR/memory/workflows/build_workflow_views.py"
output="$(mq_obsidian_regenerate_views)"
grep -q "RAN memory/commands/build_views.py" <<<"$output"
! grep -q "build_workflow_views" <<<"$output"

echo "[3/6] neither present: placeholder, and it names the real producers"
rm "$MQ_OBSIDIAN_DIR/memory/commands/build_views.py"
output="$(mq_obsidian_regenerate_views)"
grep -q "mqlaunch · Option 13 · Regenerate memory views" <<<"$output"
grep -q "  not implemented yet" <<<"$output"
grep -q "memory/commands/build_views.py" <<<"$output"
grep -q "memory/workflows/build_workflow_views.py" <<<"$output"

echo "[4/6] a failing renderer surfaces as a nonzero status"
cat >"$TMP_ROOT/bin/python3" <<'STUB'
#!/usr/bin/env bash
printf 'boom\n' >&2
exit 3
STUB
chmod +x "$TMP_ROOT/bin/python3"
touch "$MQ_OBSIDIAN_DIR/memory/commands/build_views.py"
set +e
mq_obsidian_regenerate_views >/dev/null 2>&1
status=$?
set -e
test "$status" -ne 0

echo "[5/6] option 13 keeps its command label"
test "$(surface_choice_summary mqobsidian 13)" = "option 13: regenerate memory views"

echo "[6/6] it runs under zsh, which is the shell the menus actually use"
# Caught a real one: a local named `status` is fine in bash and fatal in zsh,
# where $status is read-only. Testing only under bash hid it.
cat >"$TMP_ROOT/bin/python3" <<'STUB'
#!/usr/bin/env bash
printf 'RAN %s\n' "$1"
STUB
chmod +x "$TMP_ROOT/bin/python3"
output="$(zsh -c "
  export BASE_DIR='$ROOT' MQ_OBSIDIAN_DIR='$MQ_OBSIDIAN_DIR' PATH='$PATH'
  source '$ROOT/terminal/menus/mq-main-menu.sh'
  source '$ROOT/terminal/menus/mq-obsidian-menu.sh'
  mq_obsidian_regenerate_views
" 2>&1)"
grep -q "RAN memory/commands/build_views.py" <<<"$output"
! grep -qi "read-only variable" <<<"$output"

echo "OK: mqobsidian regenerate memory views smoke passed"
