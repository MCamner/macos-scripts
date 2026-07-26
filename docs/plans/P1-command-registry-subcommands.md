# P1 — Subcommand Model for the Command Registry

**Status:** D1–D6 landed; consumer conversion not started
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

* `system`, `release`, `dev`, `help` → `print_command_help "<ns>"`, exit 2, and
  nothing on stderr.
* `obsidian` → hand-written `echo` with a hardcoded usage string, exit 1. Being
  written out by hand is how it drifted: neither it nor `print_namespace_help`
  lists the aliases the branches accept (`doctor`, `open-view`, `navigate`).
* `workspace` → no error from mqlaunch. The word reaches `workspace.sh`, which
  rejects it with exit 1.
* `repos` → its `*` branch is byte-identical to its explicit
  `list|roadmaps|skills|status|wiki-status|diff-summary` branch, so the
  explicit list has no effect whatsoever.

**Correction to an earlier draft of this document:** it listed `git` here as
forwarding an unknown word "as if it were valid". That was wrong.
`open_git_menu` takes an optional **repo path** (`mqlaunch/lib/git-menus.sh:16`),
so `mqlaunch git ~/some/repo` is a supported form and the `*` branch is a
positional argument, not an unknown-subcommand slot. `git` has no closed
subcommand set to police. Verified by running it.

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

### D3 — one unknown-subcommand contract, where mqlaunch owns the set

Unknown subcommand → a diagnostic on stderr, help on stdout, exit 2, no menu.
No hand-written usage strings, because those drift from the branch that
implements them (`obsidian` already has).

The contract applies where **mqlaunch does the routing**: `obsidian`, `system`,
`release`, `dev`, `help`. It deliberately does not apply to four namespaces that
have no closed subcommand set:

* `git` takes an optional repo path.
* `srm` treats an unrecognised first word as the start of the question
  (`tools/scripts/srm.sh:132-143`). Forcing exit 2 here would remove
  `mqlaunch srm <free text>`, which is srm's primary form.
* `repos` and `workspace` let their delegate own the command set. Both already
  produce a diagnostic and a non-zero exit with no menu, so the observable
  contract holds; restating their command lists inside mqlaunch would create a
  second source of truth, which is the drift the registry exists to prevent.

### D4 — one namespace-help mechanism

Every namespace mqlaunch routes goes through the same help route and exits 0.
Namespace help is a successful operation, whether the namespace is `hal` or
`system`. The route uses `print_namespace_help` and falls back to
`print_command_help` for namespaces that only have an entry there — one route,
two text sources, rather than two routes with different exit codes.

Help must also terminate without a terminal. `git help` used to reach
`open_git_menu`, which loops on EOF; routing `help` before the namespace body
removes that path. The remaining EOF loop on *bare* menu invocations
(`mqlaunch git`, `mqlaunch repos`) is a menu-layer defect tracked in #73.

### D5 — the schema is extended only after D1–D4 land

Adding a `subcommands` array now would require per-command fields describing
which dispatch variable, which fallback, and which help mechanism each namespace
uses. That encodes the divergence in the contract and makes it permanent. The
registry states what the surface must be; it is not a survey of what it is.

**Landed.** Each of the nine namespaces with a nested `case "$sub" in` now
carries two fields:

```json
"unknown_subcommand": "reject",
"subcommands": [
  { "name": "perf", "aliases": ["performance"], "summary": "Open the performance menu" }
]
```

`unknown_subcommand` is `reject` when the namespace's `*` branch exits 2 and
`forward` when it hands the word to a delegate — the one thing a consumer must
know before publishing the list as complete. It is derived from dispatch and
checked against it, so it cannot drift into a claim.

The distinction is narrower than "closed vs open" and deliberately so: `repos`
forwards to `mq-repos.py`, which happens to accept exactly the six words the
registry lists. The registry does not know that, and must not imply it. What it
can state is who rejects the word.

The universal `help`, `-h`, `--help` subcommand is not listed per namespace. It
is owned by the single help route at the top of `dispatch_cli_command`, not by
any namespace's case, so listing it per entry would be duplicated state with
nothing to check it against.

### D6 — output modes are held to behaviour, not to a second field

**Landed.** `tests/output-mode-parity-smoke.sh` runs a named subset of the
surface with `--json` and compares the result to the declaration, in both
directions. Two defects were live on `main` at 00e6d40 and both are fixed here.

`skills` declared `"json": true`. `mq-skills.py` has no `--json` flag; argparse
rejects it and exits 2. The dispatcher reinforced the claim with
`[[ "${1:-}" != "--json" ]] && pause_enter`, a special case for a machine mode
that does not exist. The registry now states `"json": false`, and the special
case is gone. **No `--json` support was added to `mq-skills.py`**: this delivery
makes the registry true, and repairing a declaration by building the feature it
described would turn a truth gate into a feature generator.

`system doctor` was the reverse. `mqlaunch system doctor --json` emits a real
`repo_doctor` document, and nothing said so — `system` is `"json": false`, and
subcommands carried no output fields at all. A consumer generating help or docs
from the registry would have hidden a working machine contract.

That is what earns the per-subcommand fields the minimum contract below dropped.
`json` and `output_modes` are now optional on a subcommand entry, must be
declared together, and do not inherit from the parent — `system` is human-only
while `system doctor` is not, and averaging the two would lose the fact. The
validator checks the two fields against each other; the parity gate checks them
against the command.

Neither direction is reachable by static analysis. Grepping scripts for `--json`
was considered and rejected: scripts mention flags they forward rather than
implement, and `mqlaunch system doctor` reaches `doctor.sh` through a path no
grep of the dispatcher would follow. The gate executes.

The exercised subset is 18 invocations, chosen for being cheap and side-effect
free, and it is not the whole surface. What keeps that honest is a coverage
rule: anything declaring `json: true` must be exercised, or must name a test
that covers it. `release-check` takes the one exemption — `release-check --json`
runs `release-check.sh`, which runs this suite, so exercising it here would not
terminate — and the exemption is verified rather than trusted.

#### Observations this delivery deliberately leaves open

* `mqlaunch about --json` emits JSON; `mqlaunch help about --json` renders the
  dashboard. Both are declared correctly, so this is a surface asymmetry, not a
  registry lie.
* `mqlaunch docfunc --json` hangs and exits 124.
* `system time --json` accepts the flag, ignores it, and exits 0. Unhandled
  `--json` has no single contract across the surface: `repos list --json`
  exits 2. Making that uniform is a behaviour change, not a parity fix.

## Minimum contract for consumers

Each subcommand entry carries `name`, `aliases`, and `summary`, plus the
optional `json`/`output_modes` pair D6 added where behaviour demands it.

The wider set (`safety`, `interactive`, `delegates_to`) was considered and
dropped: for the 47 subcommands that exist, those values either repeat the
parent command's or describe a menu function no gate can inspect. A field the
validator cannot check is a field that drifts. They can be added per subcommand
when a consumer needs one and a check can back it — which is exactly how
`json` and `output_modes` arrived.

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

1. Fix the raw-`"${1:-}"` dispatch in `srm` and `repos` (D1). **Done in #76.**
2. Standardise the unknown-subcommand contract and the help route, including
   `git help` (D3, D4). **Done by the subcommand-dispatch convergence PR.**
3. Extend the registry schema with `subcommands` and widen the validator (D5).
   **Done by the registry subcommands PR.**
4. Hold `output_modes` to observed behaviour (D6). **Done by the output-mode
   parity PR.**
5. Convert consumers one at a time, help first.

Steps 1 and 2 were behavioural and had tests written first. Step 3 turned out
not to be mechanical: the honest field was not the one the design assumed, and
naming it cost a rewrite.

Step 4 closed the gap step 3 left open: nothing compared a command's declared
`output_modes` against what it actually does, which is how `release-check` came
to declare `"json": false` while offering JSON (#78). The gate found the same
class of error in both directions — see D6. Consumer work starts now that it is
green: help, palette, and docs can read `json` and `output_modes` as truth
because something executes the commands and fails the build when they diverge.

## Out of scope

* Renaming or removing any command. This document changes dispatch shape, not
  the surface.
* The plain-output contract (#67) and `repo_state` semantics (#66).
* Subcommands of delegated tools. `mq-repos.py` owns its own argument parsing;
  the registry records that `repos` delegates, not what the Python argparse
  accepts.
