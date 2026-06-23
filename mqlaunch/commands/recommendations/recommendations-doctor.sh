#!/usr/bin/env bash
# Health check for the recommendations consumer. Read-only — opens nothing.
# Non-zero exit on any hard problem.
#   recommendations-doctor.sh
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib/recommendations" && pwd)"
source "$LIB/errors.sh"
source "$LIB/resolve.sh"
source "$LIB/parse.sh"
source "$LIB/doctor.sh"

run_recommendations_doctor
