#!/bin/zsh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/bin"

MQ_SOURCE="$SCRIPT_DIR/terminal/launchers/mqlaunch.sh"
MQ_TARGET="$TARGET_DIR/mqlaunch"

SC_SOURCE="$SCRIPT_DIR/tools/scripts/system-check.sh"
SC_TARGET="$TARGET_DIR/system-check"

mkdir -p "$TARGET_DIR"

if [ ! -f "$MQ_SOURCE" ]; then
  echo "Source file not found: $MQ_SOURCE"
  exit 1
fi

if [ ! -f "$SC_SOURCE" ]; then
  echo "Source file not found: $SC_SOURCE"
  exit 1
fi

cp "$MQ_SOURCE" "$MQ_TARGET"
cp "$SC_SOURCE" "$SC_TARGET"

chmod +x "$MQ_TARGET"
chmod +x "$SC_TARGET"

echo "Installed:"
echo "  $MQ_TARGET"
echo "  $SC_TARGET"
echo
echo "Run with:"
echo "  mqlaunch"
echo "  system-check"
