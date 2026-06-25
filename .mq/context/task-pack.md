# macos-scripts task pack

Use this pack for MQ-stack-boundary work in `macos-scripts`.

## Contract

`mqlaunch` is a human terminal entrypoint. It may show menus, collect options,
run local checks, and delegate to MQ tools. It must not become the cognition,
review, memory, or orchestration layer.

## Read first

1. `.mq/context/repo-contract.json`
2. `.mq/context/repo-brief.md`
3. `AGENTS.md`
4. `README.md`
5. `docs/architecture/MQ_BOUNDARY.md`
6. `docs/architecture/COMMAND_SURFACE.md`

## Checks

Run `tests/mq-stack-contract-smoke.sh` after changing command routing,
architecture docs, context files, release checks, or public documentation that
mentions MQ-stack boundaries.
