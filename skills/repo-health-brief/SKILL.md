---
name: repo-health-brief
description: Use when asked for a quick health check, daily repo status, or before deciding what to work on next. Runs repo-signal brief and interprets the output.
---

# Repo Health Brief

Goal:
Give a fast, actionable health summary of a repository using repo-signal brief.

## Steps

1. Run the brief:

```bash
repo-signal brief .
```

Or for a specific repo:

```bash
repo-signal brief /path/to/repo
```

2. Read the output:

- **Health score** — if below 14/20 something is missing (docs, changelog, tests, version sync)
- **Risks** — any `high` risk needs attention before a release; `medium` is informational
- **Suggestions** — actionable improvements grouped by kind (docs, hygiene, release, testing)
- **Last commit** — confirms which state is being evaluated

3. Decide what to do:

| Signal | Action |
| ------ | ------ |
| Health < 14 | Run `repo-signal publish-checklist .` to see which checks fail |
| High risks | Inspect with `repo-signal inspect .` for detail |
| Suggestions exist | Run `repo-signal suggest .` for full list with diff previews |
| All clear | Safe to continue with planned work |

## Output formats

```bash
repo-signal brief .                   # terminal summary
repo-signal brief . --format json     # machine-readable brief.v1
repo-signal brief . --format markdown # paste into docs or PR
```

## When to use

- Before starting a work session on a repo
- Before creating a release
- When asked "what state is this repo in?"
- When triaging what to fix first

## Never

- Invent risk or suggestion data — always run the command
- Skip the brief if the user asks for repo status
- Assume health without checking
