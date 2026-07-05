# P1 — Consolidate mqlaunch Runtime Authority

**Status:** Planned
**Priority:** P1
**Type:** Architecture / Runtime consolidation
**Risk if delayed:** High
**Owner:** mqlaunch
**Goal:** Replace parallel runtime authority with one explicit live architecture
and a controlled compatibility boundary.

Linked from [ROADMAP.md](../../ROADMAP.md). This is the detailed plan; the
roadmap carries only the compact entry.

## Runtime facts (verified against repo, 2026-07-05)

Grounding for the classification below. Verified in this repo, not assumed:

* Live entrypoint chain: `bin/mqlaunch` → `terminal/launchers/mqlaunch.sh`
  (~2082-line coordinator) → sources `ui/terminal-ui/mq-ui.sh`,
  `terminal/menus/*`, `terminal/bridges/*`, and `mqlaunch/lib/{recommendations,mqobsidian}`.
* Bridges that still source `terminal/mqlaunch-v1/`: `performance-bridge.sh`,
  `dev-bridge.sh`, `tools-bridge.sh`. `hal-bridge.sh` and `brain-bridge.sh` do
  **not** reach v1.
* The only **live menu** reaching v1 directly today is
  `terminal/menus/mq-performance-menu.sh:26`, which sources
  `terminal/mqlaunch-v1/commands/performance.sh`. This is the concrete
  forbidden-direction violation Phase 4 must remove.
* Current dashboard authority is `ui/ascii/mqlaunch-dashboard-v7.1.sh` (the only
  dashboard on a live path); its render already delegates git-status parsing to
  `mq_git_status_snapshot` in `mq-ui.sh` (P3, done).
* `terminal/mqlaunch-v1/` is ~1629 LOC across 24 files, reachable only through
  the three bridges above and test/tooling scripts.

## Why this matters

mqlaunch currently carries overlapping architectural paths that make runtime
authority unclear. That ambiguity increases bug risk, slows changes, preserves
hidden legacy dependencies, and makes safe cleanup harder than it should be.

This is not a cosmetic cleanup item. It is a runtime-governance problem.

## Current problem

The repo currently behaves as if three architectural truths exist at once:

* a live launcher-centered runtime path
* a legacy modular v1 path still reachable through bridges
* a newer modular library path already used by selected menus

That creates four failure modes:

* fixes land in the wrong place
* duplicate behavior survives across generations
* legacy code remains live without being treated as live
* new contributors cannot tell where change authority belongs

## Target state

mqlaunch must have:

* one documented runtime authority
* one explicit compatibility boundary
* one current dashboard/UI authority
* one clear rule set for where new logic is allowed to live

Everything else must be marked as either `LIVE`, `COMPAT`, `DEPRECATED`, or
`TEST-ONLY`.

---

## Scope

### In scope

* define runtime authority
* classify runtime-relevant paths
* freeze further growth of legacy runtime surfaces
* document allowed import directions
* isolate or replace compat dependencies
* consolidate dashboard/UI authority

### Out of scope

* full rewrite of mqlaunch
* broad UI redesign
* unrelated menu feature work
* speculative restructuring of paths not used by current runtime

---

## Authority classification

### LIVE

* [ ] `bin/mqlaunch` is the official entrypoint
* [ ] `terminal/launchers/mqlaunch.sh` is the current runtime coordinator
* [ ] `terminal/menus/` is the official live menu layer
* [ ] `ui/terminal-ui/mq-ui.sh` is the shared live UI library
* [ ] `ui/ascii/mqlaunch-dashboard-v7.1.sh` is declared current dashboard authority
* [ ] `mqlaunch/lib/mqobsidian/*` is classified as live support library
* [ ] `mqlaunch/lib/recommendations/*` is classified as live support library

### COMPAT

* [ ] `terminal/bridges/performance-bridge.sh` is explicitly marked active compat
* [ ] `terminal/bridges/dev-bridge.sh` is explicitly marked fallback compat
* [ ] `terminal/bridges/tools-bridge.sh` is explicitly marked fallback compat
* [ ] `terminal/mqlaunch-v1/` is marked compat runtime dependency while still reachable
* [ ] `terminal/menus/mq-performance-menu.sh` is marked compat wrapper until migrated

### DEPRECATED / SHADOW

* [ ] non-authoritative `mqlaunch/` paths are marked non-runtime unless proven live
* [ ] legacy dashboard variants are marked non-current
* [ ] any duplicate implementation without runtime authority is marked deprecated

---

## Rules to lock now

* [ ] No new feature work in `terminal/mqlaunch-v1/`
* [ ] No new direct live dependencies on v1 commands or v1 libs
* [ ] No new business logic added to the monolith if a live module already owns that concern
* [ ] No duplicate dashboard or UI logic introduced outside the chosen authority path
* [ ] No path may be called "legacy" if it still participates in runtime without compat labeling

---

## Allowed dependency directions

### Allowed

* [ ] `bin/` → `terminal/launchers/`
* [ ] `terminal/launchers/` → `terminal/menus/`
* [ ] `terminal/menus/` → `ui/terminal-ui/`
* [ ] `terminal/menus/` → `mqlaunch/lib/`
* [ ] `terminal/menus/` → `terminal/bridges/` only where documented compat is required

### Not allowed

* [ ] live menus depending directly on `terminal/mqlaunch-v1/*`
* [ ] new logic added to bridges beyond routing/adaptation
* [ ] parallel implementations of the same menu responsibility across monolith, v1, and new modules
* [ ] dashboard rendering logic copied across multiple dashboard files
* [ ] hidden fallback paths without documentation

---

## Delivery plan

### Phase 1 — Declare reality

**Objective:** Document the actual runtime as it exists now.

* [x] Create `docs/AUTHORITY_MAP.md`
* [x] Mark each runtime-relevant path as `LIVE`, `COMPAT`, `DEPRECATED`, or `TEST-ONLY`
* [ ] Update repo documentation to reflect actual runtime authority
* [x] Document performance as an explicit compat exception
* [x] Declare the current dashboard authority

#### Exit criteria

* [ ] A new contributor can identify the current runtime entrypoint
* [ ] The repo documents which paths are live and which are compat
* [ ] Performance exception is explicit, not implied

---

### Phase 2 — Freeze architecture drift

**Objective:** Stop the repo from getting worse while migration is in progress.

* [ ] Freeze new feature work in `terminal/mqlaunch-v1/`
* [ ] Freeze new direct dependencies from live menus into v1
* [ ] Freeze new duplicated dashboard/UI logic
* [ ] Add comments or docs to every bridge explaining why it still exists
* [ ] Define one accepted location per concern for future fixes

#### Exit criteria

* [ ] No new change can land in v1 without explicit exception
* [ ] No new live logic increases bridge debt
* [ ] Teams stop treating all three architectures as equal options

---

### Phase 3 — Pull responsibility out of the monolith

**Objective:** Turn the launcher into orchestration, not a mixed logic container.

* [ ] Map current monolith responsibilities by concern
* [ ] Separate rendering, dispatch, git, network, obsidian, and recommendations responsibilities
* [ ] Move one concern at a time into clearly owned modules
* [ ] Keep launcher behavior stable while reducing internal decision weight
* [ ] Remove obsolete inline logic after replacement is verified

#### Exit criteria

* [ ] `mqlaunch.sh` acts primarily as coordinator
* [ ] major concerns have named ownership outside the monolith
* [ ] fixes no longer require guessing between launcher and modules

---

### Phase 4 — Reduce and remove compat

**Objective:** Eliminate live dependency on v1 where possible.

* [ ] Replace performance reliance on v1 with a current-path implementation
      (start at `terminal/menus/mq-performance-menu.sh:26`)
* [ ] Remove direct sourcing from new paths into `terminal/mqlaunch-v1/*`
* [ ] Shrink bridges into thin adapters only
* [ ] Remove bridges that no longer carry live traffic
* [ ] Reclassify v1 from `COMPAT` to `DEPRECATED` only when no live path reaches it

#### Exit criteria

* [ ] No live menu depends directly on v1
* [ ] Bridges exist only where strictly necessary
* [ ] v1 is no longer a hidden runtime dependency

---

## First cleanup PRs

### PR1 — Runtime authority declaration

* [ ] Add `docs/AUTHORITY_MAP.md`
* [ ] Document official entrypoint
* [ ] Document live menu layer
* [ ] Document compat paths
* [ ] Document forbidden dependency directions

### PR2 — Legacy freeze

* [ ] Mark `terminal/mqlaunch-v1/` as compat-only
* [ ] Add warnings in relevant READMEs
* [ ] Add bridge comments explaining temporary purpose
* [ ] State repo rule: no new feature work in v1

### PR3 — Dashboard and UI consolidation

* [ ] Choose one dashboard as current authority (v7.1)
* [ ] Mark others as legacy variants
* [ ] Move shared rendering into `ui/terminal-ui/mq-ui.sh`
* [ ] Remove or isolate duplicate rendering logic

---

## Definition of done

This initiative is complete only when all of the following are true:

* [ ] exactly one runtime authority is documented
* [ ] live paths and compat paths are explicitly classified
* [ ] no live menu depends directly on v1
* [ ] performance is either migrated or clearly isolated as compat
* [ ] launcher is orchestration-first, not mixed-responsibility
* [ ] dashboard/UI logic has one clear source of truth
* [ ] a contributor can identify where a fix belongs without guesswork

---

## Expected outcome

When this P1 is complete, mqlaunch will stop behaving like three partially
overlapping tools and start behaving like one governed runtime with an explicit
migration boundary.
