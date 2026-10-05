#!/usr/bin/env bash
# Figure colours: the launcher's pick reaches the compact header; "fixed" opts out.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DASHBOARD="$ROOT/ui/ascii/mqlaunch-dashboard-v7.1.sh"
fail() { echo "FAIL: $1" >&2; exit 1; }
render() {
  MQ_FIG_COLORS="$1" MQ_DASHBOARD_FORCE_COLOR=1 MQ_DASHBOARD_LAYOUT=compact \
    MACOS_SCRIPTS_HOME="$ROOT" bash "$DASHBOARD" MQ test ONLINE 2>/dev/null
}
echo "SMOKE: figure colours"
echo "[1/3] pinned colours reach both figures"
out="$(render "201 51")"
grep -q $'\e\\[38;5;201m▄▄████▄▄' <<<"$out" || fail "left figure not in colour 201"
grep -q $'\e\\[38;5;51m▄▄██▄▄' <<<"$out" || fail "right figure not in colour 51"
echo "[2/3] fixed keeps the theme colours"
! grep -q $'\e\\[38;5;201m' <<<"$(render fixed)" || fail "fixed still used a picked colour"
echo "[3/3] the launcher exports the pick"
grep -q '^export MQ_FIG_COLORS$' "$ROOT/terminal/launchers/mqlaunch.sh" || fail "launcher does not export MQ_FIG_COLORS"
echo "PASS: figure colours"
