#!/usr/bin/env bash
set -euo pipefail

# Eleven files under tests/ were never listed in tools/scripts/test-all.sh. Six
# of them failed when finally run by hand — one asserted that gitlaunch.sh
# contains the word "continue", which no commit reachable from HEAD does. None
# of that was reported, because a test nobody runs cannot fail. The repo looked
# better covered than it was.
#
# This gate makes the test surface honest: every file under tests/ is
# classified, every `active` one actually runs, and nothing classified `broken`
# is quietly counted as coverage.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/tests/manifest.tsv"
SUITE="$ROOT/tools/scripts/test-all.sh"

echo "SMOKE: test inventory"

# Marks a failing check.
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -f "$MANIFEST" ]] || fail "tests/manifest.tsv is missing"
[[ -f "$SUITE" ]] || fail "tools/scripts/test-all.sh is missing"

# name<TAB>class<TAB>note, skipping comments and blanks.
manifest_rows() {
  awk -F'\t' '!/^#/ && NF { print }' "$MANIFEST"
}

echo "[1/5] every classification is one this gate understands"
while IFS=$'\t' read -r name class note; do
  case "$class" in
    active|manual) ;;
    broken|obsolete)
      [[ -n "$note" && "$note" != "-" ]] \
        || fail "$name is '$class' but carries no reason — say why, or fix it"
      ;;
    *)
      fail "$name has unknown class '$class' (expected active, broken, manual, obsolete)"
      ;;
  esac
done < <(manifest_rows)

echo "[2/5] every test file is classified"
missing=""
for file in "$ROOT"/tests/*.sh; do
  base="$(basename "$file")"
  manifest_rows | cut -f1 | grep -Fxq "$base" || missing+=" $base"
done
[[ -z "$missing" ]] || {
  echo "test files with no row in tests/manifest.tsv:$missing" >&2
  echo "Add a row: name<TAB>class<TAB>note" >&2
  exit 1
}

echo "[3/5] every classified file still exists"
stale=""
while IFS=$'\t' read -r name class note; do
  [[ -f "$ROOT/tests/$name" ]] || stale+=" $name"
done < <(manifest_rows)
[[ -z "$stale" ]] || fail "tests/manifest.tsv lists files that are gone:$stale"

echo "[4/5] every active test actually runs in the suite"
unwired=""
while IFS=$'\t' read -r name class note; do
  [[ "$class" == active ]] || continue
  grep -Fq "$name" "$SUITE" || unwired+=" $name"
done < <(manifest_rows)
[[ -z "$unwired" ]] || {
  echo "classified active but absent from tools/scripts/test-all.sh:$unwired" >&2
  echo "Either wire it in, or reclassify it with a reason." >&2
  exit 1
}

echo "[5/5] nothing broken, manual, or obsolete is counted as coverage"
# The inverse matters as much: a broken test left in the suite turns the whole
# run red and invites someone to disable the suite instead of the test.
wrongly_wired=""
while IFS=$'\t' read -r name class note; do
  [[ "$class" == active ]] && continue
  grep -Fq "$name" "$SUITE" && wrongly_wired+=" $name($class)"
done < <(manifest_rows)
[[ -z "$wrongly_wired" ]] \
  || fail "listed in test-all.sh despite not being active:$wrongly_wired"

active_count="$(manifest_rows | awk -F'\t' '$2 == "active"' | wc -l | tr -d ' ')"
other_count="$(manifest_rows | awk -F'\t' '$2 != "active"' | wc -l | tr -d ' ')"

bash -n "$0"
echo "OK: ${active_count} active tests wired, ${other_count} classified out with reasons"
