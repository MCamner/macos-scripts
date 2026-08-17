# Roadmap

Current version: 2.1.0

## Current direction

`macos-scripts` is the human terminal entrypoint for the MQ stack.

The next major product step is:

```text
mqlaunch next — one deterministic next action, read from mq.pulse.v1
```

v1.0.1 established the release-readiness baseline: version, README badge, changelog, and the release gate agree, and the repo can be shipped from a known-good state. That work is done. v2.0.0 is a different problem — runtime authority and drift prevention — and it is about removing ambiguity rather than adding capability.

v2.0.0 shipped on 2026-07-28. Every P0–P3 block in that section is Done and its Definition of Done is closed against the tree, with the stack-level checks noted as out of this repo's reach.

v2.1.0 shipped on 2026-08-17. It added no new source of truth — it added one read-only operator cockpit, `mqlaunch pulse`, over the signals this repo already collects, plus the `mq.pulse.v1` machine contract underneath it. Every box in its Definition of Done is closed against the tree.

The next step reads that contract rather than adding to it. `mqlaunch next` consumes `mq.pulse.v1` and selects one already-prioritized attention item; it performs no scanning of its own and introduces no second operator model. See [Post-v2.1.0 — `mqlaunch next`](#post-v210--mqlaunch-next).

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

## P1 — Authoritative command registry ✅

Status: Done
Priority: P1
Risk if delayed: High
Owner: `macos-scripts`

73 commands, 157 names, 48 subcommands across 9 namespaces. Five consumers are
held to it: dispatch, `mqlaunch help`, the command palette, `docs/COMMANDS.md`
and README. The subcommand modelling this block was once blocked on is done; the
reasoning is kept in
[docs/plans/P1-command-registry-subcommands.md](docs/plans/P1-command-registry-subcommands.md).

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

* [x] Validate help against the registry.

  * `mqlaunch help`
  * `mqlaunch commands`
  * namespace help
  * command palette

  Held by `tests/registry-consumer-parity-smoke.sh` (#86, #87). Every word help
  advertises must dispatch; coverage is deliberately not required, because help
  is a curated index and forcing all 73 commands into it would make it worse for
  the human it is written for. The palette carries the same contract since it
  started routing through `dispatch_cli_command`.

* [x] Validate dispatch against the registry.

  * Every public command must be dispatchable or explicitly marked as planned/hidden.
  * Every dispatchable command must appear in help or be marked internal.
  * Parity is enforced in both directions; drift fails the suite.

* [x] Validate docs against the registry.

  * Public docs should not list commands that do not exist.
  * Existing commands should not be missing from docs unless intentionally hidden.

  `docs/COMMANDS.md` is the complete reference, so the same gate requires
  coverage in both directions. README is held to the curated contract instead
  (#90). Finding on delivery: help advertised six commands that printed
  `Unknown command`, and the reference never mentioned 22 that existed.

### Exit gate

* [x] One registry proves that routing, help, palette, and docs agree. Five
  consumers are checked: dispatch, help, the palette, `docs/COMMANDS.md` and
  README.
* [x] A CI test fails when command drift appears.

---

## P1 — Command registry drift tests ✅

Status: Done
Priority: P1
Risk if delayed: High
Owner: `macos-scripts`

### Problem

The dangerous failure is not a broken command. The dangerous failure is a command that appears valid in one surface but behaves differently in another.

### Tasks

* [x] Add drift tests. Not under the planned filename — the work landed as two
  files, split by what they hold rather than into one file named after the
  problem:

  * `tests/command-registry-smoke.sh` — the registry against itself and against
    dispatch, with fixtures per rule.
  * `tests/registry-consumer-parity-smoke.sh` — the registry against the four
    surfaces that publish it.

  A single `command-registry-drift-smoke.sh` would have to be one or the other,
  or both and belong to neither. The filename is not the contract.

* [x] Test command inventory consistency.

  * [x] help — every advertised word must dispatch. Coverage is not required:
    help is a curated quick index, and forcing all 73 commands into it would
    make it worse for the human it is written for.
  * [x] command list — same contract as help.
  * [x] palette — routes through `dispatch_cli_command` now, so a palette entry
    and a typed command are the same thing.
  * [x] direct dispatch — `tests/command-registry-smoke.sh` (#81).
  * [x] docs index — `docs/COMMANDS.md` is the complete reference, so coverage
    is required in both directions.
  * [x] README — same contract as help, held by `tests/command-docs-smoke.sh`,
    which stopped being a hand-maintained list of eleven remembered names (#90).

  Held by `tests/registry-consumer-parity-smoke.sh`. It found six commands the
  product advertised and could not run — `tools`, `login`, `shortcuts`, `theme`,
  `guide`, `repo` — and 22 commands the reference never mentioned.

* [x] Remove the second dispatcher.

  * `run_arg_command` was frozen against a baseline (#85), lost its last caller
    when the palette was rerouted (#87), and was deleted along with the baseline
    and its freeze gate (#88).
  * `dispatch_cli_command` is now the only dispatcher, so the registry governs
    the whole command surface rather than most of it.
  * A second dispatcher reappearing fails
    `tests/compat-path-delegation-smoke.sh`, which also stopped matching the
    palette's prose and now anchors to the call.
  * `skills/mqlaunch-menu-template` no longer tells contributors to register new
    commands there.
  * `tools/scripts/mqlaunch_desktop.sh` kept its own copy on the grounds that it
    was a separate live entrypoint. It was not an entrypoint — nothing started
    it — and it has been deleted, so the second dispatcher this bullet accepted
    is gone rather than tolerated.

* [x] Test alias consistency.

  * [x] No duplicate aliases — `validate-command-registry.py` walks every name
    and alias through one `seen_names` map, so a collision in either direction
    fails. Fixture [4/11] in `command-registry-smoke.sh` proves it fires.
  * [x] No alias points to multiple commands — same map.
  * [x] Deprecated aliases are marked explicitly — `deprecated_aliases` is
    metadata on the alias, not a flag on the command, so retiring an old
    spelling says nothing about the command it points at. A deprecated word
    still dispatches but must name a `replacement`, and neither `mqlaunch help`
    nor the palette may advertise it. Four validator rules and one consumer
    rule, five fixtures. Nothing is deprecated today: the rules exist so the
    first deprecation is stated rather than remembered.

* [x] Test namespace coverage.

  Held by `validate-command-registry.py`, which fails when a namespace grows a
  nested `case` and declares nothing, and when a declared subcommand is not
  dispatched. 48 subcommands across 9 namespaces: `workspace`, `srm`, `repos`,
  `system`, `git`, `release`, `dev`, `help`, `obsidian`.

  That is a different list from the eight originally written here, and the
  difference is the point. `agent`, `hal`, `skills`, `stack` and `workflows`
  have no nested `case` in the dispatcher — they hand the rest of the line to
  the owning repo. There are no mqlaunch-routed subcommands to model, and
  modelling the delegate's surface would make the registry claim authority over
  commands it does not route.

  The last sentence here used to read that "their `unknown_subcommand` records
  that they forward". It does not, and cannot: `unknown_subcommand` is only
  valid alongside a `subcommands` array, and `validate-command-registry.py`
  fails an entry that carries one without the other. The ten commands that have
  it are the ten with nested cases. For a forwarding command the registry is
  silent by design, and the forwarding contract is stated in
  `docs/COMMANDS.md` and gated behaviourally instead — for `stack`, by steps 10
  and 11 of `tests/mq-agent-routing-smoke.sh`.

* [x] Test delegation ownership.

  * `mq-agent` commands delegate to `mq-agent`.
  * `mq-hal` commands delegate to `mq-hal`.
  * `repo-signal` commands delegate to `repo-signal`.
  * `mq-mcp` is not called directly when `mq-agent` owns the workflow.

  This was true by convention and ungated until the sync checked it. The
  validator required `delegates_to` to be non-empty for a non-local owner, but
  not to name that owner — so an entry could declare `mq-agent` as owner while
  routing to `mq-mcp`, the boundary violation `docs/RUNTIME_AUTHORITY.md`
  forbids. `delegates_to` holds the whole delegated command, so the rule
  compares its first word against `owner`. Fixture [17/17] proves it fires.

### Exit gate

* [x] CI fails if command help, palette, docs, and dispatch drift apart.
  `.github/workflows/quality.yml` runs `tools/scripts/test-all.sh`, which runs
  both the registry gate and the consumer-parity gate.

---

## P1 — Plain and machine-readable output contract

Status: Done — see `docs/RUNTIME_AUTHORITY.md` (#63, #65, #73, #67)
Priority: P1
Risk if delayed: Medium
Owner: `macos-scripts`

### Problem

A terminal product must behave differently when used by a human and when used by a script.

Humans need clear rendering. Scripts need clean stdout, stable exit codes, and diagnostics on stderr.

### Product requirement

`mqlaunch` must have a predictable output contract.

### Tasks

* [x] Respect `NO_COLOR=1`.

  * [x] No ANSI colors when disabled — central colour guard in `ui/terminal-ui/mq-ui.sh` (#63).
  * [x] The two surfaces that defined their own colours and so never inherited
    that guard — `tools/scripts/pulse.sh`, and `tools/cli/mq-ui.sh` for `scan`,
    `doctor` and `brew-check`. Measured at 20 and 36 stray escapes; both now
    gate on the same condition, locked by
    `tests/pulse-cli-color-contract-smoke.sh`.
  * [x] No decorative dashboard output when stdout is not a TTY — `mq_wants_plain_output`
    gates `print_header`, `print_footer`, `clear_screen` and the row padding (#67).

* [x] Add or standardize `--no-color` where global parsing permits it — global flag
  parsed in `terminal/launchers/mqlaunch.sh` before the UI library is sourced,
  accepted in any position, exported as `NO_COLOR` (#67).

* [x] Keep JSON stdout clean.

  * JSON commands must print only JSON to stdout — `status --json` fixed in #65.
  * Diagnostics must go to stderr.

* [x] Suppress banners in non-interactive mode (#67).

  * No login dashboard when output is piped.
  * No cursor control codes in redirected output.
  * `mqlaunch status` piped went from 5880 bytes of dashboard to 554 bytes of
    fields, and stopped running the test suite to fill in one of them.

* [x] Preserve exit codes.

  * Delegated command failures must pass through.
  * Rendering helpers must not overwrite backend status.
  * Covered by `tests/delegated-exit-code-smoke.sh`.

* [x] Interactive surfaces terminate without a terminal.

  * Menus, `gitlaunch`, and the fzf pickers must exit rather than loop or block
    when there is no TTY — a command that never returns is worse for a script
    than one that fails.
  * Covered by `tests/menu-eof-smoke.sh` (#73).

* [x] Add `tests/plain-output-contract-smoke.sh`.

* [x] Test the output contract in:

  * [x] normal TTY mode — pty-driven check in the contract smoke
  * [x] piped mode — `| cat`, compared against the same command on a pty (#67)
  * [x] redirected mode — `> file`, checked separately from the pipe because a
    guard that looked at anything other than `isatty(1)` would pass one and
    fail the other (#67)
  * [x] `NO_COLOR=1` and `--no-color`
  * [x] JSON mode
  * [x] backend failure mode — `tests/delegated-exit-code-smoke.sh`

### Exit gate

* [x] Humans get readable output.
* [x] Scripts get clean output — no banner, no cursor codes, no padding, and
  content preserved in both piped and redirected mode (#67).
* [x] CI can trust exit codes without parsing terminal text.

---

## P1 — ShellCheck: raise the enforced threshold from error to warning ✅

Status: Done
Priority: P1
Risk if delayed: Medium
Owner: `macos-scripts`

### Problem

This section used to read "ShellCheck becomes a real gate", planning against a
premise that was wrong. ShellCheck is **not** warn-only today:
`tools/scripts/lint.sh` runs `shellcheck -S error` with no `|| true`,
`test-all.sh` calls it, and CI runs `test-all.sh`. Error severity has been a hard
gate all along. What was warn-only is the separate `quality.yml` step, which ran
the same severity over a wider surface and discarded the result. That step now
calls `lint.sh` instead of re-deriving the file list, so there is one definition
of the surface and one of the severity.

So the work is not switching a gate on. It is choosing the next threshold above
`error` and paying for it. `warning` is the only reasonable candidate: `info` and
`style` are 270 and 276 findings of mostly noise, and gating on them would buy
less than it costs to read.

Two boundaries this section must not blur. ShellCheck cannot parse zsh, so the
10 zsh entrypoints — `terminal/launchers/mqlaunch.sh` among them — are outside
its reach entirely and stay covered by `zsh -n`. Raising the ShellCheck
threshold does not make them safer. And a launcher repo being "boringly
reliable" is a claim about correctness, not about warning counts: SC2221/SC2222
are unreachable case branches and worth reading, while SC2034 is an unused
variable and mostly is not.

### Tasks

* [x] Audit current ShellCheck findings.

  * `tools/scripts/shellcheck-report.sh` measures it on demand, so the numbers
    below can be re-derived rather than trusted.

  | Severity | Findings | Files | Gate cost today |
  | --- | --- | --- | --- |
  | error | 0 | 0 | already gated, costs nothing |
  | warning | 96 | 37 | must be fixed or waived |
  | info | 270 | 78 | must be fixed or waived |
  | style | 276 | 79 | must be fixed or waived |

  * The jump is `error` → `warning`, and 51 of those 96 are one rule (SC2034,
    unused variable). The next four rules account for 36 more. Roughly nine
    tenths of the warning surface is five rules, which is what makes fixing in
    groups viable.
  * 10 zsh scripts are outside ShellCheck entirely — it cannot parse zsh, and
    `mqlaunch.sh` is one of them. They are covered by `zsh -n`. Hardening
    ShellCheck does not reach them, and the roadmap should not imply it does.
  * 34 files were scanned by the warn-only CI step but not by the gate
    (`tools/legacy/`, `terminal/mqlaunch-v1/`). Clean at error severity, but they
    hold 5 warnings — which is why that step could not simply drop `|| true` and
    now shares `lint.sh`'s surface instead.

* [x] Clear the warning baseline, in groups, by what the rule actually means.

  96 warnings to zero in seven passes, one rule group per PR:

  | PR | Group | Left |
  | --- | --- | --- |
  | #93 | SC2034 — annotate the 34 that are read across a `source` | 62 |
  | #94 | SC2034 — the other 17, decided one at a time | 45 |
  | #95 | SC2221/SC2222 — unreachable `case` branches | 31 |
  | #96 | SC1090 — `source=` directives | 21 |
  | #97 | SC2155/SC2154 | 19 |
  | #98 | SC1083 — literal braces in `@{u}` | 9 |
  | #99 | SC2046 — word splitting | 0 |

  Splitting by rule was the decision that made this work. Three of the seven
  turned up something a bulk fix would have destroyed or missed: 34 SC2034
  "unused" variables are read by `mq-ui.sh` across a `source` boundary and
  deleting them would have reset every panel title; SC2154 was a live
  `bad substitution` that aborted a dashboard halfway, reported for one of its
  three occurrences; and the SC2046 here-strings are only safe to quote because
  every one of them emits a single line.

* [x] Fix the 5 remaining warnings in `terminal/mqlaunch-v1/` and
  `tools/legacy/`, or state that frozen paths are permanently out of scope.

  Stated, in `docs/RUNTIME_AUTHORITY.md` under the compatibility policy: frozen
  paths stay outside the gated surface until they are deleted. All 5 are SC2034,
  four of them colour variables the sourcing scripts do read. Clearing them would
  mean editing frozen code to satisfy a linter, on paths the policy forbids doing
  work on, for findings that are mostly not defects. A path moving to a live
  location joins the gate with it.

* [x] Add a project-level ShellCheck policy — decided against a separate file.

  The three things such a file would state are already stated where they are
  enforced: the threshold and the file surface in `tools/scripts/lint.sh`, the
  frozen-path exclusion in `docs/RUNTIME_AUTHORITY.md` under the compatibility
  policy, and the zsh limitation in both. A fourth document would duplicate
  them, and this release exists to remove duplicate sources of truth rather than
  add one.

  If a policy file is wanted later it should **move** that text, not copy it.

* [x] Raise `lint.sh` to `-S warning`, and drop `|| true` from the `quality.yml`
  step, once the warning baseline is zero or every exception is documented.

  The workflow step now calls `lint.sh` instead of re-deriving the file list
  with its own `find` and its own exclusions. One definition of the surface and
  the severity. `shellcheck` is installed in CI and its presence asserted,
  because `lint.sh` exits 0 without it — a convenience for developers that would
  otherwise make the gate unfailable.

* [x] Add documented suppressions only where justified.

  * Every suppression explains why it is safe, next to the finding rather than
    at file level. A file-level `disable=SC2034` in `macos-tweaks.sh` would have
    silenced a genuine finding four lines away.

* [x] Keep syntax checks for all shell files.

### Exit gate

* [x] `warning` is the enforced ShellCheck threshold for the bash/sh surface.
* [x] zsh entrypoints remain covered by `zsh -n`, and the docs say why.
* [x] Remaining suppressions are documented and intentional.

---

## P2 — Thin delegation polish

Status: Done — 5 of 5 tasks, both exit gates closed
Priority: P2
Risk if delayed: Medium
Owner: `macos-scripts`
Primary delegated repo: `mq-agent`

### Problem

`mqlaunch` should feel powerful without becoming powerful in the wrong place.

The front door should make the right workflow easy to find, then hand off to the repo that owns the logic.

### Tasks

* [x] Review all `mq-agent` delegation commands.

  Measured, by line count of each handler in `terminal/menus/mq-agent-menu.sh`:

  ```text
  _run_agent                  3   pass-through
  _run_agent_architecture     3   pass-through
  _run_agent_repo_health      5   pass-through
  _run_agent_memory_cochange 13
  _run_agent_flow            39
  _run_agent_review          79   ← the one to look at
  ```

  Four of six are thin. `_run_agent_review` is 79 lines of scope and mode
  parsing that turns `mqlaunch review file X security` into
  `mq-agent review file X --security`. That is argument translation rather than
  review cognition, so it does not cross the boundary
  `docs/RUNTIME_AUTHORITY.md` draws — but it is the largest piece of local shell
  standing between an operator and a delegate, and it is where a second
  vocabulary would grow if one ever did. `_run_agent_flow` is the same shape at
  half the size.

  Reviewed 2026-08-02. **The 118 lines stay here, and the reason is not that
  moving them is hard.** `docs/RUNTIME_AUTHORITY.md` grants this repo argument
  parsing, and what these lines parse is a terminal vocabulary — positional mode
  words, so an operator types `review file X security` rather than
  `review file X --security`. Pushing that into `mq-agent` would make the
  delegate carry `mqlaunch`'s spelling, which is the boundary pointing the wrong
  way. `_run_agent_flow` is the same shape and already handles the hard case
  correctly: `_flow_has_repo_flag` checks for an operator-supplied `--repo`
  before adding its own, so the convenience never overwrites an explicit choice.

  What the review did find is that `_run_agent_review` had no such check and was
  **lossy**. `--repo` was an undocumented scope alias and is also a real
  mq-agent option on `review file`; the scope arm won, so
  `review file X --repo /p` dropped X and ran `review repo /p` — a whole repo
  reviewed instead of the named file, silently. Scope is positional now, as
  `docs/COMMANDS.md` always documented, and unrecognised words pass through.

  The conclusion this box reaches is therefore about the gate, not the line
  count: translation is allowed, and translation must be proved lossless.
  Steps 3 and 4 of `tests/mq-agent-routing-smoke.sh` grep the menu for strings
  it should contain, which passes whether or not the arguments survive. Steps 8
  and 9 run the translation against a stubbed delegate and compare the built
  command line — the form that was red on the old code.

* [x] Align `mqlaunch stack` with the release cockpit `mq-agent` actually has.

  * `mqlaunch` should display or delegate the release cockpit.
  * It should not reimplement release state logic.

  **This task was waiting for a command that was never going to exist.** It named
  `mq-agent ship status`; `mq-agent --help` lists 34 commands as of 2026-08-02
  and `ship` is not among them, and nothing in that repo is planned under the
  name. The release cockpit was already shipped under a different one —
  `mq-agent stack cockpit`, read-only, combining `stack status`,
  `contract-check`, `release-check` and the latest mqobsidian stack-truth note
  into one table with a next action per repo. Run side by side, `stack status`
  gives version, branch, last activity, drift and readiness with an empty
  `next_action`; `cockpit` fills it — `stack release --repo mq-mcp` and so on —
  and adds the stack-wide gate and brain-export freshness. Both take ~1s, so
  cost did not decide anything.

  So the fix was a correction here, not a PR in `mq-agent`. No `mq-agent` change
  was made and none was needed.

  What was actually wrong in this repo was discoverability, the same shape as
  `stack` itself being unadvertised earlier in this section. `mqlaunch stack
  cockpit` already worked — the route forwards every verb — but the word
  appeared nowhere: `mqlaunch stack --help` listed `status, contract-check,
  truth-export`, three of sixteen, and `docs/COMMANDS.md` listed the same three.
  An operator could not find the cockpit without reading mq-agent's help. Both
  now name it, say that unlisted verbs forward, and state that `--json` belongs
  to the subcommands rather than the group.

  The routing needed no change and did not get one. A bare `mqlaunch stack`
  still means `mq-agent stack status`, which is the only local decision on this
  route; `tests/mq-agent-routing-smoke.sh` steps 10 and 11 now pin that default,
  the verbatim forwarding of every other verb including one this repo has never
  heard of, and the delegate's exit code for 0, 1, 2 and 127. Both were proved
  able to fail by planting a defect.

* [x] Add a clear “owner” label in help output.

  Group headings carry the owning repo — `AGENT  (owner: mq-agent)`,
  `HAL  (owner: mq-hal)`, `OBSIDIAN  (owner: mqobsidian)` — covering the 13 of
  49 public entrypoints this repo does not implement. `macos-scripts` groups
  stay unlabelled and `docs/COMMANDS.md` states that default, because writing
  the home repo on nine of twelve headings is noise.

  The heading rather than the row, because a row is already 26 columns of prefix
  plus a 66-character summary — the full 92-column width. That works only while
  a namespace has one owner, which every one does;
  `validate-command-registry.py` now fails a registry that mixes them, so the
  label cannot start describing only some of the rows beneath it.

* [x] Improve failure messages for missing delegated tools.

  * `mq-hal` — `mq_hal_missing()` in `terminal/bridges/hal-bridge.sh`: names the
    binary, names the path, prints two runnable checks, exits 127. This was
    already right and became the template.
  * `mq-agent` — was the shell's own diagnostic:
    `_run_agent:cd:1: no such file or directory`, an internal function name and
    no mention of mq-agent being a separate repo. `_mq_agent_missing()` now
    mirrors mq-hal and adds the `MQ_AGENT_BIN` override.
  * `mq-mcp` — `not_reachable_message()` in mq-agent's bridge names the endpoint
    and prints `mq-agent mcp start`.
  * `repo-signal` — reached through `mq-mcp`'s `repo_signal_analyze` rather than
    directly, so its failure is a tool failure and surfaces as one.

  Held by `tests/delegate-missing-message-smoke.sh`, which holds both bridges to
  one contract so the good one cannot regress to the bad one's behaviour.

* [x] Keep local quick commands local only when they truly belong to the terminal entrypoint.

  Done. The rule is defined, gated and applied to the whole local surface with no
  exception: `LOCAL_ROLE_EXEMPT` is empty, because the one command that could not
  be classified was fixed rather than excused.

  `owner: macos-scripts` used to say only "not delegated". `local_role` is the
  positive rule, and every local command now declares one of exactly three,
  classified by what its own code owns rather than by what it opens:

  ```text
  terminal-ux      28   menus, help, indexes, pickers, dashboards, theme
  host-operation   14   network, processes, ports, power, scans, clipboard
  thin-entrypoint  17   starts something that lives elsewhere, owns the call
  exempt            0
  ```

  `validate-command-registry.py` fails a local command with no role, a role
  outside the three, a `local_role` on a command another repo owns, and an exempt
  command that also classifies. Four negative fixtures prove each fires.

  **`srm` was the exemption, and finding out why was the point of the exercise.**
  Its first four verbs delegate to `mq-agent memory-*`. Everything else falls
  through to `tools/scripts/srm.sh`: 156 lines that build a system prompt and
  call `https://api.openai.com/v1/responses` directly with `file_search` against
  a hardcoded vector store. Memory belongs to `mqobsidian` and orchestration to
  `mq-agent`, and "do not implement memory promotion in shell" is a v2.0.0
  non-goal on this page. Classifying it `thin-entrypoint` would have recorded the
  breach as approved, so it was named in `LOCAL_ROLE_EXEMPT` with a removal
  condition instead — and then the condition was met. The fall-through is
  retired, `mq-agent memory search|status` reaches the same vector store through
  its owner, `srm` delegates every verb and is owned by `mq-agent`. The smoke
  test now fails on any exemption at all.

  **`srm` is not the only one.** `ask`, `fix` and `chat` call the same endpoint
  from `tools/scripts/*.sh`. They are classified `thin-entrypoint`, which is
  accurate about their dispatch arms — four lines that run a script — and says
  nothing about what those scripts own. That is the same shape as `srm` one level
  down, and it is unexamined. Deciding whether an AI helper calling a provider
  directly from shell is a thin entrypoint or a boundary breach is the next
  question this section has to answer; it was not answered here, and the
  classification should not be read as having answered it.

### Exit gate

* [x] A user can tell which repo owns each command. `mqlaunch help` prints the
  owning repo on every delegated group heading, and the unlabelled default is
  documented. Held by `tests/registry-consumer-parity-smoke.sh` and the
  namespace-owner rule in `validate-command-registry.py`.
* [x] `mqlaunch` does not duplicate deeper stack logic.

  `tests/mq-stack-contract-smoke.sh` and `docs/architecture/MQ_BOUNDARY.md`
  already hold the boundary that matters — no review, risk, release or memory
  cognition in shell — and it holds. The weaker claim left open here was the 118
  lines across `_run_agent_review` and `_run_agent_flow`: argument translation
  this repo performs on the delegate's behalf, not a boundary violation but not
  nothing either.

  Reviewed and closed above. Translation is inside the boundary this repo owns;
  the risk was never that it duplicated stack logic but that it could quietly
  change what the delegate was asked to do, which is what `--repo` did. Both
  handlers now refuse to overwrite an explicit operator argument —
  `_flow_has_repo_flag` by checking, `_run_agent_review` by no longer claiming
  the flag — and steps 8 and 9 of `tests/mq-agent-routing-smoke.sh` hold the
  translation itself rather than the text of the file that performs it.

---

## P2 — Operator experience polish

Status: Complete — the original scope closed, and the five findings a measuring
pass added are closed too
Priority: P2
Risk if delayed: Low
Owner: `macos-scripts`

### Problem

Once runtime authority and command consistency are fixed, the product can become calmer and easier to use.

### Tasks

Every sub-item is a checkbox, and every box was measured rather than recalled.
An unchecked box says what is missing and how that was established, so the next
person starts from a fact instead of repeating the measurement. Measurements
below are from 2026-08-01, re-derived with
`tools/scripts/inventory-command-surfaces.py --json`.

`before` is `d2ed66c`, the state this section was written against. `main today`
is the tree after #142 through #153 landed. Three of the four targets are
enforced by `tests/command-discovery-inventory-smoke.sh` rather than measured on
demand, which is what `gated` means: they cannot drift without failing CI.

* [x] Improve first-run experience.

  * [x] `mqlaunch doctor` — twelve checks, and `--json` is a real machine
    document held against observed behaviour by
    `tests/output-mode-parity-smoke.sh`.
  * [x] dependency checks — ten tools, `OPENAI_API_KEY`, and whether `mqlaunch`
    resolves on `PATH` (`tools/scripts/doctor.sh`).
  * [x] missing tool hints — every check that does not pass now carries a hint
    on the screen and a `hint` field in the document. The nine brew formulae are
    listed by name rather than caught by a `*` arm: a fallback would turn any
    check added later into `brew install <whatever>`, and `pbcopy` has no
    formula at all. Names were confirmed with `brew info` (#128).
  * [x] the summary reflects the checks — `tools/scripts/doctor.sh` used to end
    in an unconditional `ok "MQ operational"` that never read the counters above
    it, so the screen reported success no matter what failed while `--json`
    reported `"status": "warn"`. Both modes now reach the same verdict and the
    same exit status: `0` only when every check passes.

    ```text
    before   --json {"status":"warn","summary":{"ok":3,"warn":9,"fail":0}}
             human  ✔ MQ operational                        EXIT=0
    after    --json {"status":"warn", ...}                  EXIT=1
             human  ⚠ 9 of 12 checks need attention         EXIT=1
    ```

    Held by `tests/doctor-status-contract-smoke.sh`, which builds a provisioned
    and a stripped machine from `PATH` so the contract is tested rather than the
    inventory of whichever machine runs the suite (#127).
  * [x] next recommended setup step — the run ends in one instruction, and the
    document carries it as a top-level `next`. It follows an explicit fix order
    rather than the order the checks print in, which is grouped for reading: the
    launcher first, since nothing else is reachable without it, then the tools
    it shells out to, with `eza` last because it only changes how listings look.
    Pinned by two worlds differing by one tool, so the order cannot come out
    right by luck (#128).

* [x] Improve command discovery.

  * [x] clearer namespace groups — help is grouped by the registry's `namespace`
    field, and every command carries `operator_surface` saying whether it is a
    public entrypoint at all. 48 of 74 are; the other 26 stay dispatchable and
    documented but unadvertised. `tests/registry-consumer-parity-smoke.sh`
    requires help to advertise exactly the public set and to print each command
    under a heading naming its namespace, so the curation lives in the registry
    rather than in whoever last edited the help text (#129).
  * [x] shorter summaries — help takes its descriptions from the registry's
    `summary` field. The block in `terminal/menus/mq-help-menu.sh` is generated
    by `tools/scripts/generate-help-list.py`, and the parity test regenerates it
    and requires the file to be current, so a description is written in one
    place. 45 summaries were rewritten as short user-facing text; the technical
    delegation phrasing `delegates_to` already records is gone. The validator
    caps a summary at 66 characters, which is 92 columns minus the 26-character
    row prefix rather than a number picked by taste (#131).
  * [x] fewer duplicate entries — `mqlaunch help` and `mqlaunch commands` were
    two hand-maintained copies of one list and had already drifted: `chat` was
    in the index and not in help. Both now render `command_list` in
    `terminal/menus/mq-help-menu.sh`, and `tests/registry-consumer-parity-smoke.sh`
    checks the index as a fourth consumer, so they cannot drift again (#126).
  * [x] highlight most useful workflows first — `POPULAR FLOWS` moved from the
    bottom of help to the top of the shared list, which also puts it in the
    index (#126).

* [x] Improve stack status entrypoints.

  The five boxes below are checked because `mqlaunch stack` already prints all
  of them — one table, one row per repo, with `Version`, `Branch`,
  `Last activity`, `Drift`, `Ready` and `Next`. The work left is not another
  status screen. It is that the entrypoint is invisible: `stack` is one of the
  thirty-four registry commands `mqlaunch help` does not advertise, so an
  operator finds it by reading `docs/COMMANDS.md` or not at all.

  * [x] show `mq-agent`
  * [x] show `mq-mcp`
  * [x] show `mqobsidian`
  * [x] show `mq-hal`
  * [x] show `repo-signal`
  * [x] show clear next action when one is known — the `Next` column exists and
    is `—` for every repo at the time of writing, which is the column working,
    not the column missing.
  * [x] make the entrypoint discoverable — `stack` is a public entrypoint in the
    registry, appears under the `AGENT` heading in help, and is one of the six
    rows in `POPULAR FLOWS` (#129).

  Ownership note: the table is rendered by `mq-agent`, which `mqlaunch stack`
  delegates to. What `macos-scripts` owns here is the entrypoint, not the
  status logic — see `docs/RUNTIME_AUTHORITY.md`.

* [x] Keep menus focused. Every sub-item is closed except `<= 190 total
  options`, which is retired rather than outstanding — the reasoning is under
  that box.

  Targets, measured with `tools/scripts/inventory-command-surfaces.py`:

  ```text
                                  target   before   main today
  worst menu loop                 <= 10      30       10  gated
  loops over the limit             0          5        0  gated
  undocumented duplications        0          1        0  gated
  dispatcher bypasses              0          3        0  gated
  menu files measured              —         19       23
  menu loops measured              —         34       49
  total options                   <= 190    243      301  retired
  ```

  No loop is over the limit, and the worst is exactly ten. That is the first
  time this section can say so, and the gate below means it cannot quietly stop
  being true.

  `worst menu loop` replaces a row that read `operator choices per menu 29`,
  which was the worst loop rather than a per-menu figure and read as though it
  were an average. `loops over the limit` is the number the remaining work is
  actually sized by.

  **The measurement was measuring a subset.** Two limits in
  `inventory-command-surfaces.py` hid real surfaces, and both are fixed:

  * It read only `terminal/menus/*.sh`. Four operator menus live elsewhere —
    `gitlaunch.sh`, `mq-zsh-theme-switcher.sh`, `workspace.sh` and
    `ui/dashboards/mq-dashboard.sh`. `gitlaunch.sh` is the one that matters:
    `mqlaunch git` opens it, not `mq-git-menu.sh`, so the git surface being
    measured was not the git surface anyone reaches by typing the git command.
    It had 11 choices and nothing would have reported it.
  * The arm regex required the case key and its body on one line, and accepted
    "all digits" or "all letters" but not the mixed form. `gitlaunch.sh` and
    `mq-dashboard.sh` are written entirely in the multi-line style, so neither
    registered at all; and `9|p|P` — a numbered row that also answers the letter
    it used to be bound to — counted as nothing, so a menu lost a choice from
    its total by keeping an old key working.

    Widening the key pattern did not take effect for the multi-line form until
    2026-08-01. `ARM_OPEN` was defined twice in the tool and the second, older
    definition won, so `7|m|M` and `8|p|P` in `gitlaunch.sh` still matched
    nothing: the loop an operator sees as ten was measured as eight, under a
    gate whose subject is how many choices a loop offers. Step 9 of
    `tests/command-discovery-inventory-smoke.sh` now requires both rows and
    fails when the old regex is put back.

  So the jump from 246 to 301 is the measurement getting honest, not the product
  growing. Every menu listed below is shorter than it was.

  `tools/scripts/mqlaunch_desktop.sh` was outside the count as a separate live
  entrypoint needing its own measurement. Nothing started it, so it was never an
  entrypoint and never needed one; it has been deleted. Its 63 arms never
  belonged in this total either way.

  * [x] 0 dispatcher bypasses — `excalidraw`, `reap` and the two `self-check`
    rows go through the dispatcher. The pin was a ratchet at three; it is a hard
    zero now. A ratchet at zero cannot prove itself by "one lower must fail", so
    `tests/command-discovery-inventory-smoke.sh` plants a bypass in a tracked
    menu and requires it to be reported (#132).
  * [x] 0 undocumented duplications — the Tools menu's `doctor`, `doctor --json`
    and `self-check` rows are gone. All three are on the System menu, which is
    where checks belong, and all three still run from the CLI. No allow-list was
    added: nothing needs a documented exception yet, and building the mechanism
    first would have made the target reachable by writing prose (#132).

    That held until the scan started reading multi-line case arms, which
    surfaced one bypass that had always been there: `mq-main-menu.sh` row `a`
    runs `hal-terminal-guide.sh` directly. It has to — the guide writes a path
    to `~/.hal_nav` and the menu `cd`s there afterwards, which `mqlaunch guide`
    cannot do from a subprocess. So `BYPASS_EXCEPTIONS` exists now, holding
    exactly that one entry with the reason beside it. The count stays 0, and the
    smoke test still fails when a bypass is planted.

    The count was 1, not the 3 recorded here before. `ghost`, `review`, `flow`
    and `srm` looked duplicated because the generated help list contains rows
    like `mqlaunch doctor`, which the inventory read as menu invocations.
    Printing a command's name is not a way in; the scanner skips generated list
    blocks now.
  * [x] <= 10 operator choices per menu — **no loop is over the limit.** Worst
    is exactly 10, across 49 loops in 23 files.

    ```text
    menu         before  after  where
    tools          30      10   #132
    agent          21      10   #132
    hal            17      10   #137
    system         16      10   #141
    apps           15       9   #148
    dev            14       8   #143
    git            12       9   #147
    release        12       7   #144
    gitlaunch      11       8   #146
    workflows      11       9   #149
    performance    10      10   #142 (shell guard, not a regrouping)
    ```

    Two of these were not regroupings. The git menu was answering a `9` it never
    drew — `d8ba588` removed the row and left the arm — and the workflows menu
    had two rows duplicating the submenu they sat beside. In both cases the row
    went and the function stayed, because `mq-git-menu.sh log` and
    `mqlaunch workflows save|restore` reach them.

    `gitlaunch` is on the list at all only because the measurement was widened;
    see the note above. It is also the menu `mqlaunch git` opens, which makes it
    the one an operator was most likely to meet over the limit.

    The shell-exec class is gone with it. `#137` and `#142` were the last two
    menus handing unrecognised input to `/bin/zsh -lc "$choice"`, so a typo at a
    prompt ran as a command. Both keep the deliberate `!` escape, which runs
    only what follows the bang.

    Back and quit are excluded, as the target says — they were half-counted
    before, since `x|X)` matched the arm pattern and `b|B|back)` did not.
    Correcting that took `performance` off the list without touching the menu.

    The count is per menu loop, not per file. `mq-tools-menu.sh` holds five
    loops, so counting per file said 23 choices for a menu showing ten — and
    splitting a long menu into submenus, which is the fix, could never improve
    the number.

  * [x] Retire the <= 190 total-options target. It is 301 now against 246
    before, and the increase is not regression. Two thirds of it is the widened
    measurement seeing four more menu files and the multi-line arms it used to
    skip; the rest is that every submenu adds a parent row and a Back arm of its
    own.

    Ten menus have been regrouped and the total has risen every time, including
    the ones that deleted rows. That is not ten failures. **This target and the
    per-loop limit pull in opposite directions and cannot both be met by
    grouping** — reaching 190 means deleting capability, and the capability is
    not the problem. 190 was set before the fix was known and before the
    measurement was honest.

    What an operator feels is the length of the panel in front of them, which is
    the per-loop limit. A repo-wide sum of every choice behind every submenu is
    not a number anyone experiences. Replace it with the per-loop limit plus a
    gate, below.

  * [x] Gate the per-loop limit — done, and this is the box that matters most.

    `tests/command-discovery-inventory-smoke.sh` pinned `--max-bypass 0` and
    nothing else. The per-loop target was measured on demand and enforced by
    nobody, which is how `gitlaunch` sat at eleven unremarked and how four menus
    drifted past ten in the first place. Step 8 now runs `--max-loop 10`, so the
    target is a fact about the tree rather than a number in this file.

    The gate has to be able to fail, so the step also requires `--max-loop 9` to
    exit non-zero. Three loops sit exactly at ten, which makes that off-by-one
    free to check and proves the comparison is live rather than a flag that
    always returns 0.

    It could not land before the last menu was under, or the suite would have
    failed on arrival. Eleven PRs cleared the way — #132, #136, #137, #141,
    #142, #143, #144, #146, #147, #148, #149 — which is why this comes last.

  * [x] `focus.sh` is no longer orphaned — it has a command, `mqlaunch focus`,
    and appears in help under `UTILITY`. It was routed rather than deleted
    because it works, which was checked before deciding (#134).

  * [x] `workflows` is back under the limit, and not by moving Demo flow away —
    the move was right, it is the other full-stack run. Two rows came off
    instead: "Save workspace" and "Restore workspace" were running the same
    calls as "1. Save current workspace" and "4. Restore latest snapshot" inside
    the snapshots submenu on the row above them. Eleven to nine, with no submenu
    added and nothing hidden (#149).

* [x] Fix the paths a measuring pass found unclear, one at a time, each locked
  by a behaviour test. Not a visual rebuild and not new features.

  The boxes above closed the scope this section was written with. They did not
  establish that the surface is clear, because none of them looked at it from
  the outside. On 2026-08-02 every public command was run headless — 36 of them,
  with the destructive, AI-cost and interactive-only ones excluded — and five
  problems came back. They are listed here with the measurement, so the next one
  starts from a fact.

  * [x] `pulse` and `scan` wrote ANSI escapes with stdout redirected, and
    neither `NO_COLOR=1` nor `--no-color` removed one — 20 and 36 sequences.
    Both define their own colour variables and so never inherited the central
    guard this repo already had. Fixed and gated by
    `tests/pulse-cli-color-contract-smoke.sh` (#169).
  * [x] `skills` and `repos` answered a bare invocation with something the
    operator had not asked about: argparse's error naming `mq-skills.py`, and
    "GitHub repo picker needs a terminal." for a command typed as `repos`.
    Message, usage and next step only; both exit statuses and every delegation
    are unchanged, which
    `tests/operator-usage-message-smoke.sh` checks alongside the new text.
  * [x] The menu family disagreed about its headless exit status, and there
    were three outliers rather than the two first reported — `apps` was missed
    because the first sweep read it as an AI command.

    ```text
    git release shortcuts tools workflows dev performance   exit 0
    system theme apps                                       exit 1
    ```

    All ten ended at their own prompt with the same EOF. `hal` answered 0 in
    the sweep but is not one of them: it delegates to `mq_hal_run`, a bridge
    into the mq-hal repo, so its status is the delegate's and 127 without
    mq-hal checked out is correct. The contract covers ten local menus.

    #168 had already settled the answer: a menu loop exits non-zero without a
    terminal by design, so propagating it reports "the command failed" for
    "there was no terminal". The three outliers took the split #168 gave
    `workflows` — menu path 0, argument path unchanged. `system bogusverb`
    still exits 2, and `theme apply bogus` exits 2 now too, under the third
    contract point below.

    The contract this settles, written out because three commands had been
    guessing at it:

    * a valid interactive menu with no terminal available renders at most once
      and exits 0
    * an operation given arguments propagates its real status
    * an invalid argument is 2 — which `theme` was not doing, so
      `mq-zsh-theme-switcher.sh` moved its three usage errors from 1 to 2 while
      its runtime failures kept 1
    * `repos` keeps 1 as a documented exception: it asks for a
      terminal-dependent repo picker while also offering headless subcommands,
      so "there was no terminal" is the true answer there

    `tests/menu-exit-contract-smoke.sh` holds all four end to end through
    `bin/mqlaunch`, headless and on a pty with closed stdin.

    Step 7 of `tests/delegated-exit-code-smoke.sh` could not see any of this:
    it only flags a branch that both invokes a `$BASE_DIR` script and ends in a
    bare `return 0`, which describes neither `theme` nor the mixed shape. It
    now carries a named exception list, and an entry is honoured only when the
    same branch propagates somewhere — so an exception cannot cover a branch
    that discards status everywhere, and a stale entry fails the step.

  Not defects, recorded so they are not re-measured: `review-brain` and
  `selftest` returned 124 to the sweep, which was its own 25-second timeout.

  One thing the sweep itself caused: running `signal-brain` bare wrote
  `2026-08-02-repo-signal-mq-ag…` into the mqobsidian vault. `*-brain` commands
  are writes and belong with the destructive exclusions in any repeat of this
  measurement.

### Exit gate

* [x] A new user can run `mqlaunch doctor`, understand the result, and find the right next command without reading the whole repository.

  Doctor no longer contradicts its own checks (#127), every warning says what to
  do about it (#128), help advertises the 48 public entrypoints grouped by
  namespace (#129), and a run on a healthy machine ends in `Next: mqlaunch
  stack` (#130) — a command help lists, held to that by the contract test.

  So a new operator can run `mqlaunch doctor`, read a verdict that matches its
  own checks, fix what it names, and be pointed at one command that shows the
  whole stack. That is the gate.

---

## P3 — Compatibility cleanup

Status: Complete — the edges are gone and so is the tree
Priority: P3
Risk if delayed: Low
Owner: `macos-scripts`

### Problem

Compatibility routes are useful during migration, but they become debt if they
remain forever.

### Tasks

* [x] List all compatibility paths.

  Listed in [docs/AUTHORITY_MAP.md](docs/AUTHORITY_MAP.md), which classifies
  every path in the tree and is held by
  `tests/runtime-authority-classification-smoke.sh`. The list this task asked
  for existed before the task was written; what it lacked was enforcement, which
  the freeze gate now supplies.

  One correction the listing produced: the map counted three live→legacy edges
  and there were five. The gate scanned three directories while claiming to
  cover live runtime shell, so `automation/login/mqlogin.sh` and
  `tools/scripts/create-debug-bundle.sh` were never in scope (#155).

* [x] Mark compatibility routes in the command registry.

  Exactly one command is `compat_only`: `mqlaunch`, the self-referential prefix
  so a pasted line carrying the program name still runs.
  `validate-command-registry.py` holds the field and `docs/COMMANDS.md` states
  that it is never advertisable.

  The registry was never where the compatibility surface lived. It is a path
  inventory question, not a command question, which is why the answer is the
  authority map.

* [x] Add usage notes or migration hints.

  Each retired edge is recorded in the map with what replaced it, so a
  contributor reading it learns where the concern moved rather than that it
  disappeared.

* [x] Remove only after:

  * [x] runtime authority is stable — freeze gate green with **0** compat edges
  * [x] command registry drift tests are green — `command-registry-smoke.sh`
  * [x] docs no longer point to the old path — the map and `COMMANDS.md` are updated
  * [x] release-check passes — `status: READY`, 0 blockers
  * [x] no active workflow depends on the old path — nothing live reaches the tree

  Every condition was met before the deletion, and the deletion followed as its
  own PR: 23 files and 1125 lines, plus `tools/scripts/test-mqlaunch-v1.sh`.
  Nothing that ran was edited — seven tooling files named the tree to exclude,
  test or police it, which is the distinction the gate's two lists exist to
  make. The lint surface went 189 → 188 files and stayed clean; four of the five
  exempt SC2034 findings left with the tree.

  `scripts/check-runtime-authority.sh` is a tombstone gate now. A deleted path
  cannot be depended on by accident, but it can be recreated, and a second
  runtime is what this track spent its length removing.

### What was migrated (2026-08-02)

Four live→legacy edges, none retired by weakening a gate:

```text
mq-performance-menu.sh:26  sourced 504 lines of perf_* readings out of the
                           frozen tree  →  moved verbatim to
                           mqlaunch/lib/performance.sh
tools-bridge.sh            forwarded `tools` to the v1 launcher  →  deleted;
                           neither of its functions had a caller
performance-bridge.sh      fell back to the v1 launcher when the current menu
                           was missing  →  reports and returns 1
create-debug-bundle.sh     ran `v1 help` as a health probe from a menu row  →
                           dropped
```

The one that mattered was the first. The tree was classified live in order to
supply working code, not to keep a legacy route open — which is why "delete the
compat tree" was never the small job the Status line implied.

The dependency now runs the other way: `terminal/mqlaunch-v1/mqlaunch.sh:22`
sources `mqlaunch/lib/performance.sh`. Legacy depending on live is the allowed
direction, and it keeps the tree runnable so its deletion is decided on its own
terms rather than forced by a move.

### Exit gate

* [x] Compatibility cleanup happens only after the new authority path is proven.

  Proven before the cleanup, not asserted after it: the freeze gate covers every
  tracked shell file from `git ls-files`, fails on an unclassified reference,
  and reports **0** compat edges. `tests/compat-path-delegation-smoke.sh` no
  longer proves the legacy shim forwards correctly — it proves the shim is gone,
  and that the performance route fails rather than falling through when its menu
  is missing.

---

## v2.0.0 Non-goals

* [x] Do not add more menu items just because a command exists.

  * Better product means clearer choices, not more choices.

* [x] Do not move orchestration logic from `mq-agent` into shell.

  * `mqlaunch` delegates.

* [x] Do not call `mq-mcp` directly when `mq-agent` owns the workflow.

  * Keep the stack boundary clean.

* [x] Do not implement memory promotion in shell.

  * Memory promotion belongs behind reviewed `mq-agent` / `mqobsidian` flows.

* [x] Do not introduce hidden AI fallbacks for unknown commands.

  * Unknown commands should fail clearly.

* [x] Do not make all commands JSON-capable by default.

  * JSON must be stable and schema-backed.

* [x] Do not remove legacy paths before the new runtime authority is proven.

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

Delivered across #81, #86, #87 and #90. This block tracked the same work as
`P1 — Command registry drift tests`, which closed first; the boxes here were
left behind rather than reopened.

Suggested title:

```text
test(mqlaunch): detect command surface drift
```

Scope:

* [x] Add drift tests for help, commands, palette, docs, and dispatch —
  `tests/command-registry-smoke.sh` (registry against itself and dispatch) and
  `tests/registry-consumer-parity-smoke.sh` (registry against the four
  publishing surfaces), with `tests/command-docs-smoke.sh` holding README.
* [x] Start with detection before large refactor — the tests found six
  advertised commands that printed `Unknown command` and 22 the reference never
  mentioned, before the second dispatcher was removed in #88.
* [x] Document known intentional exceptions — help and README are curated
  indexes and not required to cover all 73 commands; `operator_surface` records
  which 48 are public; `deprecated_aliases` states retirement explicitly.

Exit gate:

* [x] CI detects command-surface drift — all three tests are in
  `tests/manifest.tsv` and `tools/scripts/test-all.sh`, which runs in the
  `Quality` workflow. Re-verified green on `d2ed66c`.

---

### PR 5 — Runtime consolidation

Delivered across #85, #87 and #88, tracked in full by `P1 — Single runtime
authority`. Same situation as PR 4: the work closed there and these boxes were
never carried over.

Suggested title:

```text
refactor(mqlaunch): consolidate runtime authority
```

Scope:

* [x] Route command resolution through authority path — `dispatch_cli_command`
  is the only dispatcher. `run_arg_command` was frozen against a baseline (#85),
  lost its last caller when the palette was rerouted (#87), and was deleted with
  its freeze gate (#88). It survives only in `tools/legacy/patches/`, which is a
  frozen path, and in the test that fails if a second dispatcher reappears.
* [x] Keep legacy paths as shims — classified in `docs/AUTHORITY_MAP.md`,
  enforced by `scripts/check-runtime-authority.sh`.
* [x] Preserve compatibility aliases — `validate-command-registry.py` walks
  every name and alias through one `seen_names` map; a deprecated spelling still
  dispatches but must name a `replacement`.
* [x] Ensure delegation owners remain unchanged — the validator compares the
  first word of `delegates_to` against `owner`, so an entry cannot claim
  `mq-agent` while routing to `mq-mcp`.

Exit gate:

* [x] All smoke tests pass — verified on `d2ed66c`.
* [x] Compatibility paths delegate instead of owning behavior —
  `tests/compat-path-delegation-smoke.sh` and
  `tests/runtime-authority-freeze-smoke.sh`, both green.

---

### PR 6 — Output contract

Delivered across #63 (colour), #65 (JSON), #73 (termination) and #67 (rendering
and `--no-color`).

Suggested title:

```text
fix(mqlaunch): enforce plain output contract
```

Scope:

* [x] Respect `NO_COLOR=1` and `--no-color`
* [x] Clean JSON stdout
* [x] Diagnostics to stderr
* [x] No dashboard rendering when piped (#67)
* [x] Preserve delegated exit codes

Exit gate:

* [x] Shell scripts can consume `mqlaunch` safely — `--json` for structured
  output, plain commands for text, neither carrying terminal decoration

---

### PR 7 — ShellCheck threshold

Suggested title:

```text
ci(shell): enforce ShellCheck at warning severity
```

`error` is already enforced. This raises the threshold; it does not switch a
gate on.

Scope:

* [x] Measure the current surface (#92)
* [x] Clear SC2034 in bulk — split across #93 (the 34 read across a `source`
  boundary) and #94 (the other 17, decided one at a time). Bulk-deleting them
  would have reset every panel title.
* [x] Triage SC2221/SC2222 and SC2046 by hand — #95 and #99. The SC2046
  here-strings are only safe to quote because each emits a single line.
* [x] Document intentional suppressions — every one explains itself next to the
  finding, not at file level.
* [x] Raise `lint.sh` to `-S warning` and drop `|| true` from `quality.yml` —
  `tools/scripts/lint.sh:54` runs `shellcheck -S warning`; the workflow step
  calls `lint.sh` and asserts shellcheck is installed, because `lint.sh` exits 0
  without it.

Exit gate:

* [x] `warning` is enforced for bash/sh, and the baseline is zero or documented
  — `bash tools/scripts/lint.sh` exits 0 with no findings on `d2ed66c`. The 5
  warnings in `terminal/mqlaunch-v1/` and `tools/legacy/` are outside the gated
  surface by the compatibility policy in `docs/RUNTIME_AUTHORITY.md`.

---

## Definition of Done for v2.0.0

Closed against the tree on 2026-07-29, after the 2.0.0 tag. Each box below names
what proves it, so the next person can re-run the proof instead of trusting the
checkmark. Everything named here runs in CI: `tools/scripts/test-all.sh` is a
step in the `Quality` workflow, so these are gates, not local habits.

* [x] One runtime authority is documented. — `docs/RUNTIME_AUTHORITY.md`
* [x] Legacy runtime paths are compatibility-only. — `scripts/check-runtime-authority.sh`
  in CI, plus `tests/runtime-authority-freeze-smoke.sh` and
  `tests/runtime-authority-classification-smoke.sh`
* [x] One command registry exists. — `mqlaunch/lib/command-registry.json`
* [x] Help, commands, palette, docs, and dispatch are validated against the
  registry. — `tests/registry-consumer-parity-smoke.sh`, `tests/command-docs-smoke.sh`
* [x] Command drift fails CI. — `tests/command-registry-smoke.sh` runs
  `tools/scripts/validate-command-registry.py`
* [x] `NO_COLOR=1` is respected.
* [x] Piped output does not render dashboards or ANSI noise.
* [x] JSON stdout is clean. — `tests/plain-output-contract-smoke.sh`,
  `tests/release-check-contract-smoke.sh`
* [x] Diagnostics go to stderr. — same two tests
* [x] Delegated exit codes are preserved. — `tests/delegated-exit-code-smoke.sh`
* [x] ShellCheck is enforced at warning severity for the bash/sh surface.
* [x] `mqlaunch` remains thin. — `tests/mq-stack-contract-smoke.sh`,
  `docs/architecture/MQ_BOUNDARY.md`
* [x] Main CI is green. — `Quality` succeeded on `886c346`
* [x] Release-check is READY. — `mqlaunch release-check --json` returns
  `status: READY` with no blockers

External ownership assertions, deliberately not represented as completion
checkboxes because this repo cannot prove them:

* `mq-agent` still owns orchestration.
* `mq-mcp` still owns execution/review tools.
* `mqobsidian` still owns durable truth and memory.
* `repo-signal` still owns repo readiness.
* `mq-hal` still owns local operator summaries.

  `macos-scripts` enforces its own side of the boundary — it delegates rather
  than reimplements, and the boundary tests above fail if that stops being
  true. Whether each of those repos still holds up its side is a claim about
  their trees, not this one. Ticking these from here would be asserting
  something unverified.

* Contract-check is READY.
* Stack-preflight has 0 blockers.

  Neither is a `mqlaunch` command: both return `Unknown command`. They are
  stack-level checks that belong to whoever owns them, and this repo has no way
  to run them.

---

## v2.1.0 — MQ Pulse Operator Cockpit

Status: Shipped 2026-08-17 — tagged `v2.1.0`
Priority: P1
Owner: `macos-scripts`

### Goal

Add `mqlaunch pulse` as the canonical read-only operator cockpit for `macos-scripts` and the wider MQ stack.

The command should answer:

```text
Is the environment healthy?
What needs attention?
Which existing command should I run next?
```

`pulse` must remain a thin operator surface.

```text
mqlaunch collects -> normalizes -> renders -> points to existing commands
```

It must not move orchestration, review logic, memory logic, repo scoring, or other domain intelligence into shell.

### Why this matters

`macos-scripts` already has strong runtime authority, command governance, delegation, safety gates, repo status, stack status, memory status, Git workflows, release readiness, and health checks.

The remaining operator problem is fragmentation.

Today the user may need several commands to understand the current state:

```bash
mqlaunch doctor
mqlaunch repos status
mqlaunch stack status
mqlaunch mcp-status
mqlaunch obsidian status
mqlaunch release-check
mqlaunch skills
```

`mqlaunch pulse` should combine those existing signals into one coherent read-only view without becoming a new source of truth.

---

## P0 — Pulse contract and ownership

Status: Done — `docs/PULSE_CONTRACT.md`, `mqlaunch/lib/pulse/model.sh`,
`tests/pulse-contract-smoke.sh`
Priority: P0
Owner: `macos-scripts`

**The word `pulse` was already taken, and this section did not say so.**
`mqlaunch pulse` was the Wi-Fi and latency diagnostic — a real command, in the
registry, on the `ops` help group, with its own colour-contract test. Every line
of v2.1.0 below is addressed to that word, so the first thing this block had to
do was decide which meaning keeps it.

The diagnostic moved. It is `mqlaunch netpulse` now, running
`tools/scripts/netpulse.sh`, unchanged apart from the name. No alias was kept:
`mqlaunch pulse` answers `Did you mean: mqlaunch netpulse` through the existing
unknown-command path, which moves an operator across without letting the old
meaning resolve. A repo that spent v2.0.0 removing overlapping command surfaces
does not open v2.1.0 by giving one word two meanings.

### Tasks

* [x] Define `mqlaunch pulse` as a read-only operator surface.
* [x] Document that `macos-scripts` owns collection, normalization, rendering, and navigation only.
* [x] Preserve current ownership boundaries:

  * `mq-agent` owns orchestration and routing.
  * `mq-mcp` owns execution and review tools.
  * `mqobsidian` owns durable truth and memory.
  * `mq-hal` owns local operator summaries.
  * `repo-signal` owns repo readiness signals.

* [x] Prohibit mutation from all Pulse collectors.
* [x] Prohibit new review, scoring, promotion, routing, or architecture logic in shell.

  Stated with the line that decides the hard cases: mapping another repo's
  verdict onto a Pulse state is normalization; deriving that verdict because the
  owning repo did not publish one is domain logic and belongs there.

* [x] Define canonical Pulse states:

  * `PASS`
  * `WARN`
  * `FAIL`
  * `UNAVAILABLE`
  * `SKIPPED`

* [x] Require unavailable checks to report `UNAVAILABLE` rather than silently passing.

  Which only means something once `UNAVAILABLE` reaches the exit code, so the
  model ranks it with `WARN`. Exiting 0 would be the same silent pass one level
  down, where a script reads it; exiting 2 would say the check was measured and
  broken. The operator acts on that difference — `FAIL` means fix the subject,
  `UNAVAILABLE` means fix the reach.

* [x] Define exit-code contract:

  * `0` — healthy / no attention required.
  * `1` — one or more warnings.
  * `2` — one or more failures.
  * `3` — Pulse itself could not complete reliably.

  The case this list left open is a run with nothing in it — no checks, or every
  check `SKIPPED`. That is `3`, not `0`. Pulse holds no signals of its own, so a
  run that collected none knows nothing about the machine, and the alternative
  makes the healthiest-looking run the one where every collector failed to
  register. `SKIPPED` therefore contributes nothing to the verdict but cannot
  stand in for a measurement either.

### Exit gate

* [x] Pulse ownership is documented — `docs/PULSE_CONTRACT.md`.
* [x] Runtime authority remains unchanged. The model sits on the authority-owned
  path and is classified in `docs/AUTHORITY_MAP.md` as test-only until the first
  collector sources it, which is honest about what reaches it today.
* [x] No new domain logic is introduced into `macos-scripts`. The model reads
  nothing about the machine: every function is a pure function of the states it
  is handed.

`tests/pulse-contract-smoke.sh` holds a 15-run truth table, each row separating
two rules that would otherwise look alike, and was proved able to fail against
four planted defects — `UNAVAILABLE` ranked as `PASS`, an empty run reporting
`PASS`, a `pulse` dispatch arm running `netpulse.sh` again, and `pulse` added as
an alias of `netpulse`.

Writing it found one defect in the model. `pulse_overall_state` read stdin
whenever it was given no arguments, so on a terminal it blocked on the
operator's keyboard and never returned — the state every caller is in until a
collector registers. It reads stdin only when stdin is not a TTY now, the rule
`tests/menu-eof-smoke.sh` already holds the interactive surfaces to. The step
covering it runs under a pty, because a redirected stdin cannot reproduce the
condition; that is why the first run of the suite passed over it.

---

## P1 — Canonical Pulse model

Status: Done — `mqlaunch/lib/pulse/item.sh`, gated by
`tests/pulse-collectors-smoke.sh`
Priority: P1
Owner: `macos-scripts`

### Goal

All collectors should return the same small internal status model.

### Tasks

* [x] Define the internal Pulse item model.

Example:

```json
{
  "source": "github",
  "area": "git",
  "status": "WARN",
  "subject": "PR #184",
  "summary": "Open and mergeable",
  "evidence": "GitHub reports the PR as mergeable",
  "next_command": "mqlaunch git",
  "priority": 60
}
```

* [x] Require `source`.
* [x] Require `area`.
* [x] Require `status`.
* [x] Require `subject`.
* [x] Require `summary`.
* [x] Support optional `evidence`.
* [x] Support optional `next_command`.
* [x] Add `priority` for deterministic attention ordering.
* [x] Add optional freshness metadata.
* [x] Add optional collector duration metadata.
* [x] Ensure the complete model can be serialized losslessly to JSON.

  `priority` defaults to 0 and is never derived from the status. Mapping
  `FAIL` to a number is the attention engine's job, and doing it here would
  put the ordering in the model where nothing could change it.

  Records are joined with RS (0x1e) and their pairs with US (0x1f), and the
  JSON is written by python3 rather than assembled in shell. The first version
  inferred a record boundary from seeing the `source` key again — a heuristic,
  and a heuristic in a serializer fails on the first item that omits a field.
  Step 3 of the gate round-trips a summary holding a quote, a comma, a
  backslash, a colon and a non-ASCII glyph.

### Exit gate

* [x] Human and JSON output use the same underlying model — `pulse_render` and
  `pulse_items_json` both read `PULSE_ITEMS` and neither computes a state.
* [x] Rendering contains no independent health logic. Held by rendering a run
  whose prose disagrees with its states: an item that says "everything is fine"
  with status `FAIL` must still draw the failure glyph.
* [x] Attention can be derived entirely from Pulse items — every field the
  attention engine needs is on the item, including `priority` and
  `next_command`.

---

## P1 — Core Pulse collectors

Status: Done — six collectors, gated by `tests/pulse-collectors-smoke.sh` and
`tests/pulse-state-collectors-smoke.sh`
Priority: P1
Owner: `macos-scripts`

### System

* [x] Reuse the existing doctor/environment checks.
* [x] Report required dependency health.
* [x] Report environment/configuration failures.
* [x] Preserve existing source diagnostics where useful.

Example:

```text
SYSTEM
✓ Environment healthy
✓ Required tools available
```

### Repositories

* [x] Reuse existing repo-status functionality.

  `tools/scripts/mq-repos.py status --json` — the same code path
  `mqlaunch repos status` prints from, so the two cannot disagree about what
  dirty means. The flag is new; the readings are not. Parsing the human output
  instead would have made the screen format a contract, and a screen is not a
  contract.

* [x] Show clean/dirty state.
* [x] Show current branch.
* [x] Show ahead/behind where already available.

  "Where already available" turned out to be nowhere: nothing in this repo read
  ahead/behind. `mq-repos.py` now derives it from
  `git rev-list --count --left-right @{u}...HEAD`, which fails on a branch with
  no upstream — a normal state, reported as such rather than as an error. A
  clean tree that is two commits ahead is a warning in Pulse, and that is the
  reading the flag was added for.

* [x] Report inaccessible repos explicitly.
* [x] Summarize how many repos require attention.

  One item per repo that needs attention, then one summary item for the rest.
  A row per clean repo is what `mqlaunch repos status` is for; Pulse exists to
  be shorter than the commands it summarises.

Example:

```text
REPOSITORIES
✓ mq-agent        main · clean
✓ mq-mcp          main · clean
! macos-scripts   feature/pulse · dirty
```

### MQ Stack

* [x] Reuse canonical stack truth from `mq-agent`.

  `mq-agent stack status --json`, run through `uv` in the mq-agent checkout —
  the same route `mqlaunch stack` takes. Pulse reads `exists` and
  `next_action` and maps them; it derives no readiness of its own.

* [x] Surface `mq-agent` availability.
* [x] Surface `mq-mcp` availability.
* [x] Surface `mq-hal` availability.
* [x] Surface `mqobsidian` availability.
* [x] Surface `repo-signal` availability.

  Five boxes, one rule: availability comes from the delegate's own `exists`
  field, per repo, whatever repos it lists. Hard-coding these five names in the
  collector would make Pulse wrong the day the stack gains a sixth.

  When mq-agent itself is not installed the whole area is one `UNAVAILABLE`
  item — not five. Five rows saying "unknown" would be five guesses dressed as
  readings, and the gate asserts the count.

Example:

```text
MQ STACK
✓ mq-agent
✓ mq-mcp
✓ mq-hal
✓ mqobsidian
✓ repo-signal
```

### Memory

* [x] Surface semantic repository memory availability.
* [x] Surface vector-store availability.
* [x] Surface vector-store source where already exposed.
* [x] Surface stack-truth freshness.
* [ ] Surface existing held/review queues when a read-only interface exists.

  **Not done, and the condition is the reason.** `mq-agent memory review-status`
  exists and is read-only, but it prints for a human — no `--json`. Reading it
  would make mq-agent's screen layout a contract this repo depends on, which is
  the mistake `--json` on `mq-repos.py` was added to avoid one level down.

  So the queue is absent from `MEMORY` rather than guessed at. Closing this box
  needs a machine-readable mode on `mq-agent memory review-status`, in mq-agent.
  Nothing in `macos-scripts` can close it.
* [x] Never infer memory state from missing data.

Example:

```text
MEMORY
✓ semantic store
! stack truth aging
✓ review queue empty
```

### Git / GitHub

* [x] Surface open PR count for the current repo.
* [x] Surface mergeability where GitHub reports it.
* [x] Surface failing CI.
* [x] Surface pending CI.
* [x] Surface dirty worktree.
* [x] Surface unpushed local commits where already available.
* [x] Perform no push, merge, checkout, or branch mutation.

Example:

```text
GIT / GITHUB
! 2 open PRs
✓ CI passing
✓ worktree clean
```

### Quality

* [x] Reuse command-registry validation.
* [x] Reuse runtime-authority validation.
* [x] Reuse skill-discoverability validation.
* [x] Reuse documentation parity checks.
* [x] Reuse existing test/shell inventory checks.
* [x] Do not implement parallel quality validators.

Example:

```text
QUALITY
✓ command registry
✓ runtime authority
✓ skills discoverable
✓ docs parity
```

### Exit gate

* [x] Every collector can run independently.
* [x] One failed collector does not crash the whole Pulse.

  Held end to end: a run with mq-agent absent, `gh` absent and one quality gate
  failing still renders all six areas and exits 2. Getting there closed four
  real `set -e` hazards — `var="$(cmd)"` ends the caller when the command fails,
  and every collector reads a delegate that legitimately exits non-zero.
* [x] Collector failures become `FAIL` or `UNAVAILABLE`.
* [x] All collectors are read-only. Asserted rather than asserted-to: the git
  collector runs against a scratch repository and the test compares `HEAD` and
  the worktree before and after.

---

## P1 — Attention engine

Status: Done — `mqlaunch/lib/pulse/attention.sh`, gated by
`tests/pulse-attention-smoke.sh`
Priority: P1
Owner: `macos-scripts`

### Goal

Turn status into an actionable operator view without making decisions that belong elsewhere.

### Tasks

* [x] Collect all `WARN` and `FAIL` items — and `UNAVAILABLE`, which this
  line does not mention and the engine includes anyway. A run holding one
  unreachable collector and nothing else reports `WARN`, so an attention list
  without it would print a heading that says something needs attention above an
  empty list. The model already ranks `UNAVAILABLE` with `WARN`; the engine
  follows the model rather than the sentence.
* [x] Sort deterministically by priority.
* [x] Deduplicate repeated manifestations of the same problem.

  On a key the collector supplies, never on a resemblance the engine noticed.
  `dedupe_key` is a new optional item field: the repositories collector and the
  Git collector both see this checkout is dirty — one walking the MQ repos, one
  reading the repo mqlaunch runs in — and both label it `worktree:<repo>`. The
  engine merges those two into one finding and merges nothing else. Items
  without a key are always kept, because two rows that look alike are not
  evidence that they are one problem, and dropping one on that basis would hide
  a real one.
* [x] Show a maximum of 5 items in the default view.
* [x] Show additional count when more issues exist.

Example:

```text
+ 3 additional warnings
```

* [x] Prioritize in this order, with one rank that is real and unreachable —
  see below the list:

```text
FAIL
security / destructive risk
broken runtime
failing CI
repo divergence
stale state
maintenance
```

`security / destructive risk` has no items. No collector publishes that signal
today, and inventing one to fill the row would be the engine deciding something
about the world. The rank exists in `pulse_attention_rank` because the order is
the contract; when a collector starts reporting risk it has a place to land, and
until then nothing sorts into it. The other six are derived from what an item
already carries — its status, area and subject — because those are the only
things the engine is allowed to read.

* [x] Allow an Attention item to contain an existing `next_command`.
* [x] Require every recommendation to be backed by actual evidence.
* [x] Never convert a technical state into an unsupported decision.

Allowed:

```text
Stack truth is stale
Run: mqlaunch stack truth-export
```

Not allowed:

```text
Merge PR #184 now
```

### Exit gate

* [x] Attention ordering is deterministic. Rank, then the item's own
  `priority`, then area, then subject — with `LC_ALL=C` on the sort, so the
  order does not change with the operator's locale. Held by building the same
  run backwards and requiring the same list.
* [x] Every recommendation has a traceable source: the engine repeats the
  `next_command` an item carried and has no way to produce one. A finding
  without a command renders without an arrow, which the gate asserts by counting
  them.
* [x] No recommendation performs a write automatically. Held structurally as
  well as behaviourally — the gate fails if `attention.sh` ever names `git`,
  `gh`, `uv`, `curl` or a mutation verb. That check is the reason this block
  reads only items: PR 2 and PR 3 each found a defect where a command failed,
  its output was empty, and empty read as healthy. An engine that ran its own
  probes would be a fresh place for that to happen, one level further from the
  contract that gates the collectors.

---

## P1 — `mqlaunch pulse` command surface

Status: Done — the command, the scopes, `--json`, `--plain`, `--no-network`
and `--verbose`, gated by `tests/pulse-machine-surface-smoke.sh`
Priority: P1
Owner: `macos-scripts`

### Tasks

* [x] Add:

```bash
mqlaunch pulse
```

* [x] Add machine-readable output:

```bash
mqlaunch pulse --json
```

One `mq.pulse.v1` document on stdout, exit code unchanged.

* [x] Add scoped views — one area's collector runs, and only that area
  renders. `attention` is the exception: it collects everything and narrows the
  rendering, because a view over every area cannot be scoped to one collector
  without becoming the least informed screen in the product.

```bash
mqlaunch pulse system
mqlaunch pulse repos
mqlaunch pulse stack
mqlaunch pulse memory
mqlaunch pulse git
mqlaunch pulse quality
mqlaunch pulse attention
```

* [x] Add:

```bash
mqlaunch pulse --no-network
```

Network-dependent checks should become `SKIPPED`.

* [x] Add:

```bash
mqlaunch pulse --verbose
```

Show evidence and collector details. Both were already on the item — the flag
prints them rather than collecting anything more.

* [x] Add:

```bash
mqlaunch pulse --plain
```

Stable non-panel output — five tab-separated fields per item, the verdict on a
`#` comment line. `--json` and `--plain` together are refused rather than
resolved by precedence: picking one for the caller is how a pipeline ends up
parsing the other.

* [x] Respect `NO_COLOR=1`.
* [x] Keep JSON stdout free from ANSI and diagnostics — including a delegate that prints a warning line before its own document.
* [x] Preserve stable exit codes.
* [x] Register Pulse in the canonical command registry.
* [x] Keep help, palette, dispatch, README, and `docs/COMMANDS.md` in sync.

### Exit gate

* [x] Direct CLI works.
* [x] Registry and dispatch agree.
* [x] Human and JSON output are covered by tests.
* [x] All exit codes are tested — 0, 1 and 2 driven end to end, 3 in `pulse-contract-smoke.sh`.

---

## P1 — Pulse menu

Status: Done — `terminal/menus/mq-pulse-menu.sh`, gated by
`tests/pulse-menu-smoke.sh`
Priority: P1
Owner: `macos-scripts`

### Goal

Add one compact menu for status inspection and drill-down.

### Menu

```text
╔══════════════════════════════════════════════════════════════╗
║ MQ PULSE // Operator Status                                  ║
╚══════════════════════════════════════════════════════════════╝

OVERVIEW
1. Full Pulse
2. Attention

ENVIRONMENT
3. System
4. Repositories
5. MQ Stack

STATE
6. Memory
7. Git / GitHub
8. Quality

TOOLS
9. Refresh

b. Back
q. Quit
```

### Tasks

* [x] Add `Full Pulse`.
* [x] Add `Attention`.
* [x] Add `System`.
* [x] Add `Repositories`.
* [x] Add `MQ Stack`.
* [x] Add `Memory`.
* [x] Add `Git / GitHub`.
* [x] Add `Quality`.
* [x] Add `Refresh` — which repeats the view the operator last opened rather
  than always returning to the full run. Nothing here caches, so a Refresh that
  meant "run the full view again" would be row 1 under a second name, and the
  repo's inventory gate counts that as a duplication for good reason.
* [x] Keep the menu within the repo's existing menu-size guardrail — nine
  options against a limit of ten, enforced by
  `tests/command-discovery-inventory-smoke.sh` rather than counted here.
* [x] Route drill-down to existing command surfaces rather than implementing duplicate behavior.

### Exit gate

* [x] The menu stays within the existing option-count contract.
* [x] Every menu item routes through the authoritative dispatcher or an approved delegation path.
* [x] No menu item bypasses runtime authority. Every row runs
  `bin/mqlaunch pulse <scope>`, never `tools/scripts/pulse.sh`, so a menu row
  and a typed command are the same thing.

The menu's exit key is `x`, not the `q` sketched above: `read_menu_choice`
prints "or x to exit" and `tests/menu-exit-contract-smoke.sh` holds every menu
to it. A screen offering a key the prompt does not mention would be the
inconsistency this release exists to remove.

The menu holds no status logic, and that is gated structurally as well as by
behaviour — the smoke test fails if the file ever calls `git`, `gh`, `uv` or
`curl`, or names a Pulse state. It is the easiest place in the product to add a
second definition of "healthy", one level above the collectors the contract
gates, so it is the place worth pinning.

---

## P1 — Full Pulse view

Status: Done except a minimal header, deferred past v2.1.0
Priority: P1
Owner: `macos-scripts`

Closed against a run, not against the sketch: `mqlaunch pulse` on `main`,
2026-08-16. Two boxes shipped in a different shape than drawn and say so below;
the header shipped not at all.

### Header

Not built. None of these render, on a TTY or through a pipe, and no total
duration exists anywhere — `--verbose` prints per-item timing only, and
`mq.pulse.v1` has no total key.

**Decided 2026-08-16: build a minimal header when it is built, not this one.**
The case for a header is pasted output — Pulse runs interactively in the repo
you are already standing in, so repo, branch and "just now" are on screen
anyway, and all of it disappears the moment the output is pasted into an issue
for someone else to read. That case needs three fields:

```text
macos-scripts · main · 01:31
```

Host and total duration are not part of it. Neither answers a question a reader
of pasted output is asking, and the sketch's five-line block costs more screen
than the run it describes. They stay listed below, unticked and without an
owner, until something actually asks for them.

* [ ] Show current repo.
* [ ] Show current branch.
* [ ] Show check time.
* [ ] ~~Show host.~~ Deferred — no use case.
* [ ] ~~Show total duration where useful.~~ Deferred — no use case.

Superseded sketch, kept for the record:

```text
MQ PULSE
Host: Zephyr
Repo: macos-scripts
Branch: main
Checked: 01:31
```

### Overall

* [x] Add one simple aggregate state.

One line, plus the exit code that carries the same answer to a caller:
`Pulse: WARN` → 1. Rendered as a footer rather than the `OVERALL` block drawn
below, because the verdict reads better after the evidence than before it.

```text
OVERALL
WARN · 2 items need attention
```

* [x] Avoid introducing a complex health score in v2.1.0.

Held. Four states and nothing else: `PASS`, `WARN`, `FAIL`, `INCOMPLETE`. No
score, no percentage, no weighting — every one of which would have to be
explained before it could be trusted.

### Sections

* [x] `SYSTEM`
* [x] `REPOSITORIES`
* [x] `MQ STACK`
* [x] `MEMORY`
* [x] `GIT / GITHUB`
* [x] `QUALITY`
* [x] `ATTENTION`
* [x] Every item that needs action carries the command that addresses it.

The last one replaces a `NEXT COMMANDS` section. The command sits inline under
the item it fixes (`→ mqlaunch repos status`) instead of in a list at the
bottom, so the reader never has to pair a command back to the problem it
belongs to. `tests/pulse-contract-smoke.sh` step 9 gates the stronger property
this makes possible: every suggested command must resolve against the registry,
so Pulse cannot advise running something that does not exist.

### Default rendering

Example:

```text
SYSTEM
✓ environment
✓ dependencies

REPOSITORIES
✓ 7 clean
! 1 dirty

MQ STACK
✓ 5/5 available

MEMORY
✓ semantic store
! stack truth aging

GIT / GITHUB
! 2 open PRs
✓ CI passing

QUALITY
✓ registry
✓ runtime authority
✓ skills

ATTENTION

1. Stack truth is stale
   Run: mqlaunch stack truth-export

2. 2 pull requests are open
   Run: mqlaunch git
```

### Exit gate

* [ ] The default view fits comfortably in one terminal screen under normal conditions.

Measured at 44 lines on a clean-ish tree, and it grows with every warning. That
fits a full-height window and does not fit an 80×24 default, so the box stays
open rather than being ticked against a generous terminal.

The answer built instead is scoped views (#191): `mqlaunch pulse git` and the
other five each fit anywhere, and the Pulse menu remembers the last one. A full
run is the deliberate wide view, not the one to squeeze.

* [x] Detailed evidence is hidden unless requested.

`--verbose` adds the evidence line and per-item timing; without it neither
appears. Gated in `tests/pulse-collectors-smoke.sh`, which checks both that the
flag shows them and that their absence is real without it.

* [x] Attention is visually more prominent than raw diagnostics.

By construction rather than by styling: the diagnostics are hidden by default,
so what stays on screen is the item, its state and its next command — and
`ATTENTION` then repeats only what needs action. `tests/pulse-attention-smoke.sh`
holds the ordering, and `tests/pulse-machine-surface-smoke.sh` gates that
attention is an exact subset of the section items rather than a second source
of truth.

---

## P1 — Pulse test coverage

Status: Done — seven files, all in `tools/scripts/test-all.sh`
Priority: P1
Owner: `macos-scripts`

Ticked against a test that actually exercises the case, not against a file whose
name suggests it. Two boxes were still open when this block was closed and were
closed by writing the missing test: `--verbose` and failing CI.

### State tests

* [x] `PASS`
* [x] `WARN`
* [x] `FAIL`
* [x] `UNAVAILABLE`
* [x] `SKIPPED`

### Aggregation tests

* [x] Overall PASS.
* [x] Overall WARN.
* [x] Overall FAIL.
* [x] Attention priority ordering.
* [x] Attention deduplication.

### CLI tests

* [x] `mqlaunch pulse`
* [x] `mqlaunch pulse --json`
* [x] `mqlaunch pulse --plain`
* [x] `mqlaunch pulse --verbose` — evidence and timing on demand, absent by
  default, added in PR 7 when this box turned out to be the only untested flag.
* [x] `mqlaunch pulse --no-network`
* [x] Every scoped Pulse command.

### Environment tests

* [x] bash.
* [ ] ~~zsh.~~ N/A — the entrypoint is bash and is always invoked as
  `bash pulse.sh`, so there is no zsh path to test. What is zsh is the launcher
  that dispatches to it, and `tests/menu-shell-guard-smoke.sh` covers that. The
  box stays unticked on purpose: ticking it would claim coverage of a path that
  does not exist. The strikethrough is what says it is settled rather than
  waiting.
* [x] TTY.
* [x] non-TTY.
* [x] `NO_COLOR=1`.

### Failure injection

* [x] GitHub unavailable.
* [x] `mq-agent` unavailable.
* [ ] ~~`mqobsidian` unavailable.~~ N/A — Pulse never reads mqobsidian: memory
  comes from mq-agent, which owns that reading. There is nothing here to inject,
  and the mq-agent case above is the failure that actually reaches Pulse.
* [x] malformed delegated JSON.
* [x] collector timeout.
* [x] dirty repository.
* [x] failing CI — added in PR 7. GitHub's own verdict arrives as `FAIL` and
  names the workflow, which is the other half of the timeout rule: the collector
  may not invent a verdict, and may not drop one it was given.

### Governance tests

* [x] command registry parity.
* [x] docs parity.
* [x] runtime authority.
* [x] test inventory.
* [x] shell lint.

### Exit gate

* [x] Pulse is included in the full selftest suite.
* [x] Failure-path tests prove degraded behavior instead of only happy-path
  rendering — `tests/pulse-degradation-smoke.sh`, whose first three steps are
  exactly that: a gate past its budget is `UNAVAILABLE` rather than `FAIL`, the
  timeout is named so it is not read as an empty answer, and a slow GitHub does
  not become a broken CI. The failure-injection list above is closed apart from
  the one case that cannot occur.

---

## P2 — Interactive drill-down

Status: Declined 2026-08-16 — the constraints landed, the navigation will not
Priority: P2
Owner: `macos-scripts`

**Decision: do not build the handoff.** The model that shipped is the cleaner
one, and it is complete as it stands:

```text
Pulse observes → names the owner → prints a command that resolves
              → the operator chooses to leave Pulse
```

Opening other menus from inside Pulse introduces navigation and back-stack
state to serve a step the operator can already take in one keystroke. The
unticked tasks below stay as the record of what was considered and why it was
not built — not as work waiting to be scheduled.

Reopen only if something concrete asks for it: an operator who cannot act on a
named command, or an area whose owner has no reachable surface at all.

Checked against the menu and a run, 2026-08-16. What shipped in #191 is
adjacent but not this: the Pulse menu drills into **narrower Pulse views**,
not into the surfaces that own each area. Selecting `3. System` runs
`mqlaunch pulse system`; it does not open the doctor.

What Pulse does instead is **name** the owner: every item that needs action
carries the command that addresses it, and
`tests/pulse-contract-smoke.sh` step 9 gates that the command resolves against
the registry. The operator is told exactly where to go, and the command is
guaranteed to exist. That turned out to be the whole answer.

### Tasks

* [ ] System drill-down opens the existing doctor/system surface.
* [ ] Repository drill-down opens the repo hub.
* [ ] Stack drill-down opens the existing stack surface.
* [ ] Memory drill-down opens the existing memory/obsidian surface.
* [ ] Git/GitHub drill-down opens the Git surface.
* [ ] Quality drill-down opens the relevant validation/selftest surface.
* [ ] Attention details may expose:

  * View evidence.
  * Open owning menu.
  * Copy suggested command.
  * Back.

Two of these four exist in another form: evidence is `--verbose`, and the
suggested command is printed under the item rather than copied — which is
better, since a printed command can be gated for existence and a copied one
cannot. `Open owning menu` and its `Back` are the pair being declined; they are
also the only two that would need state to get right.

* [x] Do not duplicate existing command implementations inside Pulse.

Held throughout. Every collector shells out to the command that already owns
the answer — `doctor`, `repos status`, mq-agent, `gh`, the repo's own gates —
and Pulse reports what it got. `mqlaunch/lib/pulse/` contains no second
implementation of anything, which is also why a full run costs 3.8s.

### Exit gate

* [x] Pulse navigation remains thin.

The menu holds no logic: every row runs `mqlaunch pulse <scope>` through the
dispatcher rather than calling the collectors, so a menu row and a typed
command cannot diverge. `tests/pulse-menu-smoke.sh` gates it.

* [x] Existing owners execute existing workflows.

Pulse observes and never acts on repo or stack state: no push, merge, commit or
delete, per `docs/PULSE_CONTRACT.md`. The only writes anywhere in
`mqlaunch/lib/pulse/` are its own scratch files, one per parallel quality probe.
The work stays with the owner in both directions — Pulse asks the owner for the
answer, and hands the operator the owner's command to change anything.

---

## P2 — `mq.pulse.v1` JSON contract

Status: Done — `mqlaunch/lib/pulse/document.sh`, gated by
`tests/pulse-machine-surface-smoke.sh`
Priority: P2
Owner: `macos-scripts`

### Tasks

* [x] Version the public machine contract as:

```text
mq.pulse.v1
```

* [x] Use a stable top-level structure. Two additions to the sketch below, both
  of them the contract's "absence" rule in a data structure: `scope`, and
  `collected` — the areas that actually ran. A section missing from `sections`
  means its collector did not run, never that the area was fine, and without
  `collected` a scoped document reads as five healthy areas. Section keys are
  the item's `area` verbatim (`repositories`, not `repos`): a translation table
  would drop the first area a new collector introduces.

Example:

```json
{
  "schema": "mq.pulse.v1",
  "status": "WARN",
  "summary": {
    "pass": 18,
    "warn": 2,
    "fail": 0,
    "unavailable": 0,
    "skipped": 0
  },
  "sections": {
    "system": [],
    "repos": [],
    "stack": [],
    "memory": [],
    "git": [],
    "quality": []
  },
  "attention": []
}
```

* [x] Guarantee no ANSI in JSON output.
* [x] Send diagnostics to stderr.
* [x] Add schema/contract validation.
* [x] Add fixtures for stable output — `tests/fixtures/pulse/mq.pulse.v1.json`,
  landed with PR 7 (#193). This box was held open on the objection that a golden
  document would pin `duration_ms` and this machine's repo list along with the
  schema, and both halves were answered rather than waived:
  `tests/pulse-degradation-smoke.sh` strips `duration_ms` from every item before
  comparing, and runs against a stub tree, so the repo list is the stub's rather
  than this machine's.
* [x] Test malformed delegate responses — noise before the document leaves the area `UNAVAILABLE`, never empty and never healthy.

### Exit gate

* [x] `mqlaunch pulse --json | jq .` succeeds.
* [x] Human, `--plain` and JSON views represent the same state, and exit alike.
* [x] Contract changes require an explicit schema version decision.

---

## P2 — Pulse performance and degradation

Status: Mostly done — degradation and the local-only target are gated by
`tests/pulse-degradation-smoke.sh`; the full-run target is not met, see below
Priority: P2
Owner: `macos-scripts`

### Goal

Pulse should feel like a status command, not a long-running workflow.

### Measured

M-series Mac, warm `uv` cache, `--json` per scope. Taken before any tuning:

```text
system      132 ms
repos       519 ms
stack      1437 ms      mq-agent through uv
memory     1226 ms      mq-agent through uv, two calls
git        1626 ms      two gh calls
quality    1351 ms      five gates, serial

local-only 1787 ms      --no-network --no-stack
full       5365 ms
```

Two changes came out of that, and nothing else was tuned on a guess:

* the clock was a process. `pulse_now_ms` shelled out to python3 twice per
  collector — fifteen spawns, 287 ms, 16% of a local-only run spent asking what
  time it was. bash 5 publishes `EPOCHREALTIME`; the fallback stays for bash 3.2
  and for locales whose decimal separator is not a point.
* the five quality gates were serial. They are independent and read-only, so
  they now run concurrently and are reported in list order — never the order
  they finish in, which `tests/pulse-degradation-smoke.sh` holds by planting the
  slowest gate second.

```text
quality    1351 ms  →  574 ms
local-only 1787 ms  →  982 ms
full       5365 ms  →  3850 ms
```

### Tasks

* [x] Measure each collector.
* [x] Record collector duration in verbose mode.
* [x] Parallelize independent read-only collectors where safe — the five quality
  gates. Deliberately not the six collectors: two of them shell into mq-agent
  through the same `uv` project, and the item order is the screen's order.
  "Where safe" is doing real work in that sentence.
* [x] Add timeouts to network-dependent collectors.
* [ ] Do not let one slow GitHub request block all other output. Bounded, not
  concurrent: a slow `gh` delays the rest by at most `PULSE_GH_TIMEOUT` and
  costs nothing else — every other area is still collected and rendered. Making
  it genuinely non-blocking needs the collectors themselves parallel, which is
  the change ruled out above.
* [x] Allow local-only execution with `--no-network`.
* [ ] Cache only where a clear TTL exists. Still open, and it may stay open: no
  owner in the stack publishes a TTL for its status, so a cache here would be
  Pulse inventing a freshness claim — the one thing this contract forbids.
* [ ] ~~Mark cached data explicitly.~~ N/A until a cache exists. It is a
  condition on the box above, not work of its own, and it read as a third
  implementation task sitting beside one blocked requirement.
* [ ] ~~Never render stale cached data as live state.~~ N/A until a cache
  exists — currently guaranteed by there being nothing to go stale. If the box
  above is ever unblocked, both of these become its acceptance criteria rather
  than separate items.

### Degradation

```text
timeout   is not   FAIL on the subject
timeout   is       UNAVAILABLE on the observation
```

A gate killed at its budget is not a failing gate, and GitHub not answering is
not broken CI. Before this block, a slow machine reported the repo's own quality
as `FAIL` with "run `mqlaunch selftest`" next to it — the advice being to run the
thing that had just timed out.

| Budget | Seconds | Covers |
| --- | --- | --- |
| `PULSE_COLLECTOR_TIMEOUT` | 10 | doctor, repos, each quality gate |
| `PULSE_STACK_TIMEOUT` | 30 | every mq-agent call, through `uv` |
| `PULSE_GH_TIMEOUT` | 8 | each `gh` call |

The stack budget keeps room for a cold `uv` cache, which is slower than anything
measured here by an order of magnitude. Cutting a first run off would make Pulse
look broken exactly once per dependency change.

### Performance targets

* [x] Local-only Pulse target: `< 1s` — 982 ms measured.
* [ ] Full Pulse target: `< 3s` under normal conditions. 3850 ms measured, and
  not reachable by tuning: 3.4 s of it is four calls to delegates in other repos
  (two `uv`, two `gh`). Reaching it means running the collectors concurrently,
  which is a change to how the run is ordered rather than a bound on how long it
  takes, and it belongs in its own block.

### Exit gate

* [x] A slow external dependency degrades gracefully.
* [x] Local status remains usable during network failure.

---

## P2 — Pulse documentation

Status: Done 2026-08-17 — closed against the tree, having been written
incrementally by the PRs that shipped each surface rather than as one docs pass
Priority: P2
Owner: `macos-scripts`

### Tasks

* [x] Add Pulse to README — `mqlaunch pulse`, `pulse attention` and
  `pulse --json` in the command block.
* [x] Add Pulse to `docs/COMMANDS.md` — the `### Pulse` section.
* [x] Document the Pulse menu — how a menu row and a typed command are the same
  dispatch, and what `Refresh` repeats.
* [x] Document status meanings — the five check states in
  `docs/PULSE_CONTRACT.md`, each with what it claims about the subject.
* [x] Document exit codes — in both files, and the fact that they are the same
  in every output mode.
* [x] Document `mq.pulse.v1` — the schema, and the rule that `collected` is read
  before `sections`.
* [x] Document network-dependent checks — which collectors reach GitHub, and the
  per-call budget.
* [x] Document `--no-network` — including that it marks rather than drops, and
  that `--no-stack` covers `MEMORY` too.
* [x] Document that Pulse is read-only — stated in the contract as an ownership
  rule, not as a promise about the current code.
* [x] Document ownership boundaries — the collector table names the repo that
  owns each signal.

### Exit gate

* [x] README, command reference, registry, help, and dispatcher agree — gated,
  not asserted: `tests/registry-consumer-parity-smoke.sh` checks all four
  consumers against the registry and `tests/command-docs-smoke.sh` checks that
  every command README shows actually dispatches.
* [x] Users can understand why a check is `UNAVAILABLE` or `SKIPPED` — the
  distinction is the contract's opening subject, and the timeout rule spells out
  the case an operator hits most.

---

## Recommended PR sequence for v2.1.0

### PR 1 — Pulse contract

* [x] Architecture and ownership.
* [x] Status model.
* [x] Exit codes.
* [x] Initial tests.
* [x] Free the command word — the diagnostic that held `pulse` is `netpulse`.
  Not on the original list, and it had to come first: every PR below is
  addressed to `mqlaunch pulse`.

### PR 2 — Core collectors

* [x] System.
* [x] Repositories.
* [x] MQ Stack.
* [x] Initial human renderer.
* [x] The canonical item model, which PR 1 did not carry and the collectors
  could not be written without.
* [x] `--json` on `tools/scripts/mq-repos.py status` — the repositories
  collector needed a machine contract to read, and the alternative was parsing
  a screen.

### PR 3 — State collectors

* [x] Memory — semantic store, vector store and stack-truth freshness. The
  held/review queue is not here; see the box in the collector block for why the
  gap is left open rather than guessed at.
* [x] Git/GitHub.
* [x] Quality.
* [x] `--no-network`, which the Git collector needed to be testable and an
  operator needs on a plane. Its place in the `mq.pulse.v1` contract is still
  PR 6's.

### PR 4 — Attention

* [x] Priority model.
* [x] Deduplication — needing `dedupe_key` on the item model, so that merging is
  something a collector states rather than something the engine infers.
* [x] Suggested commands.
* [x] Overall state — already landed with the contract in PR 1; the attention
  list is what the aggregate now points at.

### PR 5 — Pulse menu

* [x] Menu.
* [x] Drill-down — needing the scoped views from the command-surface block,
  since a menu that could only run the full view has nothing to drill into.
* [x] Refresh.
* [x] `--verbose`, from the same block: the drill-down screens are where "why
  does it say that" gets asked, and the evidence was already on the item.

### PR 6 — Machine surface

* [x] `mq.pulse.v1`.
* [x] `--json`.
* [x] `--plain`.
* [x] `--no-network` — landed in PR 3.
* [x] Exit-code tests.

### PR 7 — Performance and polish

* [x] Timeouts — sized from measurement, and a spent budget reports UNAVAILABLE
  with the timeout named.
* [x] Collector timing.
* [x] Degraded-state handling.
* [x] Documentation.
* [x] Full regression verification — the test-coverage block above, closed box
  by box against tests that run.

---

## Definition of Done for v2.1.0

* [x] `mqlaunch pulse` provides one coherent operator status view.
* [x] System, repositories, MQ stack, memory, Git/GitHub, and quality are represented.
* [x] Attention surfaces the most important actionable states.
* [x] Suggested actions only point to existing commands — gated in PR 7. It was
  the one contract rule nothing checked, and the check found `mqlaunch stack
  cockpit`, which resolves only because `stack` declares a delegation. A
  suggestion that does not resolve is worse than none: an operator types it
  before doubting it.
* [x] Pulse performs no mutation — the only write in `mqlaunch/lib/pulse` is the
  `mktemp -d` the quality collector cleans up after itself.
* [x] Pulse duplicates no MQ domain logic.
* [x] Failed dependencies degrade to explicit status rather than crashing the command.
* [x] `mq.pulse.v1` provides a stable machine-readable contract.
* [x] `NO_COLOR`, TTY, non-TTY, and plain output contracts are preserved.
* [x] Command registry, help, palette, dispatch, README, and command docs remain
  synchronized — README was the gap, and closing this box is what found it.
* [x] Full selftest and release checks pass — 84 active tests, shell lint at
  warning severity over 214 files, `release-check --json` READY with no blockers.
* [x] `mqlaunch` remains a thin operator surface.

---

## Post-v2.1.0 — `mqlaunch next`

Status: In progress — the selector and the typed command have shipped; menu
integration is the remaining surface
Priority: P1
Owner: `macos-scripts`

Held out of the v2.1.0 completion gate on purpose — a selector is only worth
building on a substrate that has proven stable, and `mq.pulse.v1` had to ship
first.

```bash
mqlaunch next
mqlaunch next --json
mqlaunch next --plain
mqlaunch next --input FILE
```

It consumes `mq.pulse.v1` rather than performing its own scanning, and returns one deterministic primary next action.

Keep the first version thin: it selects exactly one item from the attention list Pulse already produces, using the priority Pulse already assigns. No second scan, no second risk model, no re-ranking. Anything that ranks differently from Pulse is a second operator model wearing a shorter name.

### Contract — `mq.next.v1` (#203)

Locked before any rendering, so the presentation layer is argued about on top of
settled semantics rather than establishing them by accident.

* [x] Define `mq.next.v1`.
* [x] Select `attention[0]` verbatim — no re-ranking, and in particular no
  skipping an `UNAVAILABLE` head to reach a `FAIL` below it.
* [x] Distinguish `NONE` from could-not-measure. Three absences, three answers:
  an empty attention list from a run that measured something, an empty list from
  an `INCOMPLETE` run, and a document that could not be read.
* [x] Preserve Pulse's exit semantics — the same table, so `$?` from `next` and
  from `pulse` agree about the same finding.
* [x] Echo `scope` and `collected`, so a scoped `NONE` cannot read as a full one.
* [x] Selector performs no scanning — the caller supplies the document.
* [x] Gate it: `tests/next-contract-smoke.sh`, verified failable against three
  planted defects.

### Command surface (#204, #205)

* [x] Add registry entry.
* [x] Add dispatcher route, and the suggestion list.
* [x] Default CLI collects fresh `mq.pulse.v1` — the command is typable without
  the operator producing a document first.
* [x] Pulse's exit code is not control flow. A run that exits `1` or `2` still
  produced a complete document, and that document is the input.
* [x] Add explicit existing-document input — `--input FILE`.
* [x] Add human renderer, reusing Pulse's glyph and colour tables rather than
  defining a second vocabulary.
* [x] Add `--json`.
* [x] Add `--plain` — six fields, always six, with the selection status on the
  row rather than on a `#` comment line, because otherwise `NONE` and
  `UNAVAILABLE` both filter down to zero rows.
* [x] Sync README.
* [x] Sync `docs/COMMANDS.md`, and write `docs/NEXT_CONTRACT.md`.
* [x] Add end-to-end CLI tests — `tests/next-command-smoke.sh`, 10 steps,
  verified failable against six planted defects across two PRs.

### Open

* [ ] Menu integration. Held until the typed command has settled. The open
  design question is where the row belongs: in the Pulse menu, where it reads
  the same document, or in the main menu, where it is its own answer rather than
  a view of Pulse.
* [ ] Reuse a collected document between `pulse` and `next` — see the decision
  below. Blocked on the same freshness contract as the Pulse cache, and
  deliberately not solved from this side.

### Decision 2026-08-17 — repeated collection is accepted

`mqlaunch next` collects fresh Pulse state by default, so running `mqlaunch
pulse` and then `mqlaunch next` by hand pays for the collection twice — about
4s each, most of it calls into other repos. That cost is accepted for now.

Caching the last document would be the obvious fix and is the wrong thing to
build from this side. Reuse needs a freshness contract, and the questions it
opens are Pulse's rather than its consumer's:

```text
how old may the document be
which scope produced it
was --no-network or --no-stack in effect
is it from this repo
```

That is the same TTL/freshness question already held open above, and answering
it inside `next` would settle it by accident for whoever asks next. `--input
FILE` is the reuse path for automation, which is where repeated collection
actually costs something.

```text
Pulse observes -> Attention prioritizes -> Next selects
```

This preserves Pulse as the canonical status substrate and avoids creating another independent operator model.

---

## Most important product decision

Do not make `mqlaunch` bigger.

Make it clearer.

The best version of `mqlaunch` is not the one with the most commands. It is the one where the right command is obvious, the output is predictable, and every deeper responsibility is delegated to the repo that owns it.
