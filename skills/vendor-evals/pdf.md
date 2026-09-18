# MQ evals: pdf (vendored)

`skills/pdf/` is Anthropic's PDF skill, vendored unchanged under its own
licence. Its files are never edited here, so its routing evals live outside the
vendor tree, in this file, and `scripts/check-skills.sh` reads them from here
instead of requiring an `## Evals` section inside the vendored `SKILL.md`.

Integrity of the vendored files is asserted against
`skills/vendor-evals/pdf.sha256`. Regenerate that manifest only when
deliberately re-syncing from upstream, and say which upstream version in the
commit message.

## Evals

### Should trigger

- "fill in this PDF form"
- "extract the form fields from this document"
- "convert these PDF pages to images so I can look at them"
- "check whether this PDF's fillable fields are laid out correctly"

### Should not trigger

- "write the release notes as a PDF" → out of scope for this repo; the release
  flow produces markdown
- "audit the menus and scripts" → use `audit-macos-scripts-menus`
- "score the README for publish readiness" → use `repo-health-brief`

## Boundary

This skill is third-party and repo-agnostic. It carries no macos-scripts
conventions, does not know the mqlaunch command surface, and must not be
extended with MQ-specific steps — those belong in a first-party skill under
`skills/` that calls it.
