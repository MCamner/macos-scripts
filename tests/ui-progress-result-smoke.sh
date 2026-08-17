#!/usr/bin/env bash
# Locks the shell contract for ui_progress_steps and ui_result_panel.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI="$ROOT/ui/terminal-ui/mq-ui.sh"
PROGRESS="$ROOT/ui/terminal-ui/mq-progress.sh"
MENU="$ROOT/terminal/menus/mq-agent-menu.sh"

echo "SMOKE: step progress + result panel"

echo "[1/11] both primitives exist"
test -f "$PROGRESS"
grep -q '^ui_progress_steps()' "$PROGRESS"
grep -q '^ui_result_panel()' "$PROGRESS"

echo "[2/11] step progress has stable semantic glyphs"
out="$(bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'done|Scan' 'active|Review' 'pending|Save' 'warn|Check' 'fail|Write'")"
grep -q '^✓ Scan$' <<<"$out"
grep -q '^■ Review$' <<<"$out"
grep -q '^□ Save$' <<<"$out"
grep -q '^! Check$' <<<"$out"
grep -q '^✗ Write$' <<<"$out"

echo "[3/11] result panel is plain and deterministic when piped"
out="$(bash -c "source '$UI'; source '$PROGRESS'; ui_result_panel PASS 'Review complete' 'Brain: mqobsidian' 'Next: mqlaunch memory review-status'")"
test "$out" = $'✓ Review complete\nBrain: mqobsidian\nNext: mqlaunch memory review-status'

echo "[4/11] headless output contains no ANSI or cursor controls"
out="$(MQ_NO_TUI=1 bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'active|Work'; ui_result_panel WARN 'Needs attention' 'Findings: 2'")"
if printf '%s' "$out" | LC_ALL=C grep -q $'\033'; then
  echo "ANSI escape leaked into headless output" >&2
  exit 1
fi

echo "[5/11] interactive result uses the canonical box surface"
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

echo "[6/11] NO_COLOR removes status color while preserving semantics"
out="$(NO_COLOR=1 bash -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'done|Scan'; ui_result_panel PASS 'Done'")"
if printf '%s' "$out" | LC_ALL=C grep -q $'\033'; then
  echo "ANSI escape leaked with NO_COLOR=1" >&2
  exit 1
fi
grep -q '✓ Scan' <<<"$out"
grep -q '✓ Done' <<<"$out"

echo "[7/11] both primitives run under zsh, the interactive menu shell"
out="$(zsh -c "source '$UI'; source '$PROGRESS'; ui_progress_steps 'active|zsh-step'; ui_result_panel INFO 'zsh-result'" 2>&1)"
grep -q '■ zsh-step' <<<"$out"
grep -q 'i zsh-result' <<<"$out"
! grep -qi 'read-only variable\|parse error\|command not found' <<<"$out"

echo "[8/11] Review repo → brain routes through the shared integration helper"
grep -q '^_run_agent_review_brain_ui()' "$MENU"
grep -q '1) _run_agent_review_brain_ui; pause_enter ;;' "$MENU"

echo "[9/11] successful review + brain write finishes both steps and the PASS footer"
out="$(MQ_NO_TUI=1 BASE_DIR="$ROOT" bash -c "
  source '$UI'
  source '$PROGRESS'
  source '$MENU'
  ui_spinner() { shift; \"\$@\"; }
  _run_agent() { printf 'review body\\n→ brain: memory/reviews/demo.md\\n'; }
  _run_agent_review_brain_ui
")"
grep -q '^■ Review repository$' <<<"$out"
grep -q '^□ Save review to brain$' <<<"$out"
grep -q '^✓ Review repository$' <<<"$out"
grep -q '^✓ Save review to brain$' <<<"$out"
grep -q '^✓ Review complete$' <<<"$out"
grep -q '^Brain: memory/reviews/demo.md$' <<<"$out"

echo "[10/11] brain warning stays WARN even when the review command exits zero"
out="$(MQ_NO_TUI=1 BASE_DIR="$ROOT" bash -c "
  source '$UI'
  source '$PROGRESS'
  source '$MENU'
  ui_spinner() { shift; \"\$@\"; }
  _run_agent() { printf 'review body\\nbrain: mqobsidian unavailable\\n'; }
  _run_agent_review_brain_ui
")"
grep -q '^✓ Review repository$' <<<"$out"
grep -q '^! Save review to brain$' <<<"$out"
grep -q '^! Review complete; brain write needs attention$' <<<"$out"
grep -q '^Brain: mqobsidian unavailable$' <<<"$out"

echo "[11/11] review failure preserves the delegated exit code and skips brain"
out="$(MQ_NO_TUI=1 BASE_DIR="$ROOT" zsh -c "
  source '$UI'
  source '$PROGRESS'
  source '$MENU'
  ui_spinner() { shift; \"\$@\"; }
  _run_agent() { print -u2 -- 'review failed'; return 7; }
  rc=0
  _run_agent_review_brain_ui || rc=\$?
  print -- RC:\$rc
" 2>&1)"
grep -q '^✗ Review repository$' <<<"$out"
grep -q '^– Save review to brain$' <<<"$out"
grep -q '^✗ Review failed$' <<<"$out"
grep -q '^Brain: not updated$' <<<"$out"
grep -q '^RC:7$' <<<"$out"
! grep -qi 'read-only variable\|parse error\|command not found' <<<"$out"

echo "OK: progress/result UI smoke passed"
