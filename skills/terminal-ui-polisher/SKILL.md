---
name: terminal-ui-polisher
description: Improve terminal GUI menus, CLI, TUI, ASCII, ANSI, and command-surface interfaces with focus on clarity, hierarchy, keyboard flow, spacing, status feedback, and product-level polish.
---

# Terminal UI Polisher

Use this skill to review and improve terminal-based interfaces.

The goal is to make CLI/TUI tools feel clear, intentional, fast, and product-level while keeping them practical and maintainable.

## When to use

Use this skill when the user asks to improve:

- CLI menus
- Terminal dashboards
- mqlaunch terminal GUI panels built with `surface_*` helpers
- ASCII/ANSI interfaces
- Command surfaces
- Shell launchers
- Script output
- TUI layout
- Prompt flows
- mqlaunch-style menus
- Retro terminal aesthetics
- Status screens
- Help screens
- Doctor/checkup output
- Error messages
- Keyboard navigation

## When not to use

Do not use this skill for:

- Web UI design
- GUI app design
- Pure shell correctness review
- Security review
- Deep performance profiling unless terminal output clarity is part of the task

## Core principles

A good terminal UI should be:

1. Scannable  
   The user should understand the screen in 3 seconds.

2. Predictable  
   Navigation, keys, return behavior, and labels should be consistent.

3. Calm  
   Avoid noisy boxes, too many colors, and decorative overload.

4. Useful  
   Every line should help the user decide or act.

5. Fast  
   Common actions should be reachable quickly.

6. Honest  
   Status, warnings, errors, and partial failures should be clear.

7. Maintainable  
   Visual polish must not make the code fragile.

## Review checklist

Always evaluate:

- Header clarity
- Current context: host, user, path, mode, time
- Section hierarchy
- Menu grouping
- Keyboard shortcuts
- Return-to-menu behavior
- Error and empty states
- Status indicators
- Alignment and spacing
- Color usage
- Width handling
- Dynamic terminal size handling
- Copy-paste safety
- Command discoverability
- Help screen quality
- Progressive disclosure
- Consistency across screens

## Output format

Return the answer in this structure:

## Goal
State what the terminal UI should become.

## Current state
Summarize what the current interface communicates.

## Problems
List the main issues in priority order.

## Recommended polish
Give concrete improvements.

## Copy-paste changes
When useful, provide ready-to-paste shell functions, output templates, menu layouts, or text blocks.

## Final UI direction
Describe the target style in one short paragraph.

## Next step
Give exactly one next action.

## Scoring model

Score from 1 to 5:

1. Visual hierarchy
2. Menu clarity
3. Keyboard flow
4. Status feedback
5. Error handling
6. Consistency
7. Terminal resilience
8. Product feel

Then provide an overall score out of 40.

## Style guidance

Prefer:

- clean separators
- strong section labels
- restrained ANSI colors
- short action labels
- predictable keys
- compact help text
- one-line status messages
- consistent prompt format

Avoid:

- excessive ASCII art
- random colors
- inconsistent key labels
- giant menus with no grouping
- unclear abbreviations
- noisy animations
- hidden destructive actions
- output that scrolls too much
- fragile hardcoded widths unless fallback exists

## mqlaunch menu GUI standard

For macos-scripts, "GUI" usually means a terminal GUI built from the mqlaunch
surface helpers. Do not design these screens from scratch. Match the current
menu family.

Reference files:

- `skills/terminal-ui-polisher/assets/box-templates.md` contains reusable box templates; use it before writing manual box math.
- `terminal/menus/mq-hal-menu.sh` is the clearest submenu pattern.
- `terminal/menus/mq-performance-menu.sh` shows status-driven panels.
- `terminal/menus/mq-main-menu.sh` shows the main command surface.
- `ui/terminal-ui/mq-ui.sh` owns shared primitives.
- `tests/hal-menu-layout-smoke.sh` captures the layout contract.

Use this construction pattern:

1. Top of file: sourced guard such as `*_menu_is_sourced`.
2. Fallback UI loading: source `ui/terminal-ui/mq-ui.sh` only if `surface_top` is unavailable.
3. Render function: `render_*_panel`.
4. Header: optional `print_header`, then `surface_panel_header "Title" "Mode" "$width" "$panel_color"`.
5. Body: `surface_row` for section labels and blank rows, `surface_split_row` for actions.
6. Navigation row: `b. Back` and `x. Exit launcher`.
7. Prompt: `read_main_choice "short-label"` when available, with a plain fallback prompt.
8. Actions: route through existing commands/scripts and call `pause_enter` after visible output.
9. Footer: standalone execution guard at the bottom.

Layout rules:

- Section names are short uppercase nouns.
- Menu options stay stable and obvious; aliases should be intentional.
- Prefer two-column option rows; use one-column rows only for long status or warnings.
- Keep dynamic status to one or two rows near the top or bottom.
- Use `surface_terminal_width`; do not hardcode panel widths.
- Use `surface_panel_color`; do not add local color schemes.
- Text must fit at 60 columns because `surface_terminal_width` clamps there.
- If a dependency is missing, render a panel explaining the missing binary and the exact check command.
- Menus should work sourced from mqlaunch and directly as scripts.
- For legacy launchers with local frame helpers, copy the width math from `assets/box-templates.md`; do not draw nested two-column boxes.

When reviewing a proposed menu, reject it if it:

- uses ad hoc `echo` boxes instead of `surface_*`
- omits `b. Back` or `x. Exit launcher`
- bypasses `read_main_choice`
- duplicates command logic that already lives in a bridge, command, or tool script
- introduces new visual language that does not match the other menus
- cannot pass `bash -n`

## Recommended command-surface structure

A strong terminal screen usually follows this pattern:

```text
APP NAME / MODE
────────────────────────────────────────────────────────────
Context: host · user · path · time

SECTION
  1. Action
  2. Action
  3. Action

QUICK
  h help   b back   r refresh   q quit

Status: ready
> 
```

## Tone rules

Be direct and practical.

If the UI is messy, say so clearly.
If the aesthetic is cool but hurts usability, say that.
Do not remove personality; refine it.
Prioritize structure before decoration.
