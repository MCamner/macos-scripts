#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/prompts.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Marks a failing check.
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

echo "[1/5] shared prompt library exists and is sourced"
test -f "$LIB" || fail "prompt library missing"
grep -q 'mqlaunch/lib/prompts.sh' "$LAUNCHER" || fail "launcher does not source prompt library"

echo "[2/5] prompt functions have one definition"
for function_name in resolve_prompt_dir resolve_ai_status safe_run_ai prompts_pick show_prompt_files backup_prompts open_ai_prompts_folder; do
  count="$(grep -R -h "^${function_name}()" "$LIB" "$LAUNCHER" | wc -l | tr -d ' ')"
  test "$count" = "1" || fail "$function_name has $count definitions"
done

echo "[3/5] prompt directory resolution preserves precedence and failure"
mkdir -p "$TMPDIR_TEST/repo/ai-prompts" "$TMPDIR_TEST/configured"
output="$(BASE_DIR="$TMPDIR_TEST/repo" PROMPT_DIR="$TMPDIR_TEST/configured" zsh -c 'source "$1"; resolve_prompt_dir' _ "$LIB")"
test "$output" = "$TMPDIR_TEST/repo/ai-prompts" || fail "repo prompt directory did not win"
rm -rf "$TMPDIR_TEST/repo/ai-prompts"
output="$(BASE_DIR="$TMPDIR_TEST/repo" PROMPT_DIR="$TMPDIR_TEST/configured" zsh -c 'source "$1"; resolve_prompt_dir' _ "$LIB")"
test "$output" = "$TMPDIR_TEST/configured" || fail "configured prompt directory was not used"
rm -rf "$TMPDIR_TEST/configured"
if BASE_DIR="$TMPDIR_TEST/repo" PROMPT_DIR="$TMPDIR_TEST/missing" zsh -c 'source "$1"; resolve_prompt_dir' _ "$LIB" >/dev/null 2>&1; then
  fail "missing prompt directories returned success"
fi

echo "[4/5] AI status preserves all backend states"
AI_SCRIPT="$TMPDIR_TEST/ai-mode.sh"
output="$(AI_SCRIPT="$AI_SCRIPT" zsh -c 'source "$1"; resolve_ai_status' _ "$LIB")"
test "$output" = "MISSING" || fail "missing backend status changed"
touch "$AI_SCRIPT"
output="$(AI_SCRIPT="$AI_SCRIPT" zsh -c 'source "$1"; resolve_ai_status' _ "$LIB")"
test "$output" = "FOUND_NOT_EXECUTABLE" || fail "non-executable backend status changed"
chmod +x "$AI_SCRIPT"
output="$(AI_SCRIPT="$AI_SCRIPT" zsh -c 'source "$1"; resolve_ai_status' _ "$LIB")"
test "$output" = "OK" || fail "executable backend status changed"

echo "[5/5] AI mode is forwarded unchanged"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@"\n' > "$AI_SCRIPT"
chmod +x "$AI_SCRIPT"
output="$(AI_SCRIPT="$AI_SCRIPT" zsh -c 'source "$1"; safe_run_ai research' _ "$LIB")"
test "$output" = "research" || fail "AI mode forwarding changed"

echo "OK: shared prompt concern"
