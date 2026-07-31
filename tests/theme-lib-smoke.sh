#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/themes.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
MENU="$ROOT/terminal/menus/mq-themes-menu.sh"
THEME="$ROOT/terminal/themes/mq-zsh-theme-v3.zsh"
SWITCHER="$ROOT/terminal/themes/mq-zsh-theme-switcher.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "[1/9] shared theme library exists"
test -f "$LIB"

echo "[2/9] launcher and menu source the shared library"
grep -q 'mqlaunch/lib/themes.sh' "$LAUNCHER"
grep -q 'mqlaunch/lib/themes.sh' "$MENU"

echo "[3/9] theme functions have one definition"
for function_name in open_themes_menu theme_cmd theme_current_variant theme_source_state; do
  count="$(grep -R -h "^${function_name}()" "$LIB" "$LAUNCHER" "$MENU" | wc -l | tr -d ' ')"
  test "$count" = "1"
done

echo "[4/9] theme command preserves arguments"
mkdir -p "$TMPDIR_TEST/repo/terminal/themes"
cat > "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@"
FAKE
chmod +x "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh"
output="$(BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_cmd apply amber' _ "$LIB")"
test "$output" = $'apply\namber'

echo "[5/9] status helpers preserve empty-home fallbacks"
output="$(HOME="$TMPDIR_TEST/home" BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_current_variant; theme_source_state' _ "$LIB")"
test "$output" = $'not-set\nMISSING'

echo "[6/9] inherited legacy guard does not skip the selected palette"
output="$(MQ_ZSH_THEME_V3_LOADED=1 MQ_ZSH_VARIANT=green zsh -fc 'source "$1"; typeset -p MQC_ACCENT 2>/dev/null || print MISSING_PALETTE' _ "$THEME")"
test "$output" = "typeset MQC_ACCENT='%F{82}'"

echo "[7/9] theme load guard stays local to the current shell"
output="$(MQ_ZSH_VARIANT=green zsh -fc 'source "$1"; print -r -- "${parameters[MQ_ZSH_THEME_V3_LOADED]}"' _ "$THEME")"
test "$output" = "scalar"

echo "[8/9] applying a theme keeps Zsh and MQ UI colors in sync"
mkdir -p "$TMPDIR_TEST/home"
ln -s "$ROOT" "$TMPDIR_TEST/home/macos-scripts"
printf '\n' | HOME="$TMPDIR_TEST/home" bash "$SWITCHER" apply green >/dev/null
grep -q '^export MQ_ZSH_VARIANT="green"$' "$TMPDIR_TEST/home/.zshrc"
grep -q '^export MQ_THEME_NAME="green"$' "$TMPDIR_TEST/home/.mq-theme"

echo "[9/9] reset clears both managed theme tracks"
printf '\n' | HOME="$TMPDIR_TEST/home" bash "$SWITCHER" reset >/dev/null
! grep -q 'MQ_ZSH_VARIANT\\|mq-zsh-theme-v3.zsh' "$TMPDIR_TEST/home/.zshrc"
test ! -e "$TMPDIR_TEST/home/.mq-theme"

echo "OK: shared theme concern"
