#!/usr/bin/env bash
# The mqobsidian manifest reader has to work under both shells the launcher
# uses, and has to name the real problem when a dependency is missing.
#
# Two bugs shipped together in menu option 3 (open the roadmap doc):
#
#   get_mqobsidian_manifest_path:2: BASH_SOURCE[0]: parameter not set
#   get_mqobsidian_manifest_path:cd:2: no such file or directory: /../../config/mqobsidian
#   resolve_view_relative_path:3: command not found: jq
#   [mqobsidian][error] Requested view key is not defined in views.json: roadmap-doc
#
# The first is a shell split: bin/mqlaunch is bash, so command mode
# (`mqlaunch obsidian doctor`) resolved the manifest fine, while the
# interactive menu runs terminal/launchers/mqlaunch.sh, which is zsh — and
# zsh has no BASH_SOURCE. Sibling libs already handle this at source time;
# manifest.sh read it inside a function, where even zsh's $0 is no help
# because there it holds the function name.
#
# The second is the diagnosis: whatever went wrong upstream, the operator was
# told the view key was undefined. It is defined. Sending someone to inspect
# views.json when the actual fault is BASH_SOURCE or a missing jq is worse
# than saying nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/mqobsidian"
EXPECTED="$ROOT/mqlaunch/config/mqobsidian/views.json"

echo "SMOKE: mqobsidian manifest reader, bash and zsh parity"

echo "[1/8] libs and manifest exist"
test -f "$LIB/errors.sh"
test -f "$LIB/manifest.sh"
test -f "$EXPECTED"

load="source '$LIB/errors.sh'; source '$LIB/manifest.sh'"

echo "[2/8] bash resolves the manifest path"
got="$(bash -c "set -u; $load; get_mqobsidian_manifest_path")"
test "$got" = "$EXPECTED"

echo "[3/8] zsh resolves the same path, with no unset-parameter error"
# `set -u` is what the launcher runs under (terminal/launchers/mqlaunch.sh:3).
out="$(zsh -c "set -u; $load; get_mqobsidian_manifest_path" 2>&1)"
test "$out" = "$EXPECTED"

echo "[4/8] zsh resolves the view that option 3 opens"
out="$(zsh -c "set -u; $load; resolve_view_relative_path roadmap-doc" 2>&1)"
test "$out" = "docs/roadmap-token-reduction.md"

echo "[5/8] zsh resolves type and label too"
out="$(zsh -c "set -u; $load; resolve_view_type roadmap-doc" 2>&1)"
test "$out" = "file"
out="$(zsh -c "set -u; $load; resolve_view_label roadmap-doc" 2>&1)"
test -n "$out"

echo "[6/8] opening a view under zsh does not blank PATH"
# This is the fault behind "command not found: jq" on a machine that has jq.
# assert_view_target_exists declared `local path`, and in zsh $path is a
# special array tied to $PATH — so PATH was empty for everything it called,
# including the jq that reads the manifest. A fake vault keeps the assertion
# about the shell, not about what happens to be in the real one.
VAULT="$(mktemp -d)"
trap 'rm -rf "$VAULT"' EXIT
# systems/ and memory/ are what the resolver uses to recognise a vault.
mkdir -p "$VAULT/docs" "$VAULT/systems" "$VAULT/memory"
touch "$VAULT/docs/roadmap-token-reduction.md"

open_load="source '$LIB/errors.sh'; source '$LIB/resolve.sh'; source '$LIB/manifest.sh'; source '$LIB/open.sh'"
out="$(zsh -c "set -u; export MQ_OBSIDIAN_DIR='$VAULT'; $open_load; assert_view_target_exists roadmap-doc" 2>&1)"
test "$out" = "$VAULT/docs/roadmap-token-reduction.md"

# And no `local path` / `local status` may come back into the consumer lib.
! grep -qE '^[[:space:]]*local .*\b(path|status)\b' "$LIB"/*.sh

echo "[7/8] the doctor runs under zsh, where \$status is read-only"
out="$(zsh -c "set -u; export MQ_OBSIDIAN_DIR='$VAULT'; $open_load; source '$LIB/doctor.sh'; doctor_mqobsidian_views" 2>&1 || true)"
! grep -qi "read-only variable" <<<"$out"
grep -q "view roadmap-doc" <<<"$out"

echo "[8/8] a missing jq is reported as a missing jq"
# PATH is stripped after sourcing, so the source-time path resolution still
# has dirname; only the jq lookup fails. The old code blamed views.json.
rc=0
out="$(zsh -c "set -u; $load; PATH=/nonexistent; resolve_view_relative_path roadmap-doc" 2>&1)" || rc=$?
test "$rc" -ne 0
grep -q "jq" <<<"$out"
! grep -q "not defined in views.json" <<<"$out"

echo "OK: mqobsidian manifest shell parity passed"
