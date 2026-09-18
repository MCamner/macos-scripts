#!/usr/bin/env bash
# Syntax-check every shell script in the repo, routed by shebang.
#
# Extracted from .github/workflows/quality.yml so the local release gate and CI
# run the same sweep rather than two similar ones. release-check.sh used to
# check install.sh, release.sh and scripts/*.sh -- five files out of 261 -- and
# still printed an ok line for "Shell syntax". In a repo that is almost
# entirely shell, that gate reported on 2% of the surface.
#
# The count is asserted before the loop, and the success line reports it.
# Without that, an enumeration that produced nothing runs the loop body zero
# times and prints a clean result having checked nothing: a broken checkout, a
# wrong working directory or an exclusion that swallowed the tree all look like
# a clean repo to a loop that never runs.
#
#     could-not-measure != measured-clean

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

mapfile -d '' -t files < <(
  find . \
    -name "*.sh" \
    -not -path "./.git/*" \
    -not -path "./backups/*" \
    -print0
)

if (( ${#files[@]} == 0 )); then
  echo "FAIL: found no .sh files to check - the enumeration is broken" >&2
  exit 1
fi

status=0
for f in "${files[@]}"; do
  shebang="$(head -1 "$f")"
  if [[ "$shebang" == *zsh* ]]; then
    zsh -n "$f" </dev/null || { echo "FAIL (zsh -n): $f" >&2; status=1; }
  else
    bash -n "$f" </dev/null || { echo "FAIL (bash -n): $f" >&2; status=1; }
  fi
done

if (( status == 0 )); then
  echo "All ${#files[@]} .sh files (excl. backups/) pass syntax check"
fi
exit "$status"
