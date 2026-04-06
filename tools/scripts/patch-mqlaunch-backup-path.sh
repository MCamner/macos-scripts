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

new_func = r'''backup_mqlaunch() {
  local stamp launcher_backup_dir backup_file
  stamp="$(date '+%Y%m%d-%H%M%S')"
  launcher_backup_dir="$BACKUP_DIR/launchers"
  backup_file="$launcher_backup_dir/mqlaunch-$stamp.sh.bak"

  mkdir -p "$launcher_backup_dir"

  print_header
  row "BACKUP MQLAUNCH"
  empty_row

  if [[ -f "$MQ_SCRIPT" ]]; then
    cp "$MQ_SCRIPT" "$backup_file"
    chmod +x "$backup_file" 2>/dev/null || true

    row "Backup created successfully."
    row "Directory:"
    row " $launcher_backup_dir"
    row "File:"
    row " $backup_file"
  else
    row "mqlaunch.sh not found:"
    row " $MQ_SCRIPT"
  fi

  print_footer
  pause_enter
}'''

text, count = re.subn(
    r'backup_mqlaunch\(\)\s*\{.*?^\}',
    new_func,
    text,
    flags=re.S | re.M,
    count=1
)

if count != 1:
    print("Could not patch backup_mqlaunch().")
    sys.exit(1)

if text == original:
    print("No changes were needed.")
else:
    path.write_text(text)
    print(f"Patched: {path}")
PY

echo
echo "Verify with:"
echo 'grep -n "launcher_backup_dir\|BACKUP_DIR/launchers\|mqlaunch-\$stamp.sh.bak" "$HOME/macos-scripts/terminal/launchers/mqlaunch.sh"'
