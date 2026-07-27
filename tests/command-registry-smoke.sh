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

echo "[1/16] registry and validator exist"
test -f "$REGISTRY"
test -f "$VALIDATOR"

echo "[2/16] registry is valid and agrees with dispatch"
python3 "$VALIDATOR" >/dev/null

echo "[3/16] the registry lives on the authority-owned path"
# docs/RUNTIME_AUTHORITY.md forbids the registry living in a legacy runtime path.
case "$REGISTRY" in
  */mqlaunch/lib/*) ;;
  *) echo "registry is not on an authority-owned path: $REGISTRY" >&2; exit 1 ;;
esac
grep -q 'terminal/mqlaunch-v1' "$REGISTRY" && {
  echo "registry references a legacy runtime path" >&2; exit 1
}

echo "[4/16] the validator rejects a duplicate command name"
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

echo "[5/16] the validator rejects a subcommand the dispatcher does not handle"
mutate "$tmp_dir/extra-sub.json" \
  'entry["subcommands"].append({"name": "not-a-real-subcommand", "aliases": [], "summary": "x"})'
expect_reject "$tmp_dir/extra-sub.json" "a subcommand dispatch does not handle" \
  "registry lists subcommand 'not-a-real-subcommand'"

echo "[6/16] the validator rejects a dispatch subcommand missing from the registry"
mutate "$tmp_dir/missing-sub.json" 'entry["subcommands"].pop()'
expect_reject "$tmp_dir/missing-sub.json" "a registry missing a dispatched subcommand" \
  "but the registry does not list it"

echo "[7/16] the validator rejects a missing alias of a dispatched subcommand"
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

echo "[8/16] the validator rejects dropping subcommands from a namespace that has them"
# Drift by omission is the easy failure: a namespace grows a nested case and
# nobody declares it. Silence must fail too.
mutate "$tmp_dir/no-subs.json" 'entry.pop("subcommands"); entry.pop("unknown_subcommand", None)'
expect_reject "$tmp_dir/no-subs.json" "a namespace that dropped its subcommands" \
  "but the registry declares none"

echo "[9/16] the validator rejects an unknown_subcommand claim that contradicts dispatch"
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

echo "[10/16] the validator rejects a subcommand claiming JSON it does not list"
sub_mutate "$tmp_dir/sub-json-modes.json" 'sub["output_modes"] = ["human"]'
expect_reject "$tmp_dir/sub-json-modes.json" "a subcommand whose json flag and output_modes disagree" \
  "system doctor: json is true but 'json' is not in output_modes"

echo "[11/16] the validator rejects a half-stated subcommand output declaration"
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

echo "[12/16] a well-formed deprecation validates"
# The rules must leave a correct registry alone. Without this, every check below
# would still pass if the validator rejected the field outright.
dep_mutate "$tmp_dir/dep-ok.json" 'pass'
if ! out="$(python3 "$VALIDATOR" "$tmp_dir/dep-ok.json" 2>&1)"; then
  echo "validator rejected a well-formed deprecated alias:" >&2
  echo "$out" >&2
  exit 1
fi

echo "[13/16] the validator rejects a deprecated alias without a replacement"
# A deprecation that does not say what to use instead is a dead end for the
# person who typed the old word.
dep_mutate "$tmp_dir/dep-no-replacement.json" 'dep.pop("replacement")'
expect_reject "$tmp_dir/dep-no-replacement.json" "a deprecated alias with no replacement" \
  "deprecated alias 'performance': missing required field 'replacement'"

echo "[14/16] the validator rejects a replacement that resolves to nothing"
# Naming a replacement is not enough — it has to be a word that dispatches.
dep_mutate "$tmp_dir/dep-ghost-replacement.json" 'dep["replacement"] = "not-a-command"'
expect_reject "$tmp_dir/dep-ghost-replacement.json" "a replacement nothing dispatches" \
  "replacement 'not-a-command' is not an active command name or alias"

echo "[15/16] the validator rejects a word that is active and deprecated at once"
# The contradiction the field exists to prevent: help would advertise it while
# the registry says it is being retired.
dep_mutate "$tmp_dir/dep-both.json" 'entry["aliases"] = entry["aliases"] + ["performance"]'
expect_reject "$tmp_dir/dep-both.json" "a word listed as both an alias and deprecated" \
  "'performance' is listed as both an active alias and a deprecated one"

echo "[16/16] the validator rejects a deprecated alias claimed by another command"
# Same rule as active names: one word, one command. A collision here would make
# the replacement advice depend on which entry a consumer read first.
dep_mutate "$tmp_dir/dep-collision.json" '''
other = next(c for c in doc["commands"] if c["name"] == "net")
other["deprecated_aliases"] = [{"name": "performance", "replacement": "net"}]
'''
expect_reject "$tmp_dir/dep-collision.json" "a deprecated alias claimed by two commands" \
  "duplicate command name 'performance'"

bash -n "$0"

echo "OK: command registry is canonical and its gate fires"
