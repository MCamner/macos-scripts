#!/usr/bin/env bash
# recommendations consumer — consistent messaging to stderr. Read-only.
# Mirrors lib/mqobsidian/errors.sh so the two consumers feel the same.

# Prints a red error line to stderr.
rec_error() { printf '\033[0;31m[recommend][error]\033[0m %s\n' "$*" >&2; }
# Prints a yellow warning line to stderr.
rec_warn()  { printf '\033[0;33m[recommend][warn]\033[0m %s\n' "$*" >&2; }
# Prints an info line to stderr.
rec_info()  { printf '\033[0;37m[recommend]\033[0m %s\n' "$*" >&2; }
# Prints a green ok line to stderr.
rec_ok()    { printf '\033[0;32m[recommend][ok]\033[0m %s\n' "$*" >&2; }
