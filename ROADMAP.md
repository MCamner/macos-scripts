# Roadmap

Current version: 2.0.0

## Current direction

`macos-scripts` is the human terminal entrypoint for the MQ stack.

The next major product step is:

```text
v2.0.0 — Runtime Authority and Command Surface Governance
```

v1.0.1 established the release-readiness baseline: version, README badge, changelog, and the release gate agree, and the repo can be shipped from a known-good state. That work is done. v2.0.0 is a different problem — runtime authority and drift prevention — and it is about removing ambiguity rather than adding capability.

v2.0.0 shipped on 2026-07-28. Every P0 and P1 block below is Done and its Definition of Done is closed against the tree, with the two stack-level checks noted as out of this repo's reach. What remains is P2 and P3: delegation polish, operator experience, and compatibility cleanup. None of it is release-blocking.

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
  commands it does not route. Their `unknown_subcommand` records that they
  forward, which is what a consumer needs to know before publishing a list as
  complete.

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

Status: In progress — 2 of 5 tasks done, one exit gate closed
Priority: P2
Risk if delayed: Medium
Owner: `macos-scripts`
Primary delegated repo: `mq-agent`

### Problem

`mqlaunch` should feel powerful without becoming powerful in the wrong place.

The front door should make the right workflow easy to find, then hand off to the repo that owns the logic.

### Tasks

* [ ] Review all `mq-agent` delegation commands.

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

  Unchecked because reading them is not reviewing them: the question is whether
  those 118 lines should be flags `mq-agent` parses itself.

* [ ] Add `mqlaunch stack status` alignment with `mq-agent ship status` once `ship status` exists.

  * `mqlaunch` should display or delegate the release cockpit.
  * It should not reimplement release state logic.

  Still blocked, and verified rather than assumed: there is no `ship` command in
  `mq_agent/main.py` as of 2026-08-01. Nothing to align with yet.

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

* [ ] Keep local quick commands local only when they truly belong to the terminal entrypoint.

### Exit gate

* [x] A user can tell which repo owns each command. `mqlaunch help` prints the
  owning repo on every delegated group heading, and the unlabelled default is
  documented. Held by `tests/registry-consumer-parity-smoke.sh` and the
  namespace-owner rule in `validate-command-registry.py`.
* [ ] `mqlaunch` does not duplicate deeper stack logic.

  `tests/mq-stack-contract-smoke.sh` and `docs/architecture/MQ_BOUNDARY.md`
  already hold the boundary that matters — no review, risk, release or memory
  cognition in shell — and it holds. What is unproven is the weaker claim in the
  task above: 118 lines across `_run_agent_review` and `_run_agent_flow` are
  argument translation this repo performs on the delegate's behalf. Not a
  boundary violation, but not nothing either.

---

## P2 — Operator experience polish

Status: Planned
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
  total options                   <= 190    243      299  retired
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

  So the jump from 246 to 299 is the measurement getting honest, not the product
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

  * [ ] <= 190 total options — **retire this target.** It is 299 now against 246
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

Deliberately not checked here, because this repo cannot prove them:

* [ ] `mq-agent` still owns orchestration.
* [ ] `mq-mcp` still owns execution/review tools.
* [ ] `mqobsidian` still owns durable truth and memory.
* [ ] `repo-signal` still owns repo readiness.
* [ ] `mq-hal` still owns local operator summaries.

  `macos-scripts` enforces its own side of the boundary — it delegates rather
  than reimplements, and the boundary tests above fail if that stops being
  true. Whether each of those repos still holds up its side is a claim about
  their trees, not this one. Ticking these from here would be asserting
  something unverified.

* [ ] Contract-check is READY.
* [ ] Stack-preflight has 0 blockers.

  Neither is a `mqlaunch` command: both return `Unknown command`. They are
  stack-level checks that belong to whoever owns them, and this repo has no way
  to run them.

---

## Most important product decision

Do not make `mqlaunch` bigger.

Make it clearer.

The best version of `mqlaunch` is not the one with the most commands. It is the one where the right command is obvious, the output is predictable, and every deeper responsibility is delegated to the repo that owns it.
