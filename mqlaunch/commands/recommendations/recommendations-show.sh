#!/usr/bin/env bash
# Show full detail for one recommended pattern. Read-only — renders the command
# template for show/copy; never executes it.
#   recommendations-show.sh <pattern_id>
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/recommendations" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/parse.sh"
source "$LIB/render.sh"

if [[ $# -ne 1 ]]; then
  rec_error "usage: recommendations-show.sh <pattern_id>"
  exit 2
fi

path="$(assert_recommended_json)" || exit 1

if ! rec_pattern_exists "$path" "$1"; then
  rec_error "pattern_id not present in recommended.json: $1"
  rec_info "list valid ids with: recommendations-list.sh"
  exit 2
fi

render_recommendation_detail "$path" "$1"
