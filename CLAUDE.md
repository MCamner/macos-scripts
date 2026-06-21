# Claude Instructions For macos-scripts

This repo is part of the MQ stack.

These instructions add MQ memory read-order rules. They do not replace
repo-specific build, test, safety, or release instructions.

## mqobsidian Location

Default local vault path:

`$MQ_OBSIDIAN_DIR`

If `MQ_OBSIDIAN_DIR` is set, prefer that value.

## Read Order

For work related to `macos-scripts`:

0. Read `.mq/context/task-pack.md` if it exists and matches the task.
1. Read `$MQ_OBSIDIAN_DIR/memory/learn/agent/macos-scripts.md` if it exists.
2. Read `$MQ_OBSIDIAN_DIR/systems/macos-scripts/hot.md` if it exists.
3. Read `$MQ_OBSIDIAN_DIR/systems/macos-scripts/index.md` if it exists.
4. Read `$MQ_OBSIDIAN_DIR/memory/learn/repos/macos-scripts.md` if it exists.
5. Read individual pattern notes only if the compressed notes are insufficient.

Stop reading as soon as the task is grounded.

## Low-Token Rules

* Prefer task packs and agent views over full notes.
* Prefer hot/index over pattern notes.
* Do not scan the whole vault by default.
* Do not open multiple pattern notes unless clearly needed.
* Summarize instead of replaying long note bodies.

## Source-Of-Truth Rule

`mqobsidian` is durable memory, not live runtime truth.

If the task depends on current code behavior, tests, contracts, CLI behavior,
or runtime state, verify in this repo before making claims.

## Writing Rules

When creating notes, summaries, or exports:

* separate facts, interpretation, and recommendation
* keep outputs compact
* preserve timestamps and provenance when relevant
* prefer links over duplicated prose
* avoid raw dumps

Do not store or copy secrets, tokens, internal hostnames, raw enterprise logs,
or machine-specific private paths.

## Fallback Rule

If `mqobsidian` is missing, stale, or too weak for the task, say so and verify
in the repo. Do not invent continuity.
