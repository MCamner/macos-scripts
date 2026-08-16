#!/usr/bin/env bash
set -uo pipefail

# The prompt and the UI palette are two theme systems with overlapping but
# unequal vocabularies. Sync is exact-match only: a name present on both sides
# changes both, a name present on one side changes only that side. No name is
# ever translated into a different name — that would be a product decision
# hiding inside a fallback.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWITCHER="$ROOT/terminal/themes/mq-zsh-theme-switcher.sh"
MANAGER="$ROOT/terminal/themes/mq-theme-manager.sh"
SYNC="$ROOT/terminal/themes/mq-theme-sync.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

fresh_home() {
  rm -rf "${TMP:?}/home"
  mkdir -p "$TMP/home"
  printf '# test zshrc\n' > "$TMP/home/.zshrc"
}

run_switcher() { HOME="$TMP/home" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
  bash "$SWITCHER" "$@"; }
run_manager()  { HOME="$TMP/home" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 \
  bash "$MANAGER" "$@"; }

prompt_variant() { sed -n 's/^export MQ_ZSH_VARIANT="\(.*\)"$/\1/p' "$TMP/home/.zshrc" | tail -1; }
ui_theme() {
  [[ -f "$TMP/home/.mq-theme" ]] || { printf 'NONE'; return; }
  sed -n 's/^export MQ_THEME_NAME="\{0,1\}\([a-z]*\)"\{0,1\}$/\1/p' "$TMP/home/.mq-theme" | tail -1
}

echo "[1/7] the shared set is exactly the overlap, not a hand-kept list"
[[ -f "$SYNC" ]] || fail "no shared helper at $SYNC"
prompt_names="$(MACOS_SCRIPTS_HOME="$ROOT" bash "$SWITCHER" list | awk 'NF {print $1}' | sort)"
ui_names="$(MACOS_SCRIPTS_HOME="$ROOT" bash "$MANAGER" list | awk 'NF {print $1}' | sort)"
overlap="$(comm -12 <(printf '%s\n' "$prompt_names") <(printf '%s\n' "$ui_names") | tr '\n' ' ')"
declared="$(bash -c "source '$SYNC'; printf '%s' \"\$MQ_THEME_SHARED\"" | tr ' ' '\n' | sort | tr '\n' ' ')"
[[ "$(echo "$overlap")" == "$(echo "$declared")" ]] \
  || fail "declared shared set [$declared] is not the real overlap [$overlap]"

echo "[2/7] a shared name applied on the prompt side moves the UI too"
fresh_home
run_switcher apply amber >/dev/null 2>&1 || fail "switcher apply amber failed"
[[ "$(prompt_variant)" == amber ]] || fail "prompt not amber: $(prompt_variant)"
[[ "$(ui_theme)" == amber ]] || fail "UI did not follow: $(ui_theme)"

echo "[3/7] a prompt-only name leaves the UI untouched"
fresh_home
run_manager apply ice >/dev/null 2>&1 || fail "manager apply ice failed"
run_switcher apply minimal >/dev/null 2>&1 || fail "switcher apply minimal failed"
[[ "$(prompt_variant)" == minimal ]] || fail "prompt not minimal: $(prompt_variant)"
[[ "$(ui_theme)" == ice ]] \
  || fail "a prompt-only theme changed the UI to $(ui_theme) — it must stay ice"

echo "[4/7] a shared name applied on the UI side moves the prompt too"
fresh_home
run_manager apply green >/dev/null 2>&1 || fail "manager apply green failed"
[[ "$(ui_theme)" == green ]] || fail "UI not green: $(ui_theme)"
[[ "$(prompt_variant)" == green ]] || fail "prompt did not follow: $(prompt_variant)"

echo "[5/7] a UI-only name leaves the prompt untouched"
fresh_home
run_switcher apply amber >/dev/null 2>&1 || fail "switcher apply amber failed"
run_manager apply synth >/dev/null 2>&1 || fail "manager apply synth failed"
[[ "$(ui_theme)" == synth ]] || fail "UI not synth: $(ui_theme)"
[[ "$(prompt_variant)" == amber ]] \
  || fail "a UI-only theme changed the prompt to $(prompt_variant) — it must stay amber"

echo "[6/7] the sync does not bounce back and forth"
fresh_home
# Each side calls the other for a shared name. Without a guard that is an
# infinite loop, so this step is also the reason the guard exists.
HOME="$TMP/home" MACOS_SCRIPTS_HOME="$ROOT" MQ_NO_TUI=1 MQ_THEME_SYNC_ACTIVE=1 \
  bash "$SWITCHER" apply ice >/dev/null 2>&1 || fail "guarded switcher run failed"
[[ "$(prompt_variant)" == ice ]] || fail "guarded run did not apply: $(prompt_variant)"
[[ "$(ui_theme)" == NONE ]] \
  || fail "a guarded run still synced onward, so a real run would recurse: $(ui_theme)"

echo "[7/7] a missing counterpart does not fail the change the user asked for"
fresh_home
# A checkout that has the UI library and the prompt theme file but no theme
# manager. Pointing BASE_DIR at nothing would fail for the wrong reason.
mkdir -p "$TMP/partial/terminal/themes"
ln -sfn "$ROOT/ui" "$TMP/partial/ui"
cp "$ROOT/terminal/themes/mq-zsh-theme-v3.zsh" "$TMP/partial/terminal/themes/"
cp "$SYNC" "$TMP/partial/terminal/themes/"

out="$(HOME="$TMP/home" MACOS_SCRIPTS_HOME="$TMP/partial" MQ_NO_TUI=1 \
  bash "$SWITCHER" apply amber 2>&1)"
status=$?
[[ "$status" -eq 0 ]] || fail "a missing counterpart failed the prompt change: $out"
[[ "$(prompt_variant)" == amber ]] || fail "prompt change lost: $(prompt_variant)"
grep -qi 'could not\|not synced\|skipped' <<< "$out" \
  || fail "the skipped sync is not reported: $out"

echo "OK  theme exact sync"
