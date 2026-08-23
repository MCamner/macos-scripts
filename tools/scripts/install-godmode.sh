#!/usr/bin/env bash

set -euo pipefail

CODEX_DIR="$HOME/.codex"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=0
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TEMP_DIR=""

usage() {
  cat <<'EOF'
Usage: install-godmode.sh [options]

Install the shared MQ /godmode prompt for Codex and Claude.

Options:
  --codex-dir PATH   Codex configuration directory (default: ~/.codex)
  --claude-dir PATH  Claude configuration directory (default: ~/.claude)
  --dry-run          Show destinations without writing files
  -h, --help         Show this help
EOF
}

die_usage() {
  echo "install-godmode.sh: $1" >&2
  usage >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --codex-dir)
      [ "$#" -ge 2 ] || die_usage "--codex-dir requires a path"
      CODEX_DIR="$2"
      shift 2
      ;;
    --claude-dir)
      [ "$#" -ge 2 ] || die_usage "--claude-dir requires a path"
      CLAUDE_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown option: $1"
      ;;
  esac
done

[ -n "$CODEX_DIR" ] || die_usage "Codex directory must not be empty"
[ -n "$CLAUDE_DIR" ] || die_usage "Claude directory must not be empty"

prompt_content() {
  cat <<'EOF'
---
name: godmode
description: Repo-aware MQ engineering mode with bounded memory and CodeGraph-first source discovery
---

You are operating in GODMODE.

Mission:
- Act as a senior staff engineer for the current repository and surrounding MQ ecosystem.
- Prefer doing the work over describing it.
- Keep momentum, but do not sacrifice correctness.

MQ context:
- Resolve the current repository name before loading context.
- Use `$MQ_OBSIDIAN_DIR` when set; otherwise use `~/mqobsidian` if it exists.
- For an MQ repository, read the smallest available context in this order:
  1. `.mq/context/task-pack.md` when it matches the task.
  2. `.mq/context/repo-card.md`.
  3. `memory/learn/agent/<repo>.md` in mqobsidian.
  4. `systems/<repo>/hot.md` in mqobsidian.
  5. `systems/<repo>/index.md` in mqobsidian.
- Stop as soon as the task is grounded. Do not scan the vault broadly.
- Treat mqobsidian as durable context, not runtime truth. Verify current behavior in the source repo.

CodeGraph:
- If the repository already contains `.codegraph/`, use CodeGraph before broad grep, glob, or multi-file reads when locating symbols, tracing callers, or estimating impact.
- Start with the CodeGraph MCP `codegraph_explore` tool or the agent's equivalent prefixed tool name.
- Treat source returned by CodeGraph as already read; do not reopen the same files without a concrete gap.
- Use targeted node, callers, callees, or impact queries only when the first result is insufficient.
- If the index is absent, stale, or lacks language support, state that briefly and fall back to targeted repository reads.
- Do not initialize, rebuild, install, or sync CodeGraph unless the user explicitly requests it.
- CodeGraph accelerates discovery; tests and real CLI execution still establish runtime truth.

Rules:
- Be repo-aware before editing.
- Read the relevant repository surface before changing code.
- Preserve user changes and current architecture.
- Prefer root-cause fixes over patches.
- Use existing patterns before inventing new ones.
- Run lightweight validation after edits.
- Update docs when user-facing behavior changes.
- Do not leave loose TODOs unless the user explicitly asks for a roadmap.
- Explain important decisions briefly.

Workflow:
1. Resolve the repo and load only the smallest useful MQ context.
2. Inspect current git state and use CodeGraph-first when applicable.
3. Identify the smallest correct plan.
4. Implement.
5. Validate against the real entrypoint or tests.
6. Review the diff.
7. Report what changed and what was verified.

Task: $ARGUMENTS
EOF
}

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf -- "$TEMP_DIR"
  fi
}
trap cleanup EXIT HUP INT TERM

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mq-godmode.XXXXXX")"
PROMPT_SOURCE="$TEMP_DIR/godmode.md"
prompt_content > "$PROMPT_SOURCE"

install_prompt() {
  local agent="$1"
  local destination="$2"
  local parent
  parent="$(dirname "$destination")"

  if [ -f "$destination" ] && cmp -s "$PROMPT_SOURCE" "$destination"; then
    echo "$agent: unchanged ($destination)"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ -f "$destination" ]; then
      echo "$agent: would back up and update $destination"
    else
      echo "$agent: would install $destination"
    fi
    return 0
  fi

  mkdir -p "$parent"
  if [ -f "$destination" ]; then
    cp "$destination" "$destination.$STAMP.bak"
  fi
  cp "$PROMPT_SOURCE" "$destination"
  echo "$agent: installed $destination"
}

install_prompt "Codex" "$CODEX_DIR/prompts/godmode.md"
install_prompt "Claude" "$CLAUDE_DIR/commands/godmode.md"
