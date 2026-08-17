#!/usr/bin/env bash
# Forbids assigning to `status` in code zsh runs or sources.
#
# `status` is zsh's own name for `$?`, and it is read-only. Declaring it is
# allowed; assigning to it aborts the enclosing function on the spot — the
# statements after it never run, and the caller gets whatever exit code the
# abort produced rather than the one the function meant to return.
#
#     local status        allowed   — a declaration, not an assignment
#     local status=0      aborts    — read-only variable: status
#     status=$?           aborts
#     typeset status=1    aborts
#     export status=1     aborts
#     some_status=0       allowed   — a different name
#
# `status = 0` is deliberately absent. It is not an assignment in zsh — the
# shell reads it as the command `status` with the arguments `= 0` — so it never
# reaches the read-only trap. Matching it would turn this gate into a typo
# checker for a form that cannot cause the failure it exists to prevent.
#
# Why a static gate rather than the skill note that already documents this:
# `zsh -n` does not catch it. `local status=0` is valid syntax that fails at
# runtime, so CI's syntax check passes and the defect is only found if a test
# happens to execute that line. It has bitten twice — the Git submenu, and
# `run_markdownlint` in terminal/menus/mq-tools-menu.sh, which was live on main
# and is fixed in the same commit as this file.
#
# Scope is what zsh actually reaches: files with a zsh shebang, plus the closure
# of what they source. A bash file that no zsh file loads cannot hit this, and
# failing it would mean renaming 45 harmless variables to land the gate.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "SMOKE: zsh status assignment"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# Prints every assignment to `status` in one file, as `line:text`.
#
# Comments are dropped first: this file and the ones it guards explain the trap
# in prose, and prose about not doing something reads exactly like doing it to a
# grep — the trap tests/pulse-menu-smoke.sh records.
scan_file() { # PATH
  grep -nE '^[[:space:]]*(local|typeset|export|declare)?[[:space:]]*status\+?=' "$1" 2>/dev/null \
    | grep -vE '^[0-9]+:[[:space:]]*#' || true
}

# Prints the files zsh runs or sources, one per line.
#
# The set comes from zsh itself, through SOURCE_TRACE, rather than from a regex
# over `source` lines. The regex version had a false negative on the one file
# that motivated this gate: mqlaunch.sh loads the tools menu as
#
#     MACOS_SCRIPTS_HOME="$BASE_DIR" source ".../mq-tools-menu.sh"
#
# and a pattern anchored to `source` at the start of the line does not see a
# directive that follows a variable assignment. Loosening the anchor instead
# matched prose — a comment ending a sentence with `.` before a filename read as
# a source directive. Both failures are the same mistake: guessing at what a
# shell loads instead of asking it.
#
# Seeds are the files zsh executes, found by shebang. SOURCE_TRACE then reports
# what one real run actually pulls in, which is where the menus and libraries
# come from.
zsh_context_files() {
  local trace="$TMP/trace" home="$TMP/home"
  mkdir -p "$home"

  # `version` is the cheapest verb that still loads the whole surface: the
  # launcher sources its libraries and menus before it dispatches anything.
  HOME="$home" MQ_NO_TUI=1 NO_COLOR=1 MACOS_SCRIPTS_HOME="$ROOT" \
    timeout 120 zsh -o sourcetrace "$ROOT/terminal/launchers/mqlaunch.sh" version \
    >/dev/null 2>"$trace" || true

  {
    find "$ROOT" -type f \( -name '*.sh' -o -name '*.zsh' \) \
      -not -path "$ROOT/backups/*" -not -path "$ROOT/.git/*" \
      -exec sh -c 'head -1 "$1" | grep -q zsh && printf "%s\n" "$1"' _ {} \;

    # SOURCE_TRACE prints `+<path>:<line># <command>`. Paths can carry `..`
    # segments, so they are normalised before the set is deduplicated.
    grep -oE "\\+${ROOT}[^:]*\\.(sh|zsh)" "$trace" 2>/dev/null \
      | sed 's/^+//' \
      | while IFS= read -r raw; do
          [[ -f "$raw" ]] && (cd "$(dirname "$raw")" 2>/dev/null && printf '%s/%s\n' "$PWD" "$(basename "$raw")")
        done
  } | sort -u
}

echo "[1/4] the scanner recognises every form that aborts, and no other"
fixtures="$TMP/fixtures"
mkdir -p "$fixtures"
printf '#!/usr/bin/env zsh\nf() {\n  local status\n}\n'      > "$fixtures/ok-declare.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  some_status=0\n}\n'      > "$fixtures/ok-other-name.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  status = 0\n}\n'         > "$fixtures/ok-not-assignment.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  local status=0\n}\n'     > "$fixtures/bad-local.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  status=$?\n}\n'          > "$fixtures/bad-bare.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  typeset status=1\n}\n'   > "$fixtures/bad-typeset.zsh"
printf '#!/usr/bin/env zsh\nf() {\n  export status=1\n}\n'    > "$fixtures/bad-export.zsh"

for f in "$fixtures"/ok-*.zsh; do
  [[ -z "$(scan_file "$f")" ]] || fail "the scanner flagged an allowed form: ${f##*/}"
done
for f in "$fixtures"/bad-*.zsh; do
  [[ -n "$(scan_file "$f")" ]] || fail "the scanner missed a form that aborts: ${f##*/}"
done
echo "  ok: 3 allowed forms pass, 4 aborting forms are caught"

echo "[2/4] the allowed and forbidden fixtures behave as claimed under zsh"
# The matrix above is an assertion about zsh, so it is measured rather than
# trusted. A gate built on a wrong belief about the shell is worse than none.
if command -v zsh >/dev/null 2>&1; then
  probe() { # SNIPPET -> prints "abort" or "ok"
    printf '#!/usr/bin/env zsh\nf() {\n  %s\n  print REACHED\n}\nf\n' "$1" > "$TMP/probe.zsh"
    if zsh "$TMP/probe.zsh" 2>&1 | grep -q REACHED; then printf 'ok'; else printf 'abort'; fi
  }
  [[ "$(probe 'local status')"   == "ok" ]]    || fail "'local status' aborted — the matrix is wrong"
  [[ "$(probe 'some_status=0')"  == "ok" ]]    || fail "'some_status=0' aborted — the matrix is wrong"
  [[ "$(probe 'status = 0')"     == "ok" ]]    || fail "'status = 0' aborted — it should be excluded, not allowed"
  [[ "$(probe 'local status=0')" == "abort" ]] || fail "'local status=0' did not abort"
  [[ "$(probe 'status=$?')"      == "abort" ]] || fail "'status=\$?' did not abort"
  [[ "$(probe 'typeset status=1')" == "abort" ]] || fail "'typeset status=1' did not abort"
  [[ "$(probe 'export status=1')"  == "abort" ]] || fail "'export status=1' did not abort"
  echo "  ok: measured against zsh, not assumed"
else
  echo "  SKIP: zsh is not installed, the matrix could not be measured"
fi

echo "[3/4] no file zsh runs or sources assigns to status"
targets="$TMP/targets"
zsh_context_files > "$targets"
count="$(wc -l <"$targets" | tr -d ' ')"
# A pass that scanned nothing is the defect this repo just spent a PR on.
[[ "$count" -gt 0 ]] \
  || fail "the zsh context came out empty — nothing was scanned, so nothing was proven"

offenders=0
while IFS= read -r f; do
  hits="$(scan_file "$f")"
  [[ -z "$hits" ]] && continue
  offenders=$((offenders + 1))
  printf '  %s\n' "${f#"$ROOT"/}" >&2
  printf '%s\n' "$hits" | sed 's/^/      /' >&2
done < "$targets"

[[ "$offenders" -eq 0 ]] \
  || fail "$offenders file(s) zsh loads assign to status — each aborts its function"
echo "  ok: $count file(s) in the zsh context, none assigns to status"

echo "[4/4] the scan would notice a real one"
# Planted in the zsh context rather than in a fixture directory, so this proves
# the whole path — enumeration, closure and match — not just the regex.
plant="$ROOT/terminal/menus/mq-tools-menu.sh"
[[ -f "$plant" ]] || fail "the planted file is missing: $plant"
cp "$plant" "$TMP/plant.bak"
printf '\nzsh_status_guard_probe() {\n  local status=0\n}\n' >> "$plant"
found=0
if [[ -n "$(scan_file "$plant")" ]]; then found=1; fi
cp "$TMP/plant.bak" "$plant"
[[ "$found" -eq 1 ]] || fail "a planted assignment was not detected"
[[ -z "$(scan_file "$plant")" ]] || fail "the plant was not cleaned up"
echo "  ok: a planted assignment is caught, and the file is restored"

echo "OK: zsh status assignment smoke test passed"
