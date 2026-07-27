#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU="$ROOT/terminal/menus/mq-obsidian-menu.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

export BASE_DIR="$ROOT"
export MQ_OBSIDIAN_DIR="$TMP_ROOT/mqobsidian"
mkdir -p "$MQ_OBSIDIAN_DIR/.venv/bin"
printf '#!/usr/bin/env sh\nexit 0\n' >"$MQ_OBSIDIAN_DIR/.venv/bin/python3"
chmod +x "$MQ_OBSIDIAN_DIR/.venv/bin/python3"

# shellcheck source=../terminal/menus/mq-obsidian-menu.sh
source "$MENU"

echo "[1/2] repo-local virtualenv wins"
test "$(mq_obsidian_python)" = "$MQ_OBSIDIAN_DIR/.venv/bin/python3"

echo "[2/2] PATH python remains the fallback"
rm "$MQ_OBSIDIAN_DIR/.venv/bin/python3"
test "$(mq_obsidian_python)" = "$(command -v python3)"

echo "OK: mqobsidian Python resolution passed"
