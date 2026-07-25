# Roadmap

Current version: 1.0.1

## Current direction

`macos-scripts` is the human terminal entrypoint for the MQ stack.

The next major product step is:

```text
v2.0.0 — Runtime Authority and Command Surface Governance
```

v1.0.1 established the release-readiness baseline: version, README badge, changelog, and the release gate agree, and the repo can be shipped from a known-good state. That work is done. v2.0.0 is a different problem — runtime authority and drift prevention — and it is about removing ambiguity rather than adding capability.

The goal is not to add more shortcuts, more menus, or more shell logic. The goal is to make `mqlaunch` feel like one clear, predictable product surface.

`mqlaunch` should stay thin:

```text
mqlaunch shows the right workflow
mq-agent owns orchestration
mq-mcp owns execution and review tools
mqobsidian owns durable truth and memory
mq-hal owns local operator summaries
repo-signal owns repo readiness signals
```

The existing public delegation boundary remains:

```text
mqlaunch shows menu -> mq-agent orchestrates -> mq-mcp executes
```

In practical terms, `mqlaunch` must not implement review, risk, or architecture logic itself, or parse, score, or promote semantic memory in shell scripts.

The product problem is that `mqlaunch` currently has too many overlapping command surfaces: menu entries, help output, command palette, direct command dispatch, legacy launcher paths, and newer module paths. The next release must reduce that ambiguity.

---

## Product principle

The user should never wonder:

```text
Which mqlaunch path am I using?
Is this command shown in help but missing from dispatch?
Will this print clean JSON or a terminal dashboard?
Does this shell path own logic that should belong to mq-agent?
```

A good terminal entrypoint feels obvious. It does not hide complexity. It routes it.

---

## v2.0.0 — Runtime Authority and Command Surface Governance

### Goal

Make `mqlaunch` one coherent operator surface with one runtime authority, one command registry, one help source, and one output contract.

### Why this matters

`macos-scripts` is the front door of the MQ stack. If the front door feels inconsistent, the whole product feels inconsistent — even when the deeper repos are working correctly.

`mq-agent` now has a proven PR-mediated release chain. `mqlaunch` should now become the clean, predictable human surface that delegates to it.

---

## P0 — Roadmap and status sync

Status: Done
Priority: P0
Risk if delayed: Low
Owner: `macos-scripts`

### Problem

The repo version and public docs are ahead of the roadmap status text. Before v2.0.0 work starts, the roadmap must stop describing old release-readiness work as the current focus.

### Tasks

* [x] Update `Current version` to `1.0.1`

  * The version file and README badge already show `1.0.1`.
  * The roadmap should match the released state.

* [x] Replace the old current focus text.

  * Remove stale focus on `v1.0.1 release readiness hardening`.
  * Set the new focus to `v2.0.0 — Runtime Authority and Command Surface Governance`.

* [x] Keep `mqlaunch` ownership clear.

  * `mqlaunch` owns terminal UX, menus, shortcuts, and delegation.
  * It must not own review cognition, release orchestration, memory promotion, or repo scoring.

* [x] Add a short post-v1.0.1 note.

  * State that v1.0.1 established the release-readiness baseline.
  * State that v2.0.0 now focuses on runtime authority and drift prevention.

### Exit gate

* [x] Roadmap, README, VERSION, and repo contract no longer disagree about the current direction.

---

## P1 — Single runtime authority

Status: Done — see `docs/RUNTIME_AUTHORITY.md`
Priority: P1
Risk if delayed: High
Owner: `macos-scripts`

### Problem

`mqlaunch` currently has overlapping runtime paths. This creates drift risk between what the user sees, what help documents, what the palette lists, and what the dispatcher actually runs.

### Product requirement

There must be one clearly defined live runtime authority.

Legacy paths may remain temporarily, but only as compatibility shims. They must not continue to grow as parallel runtimes.

### Tasks

* [x] Identify the single live dispatcher path.

  * Decide which runtime path owns command resolution.
  * Document why that path is authoritative.
  * `bin/mqlaunch` → `mqlaunch.sh` → `mqlaunch-command-mode.sh`.

* [x] Mark legacy paths as compatibility-only.

  * Legacy paths may forward to the authority-owned runtime.
  * They must not implement new command behavior.
  * Classified in `docs/AUTHORITY_MAP.md`, enforced by
    `scripts/check-runtime-authority.sh`.

* [x] Add a runtime authority document.

  * `docs/RUNTIME_AUTHORITY.md`

* [x] Document allowed responsibilities.

  * argument parsing
  * command lookup
  * menu routing
  * status rendering
  * delegation to owning repos
  * exit-code preservation

* [x] Document forbidden responsibilities.

  * review cognition
  * release planning
  * memory promotion
  * architecture reasoning
  * direct MCP tool execution when `mq-agent` owns the workflow
  * GitHub mutation without explicit approval

* [x] Add tests proving compatibility paths delegate correctly.

  * Direct command path
  * Menu path
  * Palette path
  * Legacy shim path
  * All four covered by `tests/compat-path-delegation-smoke.sh`.

### Exit gate

* [x] There is one documented runtime authority.
* [x] Compatibility paths are tested as delegation paths, not independent runtimes.
* [x] No new feature work is added to legacy paths — held by
  `scripts/check-runtime-authority.sh` and
  `tests/runtime-authority-freeze-smoke.sh`.

---

## P1 — Authoritative command registry

Status: In progress — registry and validation delivered, consumers open
Priority: P1
Risk if delayed: High
Owner: `macos-scripts`

### Problem

Command names, aliases, help output, palette entries, menus, and dispatch logic can drift.

A user-facing launcher cannot have five different sources of truth.

### Product requirement

Create one canonical command registry used to validate or generate:

* help output
* command list
* palette entries
* menu routing
* direct command dispatch
* docs coverage

### Tasks

* [x] Create a canonical command registry.

  * `mqlaunch/lib/command-registry.json` — 67 top-level commands, 145 names.
  * On the authority-owned path, as required by `docs/RUNTIME_AUTHORITY.md`.

* [x] Define registry fields.

  * canonical command name
  * aliases
  * namespace
  * summary
  * owner repo
  * safety mode
  * output modes
  * delegation target
  * whether JSON is supported
  * whether the command is interactive
  * whether the command is compatibility-only

* [x] Add registry validation.

  * Reject duplicate command names.
  * Reject alias collisions.
  * Reject missing summaries.
  * Reject undocumented delegated owners.
  * Reject JSON claims without a stable JSON contract.
  * `tools/scripts/validate-command-registry.py`, gated by
    `tests/command-registry-smoke.sh`.

* [ ] Validate help against the registry.

  * `mqlaunch help`
  * `mqlaunch commands`
  * namespace help
  * command palette

* [x] Validate dispatch against the registry.

  * Every public command must be dispatchable or explicitly marked as planned/hidden.
  * Every dispatchable command must appear in help or be marked internal.
  * Parity is enforced in both directions; drift fails the suite.

* [ ] Validate docs against the registry.

  * Public docs should not list commands that do not exist.
  * Existing commands should not be missing from docs unless intentionally hidden.

### Exit gate

* [ ] One registry proves that routing, help, palette, and docs agree — routing
  is proven; help, palette and docs are not yet validated against the registry.
* [x] A CI test fails when command drift appears.

---

## P1 — Command registry drift tests

Status: Planned
Priority: P1
Risk if delayed: High
Owner: `macos-scripts`

### Problem

The dangerous failure is not a broken command. The dangerous failure is a command that appears valid in one surface but behaves differently in another.

### Tasks

* [ ] Add `tests/command-registry-drift-smoke.sh`.

* [ ] Test command inventory consistency.

  * help
  * command list
  * palette
  * direct dispatch
  * docs index

* [ ] Test alias consistency.

  * No duplicate aliases.
  * No alias points to multiple commands.
  * Deprecated aliases are marked explicitly.

* [ ] Test namespace coverage.

  * `agent`
  * `hal`
  * `obsidian`
  * `repos`
  * `skills`
  * `srm`
  * `stack`
  * `workflows`

* [ ] Test delegation ownership.

  * `mq-agent` commands delegate to `mq-agent`.
  * `mq-hal` commands delegate to `mq-hal`.
  * `repo-signal` commands delegate to `repo-signal`.
  * `mq-mcp` is not called directly when `mq-agent` owns the workflow.

### Exit gate

* [ ] CI fails if command help, palette, docs, and dispatch drift apart.

---

## P1 — Plain and machine-readable output contract

Status: In progress — colour and JSON delivered, piped rendering open (#67)
Priority: P1
Risk if delayed: Medium
Owner: `macos-scripts`

### Problem

A terminal product must behave differently when used by a human and when used by a script.

Humans need clear rendering. Scripts need clean stdout, stable exit codes, and diagnostics on stderr.

### Product requirement

`mqlaunch` must have a predictable output contract.

### Tasks

* [ ] Respect `NO_COLOR=1`.

  * [x] No ANSI colors when disabled — central colour guard in `ui/terminal-ui/mq-ui.sh` (#63).
  * [ ] No decorative dashboard output when stdout is not a TTY — still open (#67).

* [ ] Add or standardize `--no-color` where global parsing permits it — not implemented (#67).

* [x] Keep JSON stdout clean.

  * JSON commands must print only JSON to stdout — `status --json` fixed in #65.
  * Diagnostics must go to stderr.

* [ ] Suppress banners in non-interactive mode — still open (#67).

  * No login dashboard when output is piped.
  * No cursor control codes in redirected output.

* [x] Preserve exit codes.

  * Delegated command failures must pass through.
  * Rendering helpers must not overwrite backend status.
  * Covered by `tests/delegated-exit-code-smoke.sh`.

* [x] Add `tests/plain-output-contract-smoke.sh`.

* [ ] Test the output contract in:

  * [x] normal TTY mode — pty-driven check in the contract smoke
  * [ ] piped mode — no test yet (#67)
  * [ ] redirected mode — no test yet (#67)
  * [x] `NO_COLOR=1`
  * [x] JSON mode
  * [x] backend failure mode — `tests/delegated-exit-code-smoke.sh`

### Exit gate

* [x] Humans get readable output.
* [ ] Scripts get clean output — `status --json` is clean, plain `status` still emits the banner when piped (#67).
* [x] CI can trust exit codes without parsing terminal text.

---

## P1 — ShellCheck becomes a real gate

Status: Planned
Priority: P1
Risk if delayed: Medium
Owner: `macos-scripts`

### Problem

Shell syntax checks are already useful, but ShellCheck must not remain warn-only forever. A launcher repo should be boringly reliable.

### Tasks

* [ ] Audit current ShellCheck findings.

  * Classify findings into real bugs, acceptable style exceptions, and intentional shell patterns.

* [ ] Add a project-level ShellCheck policy.

  * Suggested file: `docs/SHELLCHECK_POLICY.md`

* [ ] Remove `|| true` from CI ShellCheck once findings are either fixed or explicitly allowed.

* [ ] Add documented suppressions only where justified.

  * Every suppression should explain why it is safe.

* [ ] Keep syntax checks for all shell files.

### Exit gate

* [ ] ShellCheck is a required CI gate.
* [ ] Remaining suppressions are documented and intentional.

---

## P2 — Thin delegation polish

Status: Planned
Priority: P2
Risk if delayed: Medium
Owner: `macos-scripts`
Primary delegated repo: `mq-agent`

### Problem

`mqlaunch` should feel powerful without becoming powerful in the wrong place.

The front door should make the right workflow easy to find, then hand off to the repo that owns the logic.

### Tasks

* [ ] Review all `mq-agent` delegation commands.

  * Keep them as thin pass-throughs.
  * Avoid local shell logic that duplicates `mq-agent`.

* [ ] Add `mqlaunch stack status` alignment with `mq-agent ship status` once `ship status` exists.

  * `mqlaunch` should display or delegate the release cockpit.
  * It should not reimplement release state logic.

* [ ] Add a clear “owner” label in help output.

  * Example: `owner: mq-agent`
  * Example: `owner: mq-hal`
  * Example: `owner: repo-signal`

* [ ] Improve failure messages for missing delegated tools.

  * Missing `mq-agent`
  * Missing `mq-hal`
  * Missing `repo-signal`
  * Missing `mq-mcp`

* [ ] Keep local quick commands local only when they truly belong to the terminal entrypoint.

### Exit gate

* [ ] A user can tell which repo owns each command.
* [ ] `mqlaunch` does not duplicate deeper stack logic.

---

## P2 — Operator experience polish

Status: Planned
Priority: P2
Risk if delayed: Low
Owner: `macos-scripts`

### Problem

Once runtime authority and command consistency are fixed, the product can become calmer and easier to use.

### Tasks

* [ ] Improve first-run experience.

  * `mqlaunch doctor`
  * dependency checks
  * missing tool hints
  * next recommended setup step

* [ ] Improve command discovery.

  * clearer namespace groups
  * shorter summaries
  * fewer duplicate entries
  * highlight most useful workflows first

* [ ] Improve stack status entrypoints.

  * show `mq-agent`
  * show `mq-mcp`
  * show `mqobsidian`
  * show `mq-hal`
  * show `repo-signal`
  * show clear next action when one is known

* [ ] Keep menus focused.

  * Remove or hide low-value duplicated paths.
  * Prefer fewer, better choices.

### Exit gate

* [ ] A new user can run `mqlaunch doctor`, understand the result, and find the right next command without reading the whole repository.

---

## P3 — Compatibility cleanup

Status: Future
Priority: P3
Risk if delayed: Low
Owner: `macos-scripts`

### Problem

Compatibility routes are useful during migration, but they become debt if they remain forever.

### Tasks

* [ ] List all compatibility paths.

  * legacy command paths
  * legacy menu paths
  * old bridge paths
  * aliases
  * deprecated scripts

* [ ] Mark compatibility routes in the command registry.

* [ ] Add usage notes or migration hints.

* [ ] Remove only after:

  * runtime authority is stable
  * command registry drift tests are green
  * docs no longer point to the old path
  * release-check passes
  * no active workflow depends on the old path

### Exit gate

* [ ] Compatibility cleanup happens only after the new authority path is proven.

---

## v2.0.0 Non-goals

* [ ] Do not add more menu items just because a command exists.

  * Better product means clearer choices, not more choices.

* [ ] Do not move orchestration logic from `mq-agent` into shell.

  * `mqlaunch` delegates.

* [ ] Do not call `mq-mcp` directly when `mq-agent` owns the workflow.

  * Keep the stack boundary clean.

* [ ] Do not implement memory promotion in shell.

  * Memory promotion belongs behind reviewed `mq-agent` / `mqobsidian` flows.

* [ ] Do not introduce hidden AI fallbacks for unknown commands.

  * Unknown commands should fail clearly.

* [ ] Do not make all commands JSON-capable by default.

  * JSON must be stable and schema-backed.

* [ ] Do not remove legacy paths before the new runtime authority is proven.

---

## Recommended PR order

### PR 1 — Roadmap and status sync

Delivered in #61 and #68.

Suggested title:

```text
docs(roadmap): set v2.0.0 runtime authority direction
```

Scope:

* [x] Update current version to `1.0.1`
* [x] Replace stale current focus
* [x] Add v2.0.0 direction
* [x] Keep this docs-only

Exit gate:

* [x] No code changes
* [x] release-check remains READY

---

### PR 2 — Runtime authority design

Delivered in #69.

Suggested title:

```text
docs(mqlaunch): define runtime authority boundary
```

Scope:

* [x] Add `docs/RUNTIME_AUTHORITY.md`
* [x] Identify authority-owned runtime path
* [x] Mark legacy paths as compatibility-only
* [x] Document allowed and forbidden responsibilities

Exit gate:

* [x] No runtime behavior changes yet
* [x] Maintainers can point to one authority model

---

### PR 3 — Command registry foundation

Suggested title:

```text
feat(mqlaunch): add command registry foundation
```

Scope:

* [x] Add canonical command registry
* [x] Add registry validation
* [x] Add tests for duplicate names and alias collisions
* [x] Do not refactor every command yet

Exit gate:

* [x] Registry exists
* [x] Registry validation runs in CI
* [x] Existing commands still work

---

### PR 4 — Drift detection

Suggested title:

```text
test(mqlaunch): detect command surface drift
```

Scope:

* [ ] Add drift tests for help, commands, palette, docs, and dispatch
* [ ] Start with detection before large refactor
* [ ] Document known intentional exceptions

Exit gate:

* [ ] CI detects command-surface drift

---

### PR 5 — Runtime consolidation

Suggested title:

```text
refactor(mqlaunch): consolidate runtime authority
```

Scope:

* [ ] Route command resolution through authority path
* [ ] Keep legacy paths as shims
* [ ] Preserve compatibility aliases
* [ ] Ensure delegation owners remain unchanged

Exit gate:

* [ ] All smoke tests pass
* [ ] Compatibility paths delegate instead of owning behavior

---

### PR 6 — Output contract

Partly delivered in #63 and #65; the rest is tracked in #67.

Suggested title:

```text
fix(mqlaunch): enforce plain output contract
```

Scope:

* [x] Respect `NO_COLOR=1`
* [x] Clean JSON stdout
* [x] Diagnostics to stderr
* [ ] No dashboard rendering when piped — open (#67)
* [x] Preserve delegated exit codes

Exit gate:

* [ ] Shell scripts can consume `mqlaunch` safely — `status --json` is safe;
  plain `status` still emits the banner when piped (#67)

---

### PR 7 — ShellCheck gate

Suggested title:

```text
ci(shell): make ShellCheck a required gate
```

Scope:

* [ ] Classify ShellCheck findings
* [ ] Fix real issues
* [ ] Document intentional suppressions
* [ ] Remove warn-only behavior

Exit gate:

* [ ] ShellCheck becomes a real CI gate

---

## Definition of Done for v2.0.0

* [ ] One runtime authority is documented.
* [ ] Legacy runtime paths are compatibility-only.
* [ ] One command registry exists.
* [ ] Help, commands, palette, docs, and dispatch are validated against the registry.
* [ ] Command drift fails CI.
* [ ] `NO_COLOR=1` is respected.
* [ ] Piped output does not render dashboards or ANSI noise.
* [ ] JSON stdout is clean.
* [ ] Diagnostics go to stderr.
* [ ] Delegated exit codes are preserved.
* [ ] ShellCheck is no longer warn-only.
* [ ] `mqlaunch` remains thin.
* [ ] `mq-agent` still owns orchestration.
* [ ] `mq-mcp` still owns execution/review tools.
* [ ] `mqobsidian` still owns durable truth and memory.
* [ ] `repo-signal` still owns repo readiness.
* [ ] `mq-hal` still owns local operator summaries.
* [ ] Main CI is green.
* [ ] Release-check is READY.
* [ ] Contract-check is READY.
* [ ] Stack-preflight has 0 blockers.

---

## Most important product decision

Do not make `mqlaunch` bigger.

Make it clearer.

The best version of `mqlaunch` is not the one with the most commands. It is the one where the right command is obvious, the output is predictable, and every deeper responsibility is delegated to the repo that owns it.
