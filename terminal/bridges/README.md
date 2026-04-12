# Bridges

This folder contains compatibility bridge scripts between the main `mqlaunch` launcher and `terminal/mqlaunch-v1`.

They exist to support incremental migration:

- keep the current launcher usable
- route selected commands into v1 where no newer replacement exists yet
- preserve stable entrypoints during cleanup

## Current status

Migration is now mixed rather than all-in:

- `dev` uses the newer main-menu implementation
- `tools` now uses the newer main-menu implementation
- `performance` still routes through `mqlaunch-v1`

So the bridge layer is now mostly a compatibility/fallback layer, not the primary path for every migrated area.

## Files

```text
terminal/bridges/
├── dev-bridge.sh           # legacy fallback for old Dev routing
├── performance-bridge.sh   # active bridge for Performance
├── tools-bridge.sh         # legacy fallback for old Tools routing
└── README.md
```

## How They Work

Each bridge:

- builds the path to `terminal/mqlaunch-v1/mqlaunch.sh`
- checks whether the v1 launcher is executable
- runs the matching v1 command if available
- falls back to `bash` if the file exists but is not executable
- prints an error if the v1 launcher is missing

## Current Bridge Functions

Examples from the current files:

- `open_v1_dev_menu()`
- `run_v1_dev_command()`
- `open_performance_menu()`
- `run_performance_command()`
- `open_v1_performance_menu()` (compatibility alias)
- `run_v1_performance_command()` (compatibility alias)
- `open_v1_tools_menu()`
- `run_v1_tools_command()`

These functions are sourced into the main launcher and used as routing helpers when an area still depends on v1 or when an explicit legacy path is retained.

## Why This Layer Matters

Without bridges, migration would require changing the whole launcher in one pass.

With bridges:

- migrated areas can move over one at a time
- non-migrated areas can keep working
- legacy aliases can remain available temporarily
- testing is easier because routing stays explicit

## Design Philosophy

The bridge scripts are intentionally small.

They should:

- do one job only: routing
- avoid business logic
- avoid duplicated menu logic
- stay easy to remove once migration is complete

## Relationship To The Rest Of terminal/

In simple terms:

- `launchers/` = user-facing entry points
- `mqlaunch-v1/` = older modular compatibility layer still used by some routes
- `bridges/` = explicit handoff between the primary launcher and v1

## Future Direction

As more routes move fully into the main launcher, the bridge layer should shrink.

Long term:

- keep only bridges that still serve a real compatibility purpose
- remove dead bridge paths once no command uses them
