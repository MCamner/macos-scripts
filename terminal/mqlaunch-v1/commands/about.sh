#!/usr/bin/env bash

command_show_about_dashboard() {
  print_header
  print_section "About / Status"

  local version_file="$PROJECT_ROOT/VERSION"
  local version="unknown"
  local repo_state="unknown"
  local smoke_status="unknown"
  local latest_bundle="none"
  local guide_html="$PROJECT_ROOT/docs/mac-terminal-guide.html"
  local launcher="$PROJECT_ROOT/terminal/launchers/mqlaunch.sh"
  local main_menu="$PROJECT_ROOT/terminal/menus/mq-main-menu.sh"
  local help_menu="$PROJECT_ROOT/terminal/menus/mq-help-menu.sh"
  local bundle_dir="$PROJECT_ROOT/backups/debug-bundles"
  local test_script="$PROJECT_ROOT/tools/scripts/test-all.sh"

  [[ -f "$version_file" ]] && version="$(head -n 1 "$version_file")"

  if git -C "$PROJECT_ROOT" diff --quiet --ignore-submodules HEAD >/dev/null 2>&1; then
    repo_state="clean"
  else
    repo_state="dirty"
  fi

  if [[ -x "$test_script" ]]; then
    if "$test_script" >/dev/null 2>&1; then
      smoke_status="PASS"
    else
      smoke_status="FAIL"
    fi
  else
    smoke_status="missing"
  fi

  if [[ -d "$bundle_dir" ]]; then
    latest_bundle="$(ls -1t "$bundle_dir" 2>/dev/null | head -n 1)"
    [[ -z "$latest_bundle" ]] && latest_bundle="none"
  fi

  print_kv "Project:" "macos-scripts"
  print_kv "Version:" "$version"
  print_kv "Release stage:" "baseline"
  print_kv "Repo state:" "$repo_state"
  print_kv "Smoke tests:" "$smoke_status"
  print_kv "Guide HTML:" "$guide_html"
  print_kv "Launcher:" "$launcher"
  print_kv "Main menu:" "$main_menu"
  print_kv "Help module:" "$help_menu"
  print_kv "Latest bundle:" "$latest_bundle"
  print_kv "Core menus:" "main / help / dev / ai / net"

  pause_enter
}
