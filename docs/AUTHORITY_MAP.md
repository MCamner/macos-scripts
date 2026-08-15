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
| `bin/gitlaunch` | Wrapper, not an entrypoint: `exec bin/mqlaunch git "$@"` |

`tools/scripts/mqlaunch_desktop.sh` was listed here as an "alternate live entry"
and was not one. It has been deleted; see the DEPRECATED section.

`tests/runtime-authority-classification-smoke.sh` now holds this table to the
claim it makes: a path listed here must either sit in `bin/`, which `install.sh`
links onto `PATH` wholesale, or be named by a tracked file outside `docs/` and
`tests/` — with comment lines dropped first, because prose explaining why
something is *not* live reads exactly like a caller to a grep.

Everything executable under `bin/` is what `install.sh` symlinks onto `PATH`,
and the links point *at* `bin/` rather than past it — `mqlaunch repl` is routed
in `bin/mqlaunch` and nowhere else, so a link straight to
`terminal/launchers/mqlaunch.sh` loses it. Held by
`tests/install-contract-smoke.sh`.

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
| `terminal/bridges/performance-bridge.sh` | **LIVE** | loads `mq-performance-menu.sh`; the v1 fallback is gone |
| `terminal/bridges/dev-bridge.sh` | **DEPRECATED** | inert tombstone; v1 routing retired in Step 12.1 |

`terminal/bridges/tools-bridge.sh` was here as **COMPAT**. Neither
`open_v1_tools_menu` nor `run_v1_tools_command` had a caller anywhere in the
tree, so it was deleted rather than kept working.

## Legacy runtime — DELETED

`terminal/mqlaunch-v1/` is gone as of 2026-08-02: 23 files, 1125 shell LOC, plus
its own `tools/scripts/test-mqlaunch-v1.sh`. It was the last legacy runtime and
the last duplicate UI implementation — it shipped its own `lib/ui.sh` alongside
`ui/terminal-ui/mq-ui.sh` — so removing it closes the v2.0.0 definition-of-done
items for both.

### The live→legacy edges went first (#160)

There were four, and none was retired by weakening a gate:

* `terminal/menus/mq-performance-menu.sh:26` sourced `commands/performance.sh`
  out of the tree — the only direct live-menu → v1 `source`, and the one real
  dependency. 504 lines of working `perf_*` readings, so the tree was classified
  live in order to supply code rather than to keep a legacy route open. Moved
  verbatim to `mqlaunch/lib/performance.sh`.
* `terminal/bridges/tools-bridge.sh` forwarded `tools` to the v1 launcher as a
  subprocess. Deleted: no callers.
* `terminal/bridges/performance-bridge.sh` fell back to the v1 launcher when the
  current menu was missing. It reports and returns 1 now.
* `tools/scripts/create-debug-bundle.sh` ran the v1 launcher's `help` as a
  health probe from `mq-system-menu.sh` option 6.

`automation/login/mqlogin.sh` was a fifth, fixed a day earlier: it preferred the
frozen launcher over the current runtime in `detect_mqlaunch_base`.

### What deleting it edited

Nothing that ran. Seven tooling files named the tree to exclude, test or police
it, which is exactly the distinction the gate's two lists were built to make:

```text
tools/scripts/test-mqlaunch-v1.sh      deleted with the tree
tools/scripts/test-all.sh              v1 selftest block removed
tools/scripts/test-mqlaunch.sh         v1 launcher assertions removed
tools/scripts/lint.sh                  exclusion had nothing left to exclude
tools/scripts/shellcheck-report.sh     same
tools/scripts/generate-wiki-command-ref.sh  same
scripts/check-runtime-authority.sh     became a tombstone gate
```

The lint surface went from 189 files to 188 and stayed clean at warning
severity: four of the five exempt SC2034 findings left with the tree.

### Enforcement (Step 10 freeze)

`scripts/check-runtime-authority.sh` is the freeze gate, and a tombstone gate
since the tree was deleted: a path that no longer exists cannot be depended on
by accident, but it can be recreated, and a second runtime is what the v2.0.0
track spent its length removing. It scans every tracked shell file except
`tests/`, which plants references on purpose to prove the gate still fires, and
fails if any file names the deleted tree without being classified. The file list
comes from `git ls-files`, so an untracked copy of a menu in the working tree can
neither add an edge nor hide one.

Scope was `terminal/`, `ui/` and `mqlaunch/` until 2026-08-01 — narrower than
"live runtime shell", which is how the `create-debug-bundle.sh` and `mqlogin.sh`
edges went unrecorded. A gate that does not scan a directory makes no claim
about it.

Two lists, because widening the scan pulled in files that name v1 without
depending on it:

* `COMPAT_EDGES` — live code that reaches v1 at runtime. **Empty, permanently.**
  A non-empty list means someone reintroduced the legacy runtime.
* `TOOLING` — scripts that name the tree without depending on it. Seven when the
  tree existed; two now, and both name it in order to assert its absence.

Keep both in sync with this file. The check runs in CI (Quality → *Runtime
authority freeze*) and locally via `tests/runtime-authority-freeze-smoke.sh`,
which plants an edge in `automation/` and one in `tools/` to prove the widened
scope is real rather than declared.

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
* `mqlaunch/lib/pulse/model.sh` — the v2.1.0 Pulse status model
  ([PULSE_CONTRACT.md](PULSE_CONTRACT.md)). It sits on the authority-owned path
  and is written for the runtime, but nothing on the runtime sources it yet:
  the contract landed before the first collector, deliberately, so the states
  and exit codes were fixed before anything depended on them. It moves to the
  support-library table when `mqlaunch pulse` dispatches.

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
