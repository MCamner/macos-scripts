# MQLaunch progress and result UI contract

This document defines the shared shell primitives for visible workflow progress and completion summaries.

## Authority

- `ui/terminal-ui/mq-ui.sh` owns terminal width, colors, panel geometry, TTY/plain-output behavior and `ui_spinner`.
- `ui/terminal-ui/mq-progress.sh` owns deterministic workflow step snapshots and result panels.
- Consumers should reuse these primitives instead of defining local spinners, progress glyphs or result boxes.

## Choose the right primitive

### `ui_spinner`

Use for one slow, opaque, non-interactive wait where the caller cannot observe internal phases.

```bash
ui_spinner "Reviewing repo → brain" _run_agent review repo . --brain
```

Do not wrap commands that prompt on stdin.

### `ui_progress_steps`

Use only when the workflow owner knows real phase state. Do not infer percentages from elapsed time and do not invent phases merely to make the UI look busy.

```bash
source "$BASE_DIR/ui/terminal-ui/mq-progress.sh"

ui_progress_steps \
  'done|Scan repository' \
  'active|Build review context' \
  'pending|Send to model' \
  'pending|Save to brain'
```

Canonical states:

| State | Glyph | Meaning |
| --- | --- | --- |
| `done` | `✓` | completed successfully |
| `active` | `■` | current known phase |
| `pending` | `□` | not started |
| `warn` | `!` | completed/blocked with warning |
| `fail` | `✗` | failed |
| `skipped` | `–` | intentionally not run |

Re-render the snapshot only on a real state transition.

### `ui_result_panel`

Use after a long-running or multi-step human-facing operation when a compact terminal summary adds value.

```bash
ui_result_panel PASS "Review complete" \
  "Brain: mqobsidian" \
  "Next: mqlaunch memory review-status"
```

Canonical statuses are `PASS`, `WARN`, `FAIL`, `SKIPPED`, `UNAVAILABLE`, and `INFO`. Aliases such as `OK`, `SUCCESS`, and `ERROR` are accepted for shell convenience.

## Rendering rules

1. Interactive terminal rendering reuses `surface_terminal_width`, `surface_panel_color`, `surface_top`, `surface_row`, and `surface_bottom`.
2. `NO_COLOR` remains authoritative for color suppression.
3. Piped/headless output contains semantic text only: no panel furniture, cursor movement or ANSI escapes.
4. Bash and zsh are both supported because mqlaunch command mode and interactive menus use different shells.
5. Progress and result primitives do not change delegated command exit codes. A caller decides how a command result maps to a result status.

## Product rule

A quiet terminal during an opaque wait is a spinner problem. A workflow with known phases is a step-progress problem. A finished operation whose result is hard to find in preceding output is a result-panel problem. Do not solve all three with one widget.

## v2.2.0 slow-row inventory

The slow menu rows audited for v2.2.0 are the interactive `mq-agent` rows in
`terminal/menus/mq-agent-menu.sh` that shell into `uv run mq-agent` or local
MCP server control:

- repo analysis rows: score, signal, repo summary, tools
- top-level agent rows: audit, release check, CI diagnosis, stack sweep, stack loop
- review-to-brain rows: repo review, signal save, stack truth export
- co-change rows: intake, review-status, promote-from-review, resolve-supersede, learn promotion
- MCP rows: status, tools, start, stop
- environment doctor

They use `ui_spinner` through `_run_agent_menu_wait`, because each row is one
opaque wait from mqlaunch's point of view. The repo-review-to-brain row keeps
`ui_progress_steps` and `ui_result_panel` because mqlaunch can observe real
phase evidence after mq-agent returns. The TUI dashboard row stays unwrapped
because it is itself interactive.
