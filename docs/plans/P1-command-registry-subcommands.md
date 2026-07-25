# P1 — Subcommand Model for the Command Registry

**Status:** Design — no code change proposed in this document
**Priority:** P1
**Type:** Architecture / Command surface governance
**Owner:** mqlaunch
**Goal:** Decide how subcommands are modelled before any consumer generates
help, palette entries, or docs from the registry.

Linked from [ROADMAP.md](../../ROADMAP.md). Follows
[P1-runtime-authority.md](P1-runtime-authority.md) and the registry foundation
delivered in #71.

## Why this document exists

The registry in `mqlaunch/lib/command-registry.json` covers **top-level**
commands only. The natural next step is to let help, palette, and docs read it
instead of hardcoding their own lists. That step is blocked, and not for a
reason visible from the registry: subcommand dispatch is not one shape. It is
four. A registry that models four shapes describes the current state instead of
constraining it, and every consumer built on top of it inherits the divergence.

So the order is: converge dispatch, then extend the schema, then generate.

## Verified facts (measured against `main` at 6b11b1e, 2026-07-25)

All numbers below come from parsing `case`/`esac` depth in
`terminal/launchers/mqlaunch-command-mode.sh` and from executing the commands.
Indentation in that file is not reliable, so depth tracking — not layout — is
the basis.

* 69 branches in the top-level `case "$area" in` (line 359); 67 real commands
  after excluding `""|menu` and `*`.
* 9 of those branches contain a nested subcommand `case`. The other 60 either
  take no subcommand or pass their arguments straight to a delegate.

| Branch | Line | Dispatches on | Subcommands |
| --- | --- | --- | --- |
| `workspace\|snapshots` | 373 | `$sub` | 5 + `*` |
| `srm\|memory\|repo-memory` | 512 | `"${1:-}"` | 4, no `*` |
| `repos` | 547 | `"${1:-}"` | 2 + `*` |
| `system` | 642 | `$sub` | 10 + `*` |
| `git` | 682 | `$sub` | 1 + `*` |
| `release` | 694 | `$sub` | 4 + `*` |
| `dev` | 716 | `$sub` | 4 + `*` |
| `help\|-h\|--help` | 738 | `$sub` | 8 + `*` |
| `obsidian\|…` | 922 | `$sub` | 5 + `*` |

### Divergence 1 — two dispatch variables, one of them case-sensitive

`sub` is normalised to lowercase at line 333 via `normalize_cli_word`. The
`srm` and `repos` branches `shift` and re-read the **raw** `"${1:-}"`, so they
never see that normalisation. This is user-visible:

```text
mqlaunch system TIME   → works, exit 0 (same 2765 bytes as `system time`)
mqlaunch repos LIST    → mq-repos.py: error: invalid choice: 'LIST'
```

### Divergence 2 — four different answers to an unknown subcommand

* `system`, `release`, `dev`, `help` → `print_command_help "<ns>"`, exit 2.
* `obsidian` → hand-written `echo` with a hardcoded usage string, exit 1. The
  string lists four subcommands; the branch implements five.
* `workspace`, `git` → no error at all. The unknown word is forwarded to the
  handler as if it were valid.
* `repos` → its `*` branch is byte-identical to its explicit
  `list|roadmaps|skills|status|wiki-status|diff-summary` branch, so the
  explicit list has no effect whatsoever.

### Divergence 3 — two namespace-help mechanisms with different exit codes

Line 344 grants `agent hal obsidian repos skills srm stack` a shared
`print_namespace_help` path that exits 0. Namespaces outside that list fall
through to their own `*` fallback instead:

```text
hal|repos|srm|stack|agent|obsidian|skills help   → exit 0, namespace help
system|release|dev help                          → exit 2, command help
workspace help                                   → exit 0, workspace.sh's own help
git help                                         → exit 124 (timeout, see below)
```

Same gesture, four outcomes. `tests/namespace-help-smoke.sh` covers the first
group only, which is why the split has survived.

### Divergence 4 — `mqlaunch git help` does not terminate

`git`'s `*` fallback calls `open_git_menu "help"`. That prints
`Path not found: help`, then opens the interactive GitHub Launchpad and loops
on EOF rather than exiting. With `</dev/null` and a 6-second timeout it emits
12580 bytes and exits 124. This is a hang, not slow output.

### Adjacent finding — delegated exit codes are discarded in 21 branches

29 top-level branches invoke a script under `$BASE_DIR`. 21 of them end in an
unconditional `return 0`, discarding the delegate's status. Confirmed by
execution on two independent branches:

```text
mqlaunch repos LIST                → argparse error on stderr, exit 0
mqlaunch skills no-such-subcommand → argparse error on stderr, exit 0
```

`tests/delegated-exit-code-smoke.sh` covers `review`, `stack status`, and
`hal brief` — the agent and HAL families, which propagate correctly. It does not
reach the 21 branches that do not. This contradicts the v2.0.0 output-contract
exit gate "CI can trust exit codes without parsing terminal text", and is
tracked separately so it does not ride along with a schema change.

## Decisions

### D1 — the normalised `$sub` is the norm; raw `"${1:-}"` is a defect

`srm` and `repos` convert to `$sub`. Case-insensitive command words are already
the contract at the top level; a namespace that quietly opts out of it is a bug,
not a variant worth modelling.

### D2 — a nested `case "$sub"` is the norm, not a special case

`system` is not architecturally special. It is the same shape as `release`,
`dev`, and `obsidian` with more branches — 10 instead of 4. Size is not a reason
for a second pattern. Any command with subcommands uses one nested
`case "$sub"` in the dispatcher; commands without subcommands forward their
arguments and declare no subcommand list.

### D3 — one unknown-subcommand contract

Unknown subcommand → `print_command_help "<namespace>"` on stderr → exit 2.
No hand-written usage strings, because those drift from the branch that
implements them (`obsidian` already has). No silent pass-through, because that
turns a typo into an argument. `repos`'s duplicated `*` branch collapses into
one.

### D4 — one namespace-help mechanism

Every namespace with subcommands gets `print_namespace_help`, exit 0, and the
line-344 allowlist disappears in favour of "has subcommands". Namespace help is
a successful operation; it exits 0 whether the namespace is `hal` or `system`.

### D5 — the schema is extended only after D1–D4 land

Adding a `subcommands` array now would require per-command fields describing
which dispatch variable, which fallback, and which help mechanism each namespace
uses. That encodes the divergence in the contract and makes it permanent. The
registry states what the surface must be; it is not a survey of what it is.

## Minimum contract for consumers

Once D1–D5 are in place, each subcommand entry carries the same fields as a
top-level entry: `name`, `aliases`, `summary`, `safety`, `output_modes`,
`json`, `interactive`, and `delegates_to` when it leaves the repo.

Consumers then hold to three rules:

* Read the registry. Never parse `mqlaunch-command-mode.sh`, and never keep a
  private list. `tests/command-docs-smoke.sh` greps a hardcoded set of eleven
  names today and is the first thing to convert.
* Fail the build on drift rather than rendering partial output. The gate already
  works in both directions for top-level commands (#71) and extends unchanged.
* Take rendering decisions from `interactive` and `output_modes`, not from
  guesswork about the command name.

Three consumers are in scope later, in this order: namespace and command help,
the palette, and generated docs. `.mq/context/command-surface.json` is a fourth,
hand-maintained inventory that nothing currently reads or generates; it is
either generated from the registry or deleted.

## Sequencing

1. Fix the raw-`"${1:-}"` dispatch in `srm` and `repos` (D1).
2. Standardise the unknown-subcommand contract, including `git`'s hang (D3, D4).
3. Extend the registry schema with `subcommands` and widen the validator (D5).
4. Convert consumers one at a time, help first.

Steps 1 and 2 are behavioural and need tests written first. Step 3 is
mechanical once they land. No consumer work starts before step 3 is green.

## Out of scope

* Renaming or removing any command. This document changes dispatch shape, not
  the surface.
* The plain-output contract (#67) and `repo_state` semantics (#66).
* Subcommands of delegated tools. `mq-repos.py` owns its own argument parsing;
  the registry records that `repos` delegates, not what the Python argparse
  accepts.
