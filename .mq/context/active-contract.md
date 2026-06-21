# Active Contract: macos-scripts

## Owns

* `mqlaunch` interactive and direct CLI entrypoints
* macOS workflow menus and launchers
* release-check and repo workflow shortcuts
* HAL, review, and repo-status bridges
* shell-script surface validation

## Does Not Own

* MQ-stack orchestration internals
* repo scoring logic
* durable Obsidian memory
* MCP runtime behavior
* source-repo feature implementation

## Rules

* Treat this file as routing context, not runtime truth.
* Verify current code, tests, CLI behavior, and contracts in the target repo.
* Do not duplicate behavior owned by another MQ repo.
