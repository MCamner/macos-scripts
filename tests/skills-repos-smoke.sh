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

echo "[1/12] scripts exist and are executable"
test -x "$SKILLS"
test -x "$REPOS"

echo "[2/12] script syntax checks"
PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/mqlaunch-pycache" python3 -m py_compile "$SKILLS" "$REPOS"

echo "[3/12] command-mode syntax check"
bash -n "$CMD"

echo "[4/12] launcher syntax check"
zsh -n "$LAUNCHER"

echo "[5/12] tools menu syntax check"
bash -n "$TOOLS_MENU"

echo "[6/12] command-mode routes skills and repos"
grep -q "mq-skills.py" "$CMD"
grep -q "mq-repos.py" "$CMD"

# Same as brain-bridge: the skills/repos case arms live in command mode (step 6),
# and mqlaunch.sh reaches them by sourcing that module.
echo "[7/12] main launcher reaches that routing (sources command mode)"
grep -q 'source "\$BASE_DIR/terminal/launchers/mqlaunch-command-mode.sh"' "$LAUNCHER"

echo "[8/12] tools menu exposes ecosystem actions"
# Asserted as reachable actions rather than as label text. The labels were
# "Skills audit" and "Repos diff" while those sat flat in the Tools menu; they
# are "Audit" and "Diff summary" inside the Skills and Repos submenus now, and
# the menu exposes them exactly as much as it did. A grep for the old wording
# would have failed on a regrouping that changed nothing about what is reachable.
for handler in run_mq_skills_audit run_mq_repos_diff_summary; do
  grep -qE "^[[:space:]]*[0-9]+\) $handler\b" "$TOOLS_MENU" || {
    echo "FAIL: no Tools menu option runs $handler" >&2
    exit 1
  }
done

echo "[9/12] docs mention commands"
grep -q "mqlaunch skills audit" "$DOC"
grep -q "mqlaunch skills validate --ecosystem" "$DOC"
grep -q "mqlaunch repos status" "$DOC"
grep -q "mqlaunch repos diff-summary" "$DOC"

echo "[10/12] scripts run read-only summaries"
"$SKILLS" validate >/tmp/mq-skills-validate.out
"$SKILLS" validate --ecosystem >/tmp/mq-skills-validate-ecosystem.out
"$REPOS" list >/tmp/mq-repos-list.out
"$REPOS" status --repo mq-agent >/tmp/mq-repos-status.out
"$REPOS" status --repo mq-ums >/tmp/mq-repos-status-mq-ums.out
"$SKILLS" validate --repo mq-agent >/tmp/mq-skills-validate-one.out
"$SKILLS" validate --repo mq-ums >/tmp/mq-skills-validate-mq-ums.out
"$REPOS" diff-summary --repo mq-agent --modified >/tmp/mq-repos-modified.out
"$REPOS" diff-summary --repo mq-agent --untracked >/tmp/mq-repos-untracked.out
# The commands above run clean whether or not the sibling MQ repos exist — that
# part is real coverage everywhere. What follows asserts those repos appear in
# the output, which needs them checked out next to this one. CI clones
# macos-scripts alone, so assert it only where there is something to find.
if [[ -d "$HOME/mq-mcp" && -d "$HOME/mq-ums" && -d "$HOME/mq-agent" ]]; then
  grep -q "mq-mcp" /tmp/mq-repos-list.out
  grep -q "mq-ums" /tmp/mq-repos-list.out
  grep -q "mq-agent:" /tmp/mq-repos-status.out
  grep -q "mq-ums:" /tmp/mq-repos-status-mq-ums.out
else
  echo "  skip: sibling MQ repos not checked out; listing assertions need them"
fi

echo "[11/12] audit reports whether each skill is discoverable by Claude Code"
# The blind spot this closes: mq-skills.py called all 63 skills in the stack
# "ok, indexed" while not one of them was loadable. It validated the MQ
# convention (skills/ plus a local index) and knew nothing about Claude Code's
# search path, which is .claude/skills/. An index nobody reads is not discovery.
# --repo takes a path, and it has to be this checkout: a bare name resolves
# under $HOME, which on a CI runner is not where the repo lives. Step 10 already
# skips its listing assertions for exactly that reason.
out="$("$SKILLS" audit --repo "$ROOT")"
grep -q "discoverable" <<<"$out"

echo "[12/12] an unlinked skill is reported, and a linked one is not"
# A scratch repo, so the assertion is about the checker rather than about
# whichever skills happen to be wired up in the real tree today.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/repo/skills/ghost-skill" "$work/repo/.claude/skills"
cat >"$work/repo/skills/ghost-skill/SKILL.md" <<'SKILL'
---
name: ghost-skill
description: Exists on disk, indexed, and reachable by nobody.
---
SKILL
printf 'skills/ghost-skill/SKILL.md\n' >"$work/repo/SKILLS.md"

out="$("$SKILLS" audit --repo "$work/repo" 2>&1)"
grep -q "not-discoverable" <<<"$out" || {
  echo "FAIL: an unlinked skill was not reported as undiscoverable" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

ln -s ../../skills/ghost-skill "$work/repo/.claude/skills/ghost-skill"
out="$("$SKILLS" audit --repo "$work/repo" 2>&1)"
grep -q "not-discoverable" <<<"$out" && {
  echo "FAIL: a linked skill is still reported as undiscoverable" >&2
  printf '%s\n' "$out" >&2
  exit 1
}

echo "OK: skills and repos command surface smoke test passed"
