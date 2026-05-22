---
name: release-readiness
description: Use when preparing a repo release, checking tests, docs, versioning, changelog, Git status, and publish readiness.
---

# Release Readiness

Goal:
Validate whether a repository is safe and complete enough for release.

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
