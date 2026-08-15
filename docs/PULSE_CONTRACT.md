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

## The item

Every collector returns items of one shape. Five fields are required, five are
optional, and nothing else is accepted — a collector that invents a field name
is refused rather than carried into the document as though the contract allowed
it.

```json
{
  "source": "repos",
  "area": "repositories",
  "status": "WARN",
  "subject": "macos-scripts",
  "summary": "feat/pulse · 3 modified, 1 untracked",
  "evidence": "git status --short",
  "next_command": "mqlaunch repos status",
  "priority": 0,
  "freshness": "just now",
  "duration_ms": 142
}
```

`priority` defaults to 0 and is never derived from the status: ordering belongs
to the attention engine, and putting it in the model would be the one place
nothing could change it. `next_command` must be a command that already exists.

The human screen and the machine document are rendered from the same items, so
the two cannot disagree, and the renderer computes nothing — the glyph follows
the state, never the prose.

## Collectors

| Area | Reads | Owner of the signal |
| --- | --- | --- |
| `SYSTEM` | `tools/scripts/doctor.sh --json` | `macos-scripts` |
| `REPOSITORIES` | `tools/scripts/mq-repos.py status --json` | `macos-scripts` |
| `MQ STACK` | `mq-agent stack status --json` | `mq-agent` |
| `MEMORY` | `mq-agent memory status --json`, `mq-agent stack cockpit --json` | `mq-agent`, `mqobsidian` |
| `GIT / GITHUB` | `git status`, `git rev-list`, `gh pr list`, `gh run list` | local git, GitHub |
| `QUALITY` | the repo's own gates, run one by one | `macos-scripts` |

Each one reads a machine document rather than a screen, because a screen is not
a contract. Each one is bounded by a timeout: a status command that hangs is
worse than one that reports a gap. Each one runs independently — a delegate that
is missing takes its own area to `UNAVAILABLE` and nothing else with it.

### Quality is not a score

`QUALITY` runs five real gates and reports each verdict as its own item:

```text
QUALITY
  ✔ Command registry       passing
  ✖ Runtime authority      failing
      → mqlaunch selftest
  ✔ Skills                 passing
```

It does not add them up. "Some checks passed, so quality is fine" is a verdict
that exists nowhere in this repo, so producing one here would be Pulse inventing
a signal rather than reporting one — the exact thing this contract forbids. A
failing gate names itself, and a gate that is not installed reports
`UNAVAILABLE`, because a check that is not there is not a check that passed.

### What is deliberately missing

The held/review queue is not in `MEMORY`. `mq-agent memory review-status` exists
and is read-only, but prints only for a human — reading it would make mq-agent's
screen layout a contract this repo depends on. Closing that gap needs a
machine-readable mode in mq-agent, and until then the queue is absent rather
than approximated.

Absence is the honest signal. A collector that reports nothing and a subject
that is healthy must never look the same.

### Skipping

`--no-stack` and `--no-network` mark their areas `SKIPPED` rather than dropping
them. `--no-stack` covers `MEMORY` as well as `MQ STACK`, because both spend
mq-agent calls and a flag that skipped one while paying for the other would be
lying about what the run costs.

### Timeouts

Every collector is bounded, and a spent budget is a fact about the observation:

```text
timeout   is not   FAIL on the subject
timeout   is       UNAVAILABLE on the observation
```

GitHub taking too long to answer does not mean CI is broken, and a quality gate
killed at its budget is not a failing gate — reporting one as `FAIL` would put
"run `mqlaunch selftest`" in front of an operator whose selftest is exactly what
timed out. The item names the timeout (`timed out after 8s`) rather than reusing
the wording for a delegate that answered with nothing, because "could not ask"
and "asked, got nothing" send an operator to different places.

The budgets are ceilings on a hang, not performance targets, and they are sized
from measurement — the numbers are in ROADMAP.md:

| Budget | Seconds | Covers |
| --- | --- | --- |
| `PULSE_COLLECTOR_TIMEOUT` | 10 | doctor, repos, each quality gate |
| `PULSE_STACK_TIMEOUT` | 30 | every mq-agent call, through `uv` |
| `PULSE_GH_TIMEOUT` | 8 | each `gh` call |

## What absence means

Four distinctions the collectors are built to keep, and the attention engine
inherits. Each of them was a real defect before it was a rule:

```text
command failed + empty output   is not   healthy
missing collector               is not   healthy
skipped collector               is not   missing collector
unavailable signal              is not   failed subject
```

A directory that was not a git repository reported "Worktree: clean" because
`git status` failed and empty output reads like a clean tree. A collector whose
delegate exits non-zero used to end the whole run. These are the same mistake
wearing different clothes, and the states exist to make it impossible to write
by accident.

## Attention

The attention engine orders the run's findings and shows the first five, with a
count of the rest. It reads Pulse items and nothing else — no command, no file,
no probe of its own. That restriction is what keeps the failure above from
reappearing one level up, further from the collectors this contract gates.

Ordering is the roadmap's, derived from what an item already carries:

```text
FAIL                          any area
security / destructive risk   no collector publishes this yet
broken runtime                system
failing CI                    git · CI
repo divergence               repositories, git worktree, unpushed, PRs
stale state                   memory, stack
maintenance                   everything else
```

Ties break on the item's `priority`, then area, then subject, under `LC_ALL=C` —
so two runs over the same items produce the same list on any machine.

Two rows are the same problem only when a collector said so, through
`dedupe_key`. The repositories and Git collectors both notice this checkout is
dirty, from opposite ends, and both label it `worktree:<repo>`. Items without a
key are never merged: rows that look alike are not evidence that they are one
finding.

The engine repeats a `next_command` an item supplied and cannot produce one.
That is the line between ordering and deciding:

```text
allowed      Stack truth is stale · run mqlaunch stack truth-export
not allowed  Merge PR #184 now
```

## The machine document

`mqlaunch pulse --json` prints one `mq.pulse.v1` document. It is the public
surface: a script may build on these keys, and changing what they mean requires
a new schema version rather than a quiet edit.

```json
{
  "schema": "mq.pulse.v1",
  "status": "WARN",
  "scope": null,
  "collected": ["system", "repositories", "stack", "memory", "git", "quality"],
  "summary": { "pass": 11, "warn": 4, "fail": 0, "unavailable": 0, "skipped": 1 },
  "sections": { "system": [], "repositories": [] },
  "attention": []
}
```

`collected` is the reason a scoped run is safe to consume. A section that is not
in `sections` means its collector did not run — never that the area was fine —
and `collected` is what says which happened. It is recorded by the entrypoint as
each collector runs, not derived from the items, because a collector that ran
and found nothing is a different fact from one that never ran.

A section key is the item's `area` verbatim. A translation table between area
names and document keys would drop the first area a new collector introduces,
which is the one case where silence costs most.

`attention` holds the same item objects that are in `sections`, in the attention
engine's order. It is a view, not a second data kind:
`tests/pulse-machine-surface-smoke.sh` holds every entry to appearing in a
section byte for byte, so the two can never describe the run differently.

`SKIPPED` and `UNAVAILABLE` items are serialized like any other. Dropping them
would make a skipped run and a healthy run the same document, which is the whole
of "What absence means" undone in one line of serializer.

Full and scoped runs use the same schema, and every output mode exits with the
same code. `--plain` prints one tab-separated line per item —
`area, status, subject, summary, next_command` — with the verdict on a `#`
comment line, for the operator who is piping rather than reading.

## Where the rules live

| Rule | Enforced by |
| --- | --- |
| the five check states, and their severity | `pulse_state_is_valid`, `pulse_state_severity` |
| aggregation to an overall state | `pulse_overall_state` |
| overall state to exit code | `pulse_exit_code`, `pulse_run_exit_code` |
| the item shape, and lossless serialization | `pulse_item_add`, `pulse_document` |
| the public machine document | `pulse_document`, `mq.pulse.v1` |
| what needs attention, in what order | `pulse_attention_rank`, `pulse_attention_list` |

The states and exit codes are in `mqlaunch/lib/pulse/model.sh` and the item model
in `mqlaunch/lib/pulse/item.sh`, both on the authority-owned runtime path. They
are gated by `tests/pulse-contract-smoke.sh` and
`tests/pulse-collectors-smoke.sh`.

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
