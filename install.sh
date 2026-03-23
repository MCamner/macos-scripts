#!/bin/zsh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/terminal/launchers/mqlaunch.sh"
TARGET_DIR="$HOME/bin"
TARGET_FILE="$TARGET_DIR/mqlaunch"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Source file not found: $SOURCE_FILE"
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_FILE" "$TARGET_FILE"
chmod +x "$TARGET_FILE"

echo "Installed mqlaunch to $TARGET_FILE"
echo
echo "Run it with:"
echo "mqlaunch"
