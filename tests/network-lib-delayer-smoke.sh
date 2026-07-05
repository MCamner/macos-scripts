#!/usr/bin/env bash
# Smoke (P1 Step 11a): the network concern is owned by mqlaunch/lib/network.sh,
# not by the launcher monolith. Guards the de-layering direction — a future edit
# that pulls a network_* definition back into mqlaunch.sh (or drops the lib
# source) fails here instead of silently re-monolithising.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/network.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"

fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

FUNCS=(
  network_default_interface network_service_name network_interface_ip
  network_dns_server network_gateway network_ssid network_ping_ms
  network_value network_report copy_network_info open_network_settings
  ping_test show_dns_gateway run_network_pulse run_network_ghost
  run_network_quality show_network_info
)

[[ -f "$LIB" ]] || fail "network lib missing: mqlaunch/lib/network.sh"

# Syntax: the lib is zsh (uses print -r --); check with zsh when available.
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$LIB" || fail "network lib fails zsh -n"
fi

# Every network function is defined in the lib.
for f in "${FUNCS[@]}"; do
  grep -qE "^${f}\(\) \{" "$LIB" || fail "lib does not define $f"
done

# The launcher must source the lib.
grep -qE 'source "\$BASE_DIR/mqlaunch/lib/network\.sh"' "$LAUNCHER" \
  || fail "launcher no longer sources mqlaunch/lib/network.sh"

# The launcher must NOT redefine any network function (single owner).
for f in "${FUNCS[@]}"; do
  if grep -qE "^${f}\(\) \{" "$LAUNCHER"; then
    fail "launcher redefines $f — concern must stay in the lib"
  fi
done

printf '[PASS] network de-layering: lib owns all %d network functions; launcher sources, none redefined\n' "${#FUNCS[@]}"
