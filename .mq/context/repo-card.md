---
schema: context-card.v1
repo: macos-scripts
role: macOS workflow launcher and mqlaunch operator entrypoint
updated_at: 2026-06-19T00:00:00Z
---

# Context Card: macos-scripts

## Role

macOS workflow launcher and mqlaunch operator entrypoint.

## Owns

* `mqlaunch` interactive and direct CLI entrypoints
* macOS workflow menus and launchers
* release-check and repo workflow shortcuts
* HAL, review, and repo-status bridges
* shell-script surface validation

## Does not own

* MQ-stack orchestration internals
* repo scoring logic
* durable Obsidian memory
* MCP runtime behavior
* source-repo feature implementation

## Reads from

* local MQ repos under the user workspace
* mq-agent and mq-hal command outputs
* repo-signal readiness outputs
* terminal menu and launcher scripts

## Writes to

* terminal UI output
* local workflow snapshots
* shell launcher state
* no durable memory unless routed through MQ tools

## Use this card when

* task involves `mqlaunch`
* task involves macOS terminal menus
* task touches release-check shortcuts
* task needs launcher-to-repo path boundaries

## Avoid reading unless needed

* unrelated app docs
* old menu screenshots
* full repo READMEs
* generated dependency logs
