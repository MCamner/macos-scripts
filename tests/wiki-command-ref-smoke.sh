#!/usr/bin/env bash
set -euo pipefail

# The published Command Reference carried a literal `$dashboard` as a script
# description. `extract_meta` rule 1 already refuses values containing `$` —
# the APP_NAME/APP_TITLE sed drops them — but rules 2 through 4 did not, so
# `print_dashboard_header "$dashboard"` in ui/terminal-ui/mq-ui.sh was matched
# by the `header "` rule and its unexpanded variable went straight to the wiki.
#
# An unexpanded shell variable is never a description. The check belongs to all
# four rules, not to the one that happened to have it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$ROOT/tools/scripts/generate-wiki-command-ref.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "SMOKE: wiki Command-Reference metadata"

# Marks a failing check.
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

bash -n "$GENERATOR"

# Pull the two functions under test out of the generator. Sourcing the whole
# file would run it.
eval "$(awk '/^accept_title\(\) \{/,/^\}/' "$GENERATOR")"
eval "$(awk '/^extract_meta\(\) \{/,/^\}/' "$GENERATOR")"

echo "[1/3] a value holding a shell variable is refused by every rule"
# One fixture per rule, each offering nothing but an unexpanded variable.
printf 'APP_NAME="$title"\n' > "$WORK/rule1.sh"
printf 'print_dashboard_header "$dashboard"\n' > "$WORK/rule2.sh"
printf '# -- $BANNER --\n' > "$WORK/rule3.sh"
printf '# Usage:\n#   mqlaunch $cmd\n' > "$WORK/rule4.sh"

for fixture in rule1 rule2 rule3 rule4; do
  got="$(extract_meta "$WORK/$fixture.sh")"
  case "$got" in
    *'$'*)
      fail "$fixture.sh produced a description holding a shell variable: '$got'"
      ;;
  esac
done

echo "[2/3] real descriptions still survive"
printf 'APP_NAME="MQ Tools"\n' > "$WORK/ok1.sh"
printf 'header "Network Menu"\n' > "$WORK/ok2.sh"

[[ "$(extract_meta "$WORK/ok1.sh")" == "MQ Tools" ]] \
  || fail "APP_NAME description was lost: '$(extract_meta "$WORK/ok1.sh")'"
[[ "$(extract_meta "$WORK/ok2.sh")" == "Network Menu" ]] \
  || fail "header description was lost: '$(extract_meta "$WORK/ok2.sh")'"

# Rule 3 is asserted in step [2b] below rather than here, because it needs
# fixtures for what it must *not* match as well as what it must.

echo "[2b/3] the banner rule wins where it should, and stays out where it should not"
# Banners are printed by the script's own header art, not written as comments,
# so the fixture has to look like the real thing.
#
# The delimiter is assembled from a variable rather than written inline: this
# file is itself scanned by the generator in step [3/3], and a literal banner in
# the source would make the test's own row in the published page read
# "MACOS CLEANUP TOOL".
d="--"
printf 'printf "      %s MACOS CLEANUP TOOL %s%%b\\n" "$NC"\n' "$d" "$d" > "$WORK/banner1.sh"
printf 'echo -e "   %s NETWORK LATENCY & SIGNAL DIAGNOSTIC %s${NC}"\n' "$d" "$d" > "$WORK/banner2.sh"

[[ "$(extract_meta "$WORK/banner1.sh")" == "MACOS CLEANUP TOOL" ]] \
  || fail "printf banner was not picked up: '$(extract_meta "$WORK/banner1.sh")'"
[[ "$(extract_meta "$WORK/banner2.sh")" == "NETWORK LATENCY & SIGNAL DIAGNOSTIC" ]] \
  || fail "echo banner was not picked up: '$(extract_meta "$WORK/banner2.sh")'"

# Three-dash section separators and HTML markers are not titles. Before the
# delimiter was pinned to exactly two dashes these produced descriptions like
# "COLORS (subtle)" and "BEGIN GENERATED SKILLS TABLE".
printf '# --- COLORS (subtle) ---\n' > "$WORK/sep1.sh"
printf '# --- Path 1: direct command dispatch ---------------\n' > "$WORK/sep2.sh"
printf 'say "--- Version surfaces ---"\n' > "$WORK/sep3.sh"
printf 'BEGIN_MARK="<!-- BEGIN GENERATED SKILLS TABLE -->"\n' > "$WORK/sep4.sh"

for fixture in sep1 sep2 sep3 sep4; do
  got="$(extract_meta "$WORK/$fixture.sh")"
  [[ -z "$got" ]] \
    || fail "$fixture.sh should yield no description, got '$got'"
done

echo "[3/3] a full run over the real tree emits no variable in any description"
# HOME is redirected so the generator writes into the sandbox instead of the
# operator's actual wiki checkout; BASE_DIR still points at this repo, so the
# run covers every script the published page covers.
HOME="$WORK/home" MACOS_SCRIPTS_HOME="$ROOT" "$GENERATOR" >/dev/null 2>&1 \
  || fail "generator exited non-zero"

generated="$WORK/home/macos-scripts.wiki/Command-Reference.md"
[[ -f "$generated" ]] || fail "generator wrote no Command-Reference.md"

# Column 3 of the table rows is Description. Anything else in the file (usage
# snippets, paths) may legitimately contain a dollar sign.
offenders="$(awk -F'|' '/^\| `/ && $3 ~ /\$/ { print $2 $3 }' "$generated")"
[[ -z "$offenders" ]] || {
  echo "descriptions still holding shell variables:" >&2
  printf '%s\n' "$offenders" >&2
  exit 1
}

grep -Fq 'mq-ui' "$generated" || fail "generated page lost the mq-ui rows entirely"

bash -n "$0"
echo "OK: no unexpanded shell variable reaches a Command-Reference description"
