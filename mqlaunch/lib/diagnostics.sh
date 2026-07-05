#!/usr/bin/env bash
# mqlaunch diagnostics — version reporting, self-check, debug bundle, and
# release notes.
#
# Extracted from terminal/launchers/mqlaunch.sh as part of Step 11a (monolith
# de-layering, audit P4). Sourced into the launcher's scope, so it relies on the
# launcher's ambient UI helpers (print_header/row/empty_row/print_footer/
# pause_enter) and $BASE_DIR. It defines no state of its own and changes no
# behavior — the functions are verbatim moves. Pure bash (no zsh builtins), so
# it carries a bash shebang and is covered by shellcheck.

# Gets repo version.
get_repo_version() {
  local version_file="$BASE_DIR/VERSION"

  if [[ -f "$version_file" ]]; then
    head -n 1 "$version_file"
  else
    echo "unknown"
  fi
}

# Shows version info.
show_version_info() {
  print_header
  row_bold "VERSION INFO"
  empty_row

  local version
  version="$(get_repo_version)"
  local launcher="$BASE_DIR/terminal/launchers/mqlaunch.sh"
  local main_menu="$BASE_DIR/terminal/menus/mq-main-menu.sh"
  local help_menu="$BASE_DIR/terminal/menus/mq-help-menu.sh"

  row "Project:        macos-scripts"
  row "Version:        $version"
  row "Release stage:  baseline"
  row "Shell:          zsh"
  row "Project root:   $BASE_DIR"
  row "Launcher:       $launcher"
  row "Main menu:      $main_menu"
  row "Help module:    $help_menu"

  print_footer
  pause_enter
}

# Runs self check.
run_self_check() {
  print_header
  row_bold "SELF-CHECK"
  empty_row

  local check_script="$BASE_DIR/tools/scripts/test-all.sh"

  row "Running smoke checks..."
  empty_row

  if [[ ! -x "$check_script" ]]; then
    echo "${C_ERR}Missing or non-executable:${C_RESET} $check_script"
    print_footer
    pause_enter
    return 1
  fi

  "$check_script"
  local rc=$?

  echo
  if [[ $rc -eq 0 ]]; then
    echo "${C_OK}All smoke checks passed.${C_RESET}"
  else
    echo "${C_ERR}Smoke checks failed.${C_RESET}"
  fi

  print_footer
  pause_enter
  return $rc
}

# Runs debug bundle.
run_debug_bundle() {
  print_header
  row_bold "DEBUG BUNDLE"
  empty_row

  local bundle_script="$BASE_DIR/tools/scripts/create-debug-bundle.sh"

  if [[ ! -x "$bundle_script" ]]; then
    echo "${C_ERR}Missing or non-executable:${C_RESET} $bundle_script"
    print_footer
    pause_enter
    return 1
  fi

  local outfile
  outfile="$("$bundle_script")"
  local rc=$?

  echo
  if [[ $rc -eq 0 ]]; then
    echo "${C_OK}Debug bundle created:${C_RESET}"
    echo " $outfile"
    [[ -f "$outfile" ]] && open -R "$outfile" 2>/dev/null || true
  else
    echo "${C_ERR}Debug bundle failed.${C_RESET}"
  fi

  print_footer
  pause_enter
  return $rc
}

# Shows release notes.
show_release_notes() {
  print_header
  row_bold "RELEASE NOTES"
  empty_row

  local changelog="$BASE_DIR/CHANGELOG.md"

  if [[ ! -f "$changelog" ]]; then
    echo "${C_ERR}Missing:${C_RESET} $changelog"
    print_footer
    pause_enter
    return 1
  fi

  if command -v bat >/dev/null 2>&1; then
    bat --style=plain --paging=never "$changelog" | head -n 80
  else
    head -n 80 "$changelog"
  fi

  print_footer
  pause_enter
}
