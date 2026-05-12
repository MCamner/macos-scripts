#!/usr/bin/env bash
set -u

DEFAULT_ROOT="/Users/mansys"

echo
echo "REPO SIGNAL FOLDER CHECK"
echo "────────────────────────────────────────────────────────────"
echo "Run repo-signal against a local repository folder."
echo

if ! command -v repo-signal >/dev/null 2>&1; then
  echo "✖ repo-signal not found in PATH."
  exit 1
fi

printf "Local repo path under %s/: " "$DEFAULT_ROOT"
read -r INPUT_PATH

if [ -z "$INPUT_PATH" ]; then
  echo "✖ No path provided."
  exit 1
fi

case "$INPUT_PATH" in
  "$DEFAULT_ROOT"/*)
    REPO_PATH="$INPUT_PATH"
    ;;
  /*)
    REPO_PATH="$INPUT_PATH"
    ;;
  *)
    REPO_PATH="$DEFAULT_ROOT/$INPUT_PATH"
    ;;
esac

REPO_PATH="${REPO_PATH%/}"

if [ ! -d "$REPO_PATH" ]; then
  echo "✖ Folder does not exist: $REPO_PATH"
  exit 1
fi

echo
echo "Target: $REPO_PATH"
echo

echo "ANALYZE"
echo "────────────────────────────────────────────────────────────"
repo-signal analyze "$REPO_PATH"

echo
echo "PUBLISH CHECKLIST"
echo "────────────────────────────────────────────────────────────"
repo-signal publish-checklist "$REPO_PATH"

echo
echo "Done."
