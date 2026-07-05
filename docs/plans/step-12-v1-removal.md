# Step 12 — Compat Removal: Migrate Off v1 And Delete It

**Status:** Planned
**Target release:** `v2.0.0` (final gate)
**Theme:** Make `terminal/mqlaunch-v1/` unreachable, then delete it — closing the
last legacy runtime dependency and the last duplicate UI implementation.
**Owner:** `mqlaunch`
**Risk:** High (the only high-risk step in the v2.0.0 track)

Sequenced by [v2.0.0-sequencing.md](v2.0.0-sequencing.md) (critical path
`9 → 10 → 11a → 12 → v2.0.0`). Grounded in [AUTHORITY_MAP.md](../AUTHORITY_MAP.md)
and verified against the code on 2026-07-05. Step 11a (monolith de-layering) is
complete, so Step 12 is unblocked.

> **Gating (from the sequencing doc):** v2.0.0 must not cut before Step 12 is
> green — i.e. no live path reaches `terminal/mqlaunch-v1/`, verified by
> `scripts/check-runtime-authority.sh`. Removing a bridge happens only after
> grep proves zero live callers (risk R6).

---

## What actually reaches v1 today

The v1 tree is **24 `.sh` files, ~1629 LOC**. Its *live* surface is far
narrower than its size — only three entry points, gated by the four documented
compat edges on the freeze-gate `ALLOW` list:

| Live edge | How it reaches v1 | Coupling |
| --- | --- | --- |
| `terminal/bridges/performance-bridge.sh` | `bash v1/mqlaunch.sh performance` + `run_performance_command` | **subprocess** |
| `terminal/menus/mq-performance-menu.sh` | `source v1/commands/performance.sh` (504 LOC) | **sourced — deepest** |
| `terminal/bridges/dev-bridge.sh` | `open_v1_dev_menu` / `run_v1_dev_command` → `bash v1/mqlaunch.sh dev` | **dead** (see below) |
| `terminal/bridges/tools-bridge.sh` | `open_v1_tools_menu` / `run_v1_tools_command` → `bash v1/mqlaunch.sh tools` | **dead** (see below) |

Everything else in v1 (`commands/{about,bundle,check,index,login,meta,notes,repo,shortcuts,system}.sh`,
`menus/*`, `lib/{core,router,ui}.sh`) is reachable only transitively when the v1
launcher boots for one of those three subcommands. Nothing live sources it
directly.

### Key finding — dev/tools are already off v1

The launcher's `open_dev_menu` / `open_tools_menu` already call the **live**
`dev_menu_loop` / `tools_menu_loop` (`terminal/menus/mq-dev-menu.sh`,
`mq-tools-menu.sh`, sourced at launcher lines ~149/167). The v1-reaching bridge
functions (`open_v1_dev_menu`, `run_v1_dev_command`, and the tools equivalents)
have **zero live callers** (verified by grep, 2026-07-05). They are dead code
kept alive only by the `ALLOW` list.

That means the real migration is **performance only**. dev/tools is a dead-code
decommission.

---

## Workstreams

Ordered by risk, lowest first. Each is its own PR. After each, the freeze gate
(`scripts/check-runtime-authority.sh`) must stay green and its `ALLOW` list must
shrink — the gate already flags stale allowlist entries.

| # | Workstream | Risk | Gate to start |
| --- | --- | --- | --- |
| 12.1 | Decommission dead dev bridge → drop `dev-bridge.sh` v1 functions; remove from `ALLOW` | Low | — |
| 12.2 | Decommission dead tools bridge → same for `tools-bridge.sh` | Low | — |
| 12.3 | Golden-snapshot performance output (`mqlaunch performance` + each subcmd) as a regression fixture | Low | — |
| 12.4 | Migrate `v1/commands/performance.sh` → a live lib (`mqlaunch/lib/performance.sh`); repoint `mq-performance-menu.sh` + `performance-bridge.sh`; drop the v1 subprocess | **High** | 12.3 green |
| 12.5 | Remove `performance-bridge.sh` / `mq-performance-menu.sh` from `ALLOW`; freeze gate proves zero live→v1 edges | Low | 12.4 |
| 12.6 | Delete `terminal/mqlaunch-v1/` (all 24 files, incl. duplicate `lib/ui.sh`); remove the v1 selftest from `test-all.sh`; reclassify in `AUTHORITY_MAP` | Medium | 12.5 (ALLOW empty) |

### Dependency graph

```text
12.1 dev bridge ──┐
12.2 tools bridge ─┤ (independent, low risk)
                   │
12.3 golden snap ──┼──► 12.4 performance migration (HIGH)
                   │           │
                   │           ▼
                   └──────► 12.5 ALLOW empty + gate green
                                   │
                                   ▼
                              12.6 delete v1 tree
                                   │
                                   ▼
                              v2.0.0 cut
```

---

## Risks

| ID | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | Performance migration changes observed metrics/output | Medium | High | 12.3 golden snapshot before 12.4; diff after — no output change allowed without an explicit flag |
| R6 | A bridge is deleted while still carrying live traffic | Low | High | Delete only after grep proves zero live callers; already verified for dev/tools |
| U1 | v1's `lib/ui.sh` behaves differently from `mq-ui.sh`, so migrated performance renders differently | Medium | Medium | Migrate performance onto `mq-ui.sh` helpers; treat any visible header/format delta as a flagged behavior change (cf. the `print_header` decision on #48), not a silent one |
| U2 | A v1 command believed dead is reached by an undocumented path | Low | Medium | Freeze gate + a pre-delete grep sweep for every `v1/` path across `terminal/ ui/ mqlaunch/ bin/`; delete only when zero |
| U3 | Concurrent writer in the repo collides on shared files | Medium | Low | New/isolated files where possible; stage explicit pathspecs; never `git stash` / `git add -A` here |

---

## Exit criteria (Step 12 done)

* [ ] `dev-bridge.sh` and `tools-bridge.sh` no longer reference `mqlaunch-v1`
* [ ] performance runs entirely from a live lib; no `source`/`bash` of `v1/*`
* [ ] `scripts/check-runtime-authority.sh` `ALLOW` list is empty and the gate is green
* [ ] a grep sweep finds zero live references to `terminal/mqlaunch-v1/`
* [ ] `terminal/mqlaunch-v1/` is deleted (24 files); the v1 selftest is removed from `test-all.sh`
* [ ] `AUTHORITY_MAP.md` reflects the removal; no COMPAT row remains for v1
* [ ] one UI authority: no `lib/ui.sh` duplicate of `mq-ui.sh` remains
* [ ] full selftest suite green; performance golden snapshot unchanged

---

## Notes

* This closes the v2.0.0 definition-of-done items *"`terminal/mqlaunch-v1/` is
  deleted or DEPRECATED with no live reachability"* and *"one dashboard/UI
  authority; no duplicate rendering logic"* (v1 ships its own `lib/ui.sh`).
* Given the concurrent writer active in this repo, execute 12.x when the tree is
  quiet; the performance migration (12.4) especially should not race another
  writer.
