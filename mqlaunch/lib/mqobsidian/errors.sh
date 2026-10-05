#!/usr/bin/env bash
# mqobsidian consumer — consistent messaging to stderr. Read-only.

# Prints a red error line to stderr.
mqobsidian_error() { printf '\033[0;31m[mqobsidian][error]\033[0m %s\n' "$*" >&2; }
# Prints a yellow warning line to stderr.
mqobsidian_warn()  { printf '\033[0;33m[mqobsidian][warn]\033[0m %s\n' "$*" >&2; }
# Prints an info line to stderr.
mqobsidian_info()  { printf '\033[0;37m[mqobsidian]\033[0m %s\n' "$*" >&2; }
