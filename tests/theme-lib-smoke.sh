#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/themes.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
MENU="$ROOT/terminal/menus/mq-themes-menu.sh"
THEME="$ROOT/terminal/themes/mq-zsh-theme-v3.zsh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "[1/7] shared theme library exists"
test -f "$LIB"

echo "[2/7] launcher and menu source the shared library"
grep -q 'mqlaunch/lib/themes.sh' "$LAUNCHER"
grep -q 'mqlaunch/lib/themes.sh' "$MENU"

echo "[3/7] theme functions have one definition"
for function_name in open_themes_menu theme_cmd theme_current_variant theme_source_state; do
  count="$(grep -R -h "^${function_name}()" "$LIB" "$LAUNCHER" "$MENU" | wc -l | tr -d ' ')"
  test "$count" = "1"
done

echo "[4/7] theme command preserves arguments"
mkdir -p "$TMPDIR_TEST/repo/terminal/themes"
cat > "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@"
FAKE
chmod +x "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh"
output="$(BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_cmd apply amber' _ "$LIB")"
test "$output" = $'apply\namber'

echo "[5/7] status helpers preserve empty-home fallbacks"
output="$(HOME="$TMPDIR_TEST/home" BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_current_variant; theme_source_state' _ "$LIB")"
test "$output" = $'not-set\nMISSING'

echo "[6/7] an inherited load guard does not skip the newly selected palette"
# The switcher tells the user to run `exec zsh`, which inherits the exported
# guard from the shell that applied the theme. Treating that as "already
# loaded" means the palette the user just chose never loads — the switcher's
# own activation instruction defeats the switcher.
output="$(MQ_ZSH_THEME_V3_LOADED=1 MQ_ZSH_VARIANT=green zsh -fc \
  'source "$1"; typeset -p MQC_ACCENT 2>/dev/null || print MISSING_PALETTE' _ "$THEME")"
test "$output" = "typeset MQC_ACCENT='%F{82}'"

echo "[7/7] the load guard stays local to the shell that set it"
# Local, so it still prevents a double load inside one shell — the guard is
# not simply removed.
output="$(MQ_ZSH_VARIANT=green zsh -fc \
  'source "$1"; print -r -- "${parameters[MQ_ZSH_THEME_V3_LOADED]}"' _ "$THEME")"
test "$output" = "scalar"

echo "OK: shared theme concern"
