#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys

path = Path.home() / "macos-scripts" / "terminal" / "launchers" / "mqlaunch.sh"

if not path.exists():
    print(f"Missing file: {path}")
    sys.exit(1)

text = path.read_text()
original = text

# 1) Replace old backup_file path
text, count1 = re.subn(
    r'backup_file="\$BASE_DIR/terminal/launchers/mqlaunch-\$stamp\.sh\.bak"',
    'launcher_backup_dir="$BACKUP_DIR/launchers"\n  backup_file="$launcher_backup_dir/mqlaunch-$stamp.sh.bak"',
    text,
    count=1
)

if count1 != 1:
    print("Could not find old backup_file line to replace.")
    sys.exit(1)

# 2) Ensure mkdir exists after launcher_backup_dir/backup_file block
if 'mkdir -p "$launcher_backup_dir"' not in text:
    text = text.replace(
        '  backup_file="$launcher_backup_dir/mqlaunch-$stamp.sh.bak"\n',
        '  backup_file="$launcher_backup_dir/mqlaunch-$stamp.sh.bak"\n\n  mkdir -p "$launcher_backup_dir"\n',
        1
    )

if text == original:
    print("No changes were needed.")
else:
    path.write_text(text)
    print(f"Patched: {path}")
PY

echo
echo "Verify with:"
echo 'grep -n "launcher_backup_dir\|BACKUP_DIR/launchers\|mqlaunch-\$stamp.sh.bak" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
