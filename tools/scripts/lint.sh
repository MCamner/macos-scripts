#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

# Exit 3 rather than 0. A gate that cannot run has not passed, and this one used
# to answer 0 — so `tools/scripts/test-all.sh` printed "All selftest checks
# passed" on a machine that had linted nothing. That is the same defect the
# release gate's secrets scan had (#214) and the same invariant
# docs/PULSE_CONTRACT.md carries for collectors:
#
#     could-not-measure  !=  measured-clean
#
# 3 is the code this stack already uses for "the command failed at its own job
# rather than finding something", per docs/PULSE_CONTRACT.md.
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "[UNAVAILABLE] shellcheck is not installed; no shell file was linted" >&2
  echo "  install it with: brew install shellcheck" >&2
  exit 3
fi

scripts=()
while IFS= read -r script; do
  scripts+=("$script")
done < <(
  find "$PROJECT_ROOT" -type f -name '*.sh' \
    -not -path "$PROJECT_ROOT/backups/*" \
    -not -path "$PROJECT_ROOT/tools/legacy/*" \
    | sort
)

# Never a legitimate outcome in this repo, which carries over two hundred shell
# files. An empty enumeration means the find failed, the root is wrong, or an
# exclusion swallowed everything — none of which is a clean tree, and all of
# which used to print a WARN and answer 0.
if (( ${#scripts[@]} == 0 )); then
  echo "[UNAVAILABLE] no shell scripts found under $PROJECT_ROOT" >&2
  echo "  the file enumeration produced nothing, so nothing was linted" >&2
  exit 3
fi

bash_scripts=()
for script in "${scripts[@]}"; do
  shebang="$(head -n 1 "$script" 2>/dev/null || true)"
  case "$shebang" in
    *zsh*)
      ;;
    *bash*|*'/sh')
      bash_scripts+=("$script")
      ;;
  esac
done

if (( ${#bash_scripts[@]} == 0 )); then
  echo "[UNAVAILABLE] no bash/sh scripts among ${#scripts[@]} shell file(s)" >&2
  echo "  the shebang filter matched nothing, so shellcheck was never run" >&2
  exit 3
fi

# Warning severity, enforced. `error` was already a hard gate here — this file
# has never had `|| true` and test-all.sh calls it — so raising the threshold is
# the actual change, not switching a gate on (#92).
#
# The baseline reached zero in #93-#99: 96 warnings, cleared in seven passes by
# rule rather than in bulk. Keeping it at zero is cheaper than getting back to
# it, which is the whole reason to enforce rather than report.
#
# zsh scripts are filtered out above because ShellCheck cannot parse zsh, not
# because they are exempt from scrutiny; they are covered by `zsh -n`.
shellcheck -S warning "${bash_scripts[@]}"
echo "[PASS] Shell lint passed at warning severity (${#bash_scripts[@]} files)"
