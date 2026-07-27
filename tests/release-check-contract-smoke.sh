#!/usr/bin/env bash
set -euo pipefail

# `mqlaunch release-check --json` must reach the machine contract, not the human
# report. It used to forward the flag to terminal/release/mq-release-check.sh,
# which reads only --brain and discards everything else — so the flag was
# accepted, ignored, and the caller got a banner with exit 0.
#
# The delegates are stubbed. The real root release-check.sh runs the whole smoke
# suite, and this file runs inside that suite: calling it for real would recurse
# and cost a full test run per assertion. What is under test here is dispatch —
# which delegate is chosen, which arguments survive, and what an unknown flag
# does — and that is exactly what a stub can prove.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_MODE="$ROOT/terminal/launchers/mqlaunch-command-mode.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "SMOKE: release-check contract"

# A fake BASE_DIR holding both delegates, each announcing which one ran.
mkdir -p "$TMPDIR_TEST/terminal/release"
cat > "$TMPDIR_TEST/release-check.sh" <<'STUB'
#!/usr/bin/env bash
printf 'root:%s\n' "$*" >> "$STUB_LOG"
if [[ "${1:-}" == "--json" ]]; then
  printf '{"schema":"repo_release_check.v1","repo":"macos-scripts","status":"READY","blockers":[]}\n'
  exit 0
fi
echo "root human report"
STUB
cat > "$TMPDIR_TEST/terminal/release/mq-release-check.sh" <<'STUB'
#!/usr/bin/env bash
printf 'mq:%s\n' "$*" >> "$STUB_LOG"
echo "MQ RELEASE CHECK"
STUB
chmod +x "$TMPDIR_TEST/release-check.sh" \
  "$TMPDIR_TEST/terminal/release/mq-release-check.sh"

dispatch() {
  (
    export MACOS_SCRIPTS_HOME="$ROOT"
    export STUB_LOG="$TMPDIR_TEST/calls.log"
    # shellcheck source=/dev/null
    source "$COMMAND_MODE"
    pause_enter() { return 0; }
    # Read by the dispatcher sourced above — this is what points it at the stub
    # tree instead of the real one. ShellCheck cannot follow the source.
    # shellcheck disable=SC2034
    BASE_DIR="$TMPDIR_TEST"
    dispatch_cli_command "$@"
  )
}

echo "[1/4] --json reaches the canonical machine contract"
: > "$TMPDIR_TEST/calls.log"
set +e
dispatch release-check --json >"$TMPDIR_TEST/json.stdout" 2>"$TMPDIR_TEST/json.stderr"
json_status=$?
set -e
[[ $json_status -eq 0 ]] || {
  echo "release-check --json: expected exit 0, got $json_status" >&2
  exit 1
}
grep -q '^root:--json$' "$TMPDIR_TEST/calls.log" || {
  echo "release-check --json did not reach the root release-check.sh" >&2
  cat "$TMPDIR_TEST/calls.log" >&2
  exit 1
}

echo "[2/4] stdout is exactly one JSON document, with no banner around it"
python3 - "$TMPDIR_TEST/json.stdout" <<'PY'
import json
import sys

raw = open(sys.argv[1]).read()
try:
    doc = json.loads(raw)
except json.JSONDecodeError as exc:
    sys.exit(f"stdout is not a single JSON document ({exc}): {raw[:120]!r}")
if doc.get("schema") != "repo_release_check.v1":
    sys.exit(f"wrong schema: {doc.get('schema')!r}")
PY

echo "[3/4] an unknown flag is rejected, not swallowed"
: > "$TMPDIR_TEST/calls.log"
set +e
dispatch release-check --totally-bogus-flag \
  >"$TMPDIR_TEST/bogus.stdout" 2>"$TMPDIR_TEST/bogus.stderr"
bogus_status=$?
set -e
[[ $bogus_status -eq 2 ]] || {
  echo "unknown release-check flag: expected exit 2, got $bogus_status" >&2
  exit 1
}
grep -q 'ERROR:' "$TMPDIR_TEST/bogus.stderr" || {
  echo "unknown release-check flag: no diagnostic on stderr" >&2
  exit 1
}
# A human banner here would mask the failure from anything reading stdout.
[[ ! -s "$TMPDIR_TEST/calls.log" ]] || {
  echo "unknown release-check flag still ran a delegate:" >&2
  cat "$TMPDIR_TEST/calls.log" >&2
  exit 1
}

echo "[4/4] human mode keeps the broader review, and --brain survives"
# The two scripts check disjoint things; the mqlaunch surface owns the secrets
# scan and the mqobsidian manifest contract, so plain `release-check` must not
# be re-pointed at the root script.
for human_case in "" "--brain"; do
  : > "$TMPDIR_TEST/calls.log"
  if [[ -n "$human_case" ]]; then
    dispatch release-check "$human_case" >/dev/null 2>&1
  else
    dispatch release-check >/dev/null 2>&1
  fi
  grep -q "^mq:$human_case\$" "$TMPDIR_TEST/calls.log" || {
    echo "human release-check ${human_case:-(no flags)} did not reach mq-release-check.sh" >&2
    cat "$TMPDIR_TEST/calls.log" >&2
    exit 1
  }
done

bash -n "$0"
echo "OK: release-check --json is machine-readable and unknown flags fail"
