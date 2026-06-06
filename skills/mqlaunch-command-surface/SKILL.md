---
name: mqlaunch-command-surface
description: Use when changing macos-scripts mqlaunch commands, terminal GUI menus, HAL routing, command aliases, help text, or CLI/TUI command-surface behavior.
---

# mqlaunch Command Surface

Maintain the `mqlaunch` command surface as a coherent terminal product.

## When to use

Use this skill when the user asks to:

- add, rename, remove, or route an `mqlaunch` command
- change terminal menus, HAL commands, help screens, or aliases
- build a new terminal GUI/menu/panel for mqlaunch
- improve command discoverability or command-mode behavior
- update docs after CLI/TUI changes
- review whether a new workflow belongs in `terminal/`, `tools/`, `automation/`, or `system/`
- keep direct CLI commands and interactive menus consistent

## When not to use

- Command contract generation — use `command-template-library`
- Backend or API-only changes with no CLI impact
- Semantic memory updates — use `semantic-memory-maintainer`
- Release validation — use `release-readiness`

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

- Source `ui/terminal-ui/mq-ui.sh` only when `surface_top` is not already available.
- Render boxes with `surface_panel_header`, `surface_row`, `surface_split_row`, and `surface_bottom`.
- Use two-column rows for menu actions so the visual rhythm matches other menus.
- Keep section labels short and uppercase: `OBSERVE`, `PLAN`, `TOOLS`, `DEBUG`, `MEMORY`.
- Include `b. Back` and `x. Exit launcher` unless the screen is not navigational.
- Use `read_main_choice "label"` for the pinned prompt when available.
- Provide standalone fallback prompts for direct script execution.
- Wrap `pause_enter` if the menu can run standalone.
- Keep business logic in commands, bridges, or tools; menu files should own presentation and routing.
- Do not invent a second UI framework, custom box drawing helpers, or one-off color palettes.

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

After a menu/GUI change, also check:

- the menu can run when sourced by `terminal/launchers/mqlaunch.sh`
- the menu can run standalone with its fallback UI loading
- visual rows fit through `surface_terminal_width`
- prompt label matches the menu name
- the direct command route and interactive menu route invoke the same behavior
- screenshots or docs under `docs/screenshots/` need updating

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

- command/menu surfaces touched
- docs updated or intentionally left unchanged
- checks run
- any command behavior left unverified
