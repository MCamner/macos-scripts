#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

home = Path.home()
mq_ui = home / "macos-scripts" / "ui" / "terminal-ui" / "mq-ui.sh"
mqlaunch = home / "macos-scripts" / "terminal" / "launchers" / "mqlaunch.sh"

if not mq_ui.exists():
    print(f"Missing file: {mq_ui}")
    sys.exit(1)

if not mqlaunch.exists():
    print(f"Missing file: {mqlaunch}")
    sys.exit(1)

# ------------------------------------------------------------
# 1) Patch mq-ui.sh to be bash/zsh safe
# ------------------------------------------------------------
ui_text = mq_ui.read_text()

ui_text_new = ui_text.replace(
    "pause_enter() {\n  echo\n  read -r -p \"Press Enter to continue...\" _\n}\n",
    "pause_enter() {\n  echo\n  printf 'Press Enter to continue...'\n  read -r _\n}\n"
)

if ui_text_new != ui_text:
    mq_ui.write_text(ui_text_new)
    print(f"Patched shell-safe pause_enter() in: {mq_ui}")
else:
    print(f"No mq-ui.sh pause_enter() change needed: {mq_ui}")

# ------------------------------------------------------------
# 2) Patch mqlaunch.sh to source mq-ui.sh
# ------------------------------------------------------------
text = mqlaunch.read_text()
original = text

# Add UI_LIB variable after BIN_LINK if missing
if 'UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"' not in text:
    text = text.replace(
        'BIN_LINK="$HOME/bin/mqlaunch"\n',
        'BIN_LINK="$HOME/bin/mqlaunch"\nUI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"\n'
    )

# Add source block after TERMINAL_GUIDE_URL if missing
source_block = """if [[ -f "$UI_LIB" ]]; then
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

"""

if 'source "$UI_LIB"' not in text:
    text = text.replace(
        'TERMINAL_GUIDE_URL="https://mcamner.github.io/macos-scripts/"\n',
        'TERMINAL_GUIDE_URL="https://mcamner.github.io/macos-scripts/"\n\n' + source_block
    )

# Remove old inline ANSI/UI helper block.
# We keep local helper functions starting from open_app().
pattern = re.compile(
    r'# --- ANSI colors --------------------------------------------\n.*?(?=open_app\(\) \{)',
    re.S
)

replacement = """# --- Shared UI ------------------------------------------------
"""

text, count = pattern.subn(replacement, text, count=1)

if count == 0:
    print("Warning: could not remove inline UI block automatically.")
else:
    print("Removed inline UI/helper block from mqlaunch.sh")

if text != original:
    mqlaunch.write_text(text)
    print(f"Patched mqlaunch to source mq-ui.sh: {mqlaunch}")
else:
    print(f"No mqlaunch changes were needed: {mqlaunch}")
PY

echo
echo "Verify with:"
echo 'grep -n "UI_LIB\|source \"\$UI_LIB\"" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
echo 'grep -n "pause_enter()" "$HOME/macos-scripts/ui/terminal-ui/mq-ui.sh"'
