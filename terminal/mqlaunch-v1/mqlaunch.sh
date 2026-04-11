#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/router.sh"

# Commands
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/system.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/repo.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/dev.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/performance.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/tools.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/meta.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/check.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/bundle.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/notes.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/about.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/index.sh"

# Menus
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/main.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/system.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/tools.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/automation.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/dev.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/ai.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/menus/performance.sh"

main() {
  local cmd="${1:-menu}"
  route_command "$cmd"
}

main "${1:-}"
