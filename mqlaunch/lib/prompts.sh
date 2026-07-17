#!/usr/bin/env zsh

# Resolves prompt dir.
resolve_prompt_dir() {
  local candidate
  for candidate in "$BASE_DIR/ai-prompts" "$PROMPT_DIR"; do
    if [[ -d "$candidate" ]]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

# Resolves ai status.
resolve_ai_status() {
  if [[ -x "$AI_SCRIPT" ]]; then
    print -r -- "OK"
  elif [[ -e "$AI_SCRIPT" ]]; then
    print -r -- "FOUND_NOT_EXECUTABLE"
  else
    print -r -- "MISSING"
  fi
}

# Runs ai through guardrails before acting.
safe_run_ai() {
  local mode="$1"

  if [[ -x "$AI_SCRIPT" ]]; then
    "$AI_SCRIPT" "$mode"
  else
    print_header
    row "AI BACKEND STATUS"
    empty_row
    if [[ -e "$AI_SCRIPT" ]]; then
      row "ai-mode.sh found but not executable."
      row "Run:"
      row " chmod +x $AI_SCRIPT"
    else
      row "ai-mode.sh missing."
      row "Expected:"
      row " $AI_SCRIPT"
    fi
    print_footer
    pause_enter
  fi
}

# fzf: bläddra och kopiera sparade AI-prompts från mqobsidian/_prompts/
prompts_pick() {
  local vault_dir="${MQ_OBSIDIAN_DIR:-$HOME/mqobsidian}"
  local prompts_dir="$vault_dir/_prompts/saved-prompts-md-export"
  local fzf_bin
  fzf_bin="$(command -v fzf 2>/dev/null || true)"

  if [[ ! -d "$prompts_dir" ]]; then
    printf "Prompts directory not found: %s\n" "$prompts_dir" >&2
    return 1
  fi

  if [[ -z "$fzf_bin" ]]; then
    printf "fzf is not installed. Install: brew install fzf\n" >&2
    return 1
  fi

  local selected
  selected="$(
    find "$prompts_dir" -name "*.md" -not -name "INDEX.md" -not -name "README.md" -not -name "EXPORT_NOTES.md" -not -name "PROMPT_EXPORT_INDEX.md" | sort | while IFS= read -r f; do
      label="$(basename "$(dirname "$f")" | sed 's/^[0-9]*_//')/$(basename "$f" .md | sed 's/_/ /g')"
      printf "%s\t%s\n" "$label" "$f"
    done \
    | "$fzf_bin" \
        --delimiter='\t' \
        --with-nth=1 \
        --preview='head -40 {2}' \
        --preview-window='right:55%:wrap' \
        --reverse \
        --border \
        --header='Select prompt → copy to clipboard  (ESC = cancel)' \
        --prompt='prompt > ' \
        --height=80% \
    | cut -f2
  )"

  [[ -z "$selected" ]] && return 0

  if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$selected"
    printf "Copied to clipboard: %s\n" "$(basename "$selected" .txt | sed 's/_/ /g')"
  else
    printf "pbcopy not available — printing prompt:\n\n"
    cat "$selected"
  fi
}

# Opens ai prompts folder.
open_ai_prompts_folder() {
  local target=""
  target="$(resolve_prompt_dir 2>/dev/null || true)"

  print_header
  row "OPEN AI PROMPTS FOLDER"
  empty_row

  if [[ -n "$target" ]]; then
    row "Opening:"
    row " $target"
    print_footer
    open "$target"
  else
    row "Prompt dir missing."
    row "Checked:"
    row " $HOME/macos-scripts/ai-prompts"
    row " $PROMPT_DIR"
    print_footer
    pause_enter
  fi
}

# Shows prompt files.
show_prompt_files() {
  local resolved_prompt_dir=""
  local -a files
  local f
  local shown=0

  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"

  print_header
  row "PROMPT FILES"
  empty_row

  if [[ -z "$resolved_prompt_dir" ]]; then
    row "Prompt dir missing."
    row "Checked:"
    row " $HOME/macos-scripts/ai-prompts"
    row " $PROMPT_DIR"
  else
    files=("$resolved_prompt_dir"/*(.N))
    if (( ${#files[@]} == 0 )); then
      row "No prompt files found."
      row "Folder:"
      row " $resolved_prompt_dir"
    else
      for f in "${files[@]}"; do
        row " - ${f:t}"
        ((shown++))
        if (( shown >= 20 && ${#files[@]} > 20 )); then
          row " ..."
          break
        fi
      done
      empty_row
      row "Total files: ${#files[@]}"
      row "Folder: $resolved_prompt_dir"
    fi
  fi

  print_footer
  pause_enter
}

# Backs up prompts.
backup_prompts() {
  local resolved_prompt_dir=""
  local stamp backup_file

  resolved_prompt_dir="$(resolve_prompt_dir 2>/dev/null || true)"

  if [[ -z "$resolved_prompt_dir" ]]; then
    echo "${C_ERR}Prompt dir missing.${C_RESET}"
    pause_enter
    return
  fi

  if ! command -v zip >/dev/null 2>&1; then
    echo "${C_ERR}zip is missing on this system.${C_RESET}"
    pause_enter
    return
  fi

  mkdir -p "$BACKUP_DIR"
  stamp="$(date '+%Y%m%d-%H%M%S')"
  backup_file="$BACKUP_DIR/ai-prompts-$stamp.zip"

  (
    cd "$(dirname "$resolved_prompt_dir")" || exit 1
    zip -rq "$backup_file" "$(basename "$resolved_prompt_dir")"
  )

  print_header
  row "PROMPT BACKUP"
  empty_row

  if [[ -f "$backup_file" ]]; then
    row "Backup created successfully."
    row "File:"
    row " $backup_file"
  else
    row "Backup failed."
  fi

  print_footer
  pause_enter
}
