---
name: repo-health-brief
description: Use when asked for a quick health check, daily repo status, or before deciding what to work on next. Runs repo-signal brief and interprets the output.
---

# Repo Health Brief

Give a fast, actionable health summary of a repository using repo-signal brief.

## When to use

* Before starting a work session on a repo
* Before creating a release
* When asked "what state is this repo in?"
* When triaging what to fix first

## When not to use

* Full release validation — use `release-readiness`
* Acting on the suggestions (docs edits etc.) — use `docs-maintainer`
* Multi-repo stack health — use `mq-agent stack sweep` (mq-agent's `stack-operations` skill)

## Evals

### Should trigger

* "what state is this repo in?"
* "quick health check before I start"
* "what should I fix first here?"
* "run the repo brief"

### Should not trigger

* "is this ready to release?" → use `release-readiness`
* "check health across all MQ repos" → `mq-agent stack sweep`
* "fix the README issues it found" → use `docs-maintainer`

## Steps

1. Run the brief:

```bash
repo-signal brief .
repo-signal brief /path/to/repo
```

1. Read the output:

* **Health score** — repo-signal owns the scale and thresholds; treat a score below the tool's own pass level as "something is missing" (docs, changelog, tests, version sync). Check `repo-signal brief --help` or repo-signal's docs for the current scale rather than assuming fixed numbers.
* **Risks** — any `high` risk needs attention before a release; `medium` is informational
* **Suggestions** — actionable improvements grouped by kind (docs, hygiene, release, testing)
* **Last commit** — confirms which state is being evaluated

1. Decide what to do:

| Signal | Action |
| ------ | ------ |
| Low health score | Run `repo-signal publish-checklist .` to see which checks fail |
| High risks | Inspect with `repo-signal inspect .` for detail |
| Suggestions exist | Run `repo-signal suggest .` for full list with diff previews |
| All clear | Safe to continue with planned work |

## Output formats

```bash
repo-signal brief .                   # terminal summary
repo-signal brief . --format json     # machine-readable brief.v1
repo-signal brief . --format markdown # paste into docs or PR
```

## Never

* Invent risk or suggestion data — always run the command
* Skip the brief if the user asks for repo status
* Assume health without checking
* Hardcode score thresholds from memory — repo-signal's scales change between versions
