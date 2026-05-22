---
name: terminal-ui-polisher
description: Improve terminal, CLI, TUI, ASCII, ANSI, and command-surface interfaces with focus on clarity, hierarchy, keyboard flow, spacing, status feedback, and product-level polish.
---

# Terminal UI Polisher

Use this skill to review and improve terminal-based interfaces.

The goal is to make CLI/TUI tools feel clear, intentional, fast, and product-level while keeping them practical and maintainable.

## When to use

Use this skill when the user asks to improve:

- CLI menus
- Terminal dashboards
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
