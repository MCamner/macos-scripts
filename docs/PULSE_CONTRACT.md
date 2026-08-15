# Pulse contract

`mqlaunch pulse` is the read-only operator cockpit for `macos-scripts` and the
wider MQ stack. It answers three questions in one screen:

```text
Is the environment healthy?
What needs attention?
Which existing command should I run next?
```

This document is the v2.1.0 P0 contract: what Pulse owns, what it must never
own, the states a check may report, and what the command returns to a caller.
The rules that can be executed live in `mqlaunch/lib/pulse/model.sh` and are
held by `tests/pulse-contract-smoke.sh`. The prose here explains them; it does
not restate them as a second source of truth.

## Ownership

`macos-scripts` owns four things in Pulse, and no fifth:

* **collection** — running a read-only command or reading a file that another
  repo already publishes
* **normalization** — turning that output into the state model below
* **rendering** — the human screen and the machine document
* **navigation** — pointing at an existing command the operator can run next

Everything Pulse reports about is owned elsewhere:

| Repo | Owns |
| --- | --- |
| `mq-agent` | orchestration and routing |
| `mq-mcp` | execution and review tools |
| `mqobsidian` | durable truth and memory |
| `mq-hal` | local operator summaries |
| `repo-signal` | repo readiness signals |

Pulse is a view over those signals. It does not become a new source of truth for
any of them, which is the reason it can be added without changing the delegation
boundary in [RUNTIME_AUTHORITY.md](RUNTIME_AUTHORITY.md).

## Forbidden

* **No mutation.** Every collector is read-only. Pulse performs no push, merge,
  checkout, branch change, file write, promotion, or remote state change, and
  neither does anything it runs on the operator's behalf.
* **No new domain logic in shell.** Review, risk, scoring, memory promotion,
  release planning, routing decisions and architecture reasoning stay in the
  repo that owns them. A collector may read a verdict; it may not compute one.
* **No new source of truth.** If a signal is not already published by a repo in
  the table above, Pulse does not invent it — it reports `UNAVAILABLE`.

The line between normalization and domain logic is what a collector does with an
answer it did not get. Mapping another repo's verdict onto `PASS`/`WARN`/`FAIL`
is normalization. Deriving that verdict from raw material because the owning
repo did not offer one is domain logic, and belongs there instead.

## Check states

A single check reports exactly one of five states:

| State | Meaning |
| --- | --- |
| `PASS` | measured, and nothing needs attention |
| `WARN` | measured, and something needs attention |
| `FAIL` | measured, and something is broken |
| `UNAVAILABLE` | could not be measured — the tool, repo or endpoint was not reachable |
| `SKIPPED` | deliberately not measured, because the operator asked for that |

`UNAVAILABLE` is the state this contract exists to protect. A collector whose
dependency is missing must report it rather than return `PASS`, and rather than
disappear from the output: an operator reading a clean screen has to be able to
trust that everything on it was actually measured.

`SKIPPED` is not a quieter `UNAVAILABLE`. It means the operator excluded the
check — `--no-network` and the like — so the run is doing what it was asked.
The difference matters at the exit code: an unreachable check is a warning, an
excluded one is not.

## Overall state and exit codes

The run's state is the worst contribution among its checks:

| Overall | When | Exit |
| --- | --- | --- |
| `PASS` | every contributing check passed | `0` |
| `WARN` | at least one `WARN` or `UNAVAILABLE`, no `FAIL` | `1` |
| `FAIL` | at least one `FAIL` | `2` |
| `INCOMPLETE` | nothing contributed — no checks, or every check `SKIPPED` | `3` |

`UNAVAILABLE` contributes at the `WARN` level. It is not `FAIL`, because failing
to measure something is not the same as measuring it and finding it broken, and
the operator acts on the difference: `FAIL` means fix the subject, `UNAVAILABLE`
means fix the reach.

`SKIPPED` contributes nothing, and a run made entirely of skipped checks is
`INCOMPLETE` rather than `PASS`. Pulse holds no signals of its own, so a run
that collected none knows nothing about the machine — reporting health there
would make the healthiest-looking run the one where every collector failed to
register.

`INCOMPLETE` is an overall state only. No check reports it, and it is the exit
code for Pulse failing at its own job rather than for anything it found.

## Where the rules live

| Rule | Enforced by |
| --- | --- |
| the five check states, and their severity | `pulse_state_is_valid`, `pulse_state_severity` |
| aggregation to an overall state | `pulse_overall_state` |
| overall state to exit code | `pulse_exit_code`, `pulse_run_exit_code` |

All of them are in `mqlaunch/lib/pulse/model.sh`, on the authority-owned runtime
path, and gated by `tests/pulse-contract-smoke.sh`.

Pulse inherits the output contract every other `mqlaunch` command is held to —
`NO_COLOR`, non-TTY plain output, JSON-only stdout, diagnostics on stderr — from
[RUNTIME_AUTHORITY.md](RUNTIME_AUTHORITY.md). It does not restate it, and it
gets no exception from it.

## The command word

`pulse` used to be the Wi-Fi and latency diagnostic. That command still exists,
under the name it describes: `mqlaunch netpulse`, running
`tools/scripts/netpulse.sh`, unchanged apart from the word.

The rename came first because every other piece of v2.1.0 is addressed to
`mqlaunch pulse`, and a repo that spent v2.0.0 removing overlapping command
surfaces should not open v2.1.0 by giving one word two meanings. `pulse` is not
dispatchable while the cockpit is being built; it returns the same unknown-command
error as any other word the registry does not carry, rather than quietly
resolving to the network diagnostic.
