#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/mqlaunch/lib/themes.sh"
LAUNCHER="$ROOT/terminal/launchers/mqlaunch.sh"
MENU="$ROOT/terminal/menus/mq-themes-menu.sh"
TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

echo "[1/5] shared theme library exists"
test -f "$LIB"

echo "[2/5] launcher and menu source the shared library"
grep -q 'mqlaunch/lib/themes.sh' "$LAUNCHER"
grep -q 'mqlaunch/lib/themes.sh' "$MENU"

echo "[3/5] theme functions have one definition"
for function_name in open_themes_menu theme_cmd theme_current_variant theme_source_state; do
  count="$(grep -R -h "^${function_name}()" "$LIB" "$LAUNCHER" "$MENU" | wc -l | tr -d ' ')"
  test "$count" = "1"
done

echo "[4/5] theme command preserves arguments"
mkdir -p "$TMPDIR_TEST/repo/terminal/themes"
cat > "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@"
FAKE
chmod +x "$TMPDIR_TEST/repo/terminal/themes/mq-zsh-theme-switcher.sh"
output="$(BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_cmd apply amber' _ "$LIB")"
test "$output" = $'apply\namber'

echo "[5/5] status helpers preserve empty-home fallbacks"
output="$(HOME="$TMPDIR_TEST/home" BASE_DIR="$TMPDIR_TEST/repo" bash -c 'source "$1"; theme_current_variant; theme_source_state' _ "$LIB")"
test "$output" = $'not-set\nMISSING'

echo "OK: shared theme concern"
