#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

export BASE_DIR="$ROOT"
export MQ_OBSIDIAN_DIR="$TMP_ROOT/mqobsidian"
mkdir -p "$MQ_OBSIDIAN_DIR/inbox"
touch "$MQ_OBSIDIAN_DIR/inbox/README.md"

# shellcheck source=../terminal/menus/mq-main-menu.sh
source "$ROOT/terminal/menus/mq-main-menu.sh"
# shellcheck source=../terminal/menus/mq-obsidian-menu.sh
source "$ROOT/terminal/menus/mq-obsidian-menu.sh"

echo "[1/2] option 12 has a stable command label"
test "$(surface_choice_summary mqobsidian 12)" = "option 12: learning inbox triage"

echo "[2/2] triage screen explains its safe state and next owner"
output="$(mq_obsidian_triage_learning_inbox)"
grep -q "mqlaunch · Option 12 · Learning inbox triage" <<<"$output"
grep -q "Status" <<<"$output"
grep -q "  review gated" <<<"$output"
grep -q "Scope" <<<"$output"
grep -q "  Read-only inbox inspection. No promote/reject action runs here." <<<"$output"
grep -q "Memory inbox" <<<"$output"
grep -q "1. inbox/README.md" <<<"$output"
grep -q "Available here" <<<"$output"
grep -q "  Enter  return to menu" <<<"$output"
grep -q "  x      exit mqlaunch" <<<"$output"
grep -q "Next owner" <<<"$output"
grep -q "  mq-agent" <<<"$output"

echo "OK: mqobsidian triage safe-state UI passed"
