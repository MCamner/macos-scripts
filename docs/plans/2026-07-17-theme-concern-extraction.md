# Theme Concern Extraction Implementation Plan

## Goal

Move shared theme command and status behavior out of the launcher and theme menu
into one live library without changing the public command surface.

## Owner repo

macos-scripts

## Secondary repos

None.

## Architecture boundary

* `macos-scripts` owns the `mqlaunch` launcher, menus, local theme actions, and
  terminal UX.
* No orchestration, cognition, durable memory, or cross-repo behavior moves into
  the shell library.

## Non-goals

* Redesigning the theme menu.
* Changing theme names, routes, output, or mutation behavior.
* Refactoring unrelated launcher responsibilities.

## Approval gates

* Before file writes: approved by the user request.
* Before commit: yes.
* Before push/merge: yes.
* Before deletion/settings changes: yes.

## Test gates

* `bash tests/theme-lib-smoke.sh`
* `bash tests/monolith-delayer-smoke.sh`
* `bash -n mqlaunch/lib/themes.sh`
* `zsh -n terminal/launchers/mqlaunch.sh`
* `bash -n terminal/menus/mq-themes-menu.sh`
* `bash tests/headless-smoke.sh`
* `bash tests/mq-stack-contract-smoke.sh`

## Rollback

Revert the theme library, restore the verbatim functions in the launcher and
theme menu, and remove the focused smoke test.

### Task 1: Add the theme-library contract test

**Purpose:** Lock shared ownership, sourcing, argument forwarding, and status
fallback behavior before moving code.

**Files:**

* Create: `tests/theme-lib-smoke.sh`

### Task 2: Extract the theme concern

**Purpose:** Make one live library authoritative for theme actions and status.

**Files:**

* Create: `mqlaunch/lib/themes.sh`
* Modify: `terminal/launchers/mqlaunch.sh`
* Modify: `terminal/menus/mq-themes-menu.sh`
* Modify: `tests/monolith-delayer-smoke.sh`
* Modify: `tools/scripts/test-all.sh`

### Task 3: Verify and summarize

**Purpose:** Prove behavior and architecture boundaries remain intact.

**Files:**

* Read-only reference: `docs/AUTHORITY_MAP.md`
* Read-only reference: `docs/plans/v2.0.0-sequencing.md`

**Commit suggestion:**

`refactor(mqlaunch): extract shared theme concern`
