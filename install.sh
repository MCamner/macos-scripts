#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/macos-scripts}"
BIN_DIR="$PROJECT_ROOT/bin"
TARGET="$BIN_DIR/mqlaunch"
ZSHRC="$HOME/.zshrc"
RUN_CHECKS=1

for arg in "$@"; do
  case "$arg" in
    --skip-checks)
      RUN_CHECKS=0
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: ./install.sh [--skip-checks]"
      exit 1
      ;;
  esac
done

info() {
  echo "[INFO] $1"
}

pass() {
  echo "[PASS] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "== macos-scripts install =="

[[ -d "$PROJECT_ROOT" ]] || fail "Project root not found: $PROJECT_ROOT"

mkdir -p "$BIN_DIR"

cat > "$TARGET" <<'WRAPPER'
#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="$HOME/macos-scripts"
exec "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh" "$@"
WRAPPER

chmod +x "$TARGET"
pass "Installed wrapper: $TARGET"

PATH_LINE='export PATH="$HOME/macos-scripts/bin:$PATH"'
if [[ -f "$ZSHRC" ]]; then
  if ! grep -Fq "$PATH_LINE" "$ZSHRC"; then
    {
      echo ""
      echo "# macos-scripts"
      echo "$PATH_LINE"
    } >> "$ZSHRC"
    pass "Added PATH entry to $ZSHRC"
  else
    pass "PATH already configured in $ZSHRC"
  fi
else
  cat > "$ZSHRC" <<EOF2
# macos-scripts
$PATH_LINE
EOF2
  pass "Created $ZSHRC with PATH entry"
fi

[[ -f "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh" ]] || fail "Missing legacy launcher"
[[ -f "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh" ]] || fail "Missing v1 launcher"
pass "Launcher files verified"

zsh "$PROJECT_ROOT/terminal/launchers/mqlaunch.sh" help >/dev/null 2>&1 || fail "Legacy launcher help check failed"
pass "Legacy launcher responds"

bash "$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh" help >/dev/null 2>&1 || fail "V1 launcher help check failed"
pass "V1 launcher responds"

if (( RUN_CHECKS )); then
  echo
  info "Running smoke checks..."

  if [[ -x "$PROJECT_ROOT/tools/scripts/test-all.sh" ]]; then
    "$PROJECT_ROOT/tools/scripts/test-all.sh" || fail "Smoke checks failed"
    pass "All smoke checks passed"
  else
    warn "Smoke test script not found: $PROJECT_ROOT/tools/scripts/test-all.sh"
    warn "Skipping smoke checks"
  fi
else
  warn "Skipping smoke checks (--skip-checks)"
fi

echo
echo "== Install complete =="
echo
echo "Next steps:"
echo "  1. Restart terminal or run: source ~/.zshrc"
echo "  2. Run: mqlaunch"
echo "  3. Try: mqlaunch perf"
echo "  4. Run checks anytime with: ~/macos-scripts/tools/scripts/test-all.sh"
