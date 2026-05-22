---
name: mqlaunch-command-surface
description: Use when changing macos-scripts mqlaunch commands, HAL routing, terminal menus, command aliases, help text, or CLI/TUI command-surface behavior.
---

# mqlaunch Command Surface

Maintain the `mqlaunch` command surface as a coherent terminal product.

## When to use

Use this skill when the user asks to:

- add, rename, remove, or route an `mqlaunch` command
- change terminal menus, HAL commands, help screens, or aliases
- improve command discoverability or command-mode behavior
- update docs after CLI/TUI changes
- review whether a new workflow belongs in `terminal/`, `tools/`, `automation/`, or `system/`
- keep direct CLI commands and interactive menus consistent

## Core rule

Every user-facing command should work in direct CLI mode and be discoverable from the relevant menu or help surface unless there is a clear reason not to.

## Files to inspect first

- `README.md`
- `docs/COMMANDS.md`
- `terminal/launchers/mqlaunch-command-mode.sh`
- `terminal/launchers/mqlaunch.sh`
- relevant files under `terminal/menus/`
- relevant bridge under `terminal/bridges/`
- relevant tool under `tools/scripts/` or `tools/cli/`
- smoke tests under `tests/`

## Command design rules

- Prefer short, memorable command names.
- Keep aliases intentional and documented.
- Make destructive commands explicit, guarded, and visible.
- Provide clear empty, error, and missing-dependency states.
- Keep output compact enough for repeated terminal use.
- Preserve existing menu style, color conventions, and return behavior.
- Do not hide important commands only inside interactive menus.

## Consistency checks

After a command change, check whether these need updates:

- `docs/COMMANDS.md`
- `README.md` common commands
- help menu text
- direct dispatch in `mqlaunch-command-mode.sh`
- interactive menu option
- HAL bridge or raw intent examples
- smoke tests
- release notes or changelog, if user-facing

## Verification

Prefer lightweight checks:

```bash
bash -n terminal/launchers/mqlaunch-command-mode.sh
bash -n terminal/launchers/mqlaunch.sh
./tests/hal-command-surface-smoke.sh
./tests/hal-menu-smoke.sh
```

Run narrower checks when the change only touches one menu or script.

## Output

Report:

- command/menu surfaces touched
- docs updated or intentionally left unchanged
- checks run
- any command behavior left unverified

