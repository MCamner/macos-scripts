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

The newer direction in this repo is to keep `mqlaunch` as a thin coordinator and move menu behavior into modules in this folder.

## What belongs here

Use this folder for:

- reusable submenu logic
- standalone terminal tools
- menu-driven workflow modules
- extracted command groups from larger launchers

## Current files

### `mq-tools-menu.sh`
A reusable tools menu built on top of shared terminal UI helpers.

### `mq-main-menu.sh`
The extracted main menu renderer and top-level selection router used by `mqlaunch`.

### `mq-help-menu.sh`
The extracted help and command index module used by `mqlaunch`.

### `mq-dev-menu.sh`
The extracted Prompt Tools menu used by `mqlaunch` for prompts, launcher maintenance, and repo-adjacent editing tasks.

### `mq-ai-menu.sh`
The extracted AI modes menu used by `mqlaunch` for prompt and assistant entrypoints.

### `mq-net-menu.sh`
The extracted network menu used by `mqlaunch` for quick connectivity and network utilities.

### `mq-git-menu.sh`
An interactive git workspace for status, commit prep, safe push, log review, and repo navigation.

### `mq-shortcuts-menu.sh`
An interactive menu for listing, searching, running, and viewing macOS Shortcuts.

### `mq-login-menu.sh`
An interactive menu for session boot flows built on top of `mqlogin.sh`.

### `mq-release-menu.sh`
An interactive menu for dry-run releases, live releases, changelog review, and GitHub release creation.

### `mq-workflows-menu.sh`
An interactive menu for project workflows, including `project-boot.sh` and workflow documentation entrypoints.

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
