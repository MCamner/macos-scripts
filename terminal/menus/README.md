# Menus

Reusable terminal menu modules for `macos-scripts`.

This folder contains modular, menu-driven terminal tools that can be launched from the main launcher or run directly during development.

## Purpose

The `menus/` directory exists to keep terminal workflows modular.

Instead of placing every interactive flow directly inside `mqlaunch.sh`, reusable menu modules can live here and be called when needed.

This makes the system easier to:

- grow
- test
- maintain
- reuse across launchers and scripts

## What belongs here

Use this folder for:

- reusable submenu logic
- standalone terminal tools
- menu-driven workflow modules
- extracted command groups from larger launchers

## Current files

### `mq-tools-menu.sh`
A reusable tools menu built on top of shared terminal UI helpers.

### `mq-system-menu.sh`
A reusable system menu for quick macOS system actions and checks.

### `menu-template.sh`
A starter template for building new menu modules.

## Design rules

Each menu module should:

- be self-contained
- source shared UI helpers when available
- support standalone execution
- expose one main loop function
- keep actions separated into small functions
- exit cleanly back to caller

Recommended structure:

- `menu_header()`
- `show_menu()`
- `handle_choice()`
- `menu_loop()`

## Shared dependencies

Menus should prefer shared helpers from the project when available, for example:

- `ui/terminal-ui/mq-ui.sh`

If a shared helper is missing, the menu should degrade gracefully and still run.

## Running a menu directly

From the repo root:

```bash
bash terminal/menus/mq-tools-menu.sh
