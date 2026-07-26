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

echo "[1/9] registry and validator exist"
test -f "$REGISTRY"
test -f "$VALIDATOR"

echo "[2/9] registry is valid and agrees with dispatch"
python3 "$VALIDATOR" >/dev/null

echo "[3/9] the registry lives on the authority-owned path"
# docs/RUNTIME_AUTHORITY.md forbids the registry living in a legacy runtime path.
case "$REGISTRY" in
  */mqlaunch/lib/*) ;;
  *) echo "registry is not on an authority-owned path: $REGISTRY" >&2; exit 1 ;;
esac
grep -q 'terminal/mqlaunch-v1' "$REGISTRY" && {
  echo "registry references a legacy runtime path" >&2; exit 1
}

echo "[4/9] the validator rejects a duplicate command name"
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

echo "[5/9] the validator rejects a subcommand the dispatcher does not handle"
mutate "$tmp_dir/extra-sub.json" \
  'entry["subcommands"].append({"name": "not-a-real-subcommand", "aliases": [], "summary": "x"})'
expect_reject "$tmp_dir/extra-sub.json" "a subcommand dispatch does not handle" \
  "registry lists subcommand 'not-a-real-subcommand'"

echo "[6/9] the validator rejects a dispatch subcommand missing from the registry"
mutate "$tmp_dir/missing-sub.json" 'entry["subcommands"].pop()'
expect_reject "$tmp_dir/missing-sub.json" "a registry missing a dispatched subcommand" \
  "but the registry does not list it"

echo "[7/9] the validator rejects a missing alias of a dispatched subcommand"
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

echo "[8/9] the validator rejects dropping subcommands from a namespace that has them"
# Drift by omission is the easy failure: a namespace grows a nested case and
# nobody declares it. Silence must fail too.
mutate "$tmp_dir/no-subs.json" 'entry.pop("subcommands"); entry.pop("unknown_subcommand", None)'
expect_reject "$tmp_dir/no-subs.json" "a namespace that dropped its subcommands" \
  "but the registry declares none"

echo "[9/9] the validator rejects an unknown_subcommand claim that contradicts dispatch"
# `system` rejects unknown words with exit 2, so its list is the whole
# surface. Claiming it forwards would tell a consumer the list is partial.
mutate "$tmp_dir/wrong-surface.json" 'entry["unknown_subcommand"] = "forward"'
expect_reject "$tmp_dir/wrong-surface.json" "an unknown_subcommand claim contradicting dispatch" \
  "unknown_subcommand is 'forward' but dispatch is 'reject'"

bash -n "$0"

echo "OK: command registry is canonical and its gate fires"
