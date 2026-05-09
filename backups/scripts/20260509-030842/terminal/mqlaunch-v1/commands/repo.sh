#!/usr/bin/env bash

command_open_repo() {
  open_path "$PROJECT_ROOT"
}

command_open_terminal_dir() {
  open_path "$PROJECT_ROOT/terminal"
}

command_open_tools_dir() {
  open_path "$PROJECT_ROOT/tools"
}

command_open_ai_prompts_dir() {
  if [[ -d "$PROJECT_ROOT/ai-prompts" ]]; then
    open_path "$PROJECT_ROOT/ai-prompts"
  else
    err "Directory not found: $PROJECT_ROOT/ai-prompts"
    return 1
  fi
}

command_open_terminal_guide() {
  local html="$PROJECT_ROOT/tools/mac-terminal-guide/mac-terminal-guide.html"
  local readme="$PROJECT_ROOT/tools/mac-terminal-guide/README.md"

  if [[ -f "$html" ]]; then
    open "$html"
  elif [[ -f "$readme" ]]; then
    open "$readme"
  else
    err "No terminal guide found."
    return 1
  fi
}
