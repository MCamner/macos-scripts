#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PYTHONPATH="$REPO_ROOT" python3 -m mqlaunch.b2_tui.main "$@"
