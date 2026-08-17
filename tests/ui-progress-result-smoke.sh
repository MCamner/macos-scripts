#!/usr/bin/env bash
# Locks the shell contract for ui_progress_steps and ui_result_panel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
PROGRESS="$ROOT/ui/terminal-ui/mq-progress.sh"

echo "SMOKE: step progress + result panel"

echo "[1/7] both primitives exist"
test -f "$PROGRESS"
grep -q '^ui_progress_steps()' "$PROGRESS"
grep -q '^ui_result_panel()' "$PROGRESS"

echo "[2/7] step progress has stable semantic glyphs"
out="$(bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'done|Scan' 'active|Review' 'pending|Save' 'warn|Check' 'fail|Write'")"
grep -q '^✓ Scan$' <<<"$out"
grep -q '^■ Review$' <<<"$out"
grep -q '^□ Save$' <<<"$out"
grep -q '^! Check$' <<<"$out"
grep -q '^✗ Write$' <<<"$out"

echo "[3/7] result panel is plain and deterministic when piped"
out="$(bash -c "source '$UI'; source '$PROGRESS'; ui_result_panel PASS 'Review complete' 'Brain: mqobsidian' 'Next: mqlaunch memory review-status'")"
test "$out" = $'✓ Review complete\nBrain: mqobsidian\nNext: mqlaunch memory review-status'

echo "[4/7] headless output contains no ANSI or cursor controls"
out="$(MQ_NO_TUI=1 bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'active|Work'; ui_result_panel WARN 'Needs attention' 'Findings: 2'")"
if printf '%s' "$out" | LC_ALL=C grep -q $'\033'; then
  echo "ANSI escape leaked into headless output" >&2
  exit 1
fi

echo "[5/7] interactive result uses the canonical box surface"
python3 - "$UI" "$PROGRESS" <<'PY'
import os, pty, sys

ui, progress = sys.argv[1:]
os.environ.pop("MQ_NO_TUI", None)
seen = bytearray()


def read(fd):
    chunk = os.read(fd, 4096)
    seen.extend(chunk)
    return chunk

script = f"source '{ui}'; source '{progress}'; ui_result_panel PASS 'Done' 'Next: mqlaunch'"
status = pty.spawn(["bash", "-c", script], read)
assert os.waitstatus_to_exitcode(status) == 0
text = seen.decode("utf-8", errors="replace")
assert "┌─ Result" in text
assert "✓ Done" in text
assert "Next: mqlaunch" in text
assert "└" in text
PY

echo "[6/7] NO_COLOR removes status color while preserving semantics"
out="$(NO_COLOR=1 bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'done|Scan'; ui_result_panel PASS 'Done'")"
if printf '%s' "$out" | LC_ALL=C grep -q $'\033'; then
  echo "ANSI escape leaked with NO_COLOR=1" >&2
  exit 1
fi
grep -q '✓ Scan' <<<"$out"
grep -q '✓ Done' <<<"$out"

echo "[7/7] both primitives run under zsh, the interactive menu shell"
out="$(zsh -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'active|zsh-step'; ui_result_panel INFO 'zsh-result'" 2>&1)"
grep -q '■ zsh-step' <<<"$out"
grep -q 'i zsh-result' <<<"$out"
! grep -qi 'read-only variable\|parse error\|command not found' <<<"$out"

echo "OK: progress/result UI smoke passed"
