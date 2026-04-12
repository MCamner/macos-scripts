# Automation

Automation scripts and workflow surfaces for `macos-scripts`.

This directory contains higher-level automation that sits above one-off tools.
Some automation is personal and session-oriented, while some is project-oriented and repeatable across repos.

---

## Purpose

The `automation/` layer provides:

* structured automation for common tasks
* repeatable project setup routines
* session boot helpers
* macOS Shortcuts integration
* a place for multi-step scripts that don’t belong in simple tools

It sits between:

* `tools/` → small, reusable utilities
* `terminal/menus/` → interactive entry surfaces
* `mqlaunch` → top-level command launcher

---

## Structure

### `login/`

Personal session boot workflows.

Current entrypoint:

* `mqlogin.sh`

### `shortcuts/`

macOS Shortcuts automation and wrapper commands.

Current entrypoint:

* `mqshortcuts.sh`

### `workflows/`

Project-oriented automation flows.

Current entrypoint:

* `project-boot.sh`

---

## Usage

Run scripts directly from the repo root:

```bash
bash automation/login/mqlogin.sh
bash automation/shortcuts/mqshortcuts.sh list
bash automation/workflows/project-boot.sh
```

---

## Design Principles

Automation scripts should:

* be idempotent (safe to run multiple times)
* fail gracefully if dependencies are missing
* provide clear output
* avoid hardcoded paths when possible

---

## Relationship to mqlaunch

Automation can be:

* run directly from the terminal
* exposed via `mqlaunch` menus and commands

Current launcher-facing entrypoints include:

* `mqlaunch login`
* `mqlaunch shortcuts`
* `mqlaunch workflows`

---

## Future Ideas

* `project-check.sh` → validate project health
* `project-sync.sh` → pull, rebase, clean state
* `env-setup.sh` → bootstrap dev environment
* `workspace-reset.sh` → clean + restart session

---

## Summary

* `login` = start your session
* `shortcuts` = automate Shortcuts from the terminal
* `workflows` = automate project flows
* `tools` = build the pieces

Together they form a structured command system rather than a loose script collection.
