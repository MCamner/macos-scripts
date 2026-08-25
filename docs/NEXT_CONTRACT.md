# `mq.next.v1` — the selection contract

`mqlaunch next` answers one question:

```text
What is the single next thing I should do?
```

It answers it by reading the document `mqlaunch pulse --json` publishes and
returning one item from it. It collects nothing, holds no signals of its own,
and orders nothing.

```text
Pulse observes  ->  Attention prioritizes  ->  Next selects
```

This document is the selection half. The observation half is
[PULSE_CONTRACT.md](PULSE_CONTRACT.md), and everything below assumes its
vocabulary — the five check states, the four overall states, and what absence
means.

## The rule that matters most

**The selector never re-ranks.**

`attention[0]` is the answer, whatever it is. The temptation runs the other way:
an operator asking "what next" wants something concrete, and the head of the
list is sometimes `UNAVAILABLE` — a gap in the observation rather than a broken
subject — while a real `FAIL` sits below it. Skipping past the gap looks like
helpfulness.

It is a second operator model. Two commands in the same repo would then disagree
about what matters most, and the one with the shorter name would win the
argument by being typed more often. If Pulse ranks an observation gap first,
that gap is the next thing to look at: you cannot act on a subject you have
stopped measuring.

```text
allowed      return attention[0]
not allowed  return the first item that looks actionable
```

Ordering belongs to `pulse_attention_rank`. A change to what comes first is a
change to that function, where one edit moves both commands at once.

## Three absences, three answers

An empty `attention` list has more than one cause, and they are not the same
news. This is the distinction `PULSE_CONTRACT.md` keeps between `PASS`,
`SKIPPED` and `UNAVAILABLE`, one level up:

| Input | Meaning | `status` | Exit |
| --- | --- | --- | --- |
| `attention: []`, run status not `INCOMPLETE` | measured, nothing actionable | `NONE` | `0` |
| `attention: []`, run status `INCOMPLETE` | the run measured nothing | `UNAVAILABLE` | `3` |
| document missing, malformed, or a foreign schema | could not reach Pulse | `UNAVAILABLE` | `3` |

The middle row is the one that hides. A run where every check was `SKIPPED` —
`mqlaunch pulse --no-stack --no-network` — publishes a valid, well-formed
document with an empty attention list. A selector reading only `attention`
reports "no next action" about a machine nobody looked at. `status` is what
separates them, so the selector reads both.

```text
empty attention          =  measured nothing actionable
missing or broken Pulse  =  could not measure
```

These two must never produce the same output. An operator who cannot tell them
apart will trust a clean screen that was never filled in.

## Exit codes

The Pulse table, reused rather than reinvented, so a script reading `$?` from
`mqlaunch next` gets the same answer it would get from `mqlaunch pulse` about
the same finding:

| Exit | When |
| --- | --- |
| `0` | `NONE` — nothing needs attention in what was collected |
| `1` | `SELECTED`, and the item is `WARN` or `UNAVAILABLE` |
| `2` | `SELECTED`, and the item is `FAIL` |
| `3` | `UNAVAILABLE` — the document could not be read, or measured nothing |

`3` keeps the meaning it has in Pulse: the command failing at its own job, not
a verdict about anything it found.

`UNAVAILABLE` at exit `1` is deliberate. It is the item's own severity —
`UNAVAILABLE` contributes at the `WARN` level in Pulse — and it does not become
`3` just because the word appears in both tables. An unreachable collector is a
finding the selector returned; an unreadable document is the selector coming
back empty-handed.

## The document

```json
{
  "schema": "mq.next.v1",
  "status": "SELECTED",
  "item": {
    "source": "repos",
    "area": "repositories",
    "status": "WARN",
    "subject": "macos-scripts",
    "summary": "feat/pulse · 3 modified, 1 untracked",
    "evidence": "git status --short",
    "next_command": "mqlaunch repos status",
    "priority": 0
  },
  "scope": null,
  "collected": ["system", "repositories", "stack", "memory", "git", "quality"],
  "collected_at": "2026-08-24T01:52:07+02:00"
}
```

`status` is one of `SELECTED`, `NONE`, `UNAVAILABLE`.

`item` is `attention[0]` **verbatim** — the same object, every key, unchanged.
It is not rebuilt, summarized, or trimmed to the fields a renderer happens to
need. A selector that reshaped the item would be a second place where the item
model is defined, and the two could drift.

`item` is `null` for `NONE` and `UNAVAILABLE`.

`scope` and `collected` are echoed from the Pulse document, not recomputed. A
`NONE` from a scoped run is not the same claim as a `NONE` from a full one:

```text
"nothing needs attention"                            six areas collected
"nothing needs attention in what I collected"        one area collected
```

Without the echo, a consumer reads the second as the first. `collected` is the
only thing that says which happened.

`collected_at` is echoed for the same reason, and reuse is what makes it load
bearing. Without it, an answer selected from a document collected two minutes
ago is indistinguishable from one measured just now, and a consumer has no way
to tell what moment the answer describes.

`reason` appears only on `UNAVAILABLE`, and says which of the failures it was.

## Reuse

`mqlaunch next` with no arguments reuses the last complete Pulse run when there
is one worth reusing, and collects otherwise. Running `mqlaunch pulse` and then
`mqlaunch next` costs one collection rather than two — about 4s, most of it
calls into other repos.

Four conditions, and only one of them is about time:

```text
full scope        a scoped run measured one area, not six
no --no-stack     a run that skipped the stack cannot report on it
no --no-network   the same, one delegate over
young enough      NEXT_MAX_AGE seconds, 120 by default
```

The asymmetry is deliberate. A complete document can answer a narrower question
and a narrow one cannot answer a complete question, so completeness is measured
against what this command always asks for: everything.

The window is declared here, by the reader, and that is the shape the freshness
contract takes rather than an implementation detail:

```text
Pulse publishes the age    it cannot know what the answer is for
next declares its window   it knows exactly what it is about to answer
```

Two minutes is sized to the flow the reuse exists for — look at the cockpit,
then ask what to do about it. `NEXT_MAX_AGE` overrides it, because a script
driving both commands back to back and a person leaving a terminal open are not
the same reader.

Reuse is never silent. The screen says so, with the age and the way to re-ask:

```text
Reused pulse from 41s ago · mqlaunch next --fresh to re-measure
```

The machine modes carry the same fact as `collected_at`, where a consumer reads
it without parsing a sentence. `--fresh` collects unconditionally. `--input FILE`
keeps its meaning and takes precedence over everything here: a caller that named
a document gets that document at any age, and the cache is neither read nor
written — writing it would let any caller install an arbitrary document as this
machine's last observation.

The slot lives under `XDG_CACHE_HOME`, one per checkout. A Pulse document is not
purely a statement about the machine — `QUALITY` is this repo running its own
gates and `GIT` is this worktree — so two checkouts sharing one slot would let
`next` in one answer with an observation of the other.

## What this command does not do

* **It does not scan.** Every fact in its output came from a Pulse document.
* **It does not rank.** See above.
* **It does not invent a `next_command`.** It repeats what the item carries, on
  the same line `PULSE_CONTRACT.md` draws between ordering and deciding:
  `Stack truth is stale · run mqlaunch stack truth-export` is allowed,
  `Merge PR #184 now` is not.
* **It does not run Pulse.** The document is an input. Who produces it, and
  whether it is fresh, is the caller's decision — a selector that shelled out to
  its own source would make every consumer pay for a collection they may already
  have done. The CLI layer above it may collect, and may reuse; the selector
  does neither.
* **It does not publish a TTL.** The reuse window above is this command deciding
  what it will accept, not a claim about how long a Pulse document stays true.
  That distinction is `PULSE_CONTRACT.md`'s and this command is a reader of it.

## Where the rules live

| Rule | Enforced by |
| --- | --- |
| selection is `attention[0]`, verbatim | `next_select`, `tests/next-contract-smoke.sh` |
| the three absences stay distinct | `next_select`, `tests/next-contract-smoke.sh` |
| exit codes | `next_select` |
| the public document | `NEXT_SCHEMA`, `mq.next.v1` |
| when a document may be reused | `next_reusable_age`, `tests/next-reuse-smoke.sh` |
| which runs are worth keeping | `pulse_cache_keeps`, `tests/next-reuse-smoke.sh` |

The selector is `mqlaunch/lib/next/select.sh`, on the authority-owned runtime
path. It inherits the output contract every other `mqlaunch` command is held
to — `NO_COLOR`, non-TTY plain output, JSON-only stdout, diagnostics on
stderr — from [RUNTIME_AUTHORITY.md](RUNTIME_AUTHORITY.md), and gets no
exception from it.

## Status

The selection semantics above are implemented and gated, and so is the command
surface: a registry entry, a dispatcher route, human, `--json` and `--plain`
output, and row 3 of the Pulse menu.

The contract was locked one PR ahead of any of it, deliberately — the rendering
can be argued about, the meaning of an empty answer cannot. Every surface added
since has been a consumer of the rules above rather than a chance to restate
them, which is why `--plain` puts the selection status on the row: the format
had to keep `NONE` and `UNAVAILABLE` apart, and the contract is where that
requirement already lived.
