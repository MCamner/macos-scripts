# MQ boundary

`macos-scripts` owns the human terminal entrypoint for the MQ stack.

It is a cockpit and launcher: it makes local workflows discoverable, gives the
operator safe shortcuts, and delegates stack behavior to the repos that own it.

```text
mqlaunch shows menu -> delegates -> mq-agent orchestrates -> mq-mcp executes
```

## Owns

* `mqlaunch` menus and command discovery
* local launcher UX
* safe local workflow shortcuts
* operator-facing command surfaces
* release, doctor, and smoke-test entrypoints for this repo

## Delegates

* `mq-agent`: workflow orchestration, stack commands, review routing
* `mq-mcp`: review execution, architecture memory, decision writers
* `repo-signal`: publish readiness and repo quality scoring
* `mqobsidian`: durable memory, context packs, recommendation production
* `mq-hal`: local operator summaries and briefings

## Must not own

* review cognition
* direct mq-mcp tool execution logic
* semantic memory engines
* recommendation ranking or automatic execution
* GitHub write actions without explicit approval
* private machine paths in public docs

When a feature starts needing cognition, ranking, memory promotion, or
cross-repo orchestration, route it through the owning MQ repo instead of growing
`mqlaunch` into an all-in-one control plane.
