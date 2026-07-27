#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

export BASE_DIR="$ROOT"
export MQ_OBSIDIAN_DIR="$TMP_ROOT/mqobsidian"
mkdir -p "$MQ_OBSIDIAN_DIR/scripts"

# shellcheck source=../terminal/menus/mq-main-menu.sh
source "$ROOT/terminal/menus/mq-main-menu.sh"
# shellcheck source=../terminal/menus/mq-obsidian-menu.sh
source "$ROOT/terminal/menus/mq-obsidian-menu.sh"

echo "[1/2] option 13 has a stable command label"
test "$(surface_choice_summary mqobsidian 13)" = "option 13: regenerate memory views"

echo "[2/2] missing producer is presented as a planned placeholder"
output="$(mq_obsidian_regenerate_views)"
grep -q "mqlaunch · Option 13 · Regenerate memory views" <<<"$output"
grep -q "  not implemented yet" <<<"$output"
grep -q "  No regenerate-memory-views script is registered." <<<"$output"
grep -q "Expected owner" <<<"$output"
grep -q "  mq-agent orchestration" <<<"$output"
grep -q "Local producer" <<<"$output"
grep -q "  mqobsidian regenerate-memory-views script" <<<"$output"
grep -q "mqlaunch role" <<<"$output"
grep -q "  menu entry and read-only status only" <<<"$output"
grep -q "  Enter  return to menu" <<<"$output"
grep -q "  x      exit mqlaunch" <<<"$output"

echo "OK: mqobsidian regenerate placeholder UI passed"
