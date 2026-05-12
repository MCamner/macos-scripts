#!/usr/bin/env bash
set -u

FAIL_UNDER="${1:-${MQ_REPO_SIGNAL_FAIL_UNDER:-14}}"

echo
echo "REPO SIGNAL"
echo "────────────────────────────────────────────────────────────"

if ! command -v repo-signal >/dev/null 2>&1; then
  echo "⚠ repo-signal not found; skipping publish checklist"
  echo "Install or expose repo-signal in PATH to enable this release gate."
  exit 0
fi

echo "Running: repo-signal publish-checklist . --fail-under ${FAIL_UNDER}"
echo

repo-signal publish-checklist . --fail-under "${FAIL_UNDER}"
status=$?

echo

if [ "$status" -eq 0 ]; then
  echo "✔ repo-signal publish checklist passed"
else
  echo "✖ repo-signal publish checklist failed"
  echo "  Required score threshold: ${FAIL_UNDER}"
fi

exit "$status"
