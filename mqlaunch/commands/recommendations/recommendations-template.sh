#!/usr/bin/env bash
# Print one pattern's command template (the "show" action). Read-only — renders
# the template for show/copy; never executes it.
#   recommendations-template.sh <pattern_id>
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/recommendations" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/parse.sh"
source "$LIB/actions.sh"
source "$LIB/render.sh"

if [[ $# -ne 1 ]]; then
  rec_error "usage: recommendations-template.sh <pattern_id>"
  exit 2
fi

rec_require_jq || exit 1
path="$(assert_recommended_json)" || exit 1
assert_action_allowed "$path" show || exit 1

if ! rec_pattern_exists "$path" "$1"; then
  rec_error "pattern_id not present in recommended.json: $1"
  rec_info "list valid ids with: recommendations-list.sh"
  exit 2
fi

render_pattern_template "$path" "$1"
