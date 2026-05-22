# Example Terminal UI Review

## Goal

Make the menu feel like a calm command surface instead of a pile of script shortcuts.

## Current state

The tool has useful commands, but the screen lacks hierarchy. The user sees many options without a strong sense of priority, mode, or next action.

## Problems

1. Too many commands compete visually.
2. Quick actions and core flows are mixed.
3. Status feedback is weak.
4. Back/Quit behavior is not obvious.
5. The UI depends too much on fixed spacing.

## Recommended polish

1. Split the menu into CORE, QUICK ACCESS, and COMMANDS.
2. Add a compact context row: host, user, repo, mode.
3. Use one separator style across all screens.
4. Add a final status line before the prompt.
5. Reserve bright color for title and state only.

## Copy-paste changes

```text
MQ LAUNCH
────────────────────────────────────────────────────────────
Host: Zephyr   User: mansys   Mode: Main

CORE
  1. Workflows        2. System
  3. Git              4. Release
  5. Dev              6. Help

QUICK ACCESS
  p. Performance      n. Network
  h. Health Check     a. Apps

Status: ready
Select option:
```

## Final UI direction

Keep the retro command-surface personality, but make the layout calmer, more predictable, and easier to scan.

## Next step

Refactor the main menu first, then reuse the same layout grammar across all submenus.
