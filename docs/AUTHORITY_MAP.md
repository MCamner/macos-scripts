# Runtime Authority Map

The one place that says which paths are **live runtime**, which are a
**compatibility bridge to legacy code**, which are **dead**, and which are
**test-only**. It exists so a contributor can tell where a fix belongs without
guessing, and so the v2.0.0 migration (see
[ROADMAP.md](../ROADMAP.md) → *Phase 12 / v2.0.0 — Runtime Authority And Shell
Governance*, plan in [plans/P1-runtime-authority.md](plans/P1-runtime-authority.md))
has a concrete starting inventory.

Verified against the repo on **2026-07-05** by tracing actual `source`/subprocess
edges from the entry points. Re-verify (and update this file) whenever a bridge,
menu, or launcher path changes — the CI check proposed in Step 10 should fail if
a new live→legacy edge appears.

## Legend

* **LIVE** — on a real runtime path reachable from an entry point; new fixes for
  that concern belong here.
* **COMPAT** — still executed at runtime, but only as a bridge/wrapper to the
  legacy `mqlaunch-v1` tree. Allowed for now, frozen from growth, slated for
  removal in Step 12.
* **DEPRECATED** — present in the tree but not reachable from any entry point.
  Safe-to-delete candidates; keep no new dependencies on them.
* **TEST-ONLY** — reached solely by tests, smoke, or lint tooling.

## Entry points — LIVE

| Path | Role |
| --- | --- |
| `bin/mqlaunch` | Official entrypoint → `terminal/launchers/mqlaunch.sh`; `mqlaunch repl` → `mqlaunch-repl.sh` |
| `bin/mq` → `tools/cli/mq` | Secondary CLI entrypoint |
| `tools/scripts/mqlaunch_desktop.sh` | Desktop launch variant (alternate live entry) |

## Runtime coordinator — LIVE

| Path | Role |
| --- | --- |
| `terminal/launchers/mqlaunch.sh` | Current runtime coordinator (~2082 lines) |
| `terminal/launchers/mqlaunch-command-mode.sh` | CLI/command dispatch, sourced by the launcher |
| `terminal/launchers/mqlaunch-repl.sh` | Interactive REPL surface (`mqlaunch repl`) |

## Live menu layer — LIVE

Sourced directly by `terminal/launchers/mqlaunch.sh`:

* `mq-agent-menu.sh`, `mq-ai-menu.sh`, `mq-apps-menu.sh`, `mq-dev-menu.sh`,
  `mq-help-center-menu.sh`, `mq-help-menu.sh`, `mq-login-menu.sh`,
  `mq-main-menu.sh`, `mq-net-menu.sh`, `mq-obsidian-menu.sh`,
  `mq-release-menu.sh`, `mq-shortcuts-menu.sh`, `mq-system-menu.sh`,
  `mq-themes-menu.sh`, `mq-tools-menu.sh`, `mq-workflows-menu.sh`,
  `recommendations-menu.sh`

Reached through other live paths:

* `terminal/menus/mq-hal-menu.sh` — via `hal-bridge.sh` (LIVE)
* `terminal/menus/mq-git-menu.sh` — via `mqlaunch_desktop.sh` (LIVE)

## Shared UI and dashboards — LIVE

| Path | Role | Authority |
| --- | --- | --- |
| `ui/terminal-ui/mq-ui.sh` | Shared UI library (rendering, padding, git-status snapshot) | **UI authority** (26 live references) |
| `ui/ascii/mqlaunch-dashboard-v7.1.sh` | Branded dashboard | **Dashboard authority** |
| `ui/dashboards/mq-dashboard.sh` | Status dashboard used by the tools menu / theme manager | secondary, keep until folded into the authority |

## Support libraries — LIVE

| Path | Reached from |
| --- | --- |
| `mqlaunch/lib/recommendations/*` | `terminal/menus/recommendations-menu.sh` |
| `mqlaunch/lib/mqobsidian/*` | `terminal/menus/mq-obsidian-menu.sh` |

## Bridges

| Path | Class | Why |
| --- | --- | --- |
| `terminal/bridges/hal-bridge.sh` | **LIVE** | routes to `mq-hal`; no `mqlaunch-v1` reach |
| `terminal/bridges/brain-bridge.sh` | **LIVE** | routes to the mqobsidian brain surface; no v1 reach |
| `terminal/bridges/performance-bridge.sh` | **COMPAT** | invokes `terminal/mqlaunch-v1/mqlaunch.sh` as a subprocess |
| `terminal/bridges/dev-bridge.sh` | **COMPAT** | invokes `terminal/mqlaunch-v1/mqlaunch.sh` |
| `terminal/bridges/tools-bridge.sh` | **COMPAT** | invokes `terminal/mqlaunch-v1/mqlaunch.sh` |

## Legacy runtime — COMPAT

| Path | Class | Reachability |
| --- | --- | --- |
| `terminal/mqlaunch-v1/**` (24 files, ~1629 LOC) | **COMPAT** | Not reachable except through the compat edges below |
| `terminal/menus/mq-performance-menu.sh` | **COMPAT** | Live menu, but sources v1 directly (see edges) — a compat wrapper until migrated |

### The exact live→legacy edges (remove these in Step 12)

These four edges are the *entire* reason `mqlaunch-v1` is still live. Migrating
them off v1 lets the tree be reclassified `DEPRECATED` and deleted:

* `terminal/bridges/performance-bridge.sh` → subprocess `terminal/mqlaunch-v1/mqlaunch.sh`
* `terminal/bridges/dev-bridge.sh` → subprocess `terminal/mqlaunch-v1/mqlaunch.sh`
* `terminal/bridges/tools-bridge.sh` → subprocess `terminal/mqlaunch-v1/mqlaunch.sh`
* `terminal/menus/mq-performance-menu.sh:26` → **sources** `terminal/mqlaunch-v1/commands/performance.sh` (the only direct live-menu → v1 `source`)

## Dead — DEPRECATED

Present in the tree, no live reference found. Safe-to-delete candidates:

* `ui/ascii/mq-dashboard.sh`
* `ui/ascii/mq-dashboard-v3.sh`
* `ui/ascii/mq-banner.sh`

(Dashboards `v4`/`v5`/`v6` and stray `*.sh.bak` files were already removed in
PR #32.)

## Test / tooling — TEST-ONLY

* `tests/**`
* `tools/scripts/test-all.sh`, `test-mqlaunch.sh`, `test-mqlaunch-v1.sh`, `lint.sh`
* `scripts/install-smoke.sh` (smoke harness)

## Allowed dependency directions

* `bin/` → `terminal/launchers/`
* `terminal/launchers/` → `terminal/menus/`
* `terminal/menus/` → `ui/terminal-ui/`
* `terminal/menus/` → `mqlaunch/lib/`
* `terminal/menus/` → `terminal/bridges/` only where documented compat is required

### Forbidden

* live menus or launchers depending directly on `terminal/mqlaunch-v1/*`
  (one violation exists today: `mq-performance-menu.sh` — tracked above)
* new logic added to bridges beyond routing/adaptation
* parallel implementations of the same menu responsibility across the monolith,
  v1, and new modules
* dashboard rendering logic duplicated outside `ui/terminal-ui/mq-ui.sh` and the
  dashboard authority
