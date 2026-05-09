#!/usr/bin/env bash

# Handles command open repo.
command_open_repo() {
  open_path "$PROJECT_ROOT"
}

# Handles command open terminal dir.
command_open_terminal_dir() {
  open_path "$PROJECT_ROOT/terminal"
}

# Handles command open tools dir.
command_open_tools_dir() {
  open_path "$PROJECT_ROOT/tools"
}

# Handles command open ai prompts dir.
command_open_ai_prompts_dir() {
  if [[ -d "$PROJECT_ROOT/ai-prompts" ]]; then
    open_path "$PROJECT_ROOT/ai-prompts"
  else
    err "Directory not found: $PROJECT_ROOT/ai-prompts"
    return 1
  fi
}

# Handles command open terminal guide.
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
