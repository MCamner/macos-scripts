#!/usr/bin/env bash
set -euo pipefail

# The command registry is the canonical inventory of top-level mqlaunch commands.
# These checks keep it canonical: the registry must validate, it must stay in
# parity with the dispatcher, and the validator itself must actually fail when
# drift appears — a gate that cannot fail is not a gate.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"
VALIDATOR="$ROOT/tools/scripts/validate-command-registry.py"

echo "SMOKE: command registry"

echo "[1/23] registry and validator exist"
test -f "$REGISTRY"
test -f "$VALIDATOR"

echo "[2/23] registry is valid and agrees with dispatch"
python3 "$VALIDATOR" >/dev/null

echo "[3/23] the registry lives on the authority-owned path"
# docs/RUNTIME_AUTHORITY.md forbids the registry living in a legacy runtime path.
case "$REGISTRY" in
  */mqlaunch/lib/*) ;;
  *) echo "registry is not on an authority-owned path: $REGISTRY" >&2; exit 1 ;;
esac
grep -q 'terminal/mqlaunch-v1' "$REGISTRY" && {
  echo "registry references a legacy runtime path" >&2; exit 1
}

echo "[4/23] the validator rejects a duplicate command name"
# Proves the gate fires. A registry whose validator passes anything is useless.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
python3 - "$REGISTRY" "$tmp_dir/dup.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
first = doc["commands"][0]
clash = dict(first)
clash["name"] = "totally-unique-name-for-this-test"
clash["aliases"] = [first["name"]]          # collides with the first entry
doc["commands"].append(clash)
json.dump(doc, open(sys.argv[2], "w"))
PY
if python3 "$VALIDATOR" "$tmp_dir/dup.json" >/dev/null 2>&1; then
  echo "validator accepted a duplicate command name" >&2
  exit 1
fi

# Every fixture below edits the `system` entry. It is the widest closed
# namespace in the dispatcher, so a gate that catches drift there catches it
# anywhere.
mutate() {
  # mutate <output> <python body operating on `entry` and `doc`>
  local out="$1" body="$2"
  python3 - "$REGISTRY" "$out" "$body" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"] if c["name"] == "system"), None)
if entry is None:
    sys.exit("registry has no 'system' command to mutate")
if "subcommands" not in entry:
    sys.exit("'system' declares no subcommands — the registry has not been extended")
exec(sys.argv[3], {"doc": doc, "entry": entry})
json.dump(doc, open(sys.argv[2], "w"))
PY
}

expect_reject() {
  # expect_reject <fixture> <what> <expected stderr substring>
  local fixture="$1" what="$2" reason="$3" out
  if out="$(python3 "$VALIDATOR" "$fixture" 2>&1)"; then
    echo "validator accepted $what" >&2
    exit 1
  fi
  # Exit status alone is not proof: a validator that crashed would also be
  # non-zero while catching nothing.
  case "$out" in
    *"$reason"*) ;;
    *)
      echo "validator rejected $what for the wrong reason:" >&2
      echo "$out" >&2
      exit 1
      ;;
  esac
}

echo "[5/23] the validator rejects a subcommand the dispatcher does not handle"
mutate "$tmp_dir/extra-sub.json" \
  'entry["subcommands"].append({"name": "not-a-real-subcommand", "aliases": [], "summary": "x"})'
expect_reject "$tmp_dir/extra-sub.json" "a subcommand dispatch does not handle" \
  "registry lists subcommand 'not-a-real-subcommand'"

echo "[6/23] the validator rejects a dispatch subcommand missing from the registry"
mutate "$tmp_dir/missing-sub.json" 'entry["subcommands"].pop()'
expect_reject "$tmp_dir/missing-sub.json" "a registry missing a dispatched subcommand" \
  "but the registry does not list it"

echo "[7/23] the validator rejects a missing alias of a dispatched subcommand"
# Aliases are part of the surface: `mqlaunch system performance` is as real as
# `mqlaunch system perf`, and a consumer that only sees one of them is wrong.
mutate "$tmp_dir/missing-alias.json" '''
for sub in entry["subcommands"]:
    if sub["aliases"]:
        sub["aliases"] = sub["aliases"][1:]
        break
else:
    raise SystemExit("no aliased subcommand to strip")
'''
expect_reject "$tmp_dir/missing-alias.json" "a subcommand with a dropped alias" \
  "but the registry does not list it"

echo "[8/23] the validator rejects dropping subcommands from a namespace that has them"
# Drift by omission is the easy failure: a namespace grows a nested case and
# nobody declares it. Silence must fail too.
mutate "$tmp_dir/no-subs.json" 'entry.pop("subcommands"); entry.pop("unknown_subcommand", None)'
expect_reject "$tmp_dir/no-subs.json" "a namespace that dropped its subcommands" \
  "but the registry declares none"

echo "[9/23] the validator rejects an unknown_subcommand claim that contradicts dispatch"
# `system` rejects unknown words with exit 2, so its list is the whole
# surface. Claiming it forwards would tell a consumer the list is partial.
mutate "$tmp_dir/wrong-surface.json" 'entry["unknown_subcommand"] = "forward"'
expect_reject "$tmp_dir/wrong-surface.json" "an unknown_subcommand claim contradicting dispatch" \
  "unknown_subcommand is 'forward' but dispatch is 'reject'"

# `system doctor` carries the optional per-subcommand output declaration:
# `system` is human-only, but `mqlaunch system doctor --json` emits a real
# machine document. The two checks below cover what a static gate can prove
# about that field; tests/output-mode-parity-smoke.sh runs the command.
sub_mutate() {
  # sub_mutate <output> <python body operating on `sub`>
  mutate "$1" '''
sub = next((s for s in entry["subcommands"] if s["name"] == "doctor"), None)
if sub is None:
    raise SystemExit("system declares no doctor subcommand to mutate")
if "json" not in sub:
    raise SystemExit("system doctor carries no output declaration to mutate")
'''"$2"
}

echo "[10/23] the validator rejects a subcommand claiming JSON it does not list"
sub_mutate "$tmp_dir/sub-json-modes.json" 'sub["output_modes"] = ["human"]'
expect_reject "$tmp_dir/sub-json-modes.json" "a subcommand whose json flag and output_modes disagree" \
  "system doctor: json is true but 'json' is not in output_modes"

echo "[11/23] the validator rejects a half-stated subcommand output declaration"
# One field without the other leaves a consumer guessing which half to trust.
sub_mutate "$tmp_dir/sub-half.json" 'sub.pop("output_modes")'
expect_reject "$tmp_dir/sub-half.json" "a subcommand declaring json without output_modes" \
  "system doctor: declares 'json' without 'output_modes'"

# --- deprecated aliases ----------------------------------------------------
#
# An alias can outlive the reason it was added. Deleting it breaks whoever still
# types it; leaving it in `aliases` tells every consumer it is a current name.
# `deprecated_aliases` is the third state: still dispatched, no longer part of
# the surface a consumer should advertise.
#
# The field is metadata on the alias, not a flag on the command. A command whose
# old spelling is retired is not itself deprecated, and the two must not be the
# same statement.
#
# Nothing in the registry declares one yet, so these fixtures are the only
# exercise the rules get. Each starts from a *valid* deprecation — `performance`
# moved out of the `perf` entry's aliases — so a rejection can only come from the
# specific defect introduced, not from the shape being unfamiliar.
dep_mutate() {
  # dep_mutate <output> <python body operating on `dep`, `entry` and `doc`>
  local out="$1" body="$2"
  python3 - "$REGISTRY" "$out" "$body" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"] if c["name"] == "perf"), None)
if entry is None:
    sys.exit("registry has no 'perf' command to mutate")
if "performance" not in entry.get("aliases", []):
    sys.exit("'perf' no longer aliases 'performance' — pick another fixture base")

# Retire the alias rather than inventing a word: dispatch still handles
# `performance`, so parity with the dispatcher stays intact and the fixture can
# only fail for the reason it is testing.
entry["aliases"] = [a for a in entry["aliases"] if a != "performance"]
dep = {"name": "performance", "replacement": "perf"}
entry["deprecated_aliases"] = [dep]

exec(sys.argv[3], {"doc": doc, "entry": entry, "dep": dep})
json.dump(doc, open(sys.argv[2], "w"))
PY
}

echo "[12/23] a well-formed deprecation validates"
# The rules must leave a correct registry alone. Without this, every check below
# would still pass if the validator rejected the field outright.
dep_mutate "$tmp_dir/dep-ok.json" 'pass'
if ! out="$(python3 "$VALIDATOR" "$tmp_dir/dep-ok.json" 2>&1)"; then
  echo "validator rejected a well-formed deprecated alias:" >&2
  echo "$out" >&2
  exit 1
fi

echo "[13/23] the validator rejects a deprecated alias without a replacement"
# A deprecation that does not say what to use instead is a dead end for the
# person who typed the old word.
dep_mutate "$tmp_dir/dep-no-replacement.json" 'dep.pop("replacement")'
expect_reject "$tmp_dir/dep-no-replacement.json" "a deprecated alias with no replacement" \
  "deprecated alias 'performance': missing required field 'replacement'"

echo "[14/23] the validator rejects a replacement that resolves to nothing"
# Naming a replacement is not enough — it has to be a word that dispatches.
dep_mutate "$tmp_dir/dep-ghost-replacement.json" 'dep["replacement"] = "not-a-command"'
expect_reject "$tmp_dir/dep-ghost-replacement.json" "a replacement nothing dispatches" \
  "replacement 'not-a-command' is not an active command name or alias"

echo "[15/23] the validator rejects a word that is active and deprecated at once"
# The contradiction the field exists to prevent: help would advertise it while
# the registry says it is being retired.
dep_mutate "$tmp_dir/dep-both.json" 'entry["aliases"] = entry["aliases"] + ["performance"]'
expect_reject "$tmp_dir/dep-both.json" "a word listed as both an alias and deprecated" \
  "'performance' is listed as both an active alias and a deprecated one"

echo "[16/23] the validator rejects a deprecated alias claimed by another command"
# Same rule as active names: one word, one command. A collision here would make
# the replacement advice depend on which entry a consumer read first.
dep_mutate "$tmp_dir/dep-collision.json" '''
other = next(c for c in doc["commands"] if c["name"] == "net")
other["deprecated_aliases"] = [{"name": "performance", "replacement": "net"}]
'''
expect_reject "$tmp_dir/dep-collision.json" "a deprecated alias claimed by two commands" \
  "duplicate command name 'performance'"

echo "[17/23] the validator rejects a command that delegates outside its owner"
# docs/RUNTIME_AUTHORITY.md forbids routing to mq-mcp when mq-agent owns the
# workflow. An entry can state that violation plainly, so a gate can see it.
python3 - "$REGISTRY" "$tmp_dir/wrong-owner.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"]
              if c["owner"] != "macos-scripts" and c.get("delegates_to")), None)
if entry is None:
    sys.exit("no delegating command to mutate")
entry["delegates_to"] = "mq-mcp " + entry["delegates_to"].split(" ", 1)[-1]
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/wrong-owner.json" "a command delegating outside its owner" \
  "delegates_to names 'mq-mcp'"

echo "[18/23] the validator rejects read-only on a command whose script runs sudo"
# `ghost` shipped as read-only while tools/scripts/network-ghost.sh spoofed the
# machine's MAC address with `sudo ifconfig ... ether ...`. read-only is the value
# that invites running something unattended, so this was a false label with a
# security consequence rather than a cosmetic one.
#
# The fixture puts the old value back rather than inventing a case, so the gate is
# proved against the mistake it was written for.
python3 - "$REGISTRY" "$tmp_dir/sudo-read-only.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next(c for c in doc["commands"] if c["name"] == "ghost")
entry["safety"] = "read-only"
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/sudo-read-only.json" "read-only on a command that escalates" \
  "runs sudo"

# And the other direction, which is the part that makes the check usable: a
# printed suggestion is not an escalation. tools/scripts/scan.sh contains
# `echo "- Restart audio if glitching: sudo killall coreaudiod"`, and `scan` is
# correctly read-only. A substring search would have relabelled it.
scan_safety="$(python3 -c '
import json, sys
doc = json.load(open(sys.argv[1]))
print(next(c["safety"] for c in doc["commands"] if c["name"] == "scan"))
' "$REGISTRY")"
[[ "$scan_safety" == "read-only" ]] || {
  echo "FAIL: scan is $scan_safety; the fixture below no longer proves anything" >&2
  exit 1
}
grep -q 'glitching: sudo killall' "$ROOT/tools/scripts/scan.sh" || {
  echo "FAIL: scan.sh no longer mentions sudo, so the false-positive guard is moot" >&2
  exit 1
}
echo "  ok: escalation rejected, a printed sudo suggestion is not"

echo "[19/23] the validator rejects a namespace that mixes owners"
# `mqlaunch help` prints the owner on the group heading, not on each row, which
# is only honest while a namespace has one owner. Every namespace does today.
# Without this gate the first command filed under someone else's namespace would
# fail nothing: help would keep the old heading, and the label would quietly
# describe some of the rows under it instead of all of them.
python3 - "$REGISTRY" "$tmp_dir/mixed-owner.json" <<'PY'
import json, sys

doc = json.load(open(sys.argv[1]))
agent = [c for c in doc["commands"] if c["namespace"] == "agent"]
if not agent:
    sys.exit("no command in the 'agent' namespace — pick another fixture base")
if agent[0]["owner"] != "mq-agent":
    sys.exit("the 'agent' namespace no longer belongs to mq-agent")
agent[0]["owner"] = "repo-signal"       # one row, someone else's repo
json.dump(doc, open(sys.argv[2], "w"))
PY
expect_reject "$tmp_dir/mixed-owner.json" \
  "a namespace whose commands belong to two repos" \
  "mixes owners"

# And the label itself: the generated help must carry the owner for a delegated
# group and stay silent for a local one, or the heading proves nothing.
grep -q '^AGENT  (owner: mq-agent)$' "$ROOT/terminal/menus/mq-help-menu.sh" || {
  echo "FAIL: the AGENT heading does not name its owner" >&2
  exit 1
}
grep -qE '^(CORE|MENUS|OPS)  \(owner:' "$ROOT/terminal/menus/mq-help-menu.sh" && {
  echo "FAIL: a macos-scripts group carries an owner label; the home repo is" \
       "the unlabelled default" >&2
  exit 1
}
echo "  ok: delegated groups name their repo, local groups stay unlabelled"

echo "[20/23] the validator rejects a local command with no local_role"
# The gate the other three fixtures below defend. A command owned by this repo
# and classified as nothing is how `srm` reached 156 lines of direct AI memory
# querying while its entry looked ordinary.
python3 - "$REGISTRY" "$tmp_dir/no-role.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"]
              if c["owner"] == "macos-scripts" and "local_role" in c), None)
if entry is None:
    sys.exit("no classified local command to mutate")
del entry["local_role"]
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/no-role.json" "a local command with no local_role" \
  "no local_role is declared"

echo "[21/23] the validator rejects a local_role outside the allowed three"
# A fourth category is how the boundary would be widened without saying so:
# "orchestration" as a local role reads like a classification and is a breach.
python3 - "$REGISTRY" "$tmp_dir/bad-role.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"]
              if c["owner"] == "macos-scripts" and "local_role" in c), None)
if entry is None:
    sys.exit("no classified local command to mutate")
entry["local_role"] = "orchestration"
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/bad-role.json" "an invented local_role" \
  "is not one of"

echo "[22/23] the validator rejects local_role on a command another repo owns"
# `local_role` describes what this repo owns. On a delegated command it is a
# claim about someone else's tree.
python3 - "$REGISTRY" "$tmp_dir/foreign-role.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"] if c["owner"] != "macos-scripts"), None)
if entry is None:
    sys.exit("no delegated command to mutate")
entry["local_role"] = "thin-entrypoint"
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/foreign-role.json" "local_role on a delegated command" \
  "local_role is only for owner 'macos-scripts'"

echo "[23/23] the exemption is exactly one command and cannot be classified too"
# Two halves of the same rule. The list must hold exactly `srm` — a second name
# is a second breach, and the fix is the runtime, not the list — and an exempt
# command must not also carry a role, or removing it from the list later would
# silently change nothing.
exempt="$(python3 -c '
import re, sys
src = open("tools/scripts/validate-command-registry.py").read()
m = re.search(r"^LOCAL_ROLE_EXEMPT = \{([^}]*)\}", src, re.M)
print(m.group(1).strip() if m else "MISSING")
')"
if [[ "$exempt" != '"srm"' ]]; then
  echo "FAIL: LOCAL_ROLE_EXEMPT is $exempt; it must hold exactly \"srm\"." >&2
  echo "      A new exemption is a new owner breach — fix the runtime instead." >&2
  exit 1
fi
echo "  ok: the exemption list holds exactly srm"

python3 - "$REGISTRY" "$tmp_dir/exempt-classified.json" <<'FIXTURE'
import json, sys
doc = json.load(open(sys.argv[1]))
entry = next((c for c in doc["commands"] if c["name"] == "srm"), None)
if entry is None:
    sys.exit("registry has no 'srm' command")
entry["local_role"] = "thin-entrypoint"
json.dump(doc, open(sys.argv[2], "w"))
FIXTURE
expect_reject "$tmp_dir/exempt-classified.json" "an exempt command that also classifies" \
  "must not also declare local_role"

bash -n "$0"

echo "OK: command registry is canonical and its gate fires"
