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

shellcheck -S error "${bash_scripts[@]}"
echo "[PASS] Shell lint passed (${#bash_scripts[@]} files)"
