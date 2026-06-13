---
name: release-readiness
description: Use when preparing a macos-scripts release. Validates git state, version sync, changelog, docs, smoke tests, the mqlaunch release-check gate, and the MQ stack contract.
---

# Release Readiness

Validate whether macos-scripts is safe and complete enough for release.

## When to use

* Before tagging, publishing, or announcing a macos-scripts release
* After a milestone to verify version alignment, docs, and gate status
* When the release checklist needs a structured pass

## When not to use

* Regular feature or menu work not bound for immediate release
* Docs-only updates — use `docs-maintainer`
* Command or menu behavior changes — use `mqlaunch-command-surface`
* Releasing another MQ repo — use that repo's own release-readiness skill, or `mq-agent stack release`

## Evals

### Should trigger

* "is macos-scripts ready to release?"
* "run the release check before I tag"
* "what's blocking the next macos-scripts release?"
* "verify version and changelog alignment"

### Should not trigger

* "update the README" → use `docs-maintainer`
* "add an mqlaunch command" → use `mqlaunch-command-surface`
* "release mq-mcp" → use mq-mcp's release-readiness or `mq-agent stack release`
* "polish the release script output" → use `terminal-ui-polisher`

## Always inspect

* `git status --short` — uncommitted or unpushed changes
* `VERSION` vs `CHANGELOG.md` vs latest git tag
* `README.md` version references
* `.mq/repo-contract.json` — `version` must match `VERSION` (the stack contract gate checks this)
* `docs/COMMANDS.md` vs actual command surface
* smoke tests under `tests/`
* `.github/workflows/` CI status

## Verification

The release gate is a command, not a checklist:

```bash
mqlaunch release-check
MQ_REPO_SIGNAL_FAIL_UNDER=16 mqlaunch release-check   # custom threshold
```

Read-only release brief with CI, tags, and doctor summary:

```bash
mqlaunch hal release-brief
```

Stack-level contract gate (validates `.mq/repo-contract.json` across MQ repos):

```bash
mq-agent stack contract-check
```

Smoke tests:

```bash
./tests/hal-command-surface-smoke.sh
./tests/hal-menu-smoke.sh
./tests/hal-menu-layout-smoke.sh
```

## Block release on

* failing `mqlaunch release-check` or smoke tests
* version mismatch between `VERSION`, `.mq/repo-contract.json`, changelog, and README
* missing changelog entry for user-facing changes
* uncommitted changes or unpushed commits
* secrets, `.env` values, or machine-specific paths in tracked files
* contract gate reporting DRIFT or BLOCKED for this repo

## Never

* tag with failing checks
* assume CI is green without checking
* bump `VERSION` without syncing `.mq/repo-contract.json`

## Report format

Return: status (ready/blocked/uncertain), blockers, checks run, checks skipped and why, next concrete action.
