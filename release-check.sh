#!/usr/bin/env bash
# Root release readiness check for macos-scripts. Read-only.
#
# Human mode (no flags / --dry-run): prints per-check ok/FAIL, exits 1 on any
#   failure.
# Contract mode (--json): emits a repo_release_check.v1 object on stdout and
#   exits 0 (the `status` field carries the verdict). Consumed by mq-agent's
#   `stack release --all --preflight`. --dry-run is accepted; this check never
#   mutates the tree.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || exit 1
VERSION="$(cat VERSION)"

DRY_RUN=0
JSON=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --json) JSON=1 ;;
    *) echo "usage: ./release-check.sh [--dry-run] [--json]" >&2; exit 2 ;;
  esac
done
: "$DRY_RUN"

BLOCKERS=()
# Coordinates say behavior.
say()  { [[ "$JSON" -eq 1 ]] || echo "$1"; }
# Coordinates ok behavior.
ok()   { [[ "$JSON" -eq 1 ]] || echo "  ok: $1"; }
# Marks a failing check.
fail() { BLOCKERS+=("$1"); [[ "$JSON" -eq 1 ]] || echo "FAIL: $1" >&2; }

# Coordinates run behavior.
run() {
  local label="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    ok "$label"
  else
    fail "$label"
    [[ "$JSON" -eq 1 ]] || printf '%s\n' "$out" >&2
  fi
}

say "=== macos-scripts release-check v${VERSION} ==="

say "--- Version surfaces ---"
CONTRACT_VER="$(python3 -c "import json; print(json.load(open('.mq/repo-contract.json'))['version'])" 2>/dev/null)"
if [[ "$CONTRACT_VER" == "$VERSION" ]]; then
  ok ".mq/repo-contract.json matches VERSION ($VERSION)"
else
  fail ".mq/repo-contract.json version '$CONTRACT_VER' != VERSION '$VERSION'"
fi
if grep -q "$VERSION" CHANGELOG.md 2>/dev/null; then
  ok "CHANGELOG references $VERSION"
else
  fail "CHANGELOG does not reference $VERSION"
fi
if grep -q "$VERSION" README.md 2>/dev/null; then
  ok "README references $VERSION"
else
  fail "README does not reference $VERSION"
fi

say "--- Consistency checks ---"
run "skills consistent" bash scripts/check-skills.sh
run "runtime authority freeze" bash scripts/check-runtime-authority.sh

say "--- Shell syntax ---"
# shellcheck disable=SC2016  # intentional: the loop runs in the child bash -c
run "bash -n (install/release/scripts)" bash -c '
  set -e
  bash -n install.sh
  bash -n release.sh
  for f in scripts/*.sh; do [ -e "$f" ] && bash -n "$f"; done
'

say "--- mqlaunch smoke suite ---"
run "test-all.sh" env MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 ./tools/scripts/test-all.sh

if [[ "$JSON" -eq 1 ]]; then
  status=READY
  [[ "${#BLOCKERS[@]}" -gt 0 ]] && status=BLOCKED
  python3 - "$status" "$VERSION" ${BLOCKERS[@]+"${BLOCKERS[@]}"} <<'PY'
import json
import sys

status, version, *blockers = sys.argv[1:]
print(json.dumps({
    "schema": "repo_release_check.v1",
    "repo": "macos-scripts",
    "status": status,
    "blockers": blockers,
    "warnings": [],
    "evidence": {"version": version},
}))
PY
  exit 0
fi

say ""
if [[ "${#BLOCKERS[@]}" -eq 0 ]]; then
  echo "=== All checks passed — v${VERSION} is green ==="
else
  echo "=== ${#BLOCKERS[@]} check(s) failed — fix before releasing ===" >&2
  exit 1
fi
