#!/usr/bin/env bash
# Open the mqobsidian dashboard/index. Read-only.
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/mqobsidian" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/manifest.sh"
source "$LIB/open.sh"

open_mqobsidian_target "dashboard"
