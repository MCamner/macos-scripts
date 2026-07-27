#!/usr/bin/env bash
set -euo pipefail

# Measures what a stricter ShellCheck gate would cost. Changes nothing.
#
# ShellCheck runs in two places today, over two different file surfaces, with
# two different consequences:
#
#   tools/scripts/lint.sh        `shellcheck -S error`, no `|| true`. Called by
#                                test-all.sh, which CI runs — so error severity
#                                is already a hard gate, not warn-only.
#   .github/workflows/quality.yml  `shellcheck --severity=error "$f" || true`
#                                over a wider surface that includes
#                                tools/legacy/ and terminal/mqlaunch-v1/.
#                                Never fails.
#
# This report prints both surfaces and what each severity would cost on them, so
# the decision to harden is made from counts rather than from impression. It is
# not wired into test-all.sh: a measurement that gates is no longer a
# measurement, and running it on every suite would slow the loop for a number
# nobody is reading that minute.
#
# Usage: tools/scripts/shellcheck-report.sh [--full]
#   --full  list every finding after the summary

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

full=0
case "${1:-}" in
  --full) full=1 ;;
  "") ;;
  *) echo "usage: ${0##*/} [--full]" >&2; exit 2 ;;
esac

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "[SKIP] shellcheck not installed — nothing to measure"
  exit 0
fi

echo "SHELLCHECK REPORT"
echo "  $(shellcheck --version | awk '/^version:/ {print "shellcheck " $2}')"
echo

# --- file surfaces ----------------------------------------------------------
#
# ShellCheck cannot parse zsh, so zsh-shebang scripts are excluded from both
# surfaces. That is not a gap this report can close: those files are covered by
# `zsh -n` in the syntax step, and mqlaunch.sh — the launcher — is one of them.
collect() {
  # collect <find-args...>; prints bash/sh scripts, one per line
  local file shebang
  while IFS= read -r file; do
    shebang="$(head -n 1 "$file" 2>/dev/null || true)"
    case "$shebang" in
      *zsh*) ;;
      *bash*|*'/sh') printf '%s\n' "$file" ;;
    esac
  done < <(find "$@" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/backups/*' | sort)
}

lint_surface=()
while IFS= read -r file; do lint_surface+=("$file"); done < <(
  collect "$ROOT" -not -path "$ROOT/tools/legacy/*" -not -path "$ROOT/terminal/mqlaunch-v1/*"
)

ci_surface=()
while IFS= read -r file; do ci_surface+=("$file"); done < <(collect "$ROOT")

zsh_count="$(find "$ROOT" -type f -name '*.sh' -not -path '*/.git/*' -not -path '*/backups/*' \
  -exec head -n 1 {} \; 2>/dev/null | grep -c zsh || true)"

printf 'FILE SURFACE\n'
printf '  %-42s %s\n' "gated by lint.sh (-S error, hard)" "${#lint_surface[@]}"
printf '  %-42s %s\n' "scanned by CI warn-only step" "${#ci_surface[@]}"
printf '  %-42s %s\n' "zsh, unparseable by shellcheck" "$zsh_count"
printf '  %-42s %s\n' "in CI's surface but not the gate's" \
  "$(( ${#ci_surface[@]} - ${#lint_surface[@]} ))"
echo

# The report is only meaningful while it measures the files the gate covers. If
# lint.sh changes its exclusions, this is how we find out — rather than by
# reading a number that has quietly stopped describing the same thing.
lint_reported="$(MACOS_SCRIPTS_HOME="$ROOT" bash "$ROOT/tools/scripts/lint.sh" 2>/dev/null \
  | sed -n 's/.*Shell lint passed (\([0-9]*\) files).*/\1/p')"
if [[ -n "$lint_reported" && "$lint_reported" != "${#lint_surface[@]}" ]]; then
  echo "FAIL: this report scans ${#lint_surface[@]} files, lint.sh gates $lint_reported." >&2
  echo "      The surfaces have diverged — fix the exclusions before trusting counts." >&2
  exit 1
fi

# --- counts by severity -----------------------------------------------------
#
# Severities nest: -S info includes warnings and errors. The per-level cost of a
# gate is the difference, so both are shown.
run_dir="$(mktemp -d)"
trap 'rm -rf "$run_dir"' EXIT

for severity in error warning info style; do
  shellcheck -f gcc -S "$severity" "${lint_surface[@]}" 2>/dev/null \
    > "$run_dir/$severity.txt" || true
done

printf 'FINDINGS ON THE GATED SURFACE\n'
printf '  %-10s %8s %10s\n' "severity" "at least" "only this"
prev=0
for severity in error warning info style; do
  total="$(wc -l < "$run_dir/$severity.txt" | tr -d ' ')"
  printf '  %-10s %8s %10s\n' "$severity" "$total" "$(( total - prev ))"
  prev="$total"
done
echo

# --- rules ------------------------------------------------------------------
#
# The message comes from shellcheck's own output rather than a table here, so
# the wording cannot go stale against the installed version.
printf 'RULES AT WARNING AND ABOVE\n'
awk -F'[][]' '/\[SC[0-9]+\]/ {
    rule = $2
    msg = $0
    sub(/^[^ ]*: /, "", msg)
    sub(/ \[SC[0-9]+\]$/, "", msg)
    if (!(rule in seen)) { seen[rule] = msg }
    count[rule]++
  }
  END { for (r in count) printf "%6d  %-8s %s\n", count[r], r, seen[r] }' \
  "$run_dir/warning.txt" | sort -rn
echo

printf 'FILES WITH THE MOST FINDINGS (warning and above)\n'
if [[ -s "$run_dir/warning.txt" ]]; then
  cut -d: -f1 "$run_dir/warning.txt" | sort | uniq -c | sort -rn | head -n 10 \
    | while read -r count file; do
        printf '%6d  %s\n' "$count" "${file#"$ROOT"/}"
      done
else
  echo "  none"
fi
echo

# --- what a gate would cost -------------------------------------------------
printf 'COST OF HARDENING\n'
for severity in error warning info style; do
  total="$(wc -l < "$run_dir/$severity.txt" | tr -d ' ')"
  if (( total == 0 )); then
    printf '  -S %-8s already clean — a gate here costs nothing today\n' "$severity"
  else
    printf '  -S %-8s %s finding(s) across %s file(s) must be fixed or waived first\n' \
      "$severity" "$total" "$(cut -d: -f1 "$run_dir/$severity.txt" | sort -u | wc -l | tr -d ' ')"
  fi
done
echo

if (( full )); then
  printf 'ALL FINDINGS AT WARNING AND ABOVE\n'
  sed "s|$ROOT/||" "$run_dir/warning.txt"
  echo
fi

echo "Report only. Nothing was changed and nothing failed."
