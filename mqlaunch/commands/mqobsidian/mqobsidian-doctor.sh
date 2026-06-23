#!/usr/bin/env bash
# Health check for the mqobsidian consumer. Read-only — opens nothing.
# Non-zero exit on any problem.
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/mqobsidian" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/manifest.sh"
source "$LIB/doctor.sh"

run_mqobsidian_doctor
