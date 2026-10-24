#!/usr/bin/env bash
# Verify the GitHub release page agrees with the versions this repo declares.
#
# Ported from mq-hal tools/check-github-releases.sh. Two questions: is the
# version about to be released already published, and was the previous
# declared version ever published at all. A release-check that only reads
# VERSION, CHANGELOG and README stays green for a version that already has a
# release, so a bump that never happened goes unnoticed.
#
# The predecessor comes from CHANGELOG.md rather than from the tag list: the
# changelog is where a version is declared to exist. A leading `v` in a heading
# (`## [v1.35.0]`) is ignored, so both heading styles in the stack match.
#
# Network: one or two `gh release view` calls. release-check.sh keeps this
# behind --dry-run, --json and CI, so the stack preflight and CI stay
# network-free.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"   # gh resolves the repository from this checkout's remote
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
CHANGELOG="$ROOT/CHANGELOG.md"

# Fixtures, so the gate can be tested against release histories that do not
# exist in this repo.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --changelog) CHANGELOG="$2"; shift 2 ;;
    *) echo "usage: check-github-releases.sh [--version X.Y.Z] [--changelog FILE]" >&2; exit 2 ;;
  esac
done
VERSION="${VERSION#v}"

if ! gh auth status >/dev/null 2>&1; then
  # Without auth every lookup fails, which reads as "nothing is published" —
  # a false FAIL on every version. Not knowing is a skip, not a verdict.
  echo "SKIP: gh is not authenticated — cannot read the release list"
  exit 0
fi

FAILED=0

published() { gh release view "v$1" >/dev/null 2>&1; }

if published "$VERSION"; then
  echo "FAIL: v$VERSION is already published — bump VERSION before releasing"
  FAILED=1
else
  echo "OK: v$VERSION is not yet published"
fi

set +e
PREV="$(python3 - "$VERSION" "$CHANGELOG" <<'PY'
import re
import sys

version, path = sys.argv[1], sys.argv[2]
try:
    text = open(path, encoding="utf-8").read()
except OSError:
    sys.exit(5)

# Keep a Changelog order: newest first, so the predecessor is the next heading.
declared = [
    name[1:] if name.startswith("v") else name
    for name in re.findall(r"^## \[([^\]]+)\]", text, re.M)
    if name.lower() != "unreleased"
]
if version not in declared:
    sys.exit(3)
index = declared.index(version)
if index + 1 >= len(declared):
    sys.exit(4)
print(declared[index + 1])
PY
)"
prev_status=$?
set -e

case "$prev_status" in
  0)
    if published "$PREV"; then
      echo "OK: predecessor v$PREV is published"
    else
      echo "FAIL: predecessor v$PREV is declared in $(basename "$CHANGELOG") but has no published GitHub release"
      FAILED=1
    fi
    ;;
  3) echo "SKIP: $VERSION is not declared in $(basename "$CHANGELOG")" ;;
  4) echo "SKIP: v$VERSION is the oldest declared version — no predecessor" ;;
  *) echo "FAIL: could not read a predecessor from $CHANGELOG"; FAILED=1 ;;
esac

exit "$FAILED"
