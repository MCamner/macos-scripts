#!/usr/bin/env bash
# Smoke (P1 Step 11a): concerns de-layered out of the mqlaunch monolith stay
# out. For each extracted concern this guards the direction — every function is
# defined in its lib, the launcher sources that lib, and the launcher does not
# redefine any of them. A future edit that pulls a function back into
# mqlaunch.sh (or drops a lib source) fails here instead of silently
# re-monolithising. Add a row to CONCERNS as each new concern is extracted.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"

# Marks a failing check.
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }

# Each concern: "lib_relpath : space-separated function names"
CONCERNS=(
  "mqlaunch/lib/network.sh : network_default_interface network_service_name network_interface_ip network_dns_server network_gateway network_ssid network_ping_ms network_value network_report copy_network_info open_network_settings ping_test show_dns_gateway run_network_pulse run_network_ghost run_network_quality show_network_info"
  "mqlaunch/lib/fzf-pickers.sh : fzf_git_log fzf_git_branch fzf_kill_process fzf_kill_port fzf_run_snippet fzf_recent_files"
  "mqlaunch/lib/diagnostics.sh : get_repo_version show_version_info run_self_check run_debug_bundle show_release_notes system_check"
  "mqlaunch/lib/git-menus.sh : open_git_menu open_release_menu"
  "mqlaunch/lib/repo-picker.sh : run_github_repo_picker"
  "mqlaunch/lib/themes.sh : open_themes_menu theme_cmd theme_current_variant theme_source_state"
  "mqlaunch/lib/prompts.sh : resolve_prompt_dir resolve_ai_status safe_run_ai prompts_pick show_prompt_files backup_prompts open_ai_prompts_folder"
)

total=0
for entry in "${CONCERNS[@]}"; do
  lib_rel="${entry%% : *}"
  funcs="${entry#* : }"
  lib="$ROOT/$lib_rel"

  [[ -f "$lib" ]] || fail "lib missing: $lib_rel"

  # zsh-shebang libs get zsh -n; bash libs get bash -n. Both when tools exist.
  shebang="$(head -1 "$lib")"
  if [[ "$shebang" == *zsh* ]]; then
    command -v zsh >/dev/null 2>&1 && { zsh -n "$lib" || fail "$lib_rel fails zsh -n"; }
  else
    bash -n "$lib" || fail "$lib_rel fails bash -n"
  fi

  # The launcher must source this lib.
  grep -qF "source \"\$BASE_DIR/$lib_rel\"" "$LAUNCHER" \
    || fail "launcher no longer sources $lib_rel"

  for f in $funcs; do
    grep -qE "^${f}\(\) \{" "$lib" || fail "$lib_rel does not define $f"
    if grep -qE "^${f}\(\) \{" "$LAUNCHER"; then
      fail "launcher redefines $f — concern must stay in $lib_rel"
    fi
    total=$((total + 1))
  done
done

printf '[PASS] monolith de-layering: %d functions across %d concern libs; launcher sources each, redefines none\n' \
  "$total" "${#CONCERNS[@]}"
