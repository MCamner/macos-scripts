#!/usr/bin/env bash
# List recommended command patterns (default-visible, by rank). Read-only.
#   recommendations-list.sh
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/recommendations" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/parse.sh"
source "$LIB/render.sh"

rec_require_jq || exit 1
path="$(assert_recommended_json)" || exit 1

if [[ "$(rec_visible_count "$path")" -eq 0 ]]; then
  render_empty_recommendations_state "$path"
  exit 0
fi

render_recommendations_list "$path"
