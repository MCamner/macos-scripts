#!/usr/bin/env bash
# Copy one pattern's command template to the clipboard (the "copy" action).
# Copies TEXT only — never executes, opens, or routes. You fill the placeholders
# and decide what, if anything, to run.
#   recommendations-copy.sh <pattern_id>
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/recommendations" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/parse.sh"
source "$LIB/actions.sh"
source "$LIB/clipboard.sh"
source "$LIB/render.sh"

if [[ $# -ne 1 ]]; then
  rec_error "usage: recommendations-copy.sh <pattern_id>"
  exit 2
fi

rec_require_jq || exit 1
path="$(assert_recommended_json)" || exit 1
assert_action_allowed "$path" copy || exit 1
assert_clipboard_available || exit 1

if ! rec_pattern_exists "$path" "$1"; then
  rec_error "pattern_id not present in recommended.json: $1"
  rec_info "list valid ids with: recommendations-list.sh"
  exit 2
fi

copy_pattern_template_to_clipboard "$path" "$1" || exit 1
render_copy_success "$path" "$1"
