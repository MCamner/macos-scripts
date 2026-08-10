# Skills

macos-scripts ships local skills for maintaining mqlaunch, terminal UX, docs,
vector-store memory and release readiness.

The table below is generated from SKILL.md frontmatter by
`./scripts/check-skills.sh --fix`. Do not edit it by hand.

Note: `command-template-library` moved to the mq-ums repo
(`mq-ums/skills/command-template-library/`), where the contracts and generator
it documents actually live.

## Built-in skills

<!-- BEGIN GENERATED SKILLS TABLE -->
| Skill | Description |
| ----- | ----------- |
| [branch-supersede-check](skills/branch-supersede-check/SKILL.md) | Decide whether an unmerged branch still holds work that trunk does not have, before deleting or reviving it. Compares every touched file against main as it is now, instead of trusting the three-dot diff — which looks identical for a branch carrying real work and one whose work already landed by another route. Use when a branch looks unmerged but might be superseded, when triaging stale branches, or when `git diff main...branch` shows changes and you need to know whether they still matter. |
| [docs-maintainer](skills/docs-maintainer/SKILL.md) | Use when keeping repository documentation consistent after code, CLI, release, workflow, README, wiki, or GitHub Pages changes. Helps update docs surfaces without inventing behavior. |
| [mqlaunch-command-surface](skills/mqlaunch-command-surface/SKILL.md) | Use when changing macos-scripts mqlaunch commands, terminal GUI menus, HAL routing, command aliases, help text, or CLI/TUI command-surface behavior. |
| [mqlaunch-menu-template](skills/mqlaunch-menu-template/SKILL.md) | > |
| [release-readiness](skills/release-readiness/SKILL.md) | Use when preparing a macos-scripts release. Validates git state, version sync, changelog, docs, smoke tests, the mqlaunch release-check gate, and the MQ stack contract. |
| [repo-health-brief](skills/repo-health-brief/SKILL.md) | Use when asked for a quick health check, daily repo status, or before deciding what to work on next. Runs repo-signal brief and interprets the output. |
| [terminal-ui-polisher](skills/terminal-ui-polisher/SKILL.md) | Improve terminal GUI menus, CLI, TUI, ASCII, ANSI, and command-surface interfaces with focus on clarity, hierarchy, keyboard flow, spacing, status feedback, and product-level polish. |
| [vector-store-maintainer](skills/vector-store-maintainer/SKILL.md) | Use when maintaining OpenAI vector stores, knowledge packs, indexed markdown, file_search sources, or repo memory freshness across projects. Distinct from mq-mcp's semantic-memory-maintainer, which owns repo packs. |
<!-- END GENERATED SKILLS TABLE -->
