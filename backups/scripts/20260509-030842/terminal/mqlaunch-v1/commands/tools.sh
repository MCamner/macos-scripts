#!/usr/bin/env bash

command_tools_open_tools_root() {
  open_path "$PROJECT_ROOT/tools"
}

command_tools_open_scripts_dir() {
  local dir="$PROJECT_ROOT/tools/scripts"
  if [[ -d "$dir" ]]; then
    open_path "$dir"
  else
    err "Directory not found: $dir"
    pause_enter
    return 1
  fi
}

command_tools_open_cli_dir() {
  local dir="$PROJECT_ROOT/tools/cli"
  if [[ -d "$dir" ]]; then
    open_path "$dir"
  else
    err "Directory not found: $dir"
    pause_enter
    return 1
  fi
}

command_tools_open_guide_dir() {
  local dir="$PROJECT_ROOT/tools/mac-terminal-guide"
  if [[ -d "$dir" ]]; then
    open_path "$dir"
  else
    err "Directory not found: $dir"
    pause_enter
    return 1
  fi
}

command_tools_open_guide_file() {
  local html="$PROJECT_ROOT/tools/mac-terminal-guide/mac-terminal-guide.html"
  local readme="$PROJECT_ROOT/tools/mac-terminal-guide/README.md"

  if [[ -f "$html" ]]; then
    open "$html"
  elif [[ -f "$readme" ]]; then
    open "$readme"
  else
    err "No terminal guide file found."
    pause_enter
    return 1
  fi
}

command_tools_list_tree() {
  print_header
  print_section "Tools Tree"

  if [[ -d "$PROJECT_ROOT/tools" ]]; then
    find "$PROJECT_ROOT/tools" -maxdepth 2 \( -type d -o -type f \) | sed "s|$PROJECT_ROOT/||" | sort
  else
    err "Tools directory not found: $PROJECT_ROOT/tools"
  fi

  pause_enter
}

command_tools_repo_summary() {
  print_header
  print_section "Tools Summary"

  local tools_dir="$PROJECT_ROOT/tools"
  local dir_count="0"
  local file_count="0"

  if [[ ! -d "$tools_dir" ]]; then
    err "Tools directory not found: $tools_dir"
    pause_enter
    return 1
  fi

  dir_count="$(find "$tools_dir" -type d | wc -l | awk '{print $1}')"
  file_count="$(find "$tools_dir" -type f | wc -l | awk '{print $1}')"

  print_kv "Tools root:" "$tools_dir"
  print_kv "Directories:" "$dir_count"
  print_kv "Files:" "$file_count"

  echo
  print_section "Top-level entries"
  find "$tools_dir" -maxdepth 1 -mindepth 1 | sed "s|$PROJECT_ROOT/||" | sort

  pause_enter
}

command_tools_find_readmes() {
  print_header
  print_section "README Files Under tools/"

  if [[ -d "$PROJECT_ROOT/tools" ]]; then
    find "$PROJECT_ROOT/tools" -iname "README.md" | sed "s|$PROJECT_ROOT/||" | sort
  else
    err "Tools directory not found: $PROJECT_ROOT/tools"
  fi

  pause_enter
}
