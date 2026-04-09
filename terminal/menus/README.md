# Menus

Reusable terminal menu modules for `macos-scripts`.

This folder is meant for extracted or standalone menu-driven tools that can be used outside the main launcher.

---

## Purpose

The `menus/` area exists to make terminal workflows more modular.

Instead of putting every flow directly inside `mqlaunch.sh`, reusable menu modules can live here and be called when needed.

That makes the system easier to grow, test, and maintain.

---

## Current direction

This folder is intended for:

- reusable submenu logic
- standalone terminal tools
- menu-driven workflow modules
- extracted command groups from larger launchers

---

## Current file

### `mq-tools-menu.sh`

A reusable tools menu built on top of:

```bash
ui/terminal-ui/mq-ui.sh
