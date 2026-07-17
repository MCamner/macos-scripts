# Roadmap Concern Sync Implementation Plan

## Goal

Reflect completed markdownlint, theme, and prompt work in the macos-scripts
roadmap while keeping the next legacy-runtime migration visibly open.

## Owner repo

macos-scripts

## Secondary repos

None.

## Architecture boundary

* `macos-scripts` owns `mqlaunch` runtime, menus, compatibility, and tests.
* Other MQ repositories remain unchanged.

## Non-goals

* Marking Delivery D complete.
* Marking legacy runtime removal complete.
* Merging or rebasing branch history.

## Approval gates

* Before file writes: approved by the user's "fixa det" instruction.
* Before commit: yes.
* Before push/merge: yes.
* Before deletion/settings changes: yes.

## Test gates

* `tests/mq-stack-contract-smoke.sh`
* `git diff --check`
* Public-safe scan of changed Markdown.

## Rollback

Revert the roadmap checklist and completed-work additions, then remove this plan.

### Task 1: Record completed concern work

**Purpose:** Make completed work visible as checked roadmap items.

**Files:**

* Modify: `ROADMAP.md`

**Steps:**

1. Add checked items for markdownlint and the theme/prompt extractions.
2. Add an unchecked item for the remaining performance migration from v1.
3. Add concise completed-work summaries.
4. Run the test gates and stop before commit.

**Expected result:** The roadmap distinguishes completed Step 11a work from the
remaining Phase 12 legacy dependency.

**Commit suggestion:**

`docs(roadmap): record completed mqlaunch concerns`
