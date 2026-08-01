# Runtime Authority Map

The path inventory that says which paths are **live runtime**, which are a
**compatibility bridge to legacy code**, which are **dead**, and which are
**test-only**. The stable governance boundary and single-authority decision live
in [RUNTIME_AUTHORITY.md](RUNTIME_AUTHORITY.md); this map records current
reachability so a contributor can tell where a fix belongs without guessing.
The detailed migration plan lives in
[plans/P1-runtime-authority.md](plans/P1-runtime-authority.md).

Verified against the repo on **2026-07-24** by tracing actual `source`/subprocess
edges from the entry points. Re-verify (and update this file) whenever a bridge,
menu, or launcher path changes — the Step 10 CI freeze check fails if a new
live→legacy edge appears.

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

`tools/scripts/mqlaunch_desktop.sh` was listed here as an "alternate live entry"
and was not one. It has been deleted; see the DEPRECATED section.

`tests/runtime-authority-classification-smoke.sh` now holds this table to the
claim it makes: a path listed here must either sit in `bin/`, which `install.sh`
links onto `PATH` wholesale, or be named by a tracked file outside `docs/` and
`tests/` — with comment lines dropped first, because prose explaining why
something is *not* live reads exactly like a caller to a grep.

## Runtime coordinator — LIVE

| Path | Role |
| --- | --- |
| `terminal/launchers/mqlaunch.sh` | Current runtime coordinator (1078 lines) |
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

`terminal/menus/mq-git-menu.sh` was listed here as reached "via
`mqlaunch_desktop.sh` (LIVE)", which was its only claimed route. See the
DEPRECATED section — `mqlaunch git` opens `terminal/launchers/gitlaunch.sh`.

## Shared UI and dashboards — LIVE

| Path | Role | Authority |
| --- | --- | --- |
| `ui/terminal-ui/mq-ui.sh` | Shared UI library (rendering, padding, git-status snapshot, `print_header`) | **UI authority** (26 live references) — sole owner of `print_header`; the launcher no longer overrides it (Step 11a) |
| `ui/ascii/mqlaunch-dashboard-v7.1.sh` | Branded dashboard | **Dashboard authority** |
| `ui/dashboards/mq-dashboard.sh` | Status dashboard used by the tools menu / theme manager | secondary, keep until folded into the authority |

## Support libraries — LIVE

| Path | Reached from |
| --- | --- |
| `mqlaunch/lib/recommendations/*` | `terminal/menus/recommendations-menu.sh` |
| `mqlaunch/lib/mqobsidian/*` | `terminal/menus/mq-obsidian-menu.sh` |
| `mqlaunch/lib/network.sh` | `terminal/launchers/mqlaunch.sh` (sourced) — network concern de-layered out of the monolith (Step 11a) |
| `mqlaunch/lib/fzf-pickers.sh` | `terminal/launchers/mqlaunch.sh` (sourced) — fzf interactive pickers de-layered out of the monolith (Step 11a) |
| `mqlaunch/lib/diagnostics.sh` | `terminal/launchers/mqlaunch.sh` (sourced) — version/self-check/debug-bundle/release-notes/system-check de-layered out of the monolith (Step 11a) |
| `mqlaunch/lib/git-menus.sh` | `terminal/launchers/mqlaunch.sh` (sourced) — git & release menu launchers de-layered out of the monolith (Step 11a) |
| `mqlaunch/lib/repo-picker.sh` | `terminal/launchers/mqlaunch.sh` (sourced) — GitHub repo picker de-layered out of the monolith (Step 11a) |

## Bridges

| Path | Class | Why |
| --- | --- | --- |
| `terminal/bridges/hal-bridge.sh` | **LIVE** | routes to `mq-hal`; no `mqlaunch-v1` reach |
| `terminal/bridges/brain-bridge.sh` | **LIVE** | routes to the mqobsidian brain surface; no v1 reach |
| `terminal/bridges/performance-bridge.sh` | **COMPAT** | invokes `terminal/mqlaunch-v1/mqlaunch.sh` as a subprocess |
| `terminal/bridges/dev-bridge.sh` | **DEPRECATED** | inert tombstone; v1 routing retired in Step 12.1 |
| `terminal/bridges/tools-bridge.sh` | **COMPAT** | invokes `terminal/mqlaunch-v1/mqlaunch.sh` |

## Legacy runtime — COMPAT

| Path | Class | Reachability |
| --- | --- | --- |
| `terminal/mqlaunch-v1/**` (24 files, 1629 shell LOC) | **COMPAT** | Reachable only through the compat edges below |
| `terminal/menus/mq-performance-menu.sh` | **COMPAT** | Live menu, but sources v1 directly (see edges) — a compat wrapper until migrated |

### The exact live→legacy edges (remove these in Step 12)

These three edges are the *entire* reason `mqlaunch-v1` is still live. Migrating
them off v1 lets the tree be reclassified `DEPRECATED` and deleted:

* `terminal/bridges/performance-bridge.sh` → subprocess `terminal/mqlaunch-v1/mqlaunch.sh`
* `terminal/bridges/tools-bridge.sh` → subprocess `terminal/mqlaunch-v1/mqlaunch.sh`
* `terminal/menus/mq-performance-menu.sh:26` → **sources** `terminal/mqlaunch-v1/commands/performance.sh` (the only direct live-menu → v1 `source`)

### Enforcement (Step 10 freeze)

`scripts/check-runtime-authority.sh` is the freeze gate. It scans live runtime
shell (`terminal/`, `ui/`, `mqlaunch/`, excluding the v1 tree) and fails if any
file **not** on the compat allowlist references `mqlaunch-v1`. The allowlist is
exactly the three edges above; keep it in sync with this file. The check runs in
CI (Quality → *Runtime authority freeze*) and locally via
`tests/runtime-authority-freeze-smoke.sh`. Shrinking the allowlist is a Step 12
win; growing it must be a conscious, reviewed decision.

## Dead — DEPRECATED

| Path | Why |
| --- | --- |
| `terminal/menus/mq-git-menu.sh` (773 lines) | Nothing opens it; command mode still works |

`tools/scripts/mqlaunch_desktop.sh` was classified as an "alternate live entry"
until 2026-08-01 and has been deleted. Nothing in the repo invoked it — the only
two tracked mentions were comments in `inventory-command-surfaces.py` explaining
why it was excluded from the command-surface count. It was not in `bin/`, not
linked from `/usr/local/bin`, not named in a shell rc, and there was no
LaunchAgent, Raycast or Alfred integration on the machine this was checked on.

It was a second dispatcher, not a wrapper: 1104 lines, 63 numbered menu arms,
its own `eval "$cmd"`, and its own command vocabulary — `theme-amber`,
`theme-green`, `theme-ice`, `netlaunch`, `gitlaunch` — none of which exist in
`mqlaunch/lib/command-registry.json`. It knew nothing of `agent`, `obsidian`,
`hal`, `theme apply` or `repos`. It was a snapshot of an older mqlaunch, and the
"Forbidden" rule at the end of this file names exactly that shape: parallel
implementations of the same menu responsibility.

`mq-git-menu.sh` was live only because `mqlaunch_desktop.sh` was. `mqlaunch git`
opens `terminal/launchers/gitlaunch.sh` instead. The menu itself —
`print_git_menu`, `git_menu_loop`, `repo_submenu_loop` — is now reachable only
by executing the file directly.

Its command mode is not dead, which is why the file is still here:
`mq-git-menu.sh log|status|...` is a supported and documented entry
([COMMANDS.md](COMMANDS.md)), and three tests drive its functions
(`git-menu-surface-smoke.sh`, `git-restore-to-base-smoke.sh`,
`mq-git-protected-push-smoke.sh`).

Nine function names are shared with `gitlaunch.sh`, including the whole
protected-push chain, and the two implementations have already diverged:

| Function | `gitlaunch.sh` | `mq-git-menu.sh` |
| --- | --- | --- |
| `protected_branch_names` | 3 lines | identical |
| `is_protected_branch` | 7 lines | identical |
| `pr_aware_push` | 33 lines | 22 — different signature, no detached-HEAD block |
| `create_pr_branch_for_push` | 54 lines | 36 |
| `safe_push` | 26 lines | 64 |
| `analyze_diff` | 63 lines | 65 |
| `suggest_commit` | 13 lines | 44 |
| `next_action` | 40 lines | 48 |

`gitlaunch.sh` refuses to push from a detached HEAD; `mq-git-menu.sh` takes the
branch as an argument and leaves that to its caller. `mq-git-menu.sh` operates
on `$CURRENT_REPO` via `git -C`; `gitlaunch.sh` operates on the working
directory. Two designs, not two copies — which is why this is recorded rather
than deduplicated in passing.

`terminal/menus/mq-hal-menu.sh.bak.20260519-115142` was listed here as an editor
backup that PR #32 had missed. It is not in the repository and never was.
`.gitignore` has matched `terminal/menus/*.bak.*` since 2026-04-12 and the file
is dated 2026-05-19, so it was never trackable: `git log --all` on the path is
empty, and the path returns 404 on `main`. It exists only in the working copy
that produced it, where this map has no authority. Listing it was a claim about
the repository read out of a working directory instead of out of `git ls-files`.

`ui/ascii/mq-dashboard.sh`, `ui/ascii/mq-dashboard-v3.sh` and
`ui/ascii/mq-banner.sh` were listed here as safe-to-delete candidates and have
been removed. Dashboards `v4`/`v5`/`v6` and the stray `*.sh.bak` files that
existed at the time went in PR #32.

`ui/ascii/mqlaunch-dashboard-v7.1.sh` remains the dashboard authority. The
deleted files were earlier attempts at the same job that nothing routed to; one
of them had been raising `bad substitution` mid-render for long enough that
ShellCheck, not a user, was the first to notice.

A path belongs in this section only while something still points at it. Once
nothing does, the entry is a promise to delete rather than a classification —
so the list should return to empty each time it is acted on.

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
