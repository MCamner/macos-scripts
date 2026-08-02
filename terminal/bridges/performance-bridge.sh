#!/usr/bin/env bash
#
# Loads the Performance menu. Named a bridge because it used to be one: it fell
# back to the frozen v1 launcher when the current menu was missing, which is one
# of the edges that kept that tree classified live.
#
# The fallback is gone. A missing menu file is a broken checkout, and answering
# it by running a frozen launcher hides that instead of reporting it — the whole
# point of the fallback was a migration that finished.
#
# `run_performance_command`, `open_v1_performance_menu` and
# `run_v1_performance_command` went with it. None had a caller anywhere in the
# tree.

# Opens performance menu.
open_performance_menu() {
  local perf_menu="$BASE_DIR/terminal/menus/mq-performance-menu.sh"

  if [[ ! -f "$perf_menu" ]]; then
    echo "${C_ERR}Performance menu not found:${C_RESET} $perf_menu" >&2
    return 1
  fi

  # shellcheck source=../menus/mq-performance-menu.sh
  source "$perf_menu"
  open_performance_menu "$@"
}
