#!/usr/bin/env zsh
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$HOME/macos-scripts}"
BUNDLE_DIR="$PROJECT_ROOT/backups/debug-bundles"
VERSION_FILE="$PROJECT_ROOT/VERSION"
LEGACY="$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
V1="$PROJECT_ROOT/terminal/mqlaunch-v1/mqlaunch.sh"
GUIDE_HTML="$PROJECT_ROOT/docs/mac-terminal-guide.html"
TEST_ALL="$PROJECT_ROOT/tools/scripts/test-all.sh"

mkdir -p "$BUNDLE_DIR"

timestamp="$(date +"%Y-%m-%d_%H-%M-%S")"
outfile="$BUNDLE_DIR/mqlaunch-bundle-$timestamp.txt"

version="unknown"
[[ -f "$VERSION_FILE" ]] && version="$(head -n 1 "$VERSION_FILE")"

{
  echo "mqlaunch Debug Bundle"
  echo "Generated: $(date)"
  echo "Version: $version"
  echo

  echo "=== PATHS ==="
  echo "Project root: $PROJECT_ROOT"
  echo "Legacy launcher: $LEGACY"
  echo "V1 launcher: $V1"
  echo "Guide HTML: $GUIDE_HTML"
  echo "Bundle output: $outfile"
  echo

  echo "=== FILE CHECKS ==="
  [[ -f "$LEGACY" ]] && echo "[OK] Legacy launcher exists" || echo "[FAIL] Legacy launcher missing"
  [[ -f "$V1" ]] && echo "[OK] V1 launcher exists" || echo "[FAIL] V1 launcher missing"
  [[ -f "$GUIDE_HTML" ]] && echo "[OK] Guide HTML exists" || echo "[FAIL] Guide HTML missing"
  [[ -x "$TEST_ALL" ]] && echo "[OK] test-all.sh executable" || echo "[FAIL] test-all.sh missing or not executable"
  echo

  echo "=== GIT ==="
  (
    cd "$PROJECT_ROOT"
    echo "Branch: $(git branch --show-current 2>/dev/null || echo unknown)"
    echo "Last commit: $(git log -1 --pretty=format:'%h - %s (%cr)' 2>/dev/null || echo unavailable)"
    echo
    echo "Status:"
    git status --short 2>/dev/null || true
  )
  echo

  echo "=== SYSTEM ==="
  echo "Hostname: $(scutil --get ComputerName 2>/dev/null || hostname)"
  echo "User: $(whoami)"
  echo "Shell: $SHELL"
  echo "Uptime:"
  uptime
  echo
  echo "Disk (/):"
  df -h / | tail -1
  echo
  echo "Memory:"
  vm_stat | head -10
  echo
  echo "Network:"
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "No active primary IP found"
  echo
  echo "Battery:"
  pmset -g batt 2>/dev/null || echo "Battery data unavailable"
  echo

  echo "=== LAUNCHER HELP CHECKS ==="
  zsh "$LEGACY" help >/dev/null 2>&1 && echo "[OK] Legacy help works" || echo "[FAIL] Legacy help failed"
  bash "$V1" help >/dev/null 2>&1 && echo "[OK] V1 help works" || echo "[FAIL] V1 help failed"
  echo

  echo "=== SMOKE TESTS ==="
  if [[ -x "$TEST_ALL" ]]; then
    "$TEST_ALL" 2>&1 || true
  else
    echo "[FAIL] Cannot run smoke tests"
  fi
  echo

  echo "=== MENU ROUTE CHECKS ==="
  grep -nE 'WORKFLOWS|23\. Performance|24\. Dev|25\. Tools|26\. Version|27\. Self-check|28\. Debug bundle' "$LEGACY" 2>/dev/null || true
  echo
  grep -nE 'open_v1_performance_menu|open_v1_dev_menu|open_v1_tools_menu|show_version_info|run_self_check|run_debug_bundle' "$LEGACY" 2>/dev/null || true
  echo

  echo "=== RECENT REPORT FILES ==="
  find "$PROJECT_ROOT/backups" -maxdepth 2 -type f 2>/dev/null | sort | tail -20
  echo
} > "$outfile"

echo "$outfile"
