#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

home = Path.home()
tweaks = home / "macos-scripts" / "system" / "tweaks" / "macos-tweaks.sh"

if not tweaks.exists():
    print(f"Missing file: {tweaks}")
    sys.exit(1)

text = tweaks.read_text()
original = text

# 1) Ensure BASE_DIR + UI_LIB exist
if 'BASE_DIR="${HOME}/macos-scripts"' not in text:
    text = text.replace(
        'SCRIPT_NAME="$(basename "$0")"\n',
        'SCRIPT_NAME="$(basename "$0")"\nBASE_DIR="${HOME}/macos-scripts"\n'
    )

if 'UI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"' not in text:
    text = text.replace(
        'BASE_DIR="${HOME}/macos-scripts"\n',
        'BASE_DIR="${HOME}/macos-scripts"\nUI_LIB="$BASE_DIR/ui/terminal-ui/mq-ui.sh"\n'
    )

# 2) Source UI lib after variable block
source_block = '''if [[ -f "$UI_LIB" ]]; then
  source "$UI_LIB"
else
  echo "Missing UI library: $UI_LIB" >&2
  exit 1
fi

'''

if 'source "$UI_LIB"' not in text:
    anchor = 'BOX_INNER=88\n'
    if anchor in text:
        text = text.replace(anchor, anchor + '\n' + source_block, 1)
    else:
        print("Could not find BOX_INNER anchor.")
        sys.exit(1)

# 3) Remove duplicated UI functions from tweaks script
pattern = re.compile(
    r'repeat_char\(\) \{.*?pause_enter\(\) \{.*?read -r -p "Press Enter to continue..." _\n\}\n',
    re.S
)
text, count = pattern.subn('', text, count=1)

if count == 0:
    print("Warning: duplicated UI block was not removed automatically.")

# 4) Remove duplicate color TITLE/footer helpers only if still present
text = text.replace(
    "C_TITLE='\\033[1;33m'\n",
    ""
)

if text != original:
    tweaks.write_text(text)
    print(f"Patched: {tweaks}")
else:
    print("No changes were needed.")
PY

echo
echo "Verify with:"
echo 'grep -n "UI_LIB\\|source \"\\$UI_LIB\"" "$HOME/macos-scripts/system/tweaks/macos-tweaks.sh"'
