#!/usr/bin/env bash
# Open the mqobsidian vault root. Works even if individual views are missing.
# Read-only.
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/mqobsidian" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/open.sh"

root="$(assert_mqobsidian_dir)"
mqobsidian_info "Opening vault root → $root"
open_mqobsidian_path "$root"
