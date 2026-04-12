# Workflows

Reusable workflow scripts for macOS tasks and project automation.

This directory contains higher-level scripts that orchestrate multiple steps into a single command.
While `mqlogin` focuses on starting a personal session, workflows are designed to automate repeatable tasks across projects.

---

## Purpose

Workflows provide:

* structured automation for common tasks
* repeatable project setup routines
* a place for multi-step scripts that don’t belong in simple tools

They sit between:

* `tools/` → small, reusable utilities
* `automation/login/` → personal session boot
* `automation/shortcuts/` → macOS Shortcuts integration

---

## Included

### `project-boot.sh`

Bootstraps a project workspace.

Typical responsibilities:

* detect or validate project root
* open project folder
* open editor (e.g. VS Code)
* prepare terminal context
* optionally run setup or checks

---

## Usage

Run directly from repo root:

```bash
bash automation/workflows/project-boot.sh
```

Make executable:

```bash
chmod +x automation/workflows/project-boot.sh
./automation/workflows/project-boot.sh
```

---

## Design Principles

Workflows should:

* be idempotent (safe to run multiple times)
* fail gracefully if dependencies are missing
* provide clear output
* avoid hardcoded paths when possible

---

## Relationship to mqlaunch

Workflows can be:

* run directly from the terminal
* integrated into `mqlaunch` menus later

Recommended pattern:

* keep logic in `automation/workflows/`
* expose via `mqlaunch` when stable

---

## Future Ideas

* `project-check.sh` → validate project health
* `project-sync.sh` → pull, rebase, clean state
* `env-setup.sh` → bootstrap dev environment
* `workspace-reset.sh` → clean + restart session

---

## Summary

* `login` = start your session
* `workflows` = automate your work
* `tools` = build the pieces

Together they form a structured command system rather than a loose script collection.

