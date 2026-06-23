#!/usr/bin/env bash
# Open any manifest-defined mqobsidian view by key. Read-only.
#   mqobsidian-open-view.sh <view-key>
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/mqobsidian" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/manifest.sh"
source "$LIB/open.sh"

if [[ $# -ne 1 ]]; then
  mqobsidian_error "usage: mqobsidian-open-view.sh <view-key>"
  mqobsidian_info "available: $(list_supported_views | paste -sd' ' -)"
  exit 2
fi

open_mqobsidian_target "$1"
