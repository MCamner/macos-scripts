#!/usr/bin/env bash
set -euo pipefail

# A README must not name a file that is not there.
#
# Three READMEs describe their directory file by file, as `### `name`` sections:
# ui/ascii, terminal/menus and automation/workflows. That form is a hand-written
# inventory, and hand-written inventories go stale in one direction silently —
# ui/ascii/README.md carried an entry for mq-skull.txt for as long as it took
# somebody to read the directory listing next to it, long after PR #32 deleted
# the file.
#
# The contract is one-directional on purpose, the same shape used for
# `mqlaunch help` and README in tests/command-docs-smoke.sh:
#
#   documented -> must exist    A section for a file that is gone sends a reader
#                               looking for something that was deleted, and it
#                               is the kind of wrong a gate can be certain about.
#   exists -> must be documented   NOT required. Which files earn a section is
#                               curation. terminal/menus/README.md describes 11
#                               of 21 menus by design; forcing the rest in would
#                               make it a directory listing, which the shell
#                               already provides.
#
# So this measures coverage and prints it, without failing on it. A number
# moving is a prompt to look, not a build break.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# READMEs that inventory their directory with `### `name`` sections. Adding one
# here is how a new directory joins the check.
INVENTORIES=(
  "ui/ascii/README.md"
  "terminal/menus/README.md"
  "automation/workflows/README.md"
)

echo "SMOKE: README file inventories match the tree"

run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

echo "[1/3] the inventories exist"
for readme in "${INVENTORIES[@]}"; do
  test -f "$ROOT/$readme" || {
    echo "FAIL: $readme is listed as an inventory but is not there" >&2
    exit 1
  }
done

# Extraction in its own file so step 3 can run it against a mutated README and
# show the comparison failing. Same discipline as the other docs gates.
cat > "$run_dir/inventory.py" <<'PY'
"""Check that every file a README documents by name still exists."""
import pathlib
import re
import sys


def documented(readme):
    """File names from `### `name.ext`` headings.

    Anchored to a heading with an extension so prose, command names and section
    titles cannot contribute. `### `mq-banner.sh`` counts; `### Current files`
    does not.
    """
    text = pathlib.Path(readme).read_text(encoding="utf-8")
    return set(re.findall(r"^### `([^`]+\.[A-Za-z0-9]+)`", text, re.M))


def main():
    root = pathlib.Path(sys.argv[1])
    failures = []
    for rel in sys.argv[2:]:
        readme = root / rel
        directory = readme.parent
        named = documented(readme)
        on_disk = {f.name for f in directory.iterdir()
                   if f.is_file() and f.name != readme.name}

        ghosts = sorted(named - on_disk)
        if ghosts:
            failures.append(
                f"{rel} documents {len(ghosts)} file(s) that are not there: "
                + " ".join(ghosts))

        undocumented = len(on_disk - named)
        print(f"  {rel}: {len(named)} documented, "
              f"{undocumented} present but not written up")

    if failures:
        print(file=sys.stderr)
        for line in failures:
            print("  " + line, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
PY

echo "[2/3] every documented file is in the tree"
python3 "$run_dir/inventory.py" "$ROOT" "${INVENTORIES[@]}"

echo "[3/3] the check rejects a README that outlives its file"
# A gate that has never failed is a comment. The fixture is a copy of a real
# inventory with one section added for a file that was never there.
fixture_dir="$run_dir/ui/ascii"
mkdir -p "$fixture_dir"
cp "$ROOT/ui/ascii/README.md" "$fixture_dir/README.md"
for real in "$ROOT"/ui/ascii/*; do
  [[ "$(basename "$real")" == "README.md" ]] && continue
  touch "$fixture_dir/$(basename "$real")"
done
printf '\n### `never-existed.sh`\n\nA section for a file nobody wrote.\n' \
  >> "$fixture_dir/README.md"

if out="$(python3 "$run_dir/inventory.py" "$run_dir" "ui/ascii/README.md" 2>&1)"; then
  echo "FAIL: a documented file that does not exist was not detected" >&2
  exit 1
fi
case "$out" in
  *"never-existed.sh"*) ;;
  *)
    echo "FAIL: the check failed for the wrong reason:" >&2
    printf '%s\n' "$out" >&2
    exit 1
    ;;
esac
echo "  ok: a section outliving its file is detected"

bash -n "$0"

echo "OK: no README promises a file the tree does not have"
