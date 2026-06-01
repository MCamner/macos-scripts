#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
WRITE=0
CHECK=0
SHOW_DIFF=0
SUMMARY=0
BACKUP=0
STYLE="simple"
BACKUP_ROOT="$ROOT_DIR/backups/scripts"
BACKUP_TIMESTAMP=""
TARGETS=()
EXCLUDES=()
SCANNED_FILES=0
CHANGED_FILES=0
CHANGED_COMMENTS=0

# Prints usage information.
usage() {
  cat <<'EOF'
document-functions.sh — add short comments above undocumented shell functions

Usage:
  tools/scripts/document-functions.sh [options] [path ...]

Options:
  --write                  Update files in place
  --check                  Exit 1 if any file would change
  --diff                   Show a unified diff for planned changes
  --summary                Print scan totals at the end
  --backup                 Save backups under backups/scripts before --write updates
  --exclude PATTERN        Skip paths matching a shell glob pattern
  --style simple|function|name
                           Comment style to generate (default: simple)
  -h, --help               Show this help

Examples:
  tools/scripts/document-functions.sh tools/scripts/scan.sh
  tools/scripts/document-functions.sh --diff tools/scripts/scan.sh
  tools/scripts/document-functions.sh --check tools/scripts terminal
  tools/scripts/document-functions.sh --write tools/scripts/scan.sh
  tools/scripts/document-functions.sh --write --backup tools/scripts terminal
  tools/scripts/document-functions.sh --exclude '*/legacy/*' tools

Default mode is dry-run. Use --write to update files.
Existing comments are preserved; the tool only adds comments where a function
does not already have one.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write)
      WRITE=1
      shift
      ;;
    --check)
      CHECK=1
      shift
      ;;
    --diff)
      SHOW_DIFF=1
      shift
      ;;
    --summary)
      SUMMARY=1
      shift
      ;;
    --backup)
      BACKUP=1
      shift
      ;;
    --exclude)
      if [[ $# -lt 2 ]]; then
        printf 'Missing pattern for --exclude\n' >&2
        exit 2
      fi
      EXCLUDES+=("$2")
      shift 2
      ;;
    --style)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for --style\n' >&2
        exit 2
      fi
      case "$2" in
        simple|function|name)
          STYLE="$2"
          ;;
        *)
          printf 'Unsupported --style value: %s\n' "$2" >&2
          exit 2
          ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("tools/scripts")
fi

# Checks whether shell file applies.
is_shell_file() {
  local file="$1"

  [[ -f "$file" ]] || return 1
  case "$file" in
    *.sh|*.bash|*.zsh) return 0 ;;
  esac

  head -n 1 "$file" 2>/dev/null | grep -Eq '^#!.*\b(bash|zsh|sh)\b'
}

# Collects files.
collect_files() {
  local target="$1"

  if [[ -d "$target" ]]; then
    find "$target" -type f | sort
  elif [[ -f "$target" ]]; then
    printf '%s\n' "$target"
  else
    printf 'Skipping missing path: %s\n' "$target" >&2
  fi
}

# Handles should exclude.
should_exclude() {
  local file="$1"
  local pattern

  [[ ${#EXCLUDES[@]} -eq 0 ]] && return 1

  for pattern in "${EXCLUDES[@]}"; do
    # Intentional glob match: --exclude accepts shell patterns.
    # shellcheck disable=SC2254
    case "$file" in
      $pattern) return 0 ;;
    esac
  done

  return 1
}

# Backs up file.
backup_file() {
  local file="$1"
  local relative backup_path backup_dir

  if [[ -z "$BACKUP_TIMESTAMP" ]]; then
    BACKUP_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
  fi

  if [[ "$file" == "$ROOT_DIR/"* ]]; then
    relative="${file#"$ROOT_DIR"/}"
  else
    relative="$file"
  fi
  relative="${relative#./}"
  relative="${relative#/}"
  backup_path="$BACKUP_ROOT/$BACKUP_TIMESTAMP/$relative"
  backup_dir="$(dirname "$backup_path")"

  mkdir -p "$backup_dir"
  cp "$file" "$backup_path"
  printf 'Backup saved %s\n' "$backup_path"
}

# Documents file.
document_file() {
  local file="$1"
  local tmp changed
  tmp="$(mktemp "${TMPDIR:-/tmp}/mq-doc-functions.XXXXXX")"

  awk -v style="$STYLE" '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function words(name, result) {
      result = name
      gsub(/^_+/, "", result)
      gsub(/_+/, " ", result)
      return result
    }

    function strip_prefix(name, prefix, result) {
      result = name
      sub("^" prefix "_", "", result)
      return words(result)
    }

    function simple_comment(name) {
      if (name == "main") {
        return "# Runs the main entry point."
      }
      if (name == "usage") {
        return "# Prints usage information."
      }
      if (name == "pass") {
        return "# Marks a passing check."
      }
      if (name == "fail") {
        return "# Marks a failing check."
      }
      if (name == "step") {
        return "# Prints a smoke-test step."
      }
      if (name == "row") {
        return "# Prints a plain menu row."
      }
      if (name == "row_bold") {
        return "# Prints a bold menu row."
      }
      if (name == "empty_row") {
        return "# Prints a blank menu row."
      }
      if (name == "pause_enter") {
        return "# Pauses until Enter is pressed."
      }
      if (name == "mq_hal_available") {
        return "# Checks whether mq-hal is available."
      }
      if (name == "mq_hal_usage") {
        return "# Prints mq-hal bridge usage."
      }
      if (name == "mq_hal_missing") {
        return "# Shows the missing mq-hal executable error."
      }
      if (name == "mq_hal_main") {
        return "# Runs the mq-hal bridge command."
      }
      if (name == "menu_loop") {
        return "# Runs the menu loop."
      }
      if (name ~ /_menu_loop$/) {
        return "# Runs the " words(substr(name, 1, length(name) - 10)) " menu loop."
      }
      if (name == "_hal_pause_enter") {
        return "# Pauses safely after HAL menu actions."
      }
      if (name == "render_hal_panel") {
        return "# Renders the HAL menu panel."
      }
      if (name == "hal_menu_missing") {
        return "# Shows the missing mq-hal message."
      }
      if (name == "hal_menu_remember") {
        return "# Prompts HAL to remember a note."
      }
      if (name == "hal_menu_raw_intent") {
        return "# Shows HAL raw intent output."
      }
      if (name == "hal_menu_free_prompt") {
        return "# Runs a free-form HAL prompt."
      }
      if (name == "mq_hal_menu_main") {
        return "# Runs the HAL menu loop."
      }
      if (name ~ /^is_/) {
        return "# Checks whether " strip_prefix(name, "is") " applies."
      }
      if (name ~ /_is_/) {
        return "# Checks whether " words(substr(name, 1, index(name, "_is_") - 1)) " is " words(substr(name, index(name, "_is_") + 4)) "."
      }
      if (name ~ /^has_/) {
        return "# Checks whether " strip_prefix(name, "has") " is available."
      }
      if (name ~ /^ensure_/) {
        return "# Ensures " strip_prefix(name, "ensure") " is ready."
      }
      if (name ~ /^collect_/) {
        return "# Collects " strip_prefix(name, "collect") "."
      }
      if (name ~ /^document_/) {
        return "# Documents " strip_prefix(name, "document") "."
      }
      if (name ~ /^open_/) {
        return "# Opens " strip_prefix(name, "open") "."
      }
      if (name ~ /^run_/) {
        return "# Runs " strip_prefix(name, "run") "."
      }
      if (name ~ /^show_/) {
        return "# Shows " strip_prefix(name, "show") "."
      }
      if (name ~ /^print_/) {
        return "# Prints " strip_prefix(name, "print") "."
      }
      if (name ~ /^get_/) {
        return "# Gets " strip_prefix(name, "get") "."
      }
      if (name ~ /^set_/) {
        return "# Sets " strip_prefix(name, "set") "."
      }
      if (name ~ /^draw_/) {
        return "# Draws " strip_prefix(name, "draw") "."
      }
      if (name ~ /^copy_/) {
        return "# Copies " strip_prefix(name, "copy") "."
      }
      if (name ~ /^normalize_/) {
        return "# Normalizes " strip_prefix(name, "normalize") "."
      }
      if (name ~ /^choose_/) {
        return "# Chooses " strip_prefix(name, "choose") "."
      }
      if (name ~ /^analyze_/) {
        return "# Analyzes " strip_prefix(name, "analyze") "."
      }
      if (name ~ /^suggest_/) {
        return "# Suggests " strip_prefix(name, "suggest") "."
      }
      if (name ~ /^stage_/) {
        return "# Stages " strip_prefix(name, "stage") "."
      }
      if (name ~ /^commit_/) {
        return "# Commits " strip_prefix(name, "commit") "."
      }
      if (name ~ /^pull_/) {
        return "# Pulls " strip_prefix(name, "pull") "."
      }
      if (name ~ /^edit_/) {
        return "# Edits " strip_prefix(name, "edit") "."
      }
      if (name ~ /^backup_/) {
        return "# Backs up " strip_prefix(name, "backup") "."
      }
      if (name ~ /^revert_/) {
        return "# Reverts " strip_prefix(name, "revert") "."
      }
      if (name ~ /^resolve_/) {
        return "# Resolves " strip_prefix(name, "resolve") "."
      }
      if (name ~ /^lock_/) {
        return "# Locks " strip_prefix(name, "lock") "."
      }
      if (name ~ /^sleep_/) {
        return "# Sleeps " strip_prefix(name, "sleep") "."
      }
      if (name ~ /^restart_/) {
        return "# Restarts " strip_prefix(name, "restart") "."
      }
      if (name ~ /^ping_/) {
        return "# Pings " strip_prefix(name, "ping") "."
      }

      return "# Handles " words(name) "."
    }

    function generated_comment(name) {
      if (style == "function") {
        return "# Function: " name
      }
      if (style == "name") {
        return "# " name
      }
      return simple_comment(name)
    }

    function function_name(line, candidate) {
      candidate = line
      if (candidate ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/) {
        sub(/^[[:space:]]*/, "", candidate)
        sub(/[[:space:]]*\(\)[[:space:]]*\{.*/, "", candidate)
        return candidate
      }
      if (candidate ~ /^[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*(\(\))?[[:space:]]*\{/) {
        sub(/^[[:space:]]*function[[:space:]]+/, "", candidate)
        sub(/[[:space:]]*(\(\))?[[:space:]]*\{.*/, "", candidate)
        return candidate
      }
      return ""
    }

# Handles emit pending.
    function emit_pending() {
      if (has_pending) {
        print pending
        pending = ""
        has_pending = 0
      }
    }

    {
      name = function_name($0)
      if (name != "") {
        prev = trim(pending)
        expected = generated_comment(name)
        if (prev ~ /^#/) {
          emit_pending()
        } else if (!has_pending) {
          print expected
          added++
        } else if (prev !~ /^#/ && prev !~ /^$/) {
          emit_pending()
          print expected
          added++
        } else if (prev == "") {
          emit_pending()
          print expected
          added++
        } else {
          emit_pending()
        }
        print
        next
      }

      emit_pending()
      pending = $0
      has_pending = 1
    }

    END {
      emit_pending()
      if (added > 0) {
        printf "%d\n", added > "/dev/stderr"
      }
    }
  ' "$file" > "$tmp" 2>"$tmp.count"

  changed="$(cat "$tmp.count" 2>/dev/null || true)"
  rm -f "$tmp.count"

  if [[ -z "$changed" ]]; then
    rm -f "$tmp"
    return 0
  fi

  CHANGED_FILES=$((CHANGED_FILES + 1))
  CHANGED_COMMENTS=$((CHANGED_COMMENTS + changed))

  if [[ "$SHOW_DIFF" -eq 1 ]]; then
    diff -u "$file" "$tmp" || true
  fi

  if [[ "$WRITE" -eq 1 ]]; then
    if [[ "$BACKUP" -eq 1 ]]; then
      backup_file "$file"
    fi
    cp "$tmp" "$file"
    printf 'Updated %s (%s comments)\n' "$file" "$changed"
  else
    printf 'Would update %s (%s comments)\n' "$file" "$changed"
  fi

  rm -f "$tmp"
}

cd "$ROOT_DIR"

SELF="$(realpath "$0" 2>/dev/null || printf '%s' "$0")"

for target in "${TARGETS[@]}"; do
  while IFS= read -r file; do
    should_exclude "$file" && continue
    is_shell_file "$file" || continue
    [[ "$file" -ef "$SELF" ]] && continue
    SCANNED_FILES=$((SCANNED_FILES + 1))
    document_file "$file"
  done < <(collect_files "$target")
done

if [[ "$SUMMARY" -eq 1 ]]; then
  printf 'Scanned %s files\n' "$SCANNED_FILES"
  printf '%s files need updates\n' "$CHANGED_FILES"
  printf '%s function comments missing or outdated\n' "$CHANGED_COMMENTS"
fi

if [[ "$CHECK" -eq 1 && "$CHANGED_FILES" -gt 0 ]]; then
  exit 1
fi
