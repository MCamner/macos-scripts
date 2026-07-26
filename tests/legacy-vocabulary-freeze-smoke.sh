#!/usr/bin/env bash
set -euo pipefail

# The legacy command vocabulary is frozen.
#
# mqlaunch has two dispatchers, and they do not know the same words:
#
#   dispatch_cli_command   answers when a word is typed. Modelled by
#                          mqlaunch/lib/command-registry.json, gated against
#                          drift by command-registry-smoke.sh (#81) and against
#                          output-mode drift by output-mode-parity-smoke.sh (#82).
#   run_arg_command        answers when a word is chosen from the command
#                          palette. Modelled by nothing, until this file.
#
# The gap is 93 words. `mqlaunch tools`, `login`, `shortcuts`, `guide` and
# `repo` all work from the palette and print "Unknown command" when typed. That
# is exactly the question the roadmap says a user should never have to ask:
# "is this command shown in one place and missing from another?"
#
# Closing the gap by teaching the registry all 93 would make the registry carry
# a legacy vocabulary as if it were a product surface. Closing it by deleting
# palette entries would leave run_arg_command unaddressed. So the decision is
# neither: the vocabulary is compatibility-only and frozen at its current size.
# New commands go through the registry. This gate holds the line.
#
# Exact match in both directions. Additions fail because the surface must not
# grow; removals fail because a baseline that silently tolerates drift is not a
# baseline. Shrinking is the intended direction — delete the word from the case
# statement and from the baseline in the same commit.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
BASELINE="$ROOT/mqlaunch/lib/legacy-command-vocabulary.txt"
REGISTRY="$ROOT/mqlaunch/lib/command-registry.json"

echo "SMOKE: legacy command vocabulary is frozen"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/5] files exist"
test -f "$LAUNCHER"
test -f "$BASELINE"
test -f "$REGISTRY"

# Extraction lives in its own file so step 5 can run it against a mutated copy
# of the launcher. A gate that can only be pointed at the real tree cannot be
# shown to fail, and one that has never failed is a comment.
cat > "$run_dir/extract.py" <<'PY'
import re
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()

start = next((i for i, l in enumerate(lines) if l.startswith("run_arg_command()")), None)
if start is None:
    sys.exit("run_arg_command() not found — the freeze has nothing to hold")
end = next(i for i, l in enumerate(lines[start:], start) if l == "}")

labels = set()
for line in lines[start:end]:
    match = re.match(r"^    ([a-z0-9|_-]+|--?[a-z-]+)\)", line)
    if match:
        labels.update(match.group(1).split("|"))
labels.discard("*")

print("\n".join(sorted(labels)))
PY

# The baseline carries a comment header explaining why it exists; strip it.
grep -vE '^\s*(#|$)' "$BASELINE" | sort > "$run_dir/baseline.txt"
python3 "$run_dir/extract.py" "$LAUNCHER" | sort > "$run_dir/actual.txt"

echo "[2/5] the case statement and the baseline agree"
if ! diff -u "$run_dir/baseline.txt" "$run_dir/actual.txt" > "$run_dir/diff.txt"; then
  # From line 3 on: the ---/+++ headers start with the same characters as the
  # changed lines and would otherwise be counted as drift.
  body="$(tail -n +3 "$run_dir/diff.txt")"
  added="$(printf '%s\n' "$body" | grep -c '^+' || true)"
  removed="$(printf '%s\n' "$body" | grep -c '^-' || true)"
  echo "FAIL: run_arg_command has drifted from its frozen vocabulary" >&2
  echo "      $added added, $removed removed" >&2
  echo >&2
  sed -n '3,40p' "$run_dir/diff.txt" >&2
  echo >&2
  if [[ "$added" -gt 0 ]]; then
    echo "A new word here works from the palette and fails when typed." >&2
    echo "Add the command to $REGISTRY and dispatch_cli_command instead." >&2
  fi
  if [[ "$removed" -gt 0 ]]; then
    echo "Removing words is the goal — drop them from the baseline too." >&2
  fi
  exit 1
fi
printf '  ok: %s words, unchanged\n' "$(wc -l < "$run_dir/actual.txt" | tr -d ' ')"

echo "[3/5] the two vocabularies are still disjoint enough to matter"
# Recorded, not enforced: the overlap is what a migration would shrink. If it
# reaches zero the frozen surface has been fully absorbed and this gate can go.
python3 - "$REGISTRY" "$run_dir/actual.txt" <<'PY'
import json
import sys

registry = json.load(open(sys.argv[1], encoding="utf-8"))
known = {c["name"] for c in registry["commands"]}
known |= {a for c in registry["commands"] for a in c.get("aliases", [])}
legacy = set(open(sys.argv[2], encoding="utf-8").read().split())

unmodelled = legacy - known
print(f"  ok: {len(legacy)} legacy words, {len(unmodelled)} not modelled by the registry")
PY

echo "[4/5] the frozen vocabulary is reachable only through the palette"
# The freeze is about size, not reach. If a menu starts routing choices through
# run_arg_command, those 93 words become reachable from a new surface and the
# boundary has moved even though the word list did not.
callers="$(grep -rn 'run_arg_command' --include="*.sh" "$ROOT/terminal" "$ROOT/mqlaunch" "$ROOT/ui" \
  | grep -v 'run_arg_command() {' \
  | grep -v ':#' \
  || true)"
unexpected="$(printf '%s\n' "$callers" | grep -v 'mqlaunch.sh:.*run_arg_command \${=selected_cmd}' | grep . || true)"
if [[ -n "$unexpected" ]]; then
  echo "FAIL: run_arg_command is called from somewhere other than the palette:" >&2
  printf '%s\n' "$unexpected" >&2
  echo "The frozen vocabulary must not gain new entry points." >&2
  exit 1
fi
echo "  ok: the command palette is the only caller"

echo "[5/5] the comparison rejects a word that was never there"
# Same fixture discipline as command-registry-smoke.sh: prove the diff fires.
sed 's|^    finder) open_app "Finder" ;;|    finder\|deffo-not-a-command) open_app "Finder" ;;|' \
  "$LAUNCHER" > "$run_dir/mutated.sh"
if ! grep -q 'deffo-not-a-command' "$run_dir/mutated.sh"; then
  echo "FAIL: the mutation fixture did not apply — step 2 proves nothing" >&2
  exit 1
fi
python3 "$run_dir/extract.py" "$run_dir/mutated.sh" | sort > "$run_dir/mutated.txt"
if diff -q "$run_dir/baseline.txt" "$run_dir/mutated.txt" >/dev/null; then
  echo "FAIL: an injected command word did not show up as drift" >&2
  exit 1
fi
echo "  ok: an added word is detected"

bash -n "$0"
echo "OK: legacy command vocabulary is frozen"
