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

Until the authoritative command registry is implemented, the dispatcher is the
runtime truth for whether a direct command exists. Help, menus, palette entries,
and documentation must be validated against it.

The planned registry must live on the authority-owned runtime path. Once
introduced, it will become the canonical command inventory used to validate or
generate:

* direct dispatch
* help and command listings
* namespace help
* palette entries
* menu routes
* public command documentation

Legacy paths must never own or extend that registry.

## Output and failure contract

The authority-owned runtime must preserve these invariants:

* human TTY output may use the shared terminal UI
* non-TTY output must not render dashboards or cursor-control noise
* `NO_COLOR=1` and supported no-color flags must suppress ANSI color
* JSON mode prints only JSON to stdout
* diagnostics go to stderr
* delegated failures preserve the backend exit status
* unknown commands fail clearly and without side effects

The detailed output contract is tracked separately in the v2.0.0 roadmap. The
colour and JSON invariants above are enforced today by
`tests/plain-output-contract-smoke.sh`; suppressing decorative output on non-TTY
stdout is still open (see issue #67).

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
