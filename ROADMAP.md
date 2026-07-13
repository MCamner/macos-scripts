# Roadmap

Current version: 1.0.0

## Purpose

`macos-scripts` owns the local terminal entrypoint for the MQ stack.
`mqlaunch` should make the right workflow easy to find and run, while deeper
planning, review, memory, and execution logic stay in the repos that own them.

Current focus: `v1.0.1` release readiness hardening, roadmap freshness, and
stack-surface verification.

## Design Boundary

```text
mqlaunch shows menu -> delegates -> mq-agent orchestrates -> mq-mcp executes
                                      mqobsidian stores truth and memory
```

`mqlaunch` may:

* show menus, command shortcuts, and local status
* open documented Obsidian views through the mqobsidian manifest/consumer lib
* run read-only checks and status commands
* delegate orchestration to `mq-agent`, `mq-hal`, `repo-signal`, and `mq-mcp`

`mqlaunch` must not:

* implement review, risk, or architecture logic itself
* call mq-mcp tools directly when `mq-agent` owns the workflow
* parse, score, or promote semantic memory in shell scripts
* make Obsidian truth-schema decisions locally

## Repo Ownership

| Repo/layer | Owns | `mqlaunch` relationship |
| --- | --- | --- |
| `mqlaunch` / `macos-scripts` | Terminal entrypoint, menus, shortcuts, operator UX | Show and delegate |
| `mq-agent` | Orchestration, planning, promotion flow, cross-tool workflows | Primary target for mutating/intelligent commands |
| `mq-mcp` | Runtime tools, review, safety, cognition, memory APIs | Reached through `mq-agent` |
| `mqobsidian` | Single source of truth, schemas, canonical paths, dashboards | Open/read exported views; do not own schemas |
| `repo-signal` | Readiness, publishability, quality signals | Read status and release gates |
| `mq-hal` | Operator brief, local cockpit, read-only status summaries | Delegate HAL surface |
| `mq-ums` | External infrastructure signals | Future read-only signal source |

## Priority Model

1. Keep `mqlaunch` thin and predictable.
2. Make Obsidian truth visible without moving ownership into shell.
3. Prefer read-only proof commands before mutating workflows.
4. Promote repeated learnings only through a review-gated `mq-agent` flow.
5. Keep B2/Atlas as a useful prompt surface, not the owner of stack truth.

## P1: Consolidate mqlaunch Runtime Authority

Status: Planned · Priority: P1 · Risk if delayed: High · Owner: `mqlaunch`

mqlaunch currently behaves as three partially overlapping runtimes at once: the
live launcher-centered path, a legacy modular `terminal/mqlaunch-v1/` path still
reachable through bridges, and a newer `mqlaunch/lib/` module path used by some
menus. Resolving that is the headline architecture item for the next release. It
is developed below as **[Phase 12 / v2.0.0](#phase-12--v200--runtime-authority-and-shell-governance)**,
with the detailed engineering plan in
[docs/plans/P1-runtime-authority.md](docs/plans/P1-runtime-authority.md) and the
workstream sequencing (owners, dependencies, `Not before` gating, risk register)
in [docs/plans/v2.0.0-sequencing.md](docs/plans/v2.0.0-sequencing.md).

## P1: CLI Contract And Automation Safety

**Status:** Planned
**Priority:** P1
**Risk if delayed:** High
**Owner:** `macos-scripts`
**Secondary repos:** none; delegated commands keep their existing owners

Goal: make every direct `mqlaunch` command predictable for humans, scripts, and
delegated MQ tools without expanding shell into orchestration or cognition.

### Verified baseline — 2026-07-14

* [x] `repo-signal doctor` reports 100/100 repo health, docs quality, and AI readiness
* [x] `mqlaunch workflows validate` passes 16 checks with no warnings
* [x] `mqlaunch selftest` passes, including syntax checks for 148 shell files
* [x] `mqlaunch doctor --json` emits valid machine-readable health output
* [ ] unknown commands currently copy an AI prompt and return success instead of
  reporting a usage error
* [ ] namespace help is inconsistent; for example, `mqlaunch obsidian --help`
  reports an error, opens a menu, and returns success
* [ ] delegated failures can be swallowed; backend failure does not always reach
  the caller's exit status
* [ ] `mqlaunch help`, `mqlaunch commands`, docs, palette, and dispatch contain
  overlapping command inventories that can drift
* [ ] `NO_COLOR=1 mqlaunch commands` still emits ANSI/dashboard output when piped
* [ ] CI ShellCheck is warn-only because findings are ignored with `|| true`

### Architecture boundary

* [x] `mqlaunch` owns argument parsing, help, output mode, exit-code propagation,
  menus, and terminal UX
* [x] `mq-agent` continues to own orchestration and delegated workflow semantics
* [x] `mq-mcp` continues to own execution tools and safety classes
* [x] `mqobsidian` continues to own durable truth and memory contracts
* [ ] no CLI-hardening task may move delegated business logic into shell

### Non-goals

* [x] no new AI fallback for unknown commands
* [x] no rewrite of `mq-agent`, `mq-mcp`, `mq-hal`, or mqobsidian contracts
* [x] no broad menu redesign
* [x] no removal of compatibility routes before Phase 12 gates allow it
* [x] no global JSON mode for commands that do not have a stable JSON contract

### Delivery A: Strict unknown-command contract

**Files:**

* [ ] modify `terminal/launchers/mqlaunch.sh`
* [ ] modify `terminal/launchers/mqlaunch-command-mode.sh` if it owns a parallel
  unknown-command path
* [ ] create `tests/unknown-command-contract-smoke.sh`
* [ ] update `docs/COMMANDS.md`

Tasks:

* [ ] write unknown-command diagnostics to stderr
* [ ] return exit code `2` for unknown commands and invalid arguments
* [ ] never copy to clipboard, open a menu, or invoke AI implicitly
* [ ] suggest explicit `mqlaunch ask` and the nearest documented command only
* [ ] test interactive, redirected, and headless execution

Exit gate:

* [ ] a typo has no side effects and reliably returns `2`

### Delivery B: Namespace help contract

**Files:**

* [ ] modify `terminal/launchers/mqlaunch-command-mode.sh`
* [ ] modify the owning namespace modules under `terminal/menus/` or
  `mqlaunch/commands/` only where help must be implemented
* [ ] create `tests/namespace-help-smoke.sh`
* [ ] update `docs/COMMANDS.md`

Tasks:

* [ ] support `mqlaunch <namespace> --help` and `-h` for `agent`, `hal`, `obsidian`,
  `repos`, `skills`, `srm`, and `stack`
* [ ] print help without rendering the login dashboard or opening an interactive menu
* [ ] return `0` for valid help and `2` for invalid namespace arguments
* [ ] keep namespace help safe without optional backends installed

Exit gate:

* [ ] every documented namespace has non-interactive, dependency-light help

### Delivery C: Delegated exit-code propagation

**Files:**

* [ ] modify `terminal/launchers/mqlaunch-command-mode.sh`
* [ ] modify `terminal/menus/mq-agent-menu.sh`
* [ ] modify `terminal/bridges/hal-bridge.sh` only if its wrapper loses status
* [ ] create `tests/delegated-exit-code-smoke.sh`

Tasks:

* [ ] preserve the delegated command's non-zero exit status
* [ ] keep pause/render helpers from overwriting the captured status
* [ ] keep JSON stdout clean while sending launcher diagnostics to stderr
* [ ] test missing backend, backend usage error, and backend runtime failure

Exit gate:

* [ ] scripts can trust `mqlaunch` exit codes without parsing terminal text

### Delivery D: Authoritative command registry

**Not before:** Phase 12 identifies the single live dispatcher and compatibility boundary.

**Files:**

* [ ] create one registry in the Phase 12 authority-owned runtime path
* [ ] modify `terminal/menus/mq-help-menu.sh`
* [ ] modify `terminal/launchers/mqlaunch-command-mode.sh`
* [ ] modify `terminal/launchers/mqlaunch.sh`
* [ ] modify the command palette consumer
* [ ] create `tests/command-registry-drift-smoke.sh`

Tasks:

* [ ] define canonical name, aliases, namespace, summary, mode, and owner per command
* [ ] generate or validate help, command index, palette, docs, and dispatch coverage
* [ ] include currently under-discovered commands such as `architecture`,
  `repo-health`, `stack status`, `obsidian`, `srm`, and `repos wiki-status`
* [ ] reject duplicate canonical names and alias collisions
* [ ] preserve compatibility aliases until their Phase 12 removal gate is met

Exit gate:

* [ ] one registry proves that routing, help, palette, and documentation agree

### Delivery E: Plain and machine-readable output contract

**Files:**

* [ ] modify the Phase 12 authority-owned UI/output helpers
* [ ] modify `terminal/menus/mq-help-menu.sh`
* [ ] modify `terminal/launchers/mqlaunch.sh`
* [ ] create `tests/plain-output-contract-smoke.sh`
* [ ] update `docs/COMMANDS.md`

Tasks:

* [ ] respect `NO_COLOR` and add `--no-color` where global parsing permits it
* [ ] suppress banners, cursor control, and dashboard rendering when stdout is not a TTY
* [ ] define `--quiet` only for commands with useful primary stdout
* [ ] keep `--json` opt-in and schema-backed; diagnostics go to stderr
* [ ] test pipe, redirect, CI/headless, and normal TTY modes

Exit gate:

* [ ] plain output contains no ANSI escapes and JSON output parses without cleanup

### Delivery F: Enforced shell static analysis

**Files:**

* [ ] modify `.github/workflows/quality.yml`
* [ ] modify `tools/scripts/lint.sh`
* [ ] document intentional suppressions next to affected code

Tasks:

* [ ] inventory current ShellCheck error-severity findings
* [ ] fix or narrowly suppress verified false positives
* [ ] remove warn-only `|| true` behavior for `--severity=error`
* [ ] retain `bash -n` and `zsh -n` as separate syntax gates
* [ ] keep Zsh files out of Bash-only ShellCheck assumptions

Exit gate:

* [ ] new error-severity ShellCheck findings fail CI

### Sequencing

1. [ ] Delivery A — strict unknown-command behavior
2. [ ] Delivery B — namespace help
3. [ ] Delivery C — exit-code propagation
4. [ ] Phase 12 runtime-authority classification required before Delivery D
5. [ ] Delivery D — authoritative registry
6. [ ] Delivery E — plain/output contract on the authoritative runtime
7. [ ] Delivery F — enforced ShellCheck after the touched runtime is clean

### Test gates

```bash
mqlaunch workflows validate
mqlaunch selftest
MQ_NO_TUI=1 mqlaunch help
MQ_NO_TUI=1 mqlaunch definitely-not-a-command; test "$?" -eq 2
if NO_COLOR=1 MQ_NO_TUI=1 mqlaunch commands | LC_ALL=C grep -q $'\033'; then exit 1; fi
./tools/scripts/lint.sh
mqlaunch release-check
git diff --check
```

Focused tests added by each delivery must run independently before the full
selftest. A public command or output-contract change also requires README and
`docs/COMMANDS.md` review.

### Approval gates

* [x] roadmap write approved by this task
* [ ] implementation requires a separate explicit request
* [ ] commit requires explicit approval
* [ ] push and merge require explicit approval
* [ ] compatibility deletion requires the Phase 12 removal gate

### Rollback

* [ ] each delivery must be independently revertible
* [ ] retain current human help text as fallback until registry parity is proven
* [ ] preserve compatibility aliases during rollback
* [ ] never roll back by weakening exit-code or no-side-effect tests

### Overall exit criteria

* [ ] unknown and invalid commands are side-effect free and return `2`
* [ ] every public namespace has non-interactive help
* [ ] delegated failures preserve their exit status
* [ ] command routing, help, palette, and docs share one validated inventory
* [ ] redirected output is plain and JSON output is parseable
* [ ] ShellCheck error-severity findings block CI
* [ ] all existing selftests, workflow validation, release gates, and safety
  boundaries remain green

## 0-30 Days: Roadmap Sanity And SSOT Read-Only Surface

Goal: make the Obsidian SSOT plan explicit and buildable without expanding
`mqlaunch` beyond its boundary.

| Status | Deliverable |
| --- | --- |
| Done | `ROADMAP.md` reflects current `1.0.0` release state |
| Done | Historical v0.5-v1.0 work summarized under completed work |
| Done | Repo ownership map documented |
| Done | `mqlaunch` boundary against direct cognition/memory logic documented |
| Done | Existing MQ Obsidian menu kept as read-only/presentation-first surface |
| Done | Document canonical mqobsidian manifest keys consumed by `mqlaunch` |
| Done | Add/verify tests that MQ Obsidian menu actions do not promote memory |
| Done | Add/verify tests that review commands delegate through `mq-agent` |
| Done | Add `mqlaunch obsidian status` or documented alias for current menu/status |

Expected commands:

```bash
mqlaunch hal context
mqlaunch obsidian status
mqlaunch obsidian inbox
mqlaunch obsidian views
```

Definition of done:

```text
mqlaunch can show Obsidian readiness and open canonical views,
but all scoring, promotion, schema, and cognition logic is owned elsewhere.
```

Boundary test: `tests/mq-agent-routing-smoke.sh` verifies that review,
risk-review, architecture, repo-health, and mcp-status routes stay delegated
through `mq-agent`.

## 31-60 Days: Inbox Ranking And Promotion Loop

Goal: make repeated Codex/Claude/mqlaunch patterns visible as candidates
without making the user manually moderate everything.

Ownership:

```text
mqlaunch -> mq-agent obsidian ... -> mqobsidian schemas/files
```

Candidate lifecycle:

```text
observed -> candidate -> promoted -> canonical -> deprecated
```

Suggested scoring model:

```text
promotion_score =
  frequency
+ successful_reuse
+ cross_tool_reuse
+ manual_confirmation
- risk
- duplication
- staleness
```

| Status | Deliverable |
| --- | --- |
| Todo | Define inbox record schema in `mqobsidian` |
| Todo | Define promotion score schema in `mqobsidian` |
| Todo | `mq-agent obsidian inbox list` |
| Todo | `mq-agent obsidian inbox score` |
| Todo | `mq-agent obsidian promote --dry-run` |
| Todo | `mq-agent obsidian promote --confirm` |
| Done | `mqlaunch obsidian inbox` delegates to `mq-agent` or read-only export |
| Done | `mqlaunch obsidian promote` stays a thin confirm/delegate surface |
| Done | Release gate detects schema drift before release |

Threshold guidance:

```text
score >= 15       -> candidate
score >= 25       -> promotion recommended
score >= 40       -> canonical candidate
manual reject     -> suppressed
risk >= high      -> never auto-promote
```

Definition of done:

```text
Recurring workflow patterns become ranked candidates.
Only reviewed, high-value candidates become durable memory.
```

## 61-90 Days: Stack Truth Cockpit

Goal: make Obsidian the visible single source of truth across the MQ stack.

| Status | Deliverable |
| --- | --- |
| Todo | `mq-agent stack truth-export` writes canonical status |
| Todo | `mq-agent stack contract-check` compares repo contracts to Obsidian truth |
| Todo | `repo-signal` feeds readiness/publishability into truth exports |
| Todo | `mq-mcp` review and memory results can be saved as learn/review records |
| Done | `mqlaunch stack status` reads/delegates canonical truth status |
| Todo | `mqlaunch hal brief` includes Obsidian truth freshness |
| Todo | `mq-ums` contributes first read-only infrastructure signal |
| Todo | Obsidian dashboards show stack map, integration gaps, and promotion queue |
| Todo | Release gate blocks on stale truth or broken contracts |

Definition of done:

```text
The operator can answer "what is true about the MQ stack right now?"
from one terminal surface backed by Obsidian truth exports.
```

## Upstream Dependency: mqobsidian v0.1.0 SSOT Foundation

`mqobsidian` owns the canonical truth structure for the MQ stack. This repo
depends on that work, but must not implement competing truth, inbox, ranking,
or promotion logic locally.

Status: Proposed · Priority: P1 · Owner: `mqobsidian`

Current status:

* [ ] canonical truth schema is not yet fully locked
* [ ] inbox, ranking, and promotion state are not yet unified under one explicit model
* [ ] consumer repos still risk inventing local truth if exports/contracts stay underdefined
* [ ] moderator workflow risks becoming a bottleneck without clear promotion states and thresholds

### mqobsidian owns

* [ ] canonical truth schema
* [ ] inbox structure and promotion queue structure
* [ ] durable memory categories and persistence rules
* [ ] canonical status, views, and manifests consumed by other repos
* [ ] freshness/state markers for truth surfaces
* [ ] promotion state and memory lifecycle states
* [ ] single source of truth rules across the stack

### macos-scripts relationship

`mqlaunch` may consume exported status/views/manifests and delegate workflows to
`mq-agent`, but it must not define schema, compute rankings, promote memory, or
invent local lifecycle state.

Expected consumer contract:

```text
mqlaunch -> read/open exported truth views
mqlaunch -> delegate inbox/promote workflows to mq-agent
mq-agent -> write/orchestrate through mqobsidian contracts
mqobsidian -> own schema, state, persistence, and durable views
```

### Required upstream delivery

#### A. Canonical schema

* [ ] define status manifest
* [ ] define inbox manifest
* [ ] define views manifest
* [ ] define learn/review/decision schemas
* [ ] define promotion-state fields
* [ ] define archival/deprecation lifecycle fields

#### B. Inbox and ranking model

* [ ] define what enters inbox
* [ ] define recurrence/evidence fields
* [ ] define ranking inputs
* [ ] define review-needed vs auto-promotable states
* [ ] define thresholds and exception paths

#### C. Durable memory governance

* [ ] define what qualifies as durable memory
* [ ] define what remains transient or session-local
* [ ] define promotion approvals and guardrails
* [ ] define rollback/deprecation path for bad memory
* [ ] define traceability from source evidence to durable note

#### D. Consumer contracts

* [ ] define canonical read surfaces for `mqlaunch`
* [ ] define canonical delegation/contract surfaces for `mq-agent`
* [ ] version exported truth surfaces
* [ ] expose freshness and drift markers

### Dependency exit criteria

* [ ] `mqobsidian` is the undisputed truth owner
* [ ] inbox, ranking, promotion, and durable memory have one canonical model
* [ ] consumers read from exported truth surfaces instead of inventing local truth
* [ ] every promoted durable memory item can be traced back to source evidence
* [ ] `mqlaunch` has enough contract detail to stay read-only or delegate-only

## Phase 12 / v2.0.0 — Runtime Authority And Shell Governance

**Status:** Proposed
**Priority:** P1
**Type:** Architecture / Runtime governance
**Owner:** `macos-scripts`
**Goal:** Make `mqlaunch` behave as one governed terminal runtime with one
explicit compatibility boundary.

Detailed engineering plan:
[docs/plans/P1-runtime-authority.md](docs/plans/P1-runtime-authority.md).
Workstream sequencing, owners, `Not before` gating, and the risk register:
[docs/plans/v2.0.0-sequencing.md](docs/plans/v2.0.0-sequencing.md).

This repo owns runtime, launcher, menus, UI, and the compat boundary. Truth,
inbox/promotion, and durable memory now live in
[`mqobsidian`](https://github.com/MCamner/mqobsidian/blob/main/ROADMAP.md);
inbox ranking and promotion orchestration live in `mq-agent`
(`v1.22.0 — Inbox ranking and promotion orchestration`). `mqlaunch` only shows
and delegates to those surfaces — it does not implement them.

### Why this matters

`mqlaunch` currently spans overlapping runtime paths. That makes change
authority unclear, preserves hidden legacy dependencies, and increases the
chance of duplicate fixes, UI drift, and wrong-surface edits.

### This repo owns

* [ ] terminal entrypoint authority
* [ ] launcher/runtime path authority
* [ ] menu-layer authority
* [ ] dashboard/UI authority
* [ ] compat boundary for legacy runtime paths
* [ ] allowed dependency directions inside shell/runtime
* [ ] read-only or delegate-only shell integration toward other repos

### This repo does not own

* [ ] truth schema
* [ ] durable memory rules
* [ ] inbox ranking logic
* [ ] promotion/scoring logic
* [ ] review cognition
* [ ] canonical memory persistence

### Target state

* [ ] one documented runtime authority
* [ ] one documented compatibility boundary
* [ ] one current dashboard/UI authority
* [ ] one allowed dependency model
* [ ] no direct live dependency on legacy runtime paths

### Scope

* [ ] define and document runtime authority
* [ ] classify `LIVE`, `COMPAT`, `DEPRECATED`, and `TEST-ONLY` paths
* [ ] freeze further architecture drift
* [ ] consolidate dashboard/UI authority
* [ ] keep `mqlaunch obsidian *` read-only, open, or delegate-only
* [ ] require fixes to land in the authority-owning layer

### Delivery

#### A. Runtime authority

* [ ] declare official entrypoint and runtime coordinator
* [ ] declare official live menu layer
* [ ] classify `mqlaunch/lib/*` by actual live usage
* [ ] classify `terminal/mqlaunch-v1/*` as compat until unreachable
* [ ] document forbidden direct dependencies into legacy paths

#### B. Drift freeze

* [ ] freeze new feature work in legacy runtime paths
* [ ] freeze new direct live dependencies on v1
* [ ] freeze new duplicate dashboard/UI logic
* [ ] document bridge exceptions explicitly

#### C. Shell contract boundary

* [ ] keep shell-level Obsidian actions read-only or delegated
* [ ] keep shell-level inbox/promote flows as thin surfaces only
* [ ] fail checks when shell points to stale or broken backend contracts

### Exit criteria

* [ ] exactly one runtime authority is documented
* [ ] all runtime-relevant paths are classified
* [ ] no live menu depends directly on legacy runtime paths
* [ ] dashboard/UI logic has one current authority
* [ ] shell remains operator surface, not truth owner

## B2 / Atlas Prompt OS Track

B2 remains useful, but it is not the owner of stack truth. Its job is prompt
discovery, routing, composition, history, and optional review delegation.

Current state:

* `mq b2` opens the interactive prompt TUI.
* `mq b2 list`, `show`, `route`, `compose`, `history`, and `validate` exist.
* B2 review flows delegate to `mq-agent` / `mq-mcp`.
* `mq b2 repo-status`, `roadmap-drift`, and `stack` integrate repo-signal and
  Obsidian export/status surfaces.

Next B2 priorities:

| Status | Deliverable |
| --- | --- |
| Todo | Keep B2 exports aligned with mqobsidian canonical paths |
| Todo | Make B2 stack output consume SSOT truth exports when available |
| Todo | Keep B2 review and risk logic delegated through `mq-agent` |
| Todo | Avoid making B2 the promotion engine for durable memory |

## Completed Work

Completed work is intentionally summarized here so this file stays useful as a
forward-looking roadmap.

* mqlaunch command surface
* doctor / system check
* release-check gate with repo-signal publish readiness
* workflow validation / health checks
* gitleaks secrets scan
* mq-mcp review routing through `mq-agent`
* architecture, risk-review, repo-health, and mcp-status commands
* HAL bridge for brief, audit, release brief, repo status, CI, and context
* MQ Obsidian menu for opening views, checks, task packs, inbox, and view regen
* B2/Atlas Prompt OS MVP through v1.0 stack cockpit

## Open Questions

* Should `mqlaunch obsidian ...` be a direct command namespace, or should the
  current MQ Obsidian menu remain the main surface with only a few aliases?
* Which mqobsidian manifest keys are canonical for roadmap, context, inbox,
  stack truth, and promotion queue views?
* Which release gate should own stale-truth blocking: `mqlaunch release-check`,
  `repo-signal`, or `mq-agent stack contract-check`?
