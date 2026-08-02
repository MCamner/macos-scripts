# mqlaunch Runtime Authority

This document defines the stable runtime-governance contract for `mqlaunch`.
It answers two questions:

1. Which path owns command resolution?
2. Which responsibilities may that path own?

The path-by-path inventory is maintained separately in
[AUTHORITY_MAP.md](AUTHORITY_MAP.md). That map records current reachability and
may change during migration. This policy defines the boundary that must remain
true while those paths change.

## Authority decision

The single live runtime authority is:

```text
bin/mqlaunch
  -> terminal/launchers/mqlaunch.sh
       -> terminal/launchers/mqlaunch-command-mode.sh
```

`bin/mqlaunch` is the public executable entrypoint.
`terminal/launchers/mqlaunch.sh` is the runtime coordinator.
`terminal/launchers/mqlaunch-command-mode.sh` owns direct command dispatch when
arguments are present.

The coordinator may source live menus, UI helpers, support libraries, and
documented bridges. Those dependencies do not become alternative runtime
authorities. They implement a concern or delegate a workflow under the
coordinator's control.

## Product boundary

`mqlaunch` is the human terminal entrypoint for the MQ stack:

```text
mqlaunch shows the right workflow
mq-agent owns orchestration
mq-mcp owns execution and review tools
mqobsidian owns durable truth and memory
mq-hal owns local operator summaries
repo-signal owns repo readiness signals
```

The launcher owns terminal UX and routing. It must not absorb responsibilities
owned by deeper MQ repos.

## Allowed responsibilities

The authority-owned runtime may implement:

* argument parsing and global launcher flags
* command and alias lookup
* direct command dispatch
* interactive menu routing
* terminal status and help rendering
* TTY and non-interactive mode selection
* delegation to the owning MQ repo or local tool
* delegated exit-code preservation
* dependency checks and actionable missing-tool errors

Local commands may remain local when they are genuinely launcher concerns, such
as opening a menu, running this repo's doctor or release checks, or presenting
local macOS utilities.

## Forbidden responsibilities

The authority-owned runtime must not implement:

* review cognition or architecture reasoning
* release planning or cross-repo orchestration
* memory ranking, promotion, or durable-memory policy
* repo readiness scoring
* direct `mq-mcp` tool execution when `mq-agent` owns the workflow
* implicit AI fallback for unknown commands
* GitHub mutation without explicit user approval
* delegated business logic duplicated locally in shell

If a feature requires one of these responsibilities, `mqlaunch` must route to
the owning repo instead of implementing a shell equivalent.

## Runtime classes

Every runtime-relevant path must be classified in
[AUTHORITY_MAP.md](AUTHORITY_MAP.md):

* **LIVE** — reachable from a supported entrypoint; fixes for that concern
  belong there.
* **COMPAT** — still reachable, but only to preserve an existing interface
  during migration.
* **DEPRECATED** — not part of the supported runtime and must receive no new
  feature work.
* **TEST-ONLY** — used only by validation or development tooling.

Classification describes reachability, not ownership. A `LIVE` menu or support
library is still subordinate to the single coordinator and dispatcher.

## Compatibility policy

Compatibility paths may:

* preserve existing command names and aliases
* translate arguments without changing their meaning
* forward execution to the authority-owned runtime or an existing legacy
  implementation
* preserve stdout, stderr, and exit status
* emit a clear migration or missing-dependency diagnostic

Compatibility paths must not:

* gain new commands or business behavior
* become a new help, registry, or dispatch source of truth
* call another compatibility path when direct delegation is available
* hide fallback behavior from the authority map
* remain after their documented removal gate is satisfied

There are no compatibility exceptions left. The four that existed are recorded
in [AUTHORITY_MAP.md](AUTHORITY_MAP.md) with what replaced each, and
`scripts/check-runtime-authority.sh` reports zero.

### Frozen paths are outside the lint gate

`tools/legacy/` is excluded from `tools/scripts/lint.sh`, so the enforced
ShellCheck threshold does not cover it. That is a decision, not an oversight:
clearing its findings would mean editing frozen code to satisfy a linter, on a
path this document forbids doing new work on. The freeze is the stronger rule.

`terminal/mqlaunch-v1/` was excluded on the same grounds and reached the end
state that argument named — it was deleted on 2026-08-02, taking four of the
five exempt SC2034 warnings with it. They were colour variables in its
`lib/core.sh` that the scripts sourcing it did read, the same across-a-`source`
blindness that produced 34 of the findings on the live surface. The fifth is in
an archived one-shot patch script written against a launcher that no longer
exists in that form.

A path leaving `tools/legacy/` for a live location enters the gate with it, and
must be clean at warning severity to land.

## Dependency rules

Normal live dependency direction is:

```text
bin/
  -> terminal/launchers/
       -> terminal/menus/
            -> ui/terminal-ui/
            -> mqlaunch/lib/
            -> terminal/bridges/  # documented delegation or compat only
```

Recreating `terminal/mqlaunch-v1/`, or any second runtime under another name, is
forbidden; `scripts/check-runtime-authority.sh` is a tombstone gate that fails on
any shell file naming the deleted tree. New logic in bridges is also forbidden
beyond thin routing or adaptation.

## Command-surface governance

`mqlaunch/lib/command-registry.json` is the canonical command inventory. It
lives on the authority-owned runtime path and is the source used to validate or
generate:

* direct dispatch
* help and command listings
* namespace help
* palette entries
* menu routes
* public command documentation

Legacy paths must never own or extend that registry.

### Retiring an alias

An alias can outlive the reason it was added. Deleting it breaks whoever still
types it; leaving it in `aliases` tells every consumer it is a current name.
`deprecated_aliases` is the third state — still dispatched, no longer part of the
surface a consumer may advertise:

```json
"aliases": ["performance"],
"deprecated_aliases": [
  { "name": "perf-menu", "replacement": "perf" }
]
```

The field is metadata on the alias, not a flag on the command. Retiring an old
spelling says nothing about the command it points at, and a `deprecated: true` on
the entry could not express the difference.

`tools/scripts/validate-command-registry.py` enforces four rules: a deprecated
alias must name a `replacement`, that replacement must be an active command name
or alias and must not itself be deprecated, a word must not be listed as both
active and deprecated, and one word still belongs to exactly one command.
Because a deprecated word is still dispatched, it stays subject to registry
versus dispatch parity like any other.

`tests/registry-consumer-parity-smoke.sh` carries the consumer half: `mqlaunch
help` and the command palette must not offer a deprecated word, while
`docs/COMMANDS.md` may still document one — a reference that records the old
spelling is doing its job. Nothing in the registry is deprecated today; the rules
exist so the first deprecation is stated rather than remembered.

### One dispatcher

`dispatch_cli_command` in `terminal/launchers/mqlaunch-command-mode.sh` is the
only command dispatcher. It answers whether a word was typed at the shell or
chosen from the command palette, and the registry governs all of it.

That was not true until v2.0.0. `terminal/launchers/mqlaunch.sh` carried a
second dispatcher, `run_arg_command`, which answered the palette and accepted 93
words the registry had never modelled — names that worked when chosen and
printed `Unknown command` when typed. That is the ambiguity this release exists
to remove, and the product principle names it directly: a user should never have
to ask whether a command is shown in one place and missing from another.

The gap was closed in three steps:

1. The six the product actually advertised — `tools`, `login`, `shortcuts`,
   `theme`, `guide`, `repo`, all listed by `mqlaunch help` and
   `docs/COMMANDS.md` — moved into the registry and `dispatch_cli_command`. A
   help screen listing a command which does not exist is a defect in the
   command, not in the help.
2. The palette switched to `dispatch_cli_command`, so a palette entry and a
   typed command became the same thing. `run_arg_command` lost its last caller,
   and what remained in it were unadvertised legacy names reachable from
   nothing.
3. The unreachable function was deleted. Its vocabulary is recorded in the
   history of `mqlaunch/lib/legacy-command-vocabulary.txt`, removed in the same
   commit.

A new command belongs in `mqlaunch/lib/command-registry.json` and in
`dispatch_cli_command`. A second dispatcher reappearing anywhere under
`terminal/`, `mqlaunch/` or `ui/` fails
`tests/compat-path-delegation-smoke.sh`: the registry governing the whole
command surface depends on there being one surface to govern.

## Output and failure contract

The authority-owned runtime must preserve these invariants:

* human TTY output may use the shared terminal UI
* non-TTY output must not render dashboards or cursor-control noise
* `NO_COLOR=1` and the global `--no-color` flag must suppress ANSI color
* JSON mode prints only JSON to stdout
* diagnostics go to stderr
* delegated failures preserve the backend exit status
* unknown commands fail clearly and without side effects

All of the invariants above are enforced by
`tests/plain-output-contract-smoke.sh` (#67), which drives the commands rather
than reading the sources: colour is compared with and without `NO_COLOR` under a
pseudo-terminal, and the plain path is compared piped against a real terminal.

The rendering decision lives in one predicate, `mq_wants_plain_output` in
`ui/terminal-ui/mq-ui.sh`, which looks only at stdout. It is deliberately not
`MQ_NO_TUI`: that flag answers "can I prompt?" and takes stdin into account,
while this one answers "will anyone see box drawing?". A human running
`mqlaunch status | less` has a terminal on stdin and still wants plain output.

## Change rule

Before changing launcher routing:

1. identify the owning concern in this policy
2. confirm the path classification in `AUTHORITY_MAP.md`
3. update the authority map if reachability changes
4. keep compatibility changes delegation-only
5. run the runtime-authority and MQ-stack contract checks

Required checks for authority documentation or routing changes:

```bash
tests/runtime-authority-classification-smoke.sh
tests/runtime-authority-freeze-smoke.sh
tests/mq-stack-contract-smoke.sh
./release-check.sh
```

## Removal gate

A compatibility path may be removed only when:

* no live entrypoint reaches it
* its command behavior exists on the authority-owned path or is intentionally
  retired
* compatibility aliases have an explicit migration decision
* help and public docs no longer point to it
* runtime-authority checks pass with a smaller allowlist
* release-check remains green

Until those conditions are proven, compatibility paths remain explicit,
frozen adapters rather than hidden parallel runtimes.
