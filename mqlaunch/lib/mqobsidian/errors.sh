#!/usr/bin/env bash
# mqobsidian consumer — consistent messaging to stderr. Read-only.

mqobsidian_error() { printf '\033[0;31m[mqobsidian][error]\033[0m %s\n' "$*" >&2; }
mqobsidian_warn()  { printf '\033[0;33m[mqobsidian][warn]\033[0m %s\n' "$*" >&2; }
mqobsidian_info()  { printf '\033[0;37m[mqobsidian]\033[0m %s\n' "$*" >&2; }
