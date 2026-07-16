#!/usr/bin/env bash
# Run markdownlint in the current repository without requiring a global install.
#
# Usage:
#   markdownlint.sh
#   markdownlint.sh ROADMAP.md docs/
#   markdownlint.sh --fix ROADMAP.md

set -euo pipefail

VERSION="${MARKDOWNLINT_CLI2_VERSION:-0.23.0}"

if [[ $# -eq 0 ]]; then
  set -- "**/*.md"
fi

if [[ -x "./node_modules/.bin/markdownlint-cli2" ]]; then
  exec ./node_modules/.bin/markdownlint-cli2 "$@"
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  exec markdownlint-cli2 "$@"
fi

if command -v npx >/dev/null 2>&1; then
  echo "markdownlint-cli2 not installed; running pinned version ${VERSION} via npx." >&2
  exec npx --yes "markdownlint-cli2@${VERSION}" "$@"
fi

echo "ERROR: markdownlint-cli2 or npx is required." >&2
exit 127
