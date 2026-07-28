#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "[WARN] shellcheck not installed; skipping shell lint"
  exit 0
fi

scripts=()
while IFS= read -r script; do
  scripts+=("$script")
done < <(
  find "$PROJECT_ROOT" -type f -name '*.sh' \
    -not -path "$PROJECT_ROOT/backups/*" \
    -not -path "$PROJECT_ROOT/tools/legacy/*" \
    -not -path "$PROJECT_ROOT/terminal/mqlaunch-v1/*" \
    | sort
)

if (( ${#scripts[@]} == 0 )); then
  echo "[WARN] No shell scripts found"
  exit 0
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
  echo "[WARN] No bash/sh scripts found for shellcheck"
  exit 0
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
