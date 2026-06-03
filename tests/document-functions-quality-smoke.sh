#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/tools/scripts/document-functions.sh"
MENU="$ROOT/terminal/menus/mq-tools-menu.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mq-doc-quality.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "SMOKE: document function comment quality"

echo "[1/6] tool syntax"
bash -n "$TOOL"

echo "[2/6] menu exposes quality check"
grep -q "Quality selected" "$MENU"
grep -q "run_document_functions_quality_selected" "$MENU"

echo "[3/6] weak generated comment is flagged"
cat >"$TMP_DIR/weak.sh" <<'EOF'
#!/usr/bin/env bash

# Handles handle dev menu choice.
handle_dev_menu_choice() {
  :
}
EOF
if MACOS_SCRIPTS_HOME="$ROOT" "$TOOL" --quality --check "$TMP_DIR/weak.sh" >/tmp/mq-doc-quality-weak.out 2>&1; then
  echo "Expected weak comment check to fail" >&2
  exit 1
fi
grep -q "weak comment above handle_dev_menu_choice" /tmp/mq-doc-quality-weak.out

echo "[4/6] specific purpose comment passes"
cat >"$TMP_DIR/strong.sh" <<'EOF'
#!/usr/bin/env bash

# Routes a dev menu choice to the matching script or submenu.
handle_dev_menu_choice() {
  :
}
EOF
MACOS_SCRIPTS_HOME="$ROOT" "$TOOL" --quality --check "$TMP_DIR/strong.sh"

echo "[5/6] summary includes quality counters"
MACOS_SCRIPTS_HOME="$ROOT" "$TOOL" --quality --summary "$TMP_DIR/weak.sh" >/tmp/mq-doc-quality-summary.out
grep -q "weak function comments need review" /tmp/mq-doc-quality-summary.out

echo "[6/6] Ollama review syntax"
python3 -m py_compile "$ROOT/tools/scripts/ollama-document-review.py"

echo "OK: document function comment quality smoke test passed"
