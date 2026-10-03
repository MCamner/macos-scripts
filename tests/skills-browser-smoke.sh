#!/usr/bin/env bash
# Skill browser: `mq-skills.py list/show` and Tools → Skills → Browse.
#
# The help text promised "List and inspect installed skills" while the only
# verbs were audit, validate and new — none of which shows what a skill says.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS="$ROOT/tools/scripts/mq-skills.py"
TOOLS_MENU="$ROOT/terminal/menus/mq-tools-menu.sh"

echo "SMOKE: skills browser"

# Marks a failing check.
fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expected="$(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | wc -l | tr -d ' ')"

echo "[1/6] list prints one row per skill"
rows="$("$SKILLS" list --repo "$ROOT" --format tsv | wc -l | tr -d ' ')"
[[ "$rows" == "$expected" ]] || fail "list printed $rows rows, expected $expected"

echo "[2/6] list resolves folded YAML descriptions"
# mqlaunch-menu-template uses `description: >`. Read line by line, that is a
# lone ">" — which is what the browser would have shown as the description.
line="$("$SKILLS" list --repo "$ROOT" --format tsv | grep '^mqlaunch-menu-template	')" \
  || fail "mqlaunch-menu-template missing from list"
desc="${line#*	}"
[[ "$desc" == Mall\ för* ]] || fail "folded description not resolved: '$desc'"

echo "[3/6] show prints the SKILL.md verbatim"
diff <("$SKILLS" show shell-script-auditor --repo "$ROOT") \
  "$ROOT/skills/shell-script-auditor/SKILL.md" >/dev/null \
  || fail "show output differs from SKILL.md"

echo "[4/6] show rejects an unknown skill"
if err="$("$SKILLS" show no-such-skill --repo "$ROOT" 2>&1 >/dev/null)"; then
  fail "show accepted an unknown skill"
fi
grep -q "no-such-skill" <<<"$err" || fail "error does not name the skill: $err"

echo "[5/6] Tools → Skills offers Browse"
grep -qE '^[[:space:]]*4\) tools_skills_browse_loop' "$TOOLS_MENU" \
  || fail "skills submenu has no Browse option"

echo "[6/6] browser renders once without a terminal and exits"
# Non-zero is fine here — menus end that way without a TTY (menu-eof-smoke).
# Redrawing is not: that is the infinite loop that test exists for.
out="$(MACOS_SCRIPTS_HOME="$ROOT" bash "$TOOLS_MENU" skills-browse </dev/null 2>&1 || true)"
grep -q "shell-script-auditor" <<<"$out" || fail "browser did not list skills"
draws="$(grep -c "shell-script-auditor" <<<"$out")"
[[ "$draws" == 1 ]] || fail "browser redrew $draws times without a terminal"

echo "PASS: skills browser"
