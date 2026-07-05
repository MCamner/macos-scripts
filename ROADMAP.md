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
is developed below as **[Phase 12 / v2.0.0](#phase-12--v200--governed-runtime-authority-and-ssot-integration)**,
with the detailed engineering plan in
[docs/plans/P1-runtime-authority.md](docs/plans/P1-runtime-authority.md) and the
workstream sequencing (owners, dependencies, `Not before` gating, risk register)
in [docs/plans/v2.0.0-sequencing.md](docs/plans/v2.0.0-sequencing.md).

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
| Todo | Document canonical mqobsidian manifest keys consumed by `mqlaunch` |
| Todo | Add/verify tests that MQ Obsidian menu actions do not promote memory |
| Todo | Add/verify tests that review commands delegate through `mq-agent` |
| Todo | Add `mqlaunch obsidian status` or documented alias for current menu/status |

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
| Todo | `mqlaunch obsidian inbox` delegates to `mq-agent` or read-only export |
| Todo | `mqlaunch obsidian promote` stays a thin confirm/delegate surface |
| Todo | Release gate detects schema drift before release |

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
| Todo | `mqlaunch stack status` reads/delegates canonical truth status |
| Todo | `mqlaunch hal brief` includes Obsidian truth freshness |
| Todo | `mq-ums` contributes first read-only infrastructure signal |
| Todo | Obsidian dashboards show stack map, integration gaps, and promotion queue |
| Todo | Release gate blocks on stale truth or broken contracts |

Definition of done:

```text
The operator can answer "what is true about the MQ stack right now?"
from one terminal surface backed by Obsidian truth exports.
```

## Phase 12 / v2.0.0 — Governed Runtime Authority And SSOT Integration

**Status:** Proposed
**Priority:** P1
**Type:** Architecture / Runtime governance / SSOT integration
**Target release:** v2.0.0
**Owner:** `mqlaunch` / `macos-scripts`
**Primary dependencies:** `mq-agent`, `mqobsidian`, `repo-signal`
**Secondary dependencies:** `mq-mcp`, `mq-hal`, `mq-ums`
**Risk if delayed:** High

Detailed engineering plan:
[docs/plans/P1-runtime-authority.md](docs/plans/P1-runtime-authority.md).
Workstream sequencing, owners, dependencies, `Not before` gating, and the risk
register: [docs/plans/v2.0.0-sequencing.md](docs/plans/v2.0.0-sequencing.md).

### Goal

Make `mqlaunch` behave like one governed terminal runtime instead of several
overlapping architectural paths, while strengthening its read-only and
delegation-first integration with `mqobsidian` as single source of truth.

### Why this phase exists

The current roadmap already establishes three important constraints:

* `mqlaunch` must stay thin and predictable
* `mqobsidian` must remain the owner of truth and memory
* deeper review, cognition, and promotion workflows must stay outside shell scripts

This phase exists to close the gap between that design boundary and the current
repo reality.

### Problem statement

`mqlaunch` currently carries overlapping runtime surfaces:

* a live launcher-centered runtime path
* compatibility bridges that still reach legacy runtime paths
* partial modular libraries already used by selected menus

That creates an authority problem:

* fixes can land in the wrong place
* legacy runtime remains live without being governed as live
* dashboard/UI duplication can continue
* contributors cannot reliably tell where a change belongs

### Strategic intent

This phase does **not** turn `mqlaunch` into a cognition engine, memory engine,
or schema owner.

This phase does:

* define one runtime authority
* isolate compatibility paths
* make SSOT surfaces visible and stable
* keep `mqlaunch` as terminal UX + delegation layer
* reduce architecture drift before more features accumulate

### Design guardrails

Must stay true:

* [ ] `mqlaunch` remains terminal entrypoint and operator UX layer
* [ ] `mq-agent` remains primary orchestration target for intelligent or mutating flows
* [ ] `mq-mcp` remains owner of runtime cognition, review, and memory APIs
* [ ] `mqobsidian` remains owner of truth schema, canonical views, and memory state
* [ ] `repo-signal` remains owner of readiness and publishability signals
* [ ] `mqlaunch` does not score, promote, parse, or govern durable memory in shell

Must become explicit:

* [ ] one documented runtime authority
* [ ] one documented compatibility boundary
* [ ] one current dashboard/UI authority (`ui/ascii/mqlaunch-dashboard-v7.1.sh`)
* [ ] one allowed dependency direction model
* [ ] one documented SSOT surface contract for Obsidian views/status/inbox

### Scope

In scope:

* [ ] define and document runtime authority
* [ ] classify live, compat, deprecated, and test-only paths
* [ ] freeze further architecture drift
* [ ] consolidate dashboard/UI authority
* [ ] keep Obsidian integration read-only/presentation-first in shell
* [ ] delegate inbox ranking and promotion actions through `mq-agent`
* [ ] align B2 stack/status surfaces with canonical SSOT exports when available

Out of scope:

* [ ] moving cognition into shell
* [ ] making B2 the truth owner
* [ ] building semantic scoring locally in `mqlaunch`
* [ ] rewriting all of `mqlaunch` in one release
* [ ] changing mqobsidian schemas from this repo
* [ ] direct `mqlaunch` ownership of review or promotion logic

### Not before

* [ ] `docs/AUTHORITY_MAP.md` exists
* [ ] current live vs compat paths are explicitly classified
* [ ] current dashboard authority is declared
* [ ] current Obsidian manifest/view contract used by `mqlaunch` is documented
* [ ] release checks can detect broken delegation or stale SSOT links

### Depends on

Required:

* [ ] `mq-agent` exposes stable delegation surface for inbox, promote, truth export, and contract-check flows
* [ ] `mqobsidian` defines canonical manifest/view keys for status, inbox, stack truth, and promotion queue
* [ ] `repo-signal` can feed readiness or publishability signals into truth exports or release gates

Helpful but not blocking:

* [ ] `mq-hal` can consume truth freshness in operator briefs
* [ ] `mq-ums` can contribute first read-only infrastructure signal
* [ ] `mq-mcp` review outputs can be exported as learn/review records through the owned path

### Delivery plan

#### Workstream A — Runtime authority

Objective: remove ambiguity about what is actually live.

* [ ] declare `bin/mqlaunch` as official entrypoint
* [ ] declare `terminal/launchers/mqlaunch.sh` as current runtime coordinator
* [ ] declare `terminal/menus/` as official live menu layer
* [ ] declare `ui/terminal-ui/mq-ui.sh` as shared live UI authority
* [ ] declare `ui/ascii/mqlaunch-dashboard-v7.1.sh` as current dashboard authority
* [ ] classify `mqlaunch/lib/*` by actual live usage
* [ ] classify `terminal/mqlaunch-v1/*` as `COMPAT` until no live path reaches it
* [ ] document forbidden direct dependencies into legacy runtime paths

Done when:

* [ ] a contributor can identify the live runtime path without guesswork
* [ ] no repo path is simultaneously treated as live and legacy
* [ ] bridges are documented as compat, not hidden runtime truth

#### Workstream B — Freeze drift

Objective: stop the repo from getting worse during migration.

* [ ] freeze new feature work in `terminal/mqlaunch-v1/`
* [ ] freeze new direct dependencies from live menus into v1
* [ ] freeze new duplicated dashboard/UI logic
* [ ] require new fixes to land in the authority-owning layer
* [ ] document temporary exceptions in bridge files and README surfaces

Done when:

* [ ] no new PR increases legacy surface area
* [ ] no new PR creates parallel ownership for the same concern
* [ ] runtime governance is stronger than repo folklore

#### Workstream C — SSOT integration hardening

Objective: make Obsidian truth visible in `mqlaunch` without moving truth
ownership into shell.

* [ ] document canonical `mqobsidian` manifest/view keys consumed by `mqlaunch`
* [ ] add or verify `mqlaunch obsidian status`
* [ ] add or verify `mqlaunch obsidian inbox`
* [ ] add or verify `mqlaunch obsidian views`
* [ ] ensure all shell-level Obsidian actions remain read-only, open, or delegate
* [ ] ensure release checks fail when delegation or SSOT surface contracts drift

Done when:

* [ ] `mqlaunch` can show truth readiness without owning truth schema
* [ ] Obsidian status/inbox/views are stable operator surfaces
* [ ] release checks catch stale or broken SSOT integration

#### Workstream D — Delegated promotion loop

Objective: support evidence-based inbox ranking and promotion without making
shell scripts the scoring engine.

* [ ] `mqlaunch obsidian inbox` delegates to `mq-agent` or reads exported canonical status
* [ ] `mqlaunch obsidian promote` stays thin confirm/delegate surface only
* [ ] `mq-agent obsidian inbox list` is available
* [ ] `mq-agent obsidian inbox score` is available
* [ ] `mq-agent obsidian promote --dry-run` is available
* [ ] `mq-agent obsidian promote --confirm` is available
* [ ] release gate detects schema drift before promotion paths are trusted

Done when:

* [ ] repeated patterns become visible as ranked candidates
* [ ] shell remains a surface, not the judge
* [ ] durable memory promotion stays review-gated

#### Workstream E — B2 / Atlas alignment

Objective: keep B2 useful without turning it into stack truth owner.

* [ ] B2 stack/status output consumes canonical SSOT exports when available
* [ ] B2 exports align to canonical mqobsidian paths
* [ ] B2 review/risk flows keep delegating through `mq-agent`
* [ ] B2 does not become promotion engine for durable memory
* [ ] B2 remains prompt discovery, routing, composition, and operator assist surface

Done when:

* [ ] B2 enriches the stack surface without fragmenting truth ownership
* [ ] Atlas remains helpful but subordinate to SSOT
* [ ] there is no second truth plane emerging through prompt tooling

### Risks

Architectural:

* [ ] hidden runtime dependency on compat paths remains longer than expected
* [ ] UI/dashboard duplication survives behind "temporary" exceptions
* [ ] repo naming continues to imply a cleaner modularity than runtime actually has

Product:

* [ ] shell surface grows faster than delegated backends
* [ ] operator UX improves while truth contracts remain underdefined
* [ ] B2 convenience starts to compete with SSOT ownership

Delivery:

* [ ] `mq-agent` and `mqobsidian` contracts are not stable enough yet
* [ ] release gates do not block drift early enough
* [ ] migration stalls after documentation without reducing actual legacy reach

### Exit criteria

This phase is complete only when all of the following are true:

* [ ] exactly one runtime authority is documented
* [ ] all runtime-relevant paths are classified as `LIVE`, `COMPAT`, `DEPRECATED`, or `TEST-ONLY`
* [ ] no live menu depends directly on legacy runtime paths
* [ ] dashboard/UI logic has one clear current authority
* [ ] `mqlaunch` Obsidian surfaces are read-only or delegate-only
* [ ] inbox ranking and promotion flow are available through owned delegated paths
* [ ] B2 consumes SSOT exports instead of inventing competing truth
* [ ] release gates detect stale truth, broken contracts, or forbidden dependency drift

### Expected outcome

When Phase 12 / v2.0.0 is complete, `mqlaunch` will behave as a governed
terminal runtime with one clear authority path, one explicit compatibility
boundary, and one stable read-only/delegated relationship to `mqobsidian` as the
single source of truth.

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
