---
name: docs-maintainer
description: Use when keeping repository documentation consistent after code, CLI, release, workflow, README, wiki, or GitHub Pages changes. Helps update docs surfaces without inventing behavior.
---

# Docs Maintainer

Keep repository documentation accurate, consistent, and easy to navigate.

## When to use

Use this skill when the user asks to:

- update README, docs, wiki exports, command references, roadmap, changelog, or case pages
- sync documentation after code or CLI changes
- check whether documented commands still match implemented commands
- improve docs discoverability without changing product positioning
- prepare docs for release, publishing, or GitHub Pages
- explain what docs need to change after a feature or bug fix

## Core rule

Document only behavior that exists or is intentionally being added in the same change.

If a command, flag, file, workflow, page, or release process cannot be confirmed from the repo, say so and either inspect it or leave it out.

## Inspection order

Check the relevant docs surface first, then verify against implementation:

1. `README.md`
2. `docs/`
3. wiki export files, if present
4. `CHANGELOG.md`
5. `ROADMAP.md`
6. CLI entrypoints, scripts, workflow files, or source files related to the docs claim
7. tests or smoke checks for the documented workflow

## What to check

- command names, aliases, flags, examples, and exit behavior
- install and quick-start steps
- file paths and generated artifacts
- GitHub Pages links and screenshots
- release/version/changelog consistency
- docs that mention removed or renamed behavior
- duplicate docs that may drift apart
- broken internal links
- stale future-tense roadmap items that are now shipped

## Editing guidance

Prefer small docs edits that remove ambiguity.

Keep examples copy-pasteable and grounded in repo commands. When docs and code disagree, either fix the docs or flag the code/docs mismatch clearly before changing both.

Do not turn docs into marketing unless the request is product-positioning work; use `repo-product-auditor` for that.

## Output

When reporting, include:

- docs surfaces checked
- mismatches found
- files changed
- commands or checks run
- anything left unverified

