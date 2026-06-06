---
name: release-readiness
description: Use when preparing a repo release, checking tests, docs, versioning, changelog, Git status, and publish readiness.
---

# Release Readiness

Goal:
Validate whether a repository is safe and complete enough for release.

## When to use

- Before tagging, publishing, or announcing a macos-scripts release
- After completing mqlaunch or semantic memory changes to verify version and docs alignment

## When not to use

- Regular development or command changes
- Repo health checks — use `repo-health-brief`
- CLI command surface changes — use `mqlaunch-command-surface`

## Evals

### Should trigger

* "is macos-scripts ready to publish?"
* "run the macos-scripts release checklist"
* "what's blocking the next macos-scripts release?"
* "verify version, changelog, and docs before tagging macos-scripts"

### Should not trigger

* "update or add a command template" → use `command-template-library`
* "update the mqlaunch command surface" → use `mqlaunch-command-surface`
* "update docs" → use `docs-maintainer`
* "regular macos-scripts development work" → only needed at release boundaries

Always inspect:

- git status
- VERSION
- CHANGELOG.md
- README.md
- release scripts
- tags
- tests
- docs
- package metadata
- CI workflows

Check for:

- uncommitted changes
- missing changelog entries
- version mismatch
- missing release notes
- broken install instructions
- missing tests
- unpublished artifacts
- unsafe secrets
- inconsistent documentation
- missing rollback path

Prefer:

- concrete terminal commands
- actionable fixes
- minimal safe changes
- verification steps

Never:

- assume release safety
- invent missing files
- ignore failing tests
