#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
pass() { printf '[PASS] %s\n' "$1"; }

# Stub dashboard: appends a line to a counter file every time it runs, and
# echoes a marker so callers can see the rendered output.
COUNT_FILE="$TMP/runs"
: > "$COUNT_FILE"
STUB="$TMP/dashboard.sh"
cat > "$STUB" <<STUBEOF
#!/usr/bin/env bash
printf 'x\n' >> "$COUNT_FILE"
printf 'DASHBOARD %s\n' "\$1"
STUBEOF
chmod +x "$STUB"
export COUNT_FILE

runs() { wc -l < "$COUNT_FILE" | tr -d ' '; }

# shellcheck disable=SC1090
source "$ROOT/ui/terminal-ui/mq-ui.sh"
APP_TITLE="MQ"; APP_SUBTITLE="Launcher"

# 1. Two renders within the TTL window fork the dashboard once.
# Use redirection (not command substitution) so the cache update stays in this
# shell — exactly how print_header is invoked inside the menu loop.
MQ_DASHBOARD_CACHE_TTL=5
mq_dashboard_cache_invalidate
print_dashboard_header "$STUB" > "$TMP/out1"
print_dashboard_header "$STUB" > "$TMP/out2"
[[ "$(runs)" == "1" ]] || fail "expected 1 fork within TTL, got $(runs)"
diff -q "$TMP/out1" "$TMP/out2" >/dev/null || fail "cached render differs from first render"
[[ "$(cat "$TMP/out1")" == "DASHBOARD MQ" ]] || fail "unexpected render output: $(cat "$TMP/out1")"
pass "rapid renders within TTL reuse the cached dashboard"

# 2. Explicit invalidation forces a fresh fork.
mq_dashboard_cache_invalidate
print_dashboard_header "$STUB" >/dev/null
[[ "$(runs)" == "2" ]] || fail "expected fork after invalidate, got $(runs)"
pass "cache invalidation forces a fresh render"

# 3. A different working directory is a cache miss (git status is cwd-dependent).
( cd "$TMP" && print_dashboard_header "$STUB" >/dev/null )
[[ "$(runs)" == "3" ]] || fail "expected fork on cwd change, got $(runs)"
pass "changing working directory misses the cache"

# 4. TTL=0 disables caching entirely.
: > "$COUNT_FILE"
MQ_DASHBOARD_CACHE_TTL=0
mq_dashboard_cache_invalidate
print_dashboard_header "$STUB" >/dev/null
print_dashboard_header "$STUB" >/dev/null
[[ "$(runs)" == "2" ]] || fail "expected 2 forks with TTL=0, got $(runs)"
pass "MQ_DASHBOARD_CACHE_TTL=0 disables caching"

# 5. The mutating sub-menus invalidate the cache on the way back to the main
# loop, so a commit/stash/tag is reflected immediately rather than after the TTL.
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
awk '/^open_git_menu\(\)/{f=1} f&&/mq_dashboard_cache_invalidate/{print; exit}' "$LAUNCHER" \
  | grep -q mq_dashboard_cache_invalidate || fail "open_git_menu does not invalidate the cache on Back"
awk '/^open_release_menu\(\)/{f=1} f&&/mq_dashboard_cache_invalidate/{print; exit}' "$LAUNCHER" \
  | grep -q mq_dashboard_cache_invalidate || fail "open_release_menu does not invalidate the cache on Back"
pass "git and release menus invalidate the cache on return"

printf 'OK: dashboard header cache contract passed\n'
