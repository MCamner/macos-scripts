# Prompt Concern Extraction Implementation Plan

## Goal

Move prompt and AI-backend actions out of the live `mqlaunch` monolith without
changing their command or menu contracts.

## Owner repo

macos-scripts

## Secondary repos

None.

## Architecture boundary

* `macos-scripts` owns the `mqlaunch` runtime, prompt actions, menus, and tests.
* `mqobsidian` remains an optional prompt source and durable memory; it is not
  changed by this work.

## Non-goals

* Changing prompt storage, menu labels, routes, or backup format.
* Changing the AI backend.
* Migrating performance routes or other Step 11a concerns.

## Approval gates

* Before file writes: approved by the user's "kör det steget" instruction.
* Before commit: yes.
* Before push/merge: yes.
* Before deletion/settings changes: yes.

## Test gates

* `zsh -n terminal/launchers/mqlaunch.sh mqlaunch/lib/prompts.sh`
* `MACOS_SCRIPTS_HOME="$PWD" tests/prompt-lib-smoke.sh`
* `MACOS_SCRIPTS_HOME="$PWD" tests/monolith-delayer-smoke.sh`
* `MACOS_SCRIPTS_HOME="$PWD" tools/scripts/test-all.sh`

## Rollback

Restore the seven functions in `terminal/launchers/mqlaunch.sh`, remove the
library source block and concern-test registrations, then delete
`mqlaunch/lib/prompts.sh` and `tests/prompt-lib-smoke.sh`.

### Task 1: Lock the prompt contracts

**Purpose:** Prevent behavior drift while moving the concern.

**Files:**

* Create: `tests/prompt-lib-smoke.sh`
* Modify: `tools/scripts/test-all.sh`

**Steps:**

1. Test prompt-directory precedence and missing-directory failure.
2. Test all AI backend status states.
3. Test that AI modes are forwarded unchanged.
4. Register the test in the full selftest.

**Expected result:** The focused test fails until the shared library exists.

### Task 2: Extract the prompt concern

**Purpose:** Continue Step 11a with one concern and one live definition.

**Files:**

* Create: `mqlaunch/lib/prompts.sh`
* Modify: `terminal/launchers/mqlaunch.sh`
* Modify: `tests/monolith-delayer-smoke.sh`

**Steps:**

1. Move the seven prompt and AI functions to the zsh library.
2. Source the library from the launcher with the existing debug fallback.
3. Register all seven functions in the monolith de-layering gate.
4. Run focused syntax and behavior tests.

**Expected result:** Routes and menus keep working while the launcher no longer
defines the prompt concern.

### Task 3: Verify the complete runtime

**Purpose:** Catch cross-concern regressions.

**Files:**

* Read-only reference: `tools/scripts/test-all.sh`

**Steps:**

1. Run the full selftest with `MACOS_SCRIPTS_HOME` set to this worktree.
2. Inspect status and diff.
3. Stop before commit and report results.

**Expected result:** All tests pass and only the scoped files differ.
