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

echo "[1/5] registry and validator exist"
test -f "$REGISTRY"
test -f "$VALIDATOR"

echo "[2/5] registry is valid and agrees with dispatch"
python3 "$VALIDATOR" >/dev/null

echo "[3/5] the registry lives on the authority-owned path"
# docs/RUNTIME_AUTHORITY.md forbids the registry living in a legacy runtime path.
case "$REGISTRY" in
  */mqlaunch/lib/*) ;;
  *) echo "registry is not on an authority-owned path: $REGISTRY" >&2; exit 1 ;;
esac
grep -q 'terminal/mqlaunch-v1' "$REGISTRY" && {
  echo "registry references a legacy runtime path" >&2; exit 1
}

echo "[4/5] the validator rejects a duplicate command name"
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

echo "[5/5] shell syntax"
bash -n "$0"

echo "OK: command registry is canonical and its gate fires"
