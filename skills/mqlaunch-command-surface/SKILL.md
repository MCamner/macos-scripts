---
name: mqlaunch-command-surface
description: Use when changing macos-scripts mqlaunch commands, terminal GUI menus, HAL routing, command aliases, help text, or CLI/TUI command-surface behavior.
---

# mqlaunch Command Surface

Maintain the `mqlaunch` command surface as a coherent terminal product.

## When to use

Use this skill when the user asks to:

* add, rename, remove, or route an `mqlaunch` command
* change terminal menus, HAL commands, help screens, or aliases
* build a new terminal GUI/menu/panel for mqlaunch
* improve command discoverability or command-mode behavior
* update docs after CLI/TUI changes
* review whether a new workflow belongs in `terminal/`, `tools/`, `automation/`, or `system/`
* keep direct CLI commands and interactive menus consistent
* change the agent menu stack surfaces (demo flow, stack health sweep) or the B2 stack cockpit routing

## When not to use

* Pure visual polish review of an existing surface — use `terminal-ui-polisher`
* Docs-only updates — use `docs-maintainer`
* Release validation — use `release-readiness`
* mq-agent-side stack logic (sweep, cockpit, gates themselves) — that lives in mq-agent; this skill only owns the mqlaunch routing to them

## Evals

### Should trigger

* "add a new mqlaunch command for X"
* "the agent menu needs a new option"
* "route `mq b2 stack` from the dev menu too"
* "command works in CLI mode but isn't in any menu"

### Should not trigger

* "this panel looks cluttered" → use `terminal-ui-polisher`
* "update docs/COMMANDS.md only" → use `docs-maintainer`
* "change what stack sweep actually does" → mq-agent's `stack-operations` skill
* "is the repo ready to release?" → use `release-readiness`

## Core rule

Every user-facing command should work in direct CLI mode and be discoverable from the relevant menu or help surface unless there is a clear reason not to.

## Files to inspect first

* `README.md`
* `docs/COMMANDS.md`
* `terminal/launchers/mqlaunch-command-mode.sh`
* `terminal/launchers/mqlaunch.sh`
* `terminal/menus/mq-agent-menu.sh` for agent/stack surfaces
* relevant files under `terminal/menus/`
* relevant bridge under `terminal/bridges/`
* relevant tool under `tools/scripts/` or `tools/cli/`
* smoke tests under `tests/`

## Menu/GUI construction standard

When building a new mqlaunch terminal GUI, follow the existing menu system. Treat
`terminal/menus/mq-hal-menu.sh` as the reference implementation and
`ui/terminal-ui/mq-ui.sh` as the shared UI library.

New menus should use this shape:

```bash
#!/usr/bin/env bash

menu_is_sourced() {
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    [[ ":${ZSH_EVAL_CONTEXT:-}:" == *:file:* ]]
    return
  fi
  [[ "${BASH_SOURCE[0]:-}" != "$0" ]]
}

if ! command -v surface_top >/dev/null 2>&1; then
  : "${BASE_DIR:=${MACOS_SCRIPTS_HOME:-$HOME/macos-scripts}}"
  [[ -f "$BASE_DIR/ui/terminal-ui/mq-ui.sh" ]] && source "$BASE_DIR/ui/terminal-ui/mq-ui.sh"
fi

render_example_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  command -v print_header >/dev/null 2>&1 && print_header
  surface_panel_header "MQ Example" "Example" "$width" "$panel_color"
  surface_row "SECTION" "$width" "$panel_color"
  surface_split_row "1. First Action" "2. Second Action" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
  printf '\n'
}

example_menu_main() {
  local choice
  while true; do
    render_example_panel
    if command -v read_main_choice >/dev/null 2>&1; then
      read_main_choice "example" || break
    else
      printf '\nexample> '
      read -r choice
    fi

    case "$choice" in
      1) run_first_action; pause_enter ;;
      2) run_second_action; pause_enter ;;
      b|B|back) break ;;
      x|X) exit 0 ;;
      *) [[ -n "$choice" ]] && /bin/zsh -lc "$choice" && pause_enter ;;
    esac
  done
}

if ! menu_is_sourced; then
  example_menu_main "$@"
fi
```

Required conventions:

* Source `ui/terminal-ui/mq-ui.sh` only when `surface_top` is not already available.
* Render boxes with `surface_panel_header`, `surface_row`, `surface_split_row`, and `surface_bottom`.
* Use two-column rows for menu actions so the visual rhythm matches other menus.
* Keep section labels short and uppercase: `OBSERVE`, `PLAN`, `TOOLS`, `DEBUG`, `MEMORY`.
* Include `b. Back` and `x. Exit launcher` unless the screen is not navigational.
* Use `read_main_choice "label"` for the pinned prompt when available.
* Provide standalone fallback prompts for direct script execution.
* Wrap `pause_enter` if the menu can run standalone.
* Keep business logic in commands, bridges, or tools; menu files should own presentation and routing.
* Do not invent a second UI framework, custom box drawing helpers, or one-off color palettes.
* Use `surface_terminal_width` and `surface_panel_color`; never hardcode widths or local color schemes.
* Text must fit at 60 columns because `surface_terminal_width` clamps there.
* Keep dynamic status to one or two rows near the top or bottom of the panel.
* If a dependency is missing, render a panel explaining the missing binary and the exact check command.
* For reusable box templates and legacy frame math, see `skills/terminal-ui-polisher/assets/box-templates.md`.

This section is the single owner of the menu/GUI standard; `terminal-ui-polisher` references it when reviewing menus.

## Stack surfaces

The agent menu and B2 cockpit route into mq-agent's stack suite — mqlaunch owns
the routing, mq-agent owns the behavior:

* `terminal/menus/mq-agent-menu.sh` option 17 (Demo flow, full stack) and 18 (Stack health sweep)
* `mq b2 stack` — Stack cockpit (B2 + repo + roadmap + validation), see `docs/B2_TUI.md`
* `mqlaunch release-check` — release gate, `MQ_REPO_SIGNAL_FAIL_UNDER` for custom threshold

When adding stack-facing menu options, keep the direct command route and the
menu route invoking the same mq-agent command, and update `docs/COMMANDS.md`.

## Command design rules

* Prefer short, memorable command names.
* Keep aliases intentional and documented.
* Make destructive commands explicit, guarded, and visible.
* Provide clear empty, error, and missing-dependency states.
* Keep output compact enough for repeated terminal use.
* Preserve existing menu style, color conventions, and return behavior.
* Do not hide important commands only inside interactive menus.

## zsh menu safety: never assign to `status`

`terminal/launchers/gitlaunch.sh` runs under `#!/bin/zsh`, where `status` is a
read-only special parameter — zsh's own name for `$?`. Assigning to it aborts
the enclosing function on the spot:

```zsh
local status          # fine, declaration alone is allowed
local status=0        # f: read-only variable: status — function ends here
status=$?             # same, and this is the form a menu actually writes
```

The failure is nastier than it looks, because it is silent and conditional. The
submenu loop is correct; it simply never gets to run again, so the caller
redraws mqlaunch's main menu and the operator sees a menu that "jumps back"
after a successful command. Use a specific name: `push_status`, `commit_status`,
`command_status`.

When testing a fix like this, drive the **successful** path. A cancelled
confirmation returns before reaching the assignment, so the bug cannot fire and
the test passes while the product stays broken.
`tests/mq-git-protected-push-smoke.sh` holds the regression test for the
successful push path.

## Consistency checks

After a command change, check whether these need updates:

* `docs/COMMANDS.md`
* `README.md` common commands
* help menu text
* direct dispatch in `mqlaunch-command-mode.sh`
* interactive menu option
* HAL bridge or raw intent examples
* smoke tests
* release notes or changelog, if user-facing

After a menu/GUI change, also check:

* the menu can run when sourced by `terminal/launchers/mqlaunch.sh`
* the menu can run standalone with its fallback UI loading
* visual rows fit through `surface_terminal_width`
* prompt label matches the menu name
* the direct command route and interactive menu route invoke the same behavior
* screenshots or docs under `docs/screenshots/` need updating

## Verification

Prefer lightweight checks:

```bash
bash -n terminal/launchers/mqlaunch-command-mode.sh
bash -n terminal/launchers/mqlaunch.sh
bash -n terminal/menus/<changed-menu>.sh
./tests/hal-command-surface-smoke.sh
./tests/hal-menu-smoke.sh
./tests/hal-menu-layout-smoke.sh
```

Run narrower checks when the change only touches one menu or script.

## Output

Report:

* command/menu surfaces touched
* docs updated or intentionally left unchanged
* checks run
* any command behavior left unverified
