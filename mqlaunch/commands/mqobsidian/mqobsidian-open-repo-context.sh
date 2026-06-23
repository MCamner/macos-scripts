#!/usr/bin/env bash
# Open the mqobsidian context surface for a known MQ repo. Read-only.
#   mqobsidian-open-repo-context.sh <repo-key>
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/mqobsidian" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/manifest.sh"
source "$LIB/open.sh"

# repo-key -> manifest view-key. Single place for the mapping; no duplicated
# repo-path logic, and the actual paths still live only in views.json.
repo_context_view() {
  case "$1" in
    mq-agent)   printf 'mq-agent-hot\n' ;;
    mq-mcp)     printf 'mq-mcp-hot\n' ;;
    mq-hal)     printf 'mq-hal-hot\n' ;;
    mqobsidian) printf 'dashboard\n' ;;
    *) return 1 ;;
  esac
}

if [[ $# -ne 1 ]]; then
  mqobsidian_error "usage: mqobsidian-open-repo-context.sh <repo-key>"
  mqobsidian_info "supported: mq-agent mq-mcp mq-hal mqobsidian"
  exit 2
fi

if ! view="$(repo_context_view "$1")"; then
  mqobsidian_error "Unknown repo-key: $1"
  mqobsidian_info "supported: mq-agent mq-mcp mq-hal mqobsidian"
  exit 1
fi

open_mqobsidian_target "$view"
