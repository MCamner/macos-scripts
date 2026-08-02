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
# The performance data layer moved to mqlaunch/lib/performance.sh so that
# nothing live had to reach into this tree for working code. This tree reaching
# out is the allowed direction — legacy may depend on live, not the reverse —
# and it keeps v1 runnable while its deletion is decided separately.
# shellcheck source=/dev/null
source "${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}/mqlaunch/lib/performance.sh"
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
source "$SCRIPT_DIR/commands/login.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/commands/shortcuts.sh"

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

# Runs the main entry point.
main() {
  route_command "$@"
}

main "$@"
