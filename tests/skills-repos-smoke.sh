#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SKILLS="$ROOT/tools/scripts/mq-skills.py"
REPOS="$ROOT/tools/scripts/mq-repos.py"
CMD="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TOOLS_MENU="$ROOT/terminal/menus/mq-tools-menu.sh"
DOC="$ROOT/docs/COMMANDS.md"

echo "SMOKE: skills and repos command surface"

echo "[1/10] scripts exist and are executable"
test -x "$SKILLS"
test -x "$REPOS"

echo "[2/10] script syntax checks"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/mqlaunch-pycache" python3 -m py_compile "$SKILLS" "$REPOS"

echo "[3/10] command-mode syntax check"
bash -n "$CMD"

echo "[4/10] launcher syntax check"
zsh -n "$LAUNCHER"

echo "[5/10] tools menu syntax check"
bash -n "$TOOLS_MENU"

echo "[6/10] command-mode routes skills and repos"
grep -q "mq-skills.py" "$CMD"
grep -q "mq-repos.py" "$CMD"

echo "[7/10] main launcher routes skills and repos"
grep -q "skills|skill" "$LAUNCHER"
grep -q "mq-repos.py" "$LAUNCHER"

echo "[8/10] tools menu exposes ecosystem actions"
grep -q "Skills audit" "$TOOLS_MENU"
grep -q "Repos diff" "$TOOLS_MENU"

echo "[9/10] docs mention commands"
grep -q "mqlaunch skills audit" "$DOC"
grep -q "mqlaunch skills validate --ecosystem" "$DOC"
grep -q "mqlaunch repos status" "$DOC"
grep -q "mqlaunch repos diff-summary" "$DOC"

echo "[10/10] scripts run read-only summaries"
"$SKILLS" validate >/tmp/mq-skills-validate.out
"$SKILLS" validate --ecosystem >/tmp/mq-skills-validate-ecosystem.out
"$REPOS" list >/tmp/mq-repos-list.out
"$REPOS" status --repo mq-agent >/tmp/mq-repos-status.out
"$REPOS" status --repo mq-ums >/tmp/mq-repos-status-mq-ums.out
"$SKILLS" validate --repo mq-agent >/tmp/mq-skills-validate-one.out
"$SKILLS" validate --repo mq-ums >/tmp/mq-skills-validate-mq-ums.out
"$REPOS" diff-summary --repo mq-agent --modified >/tmp/mq-repos-modified.out
"$REPOS" diff-summary --repo mq-agent --untracked >/tmp/mq-repos-untracked.out
grep -q "mq-mcp" /tmp/mq-repos-list.out
grep -q "mq-ums" /tmp/mq-repos-list.out
grep -q "mq-agent:" /tmp/mq-repos-status.out
grep -q "mq-ums:" /tmp/mq-repos-status-mq-ums.out

echo "OK: skills and repos command surface smoke test passed"
