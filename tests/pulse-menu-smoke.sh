#!/usr/bin/env bash
# Holds the Pulse menu and the scoped views it routes to.
#
# The menu's whole job is choosing a view. It must therefore hold no status
# logic of its own — a reading here would be a second definition of "healthy"
# one level above the collectors the contract gates, which is the failure
# docs/PULSE_CONTRACT.md exists to prevent. Step 5 asserts that structurally,
# the same way tests/pulse-attention-smoke.sh does for the attention engine.
#
# The scoped views are driven for real against stubbed delegates: a scope that
# silently ran every collector would still look right on screen, and would cost
# an operator the whole run when they asked for one area.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-pulse-menu.sh"

echo "SMOKE: pulse menu and scoped views"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/6] the menu exists and offers every area"
test -f "$MENU"
for row in "1. Full Pulse" "2. Attention" "3. System" "4. Repositories" \
           "5. MQ Stack" "6. Memory" "7. Git / GitHub" "8. Quality" \
           "9. Refresh" "b. Back"; do
  grep -qF -- "$row" "$MENU" || {
    echo "FAIL: the menu is missing the row: $row" >&2
    exit 1
  }
done
echo "  ok: eight views, refresh and back"

echo "[2/6] every row goes through the dispatcher"
# Not `tools/scripts/pulse.sh`. A menu row and a typed command have to be the
# same thing — docs/RUNTIME_AUTHORITY.md — and a menu that shelled out directly
# would be a second way in that the registry does not govern.
# Comments are dropped first. The file explains why it does not call the script,
# and prose about not doing something reads exactly like doing it to a grep —
# the same trap docs/AUTHORITY_MAP.md's own gate had to account for.
if grep -nE 'tools/scripts/pulse\.sh' "$MENU" | grep -qv '^[0-9]*:#'; then
  echo "FAIL: the menu reaches the entrypoint script directly" >&2
  grep -nE 'tools/scripts/pulse\.sh' "$MENU" | grep -v '^[0-9]*:#' >&2
  exit 1
fi
grep -qF '"$BASE_DIR/bin/mqlaunch" pulse' "$MENU" || {
  echo "FAIL: the menu does not route through bin/mqlaunch" >&2
  exit 1
}
echo "  ok: bin/mqlaunch pulse, never the script"

echo "[3/6] the scoped views collect their own area and no other"
# Stub delegates that record being run, so "did this scope run the whole thing"
# is measured rather than assumed.
stub="$run_dir/stub"
mkdir -p "$stub/tools/scripts" "$stub/scripts" "$stub/tests" "$stub/mqlaunch/lib"
ln -sfn "$ROOT/mqlaunch/lib/pulse" "$stub/mqlaunch/lib/pulse"
cp "$ROOT/tools/scripts/pulse.sh" "$stub/tools/scripts/pulse.sh"
chmod +x "$stub/tools/scripts/pulse.sh"

cat > "$stub/tools/scripts/doctor.sh" <<EOF
#!/usr/bin/env bash
echo ran-doctor >> "$run_dir/ran.txt"
echo '{"checks":[{"name":"git","status":"ok"}]}'
EOF
cat > "$stub/tools/scripts/mq-repos.py" <<EOF
#!/usr/bin/env python3
import json, pathlib
pathlib.Path("$run_dir/ran.txt").open("a").write("ran-repos\n")
print(json.dumps({"repos": [{"name": "mq-agent", "git": True, "clean": True,
  "modified": 0, "untracked": 0, "branch": "main", "upstream": "origin/main",
  "ahead": 0, "behind": 0}], "summary": {"total": 1, "dirty": 0}}))
EOF
chmod +x "$stub/tools/scripts/doctor.sh"
printf 'raise SystemExit(0)\n' > "$stub/tools/scripts/validate-command-registry.py"
for gate in "scripts/check-runtime-authority.sh" "scripts/check-skills.sh" \
            "tests/registry-consumer-parity-smoke.sh" "tests/test-inventory-smoke.sh"; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/$gate"
  chmod +x "$stub/$gate"
done
git -C "$stub" init -q
git -C "$stub" config user.email t@example.com
git -C "$stub" config user.name Test
git -C "$stub" add -A >/dev/null 2>&1
git -C "$stub" commit -qm stub

: > "$run_dir/ran.txt"
out="$(MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" \
  bash "$stub/tools/scripts/pulse.sh" system --no-network </dev/null 2>&1 || true)"
grep -qF 'SYSTEM' <<< "$out" || { echo "FAIL: pulse system printed no SYSTEM" >&2; exit 1; }
for absent in REPOSITORIES 'MQ STACK' MEMORY 'GIT / GITHUB' QUALITY; do
  if grep -qF "$absent" <<< "$out"; then
    echo "FAIL: pulse system also printed $absent" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
done
if grep -q 'ran-repos' "$run_dir/ran.txt"; then
  echo "FAIL: pulse system ran the repositories collector" >&2
  exit 1
fi
echo "  ok: one area rendered, the other collectors never ran"

echo "[4/6] attention keeps the whole run, and says so when there is nothing"
# The exception: attention is a view over every area, so it collects everything
# and narrows only what is printed. Scoping the collection would make the most
# important screen the least informed.
: > "$run_dir/ran.txt"
out="$(MACOS_SCRIPTS_HOME="$stub" MQ_AGENT_BIN="$run_dir/absent" \
  bash "$stub/tools/scripts/pulse.sh" attention --no-network </dev/null 2>&1 || true)"
grep -q 'ran-doctor' "$run_dir/ran.txt" || {
  echo "FAIL: pulse attention skipped the system collector" >&2; exit 1; }
grep -q 'ran-repos' "$run_dir/ran.txt" || {
  echo "FAIL: pulse attention skipped the repositories collector" >&2; exit 1; }
if grep -qF 'SYSTEM' <<< "$out"; then
  echo "FAIL: pulse attention printed the area sections" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi

# On this stub tree nothing is wrong except the unreachable mq-agent, so the
# list is not empty — assert the empty case directly instead, with a run where
# every finding is skipped.
empty="$(MACOS_SCRIPTS_HOME="$stub" bash -c '
  source "'"$ROOT"'/mqlaunch/lib/pulse/render.sh"
  pulse_items_reset
  pulse_item_add doctor system PASS "Environment" "all good"
  pulse_render_attention_only PASS
' </dev/null 2>&1)"
grep -qF 'Nothing needs attention.' <<< "$empty" || {
  echo "FAIL: an empty attention view printed nothing at all" >&2
  printf '%s\n' "$empty" >&2
  exit 1
}
echo "  ok: collects everything, renders only findings, never a blank screen"

echo "[5/6] the menu holds no status logic"
# Structural, for the same reason as the attention engine's equivalent step: the
# defects this series found were all a reading that went wrong quietly, and a
# menu is the easiest place to add one back.
# The scope arguments are removed before matching rather than the whole line
# being skipped. `run_pulse_view git` names a scope; `if git -C ... status` is a
# reading. Anchoring on command position instead would miss the second one the
# moment it appears after `if`, `then` or `&&` — which is how the first version
# of this step passed a planted probe.
offenders="$(sed -E 's/run_pulse_view[[:space:]]+"?[a-z_]*"?//g' "$MENU" \
  | grep -nE '(^|[^[:alnum:]_-])(git|gh|uv|curl|doctor|jq)([[:space:]]|$)' \
  | grep -v '^[0-9]*:#' \
  | grep -v 'mqlaunch pulse' || true)"
if [[ -n "$offenders" ]]; then
  echo "FAIL: the pulse menu reads something itself:" >&2
  printf '%s\n' "$offenders" >&2
  exit 1
fi
if grep -qE 'PASS|WARN|FAIL|UNAVAILABLE' "$MENU"; then
  echo "FAIL: the pulse menu names Pulse states, so it is deciding something" >&2
  grep -nE 'PASS|WARN|FAIL|UNAVAILABLE' "$MENU" >&2
  exit 1
fi
echo "  ok: no probes, no states, only routes"

echo "[6/6] the registry and the dispatcher agree about the menu"
grep -qF '"name": "menu"' "$ROOT/mqlaunch/lib/command-registry.json"
python3 - "$ROOT/mqlaunch/lib/command-registry.json" <<'PY'
import json, sys

registry = json.load(open(sys.argv[1]))
pulse = next((c for c in registry["commands"] if c["name"] == "pulse"), None)
if pulse is None:
    raise SystemExit("FAIL: pulse is not in the registry")
subs = [s["name"] for s in pulse.get("subcommands", [])]
if subs != ["menu"]:
    raise SystemExit(f"FAIL: pulse declares subcommands {subs}, expected ['menu']")
if pulse.get("unknown_subcommand") != "forward":
    raise SystemExit("FAIL: pulse must forward unknown words — the scopes are not subcommands")
print("  ok: menu declared, scopes forwarded")
PY

echo "PASS: pulse menu and scoped views"
