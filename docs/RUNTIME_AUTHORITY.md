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

The current compatibility exceptions are listed in
[AUTHORITY_MAP.md](AUTHORITY_MAP.md#the-exact-livelegacy-edges-remove-these-in-step-12)
and enforced by `scripts/check-runtime-authority.sh`.

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

New dependencies from live launchers or menus into
`terminal/mqlaunch-v1/` are forbidden. New logic in bridges is also forbidden
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

### Two dispatchers, one surface

`terminal/launchers/mqlaunch.sh` contains a second dispatcher. The registry
governs one of them:

| Function | Answers when | Governed by |
| --- | --- | --- |
| `dispatch_cli_command` | a word is typed **or chosen from the palette** | the registry |
| `run_arg_command` | never — it has no callers | frozen baseline |

They never knew the same words. `run_arg_command` accepts dozens the registry
has never modelled, and until the palette was rerouted those names worked when
chosen and printed `Unknown command` when typed. That is the ambiguity v2.0.0
exists to remove, and the product principle names it directly: a user should
never have to ask whether a command is shown in one place and missing from
another.

The gap was 93 words, closed in two steps:

1. The six the product actually advertised — `tools`, `login`, `shortcuts`,
   `theme`, `guide`, `repo`, all listed by `mqlaunch help` and
   `docs/COMMANDS.md` — moved into the registry and `dispatch_cli_command`. A
   help screen listing a command which does not exist is a defect in the
   command, not in the help.
2. The palette then switched to `dispatch_cli_command`, so a palette entry and a
   typed command became the same thing. `run_arg_command` lost its last caller.

What remains in it are unadvertised legacy names reachable from nothing.

`run_arg_command` is therefore **compatibility-only and closed for extension**.
Its vocabulary is recorded in `mqlaunch/lib/legacy-command-vocabulary.txt` and
held there by `tests/legacy-vocabulary-freeze-smoke.sh`, which requires an exact
match in both directions: it must not grow, and a word removed from the case
statement must be removed from the baseline in the same commit. Shrinking is the
intended direction.

A new command belongs in the registry and in `dispatch_cli_command`. Adding one
to `run_arg_command` gives it a name that works when selected and fails when
typed, which is the defect, not the feature.

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
