# Bridges

This folder contains bridge scripts that connect the legacy `mqlaunch` entry points to the newer `mqlaunch-v1` command system.

They exist to support a safe migration path:

- keep the current launcher usable
- route selected commands into v1 modules
- avoid a risky full rewrite

## Purpose

The bridge layer lets the legacy launcher hand off work to the newer modular launcher without forcing the whole system to switch at once.

That means old command paths can stay stable while newer features live in `terminal/mqlaunch-v1/`.

## Files

```text
terminal/bridges/
├── dev-bridge.sh           # routes Dev commands into mqlaunch-v1
├── performance-bridge.sh   # routes Performance commands into mqlaunch-v1
├── tools-bridge.sh         # routes Tools commands into mqlaunch-v1
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
- `open_v1_performance_menu()`
- `run_v1_performance_command()`
- `open_v1_tools_menu()`
- `run_v1_tools_command()`

These functions are sourced into the main launcher and used as routing helpers.

## Why This Layer Matters

Without bridges, moving functionality into `mqlaunch-v1` would require changing the whole launcher at once.

With bridges:

- the legacy launcher can stay stable
- new modules can be developed separately
- commands can migrate one area at a time
- testing is easier because routing is explicit

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
- `mqlaunch-v1/` = newer modular implementation
- `bridges/` = compatibility handoff between the two

## Future Direction

If more modules move into `mqlaunch-v1`, additional bridge scripts can be added temporarily.

Once the migration is complete, the bridge layer can be reduced or removed entirely.
