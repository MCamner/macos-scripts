#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}"
WRITE=0
TARGETS=()

usage() {
  cat <<'EOF'
document-functions.sh — add short comments above undocumented shell functions

Usage:
  tools/scripts/document-functions.sh [--write] [path ...]

Examples:
  tools/scripts/document-functions.sh tools/scripts/scan.sh
  tools/scripts/document-functions.sh --write tools/scripts/scan.sh
  tools/scripts/document-functions.sh --write tools/scripts terminal

Default mode is dry-run. Use --write to update files.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write)
      WRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
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

is_shell_file() {
  local file="$1"

  [[ -f "$file" ]] || return 1
  case "$file" in
    *.sh|*.bash|*.zsh) return 0 ;;
  esac

  head -n 1 "$file" 2>/dev/null | grep -Eq '^#!.*\b(bash|zsh|sh)\b'
}

collect_files() {
  local target="$1"

  if [[ -d "$target" ]]; then
    find "$target" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.zsh' \) | sort
  elif [[ -f "$target" ]]; then
    printf '%s\n' "$target"
  else
    printf 'Skipping missing path: %s\n' "$target" >&2
  fi
}

document_file() {
  local file="$1"
  local tmp changed
  tmp="$(mktemp "${TMPDIR:-/tmp}/mq-doc-functions.XXXXXX")"

  awk '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function generated_comment(name) {
      return "# Function: Implements the `" name "` shell routine."
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
        if (prev ~ /^# Function:/) {
          pending = expected
          emit_pending()
          if (prev != expected) {
            added++
          }
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

  if [[ "$WRITE" -eq 1 ]]; then
    cp "$tmp" "$file"
    printf 'Updated %s (%s comments)\n' "$file" "$changed"
  else
    printf 'Would update %s (%s comments)\n' "$file" "$changed"
  fi

  rm -f "$tmp"
}

cd "$ROOT_DIR"

for target in "${TARGETS[@]}"; do
  while IFS= read -r file; do
    is_shell_file "$file" || continue
    document_file "$file"
  done < <(collect_files "$target")
done
